"""Sum Claude Code transcript usage per project and per session.

Reads ~/.claude/projects/<proj>/*.jsonl. Each assistant turn carries message.usage with
input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens and
message.model. Sidechain lines (subagents) are flagged isSidechain. Nothing is modified.
"""
import json, os, sys, glob, statistics
from collections import defaultdict
from datetime import datetime

root = os.path.expanduser('~/.claude/projects')
since = sys.argv[1] if len(sys.argv) > 1 else '2026-09-01'
projects = defaultdict(lambda: defaultdict(float))
sessions = []
models = defaultdict(lambda: defaultdict(float))
seen_msg = set()

def short(p):
    p = p.lower()
    for k in ('claude-workbench', 'devcontainers', 'infrastructure-core', 'jrg-consulting-site',
              'terraform-cloudflare-dns', 'trust-anchors', 'bounty-infra', 'bedrock-serverless-rag',
              'terraform-microsoft365-entra', 'checkov-ledger-action', 'global-bootstrap'):
        if k in p: return k
    return 'other'

for d in sorted(os.listdir(root)):
    pd = os.path.join(root, d)
    if not os.path.isdir(pd): continue
    name = short(d)
    for f in glob.glob(os.path.join(pd, '*.jsonl')):
        s = defaultdict(float); s['turns'] = 0; s['side_turns'] = 0
        first = last = None; mdl = defaultdict(int); tools = 0; compactions = 0
        try:
            with open(f, encoding='utf-8', errors='replace') as fh:
                for line in fh:
                    try: o = json.loads(line)
                    except Exception: continue
                    t = o.get('timestamp')
                    if t:
                        if first is None or t < first: first = t
                        if last is None or t > last: last = t
                    if o.get('type') == 'summary' or (o.get('type') == 'system' and 'compact' in str(o.get('content', ''))[:200].lower()):
                        compactions += 1
                    if o.get('type') != 'assistant': continue
                    m = o.get('message') or {}
                    u = m.get('usage')
                    if not u: continue
                    mid = m.get('id')
                    key = (mid, u.get('output_tokens'))
                    if mid and key in seen_msg: continue  # streamed duplicates share an id
                    seen_msg.add(key)
                    side = bool(o.get('isSidechain'))
                    s['turns'] += 1
                    if side: s['side_turns'] += 1
                    for k in ('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens'):
                        v = u.get(k) or 0
                        s[k] += v
                        s[('side_' if side else 'main_') + k] += v
                    mdl[m.get('model', '?')] += 1
                    for blk in m.get('content') or []:
                        if isinstance(blk, dict) and blk.get('type') == 'tool_use': tools += 1
                    mm = m.get('model', '?')
                    for k in ('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens'):
                        models[mm][k] += u.get(k) or 0
        except Exception as e:
            print('skip', f, e, file=sys.stderr); continue
        if not first or first < since or s['turns'] == 0: continue
        dur_h = (datetime.fromisoformat(last.replace('Z', '+00:00')) - datetime.fromisoformat(first.replace('Z', '+00:00'))).total_seconds() / 3600
        main_model = max(mdl.items(), key=lambda x: x[1])[0] if mdl else '?'
        s.update(project=name, file=os.path.basename(f)[:8], first=first[:16], hours=dur_h, model=main_model, tools=tools, compactions=compactions)
        sessions.append(s)
        for k in ('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens', 'turns', 'side_turns', 'side_cache_read_input_tokens', 'side_output_tokens'):
            projects[name][k] += s[k]
        projects[name]['sessions'] += 1
        projects[name]['hours'] += dur_h

def M(x): return f'{x/1e6:7.1f}M'
print(f'Sessions since {since}: {len(sessions)}\n')
print(f'{"project":26s} {"sess":>4s} {"hours":>6s} {"turns":>6s} {"fresh_in":>9s} {"cache_wr":>9s} {"cache_rd":>9s} {"output":>9s}  rd/turn  side%turns')
for name, p in sorted(projects.items(), key=lambda x: -x[1]['cache_read_input_tokens']):
    print(f'{name:26s} {int(p["sessions"]):4d} {p["hours"]:6.1f} {int(p["turns"]):6d} {M(p["input_tokens"])} {M(p["cache_creation_input_tokens"])} {M(p["cache_read_input_tokens"])} {M(p["output_tokens"])}  {p["cache_read_input_tokens"]/max(p["turns"],1)/1000:5.0f}k  {100*p["side_turns"]/max(p["turns"],1):4.0f}%')
tot = defaultdict(float)
for p in projects.values():
    for k, v in p.items(): tot[k] += v
print(f'{"TOTAL":26s} {int(tot["sessions"]):4d} {tot["hours"]:6.1f} {int(tot["turns"]):6d} {M(tot["input_tokens"])} {M(tot["cache_creation_input_tokens"])} {M(tot["cache_read_input_tokens"])} {M(tot["output_tokens"])}')

print('\nBy model (all time in these files):')
for mm, u in sorted(models.items(), key=lambda x: -x[1]['cache_read_input_tokens']):
    print(f'  {mm:36s} fresh {M(u["input_tokens"])} cache_wr {M(u["cache_creation_input_tokens"])} cache_rd {M(u["cache_read_input_tokens"])} out {M(u["output_tokens"])}')

print('\nSession distribution (cache_read tokens per session, the context-size proxy):')
cr = sorted(s['cache_read_input_tokens'] for s in sessions)
print(f'  median {M(statistics.median(cr))}  p75 {M(cr[3*len(cr)//4])}  p90 {M(cr[9*len(cr)//10])}  max {M(cr[-1])}')
turns = sorted(s['turns'] for s in sessions)
print(f'  turns/session: median {statistics.median(turns):.0f}  p90 {turns[9*len(turns)//10]}  max {turns[-1]}')
top = sorted(sessions, key=lambda s: -s['cache_read_input_tokens'])[:12]
print('\nTop 12 sessions by cache-read volume:')
print(f'  {"project":22s} {"start":16s} {"hrs":>5s} {"turns":>5s} {"side":>5s} {"cache_rd":>9s} {"output":>9s} {"peak_ctx":>9s} model')
for s in top:
    peak = s['cache_read_input_tokens'] / max(s['turns'] - s['side_turns'], 1)
    print(f'  {s["project"]:22s} {s["first"]:16s} {s["hours"]:5.1f} {int(s["turns"]):5d} {int(s["side_turns"]):5d} {M(s["cache_read_input_tokens"])} {M(s["output_tokens"])} {M(peak)} {s["model"]}')
share_top = sum(s['cache_read_input_tokens'] for s in top) / max(tot['cache_read_input_tokens'], 1)
print(f'\nTop 12 sessions = {100*share_top:.0f}% of all cache-read tokens since {since}.')
