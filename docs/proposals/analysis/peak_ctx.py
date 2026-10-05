"""Per-session peak context (max over turns of input+cache_write+cache_read) and
how much of each session's cache-read volume comes from turns above 150k context.
Also sums any subagent transcripts found under <project>/<session>/subagents or similar."""
import json, os, sys, glob, statistics
from collections import defaultdict

root = os.path.expanduser('~/.claude/projects')
since = sys.argv[1] if len(sys.argv) > 1 else '2026-09-01'
rows = []
sub_tot = defaultdict(float); sub_files = 0

def walk(fh):
    seen = set()
    for line in fh:
        try: o = json.loads(line)
        except Exception: continue
        if o.get('type') != 'assistant': continue
        m = o.get('message') or {}; u = m.get('usage')
        if not u: continue
        key = (m.get('id'), u.get('output_tokens'))
        if m.get('id') and key in seen: continue
        seen.add(key)
        yield o.get('timestamp', ''), m.get('model', '?'), u

for d in sorted(os.listdir(root)):
    pd = os.path.join(root, d)
    if not os.path.isdir(pd): continue
    for f in glob.glob(os.path.join(pd, '*.jsonl')):
        ctx = []; cr = 0; cr_big = 0; first = None; mdl = defaultdict(int)
        with open(f, encoding='utf-8', errors='replace') as fh:
            for t, model, u in walk(fh):
                if first is None or t < first: first = t
                c = (u.get('input_tokens') or 0) + (u.get('cache_creation_input_tokens') or 0) + (u.get('cache_read_input_tokens') or 0)
                ctx.append(c); cr += u.get('cache_read_input_tokens') or 0
                if c > 150_000: cr_big += u.get('cache_read_input_tokens') or 0
                mdl[model] += 1
        if not ctx or not first or first < since: continue
        rows.append((d, first[:16], len(ctx), max(ctx), statistics.median(ctx), cr, cr_big, max(mdl.items(), key=lambda x: x[1])[0]))
    # subagent transcripts, if stored as nested files
    for f in glob.glob(os.path.join(pd, '**', '*.jsonl'), recursive=True):
        if os.path.dirname(f) == pd: continue
        sub_files += 1
        with open(f, encoding='utf-8', errors='replace') as fh:
            for t, model, u in walk(fh):
                if t and t < since: continue
                for k in ('cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens'):
                    sub_tot[k] += u.get(k) or 0
                sub_tot['turns'] += 1
                sub_tot['model:' + model] += 1

rows.sort(key=lambda r: -r[5])
tot_cr = sum(r[5] for r in rows); tot_big = sum(r[6] for r in rows)
peaks = sorted(r[3] for r in rows)
print(f'sessions {len(rows)}; peak context per session: median {peaks[len(peaks)//2]/1000:.0f}k, p75 {peaks[3*len(peaks)//4]/1000:.0f}k, p90 {peaks[9*len(peaks)//10]/1000:.0f}k, max {peaks[-1]/1000:.0f}k')
print(f'sessions whose peak context exceeded 150k: {sum(1 for p in peaks if p > 150_000)}; share of all cache-read tokens spent on turns above 150k context: {100*tot_big/max(tot_cr,1):.0f}%')
print('\ntop 10 sessions: project | start | turns | peak ctx | median ctx | cache_rd | model')
for r in rows[:10]:
    print(f'  {r[0][-34:]:34s} {r[1]} {r[2]:4d} {r[3]/1000:6.0f}k {r[4]/1000:6.0f}k {r[5]/1e6:7.1f}M {r[7]}')
print(f'\nnested (subagent) transcript files found: {sub_files}')
if sub_files:
    print('  ' + ', '.join(f'{k}={v/1e6:.1f}M' if 'tokens' in k else f'{k}={int(v)}' for k, v in sorted(sub_tot.items())))
