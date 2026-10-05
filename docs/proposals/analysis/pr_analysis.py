import json, sys, re, statistics
from datetime import datetime

CURSOR = re.compile(r'^(docs\(cursor\)|docs: sync cursor|docs: park|docs: anchor|docs: sync \.ai)')
RECORD = re.compile(r'^(docs: mark|docs\(roadmap\)|docs\(sprint|docs\(decisions\)|docs\(ledger\)|docs\(sprint\d+\)|chore\(release\)|chore\(claude\)|chore\(ai\)|chore: bump this repo|docs: record|docs: add the missing)')
DEPS = re.compile(r'^(build\(deps\)|chore\(deps\))')

def cls(t):
    if CURSOR.match(t): return 'cursor'
    if RECORD.match(t): return 'record/release'
    if DEPS.match(t): return 'dependabot'
    return 'work'

def ts(s): return datetime.fromisoformat(s.replace('Z', '+00:00'))

for path in sys.argv[1:]:
    prs = json.load(open(path, encoding='utf-8'))
    name = path.split('/')[-1].replace('-prs.json', '')
    print(f'\n######## {name}  ({len(prs)} PRs, {prs[-1]["createdAt"][:10]} .. {prs[0]["createdAt"][:10]})')
    counts = {}
    for p in prs:
        c = cls(p['title'])
        counts.setdefault(c, [0, 0])
        counts[c][0] += 1
        if p['mergedAt']: counts[c][1] += 1
    for k, (n, m) in sorted(counts.items(), key=lambda x: -x[1][0]):
        print(f'  {k:16s} {n:4d} PRs  {m:4d} merged')
    work = [p for p in prs if cls(p['title']) == 'work' and p['mergedAt']]
    cur = [p for p in prs if cls(p['title']) == 'cursor']
    if work:
        mins = sorted(((ts(p['mergedAt']) - ts(p['createdAt'])).total_seconds() / 60 for p in work))
        print(f'  work PR open->merge minutes: median {statistics.median(mins):.0f}, p25 {mins[len(mins)//4]:.0f}, p75 {mins[3*len(mins)//4]:.0f}, max {mins[-1]:.0f}  (n={len(mins)})')
        sizes = sorted(p['additions'] + p['deletions'] for p in work)
        print(f'  work PR size (+/- lines): median {statistics.median(sizes):.0f}, p75 {sizes[3*len(sizes)//4]}')
        print(f'  cursor PRs per work PR: {len(cur)/len(work):.2f}')
    # Day-by-day cadence: PRs merged per calendar day, and the busiest days
    days = {}
    for p in prs:
        if p['mergedAt']:
            d = p['mergedAt'][:10]
            days.setdefault(d, [0, 0])
            days[d][0] += 1
            if cls(p['title']) == 'work': days[d][1] += 1
    busy = sorted(days.items(), key=lambda x: -x[1][0])[:5]
    print('  busiest days (merges total/work): ' + ', '.join(f'{d} {t}/{w}' for d, (t, w) in busy))
    # Gaps between consecutive merges on the busiest day: how long the human waits between touches
    if busy:
        d0 = busy[0][0]
        times = sorted(ts(p['mergedAt']) for p in prs if p['mergedAt'] and p['mergedAt'][:10] == d0)
        gaps = [(b - a).total_seconds() / 60 for a, b in zip(times, times[1:])]
        if gaps:
            print(f'  on {d0}: {len(times)} merges over {(times[-1]-times[0]).total_seconds()/3600:.1f} h, median gap {statistics.median(gaps):.0f} min')
