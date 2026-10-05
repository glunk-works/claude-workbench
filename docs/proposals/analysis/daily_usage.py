"""Daily usage envelope from local transcripts (main sessions + subagents), de-duplicated across
the mirrored claude-workbench project dirs. Prints per-day totals for the last N days and the
median per-session cost of 'coder-shaped' vs 'review-shaped' sessions by model."""
import json, os, sys, glob, statistics
from collections import defaultdict

root = os.path.expanduser('~/.claude/projects')
days_back = int(sys.argv[1]) if len(sys.argv) > 1 else 14
SKIP_DIR = 'c--users-sr116-projects-personal-claude-workbench'  # mirror of the glunk-works dir
day = defaultdict(lambda: defaultdict(float))
sess = []
seen = set()

def turns(path):
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            try: o = json.loads(line)
            except Exception: continue
            if o.get('type') != 'assistant': continue
            m = o.get('message') or {}; u = m.get('usage')
            if not u: continue
            key = (m.get('id'), u.get('output_tokens'))
            if m.get('id') and key in seen: continue
            seen.add(key)
            yield (o.get('timestamp') or '')[:10], m.get('model', '?'), u

for d in sorted(os.listdir(root)):
    if d.lower() == SKIP_DIR: continue
    pd = os.path.join(root, d)
    if not os.path.isdir(pd): continue
    for f in glob.glob(os.path.join(pd, '**', '*.jsonl'), recursive=True):
        is_sub = os.path.dirname(f) != pd
        s = defaultdict(float); first = None; models = defaultdict(int)
        for ts, model, u in turns(f):
            if not ts: continue
            first = ts if first is None or ts < first else first
            cr = u.get('cache_read_input_tokens') or 0; cw = u.get('cache_creation_input_tokens') or 0
            out = u.get('output_tokens') or 0
            fam = 'opus' if 'opus' in model else 'sonnet' if 'sonnet' in model else 'fable' if 'fable' in model else 'haiku' if 'haiku' in model else 'other'
            day[ts]['turns'] += 1; day[ts]['cache_read'] += cr; day[ts]['cache_write'] += cw; day[ts]['output'] += out
            day[ts]['sub_turns' if is_sub else 'main_turns'] += 1
            day[ts]['cr_' + fam] += cr
            s['cr'] += cr; s['out'] += out; s['turns'] += 1; models[fam] += 1
        if first and s['turns']:
            sess.append((first, 'sub' if is_sub else 'main', max(models.items(), key=lambda x: x[1])[0], s['cr'], s['out'], s['turns']))

dates = sorted(day)[-days_back:]
print(f'{"day":10s} {"sess":>4s} {"turns":>6s} {"main":>6s} {"sub":>6s} {"cache_rd":>9s} {"cache_wr":>8s} {"output":>7s}  cr_opus  cr_sonnet  cr_fable')
tot = defaultdict(float)
for dt in dates:
    v = day[dt]; n = sum(1 for s in sess if s[0] == dt)
    print(f'{dt} {n:4d} {int(v["turns"]):6d} {int(v["main_turns"]):6d} {int(v["sub_turns"]):6d} {v["cache_read"]/1e6:8.0f}M {v["cache_write"]/1e6:7.1f}M {v["output"]/1e6:6.2f}M  {v["cr_opus"]/1e6:6.0f}M  {v["cr_sonnet"]/1e6:7.0f}M  {v["cr_fable"]/1e6:6.0f}M')
    for k, x in v.items(): tot[k] += x
nd = len(dates) or 1
print(f'{"mean/day":10s} {len([s for s in sess if s[0] in dates])/nd:4.0f} {tot["turns"]/nd:6.0f} {tot["main_turns"]/nd:6.0f} {tot["sub_turns"]/nd:6.0f} {tot["cache_read"]/nd/1e6:8.0f}M {tot["cache_write"]/nd/1e6:7.1f}M {tot["output"]/nd/1e6:6.2f}M  {tot["cr_opus"]/nd/1e6:6.0f}M  {tot["cr_sonnet"]/nd/1e6:7.0f}M  {tot["cr_fable"]/nd/1e6:6.0f}M')

recent = [s for s in sess if s[0] in dates]
print('\nper-session median (cache_read, output, turns) by kind/model, last %d days:' % days_back)
groups = defaultdict(list)
for s in recent: groups[(s[1], s[2])].append(s)
for k, g in sorted(groups.items(), key=lambda x: -len(x[1])):
    cr = statistics.median(x[3] for x in g); out = statistics.median(x[4] for x in g); tu = statistics.median(x[5] for x in g)
    print(f'  {k[0]:4s} {k[1]:6s} n={len(g):4d}  cache_rd {cr/1e6:6.1f}M  out {out/1e3:5.0f}k  turns {tu:4.0f}  (p90 cache_rd {sorted(x[3] for x in g)[int(0.9*(len(g)-1))]/1e6:.1f}M)')
