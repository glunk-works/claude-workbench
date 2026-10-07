#!/bin/sh
# Fixture tests for scripts/loop/baseline.sh (issue #324).
#
# The script's derivation is exercised through --from-json on canned `gh pr list` output, so
# nothing here touches GitHub. The fixture is generated below: 22 work PRs 4h apart (PR i
# merges at base + 4h*i, opened 10 min earlier), plus the cases each rule exists for.
#
#   w2, w3 share only hot.txt with w1       hot file (3 of 22 work PRs): never a dependency
#   w6 shares lib/x.sh with w5              dependent at 6h and 24h (opened 3h50m after w5)
#   w17 shares lib/y.sh with w15            dependent at 24h only (opened 7h50m after)
#   w8, w9 share only CHANGELOG.md          changelog: never a dependency
#   w12, w13 share lib/z.sh, w13 open 6h    overlap risk, 2 of 22; w13 is the 360 min outlier
#   w21 touches the ledger and u21.txt      a mixed PR is a work PR, not a cursor PR
#   c1, c2 touch only the ledger/parked     cursor PRs
#   old, unmerged                           outside the window / never merged: both ignored
#
# Permitted toolset: POSIX sh, its standard utilities, bash (to run the script, which is bash)
# and jq (the script's own dependency).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/loop/baseline.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP - jq not on PATH; loop-baseline fixtures not run" >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/prs.json"

jq -n '
  def t: todate;
  ("2026-10-01T00:00:00Z" | fromdateiso8601) as $base
  | def pr($n; $m; $open; $paths):
      {number: $n, createdAt: ($m - $open | t), mergedAt: ($m | t), files: [$paths[] | {path: .}]};
    [ range(1; 23) as $i
      | ($base + $i * 14400) as $m
      | pr($i; $m; (if $i == 13 then 21600 else 600 end);
           ["u\($i).txt"]
           + (if $i <= 3 then ["hot.txt"] else [] end)
           + (if $i == 5 or $i == 6 then ["lib/x.sh"] else [] end)
           + (if $i == 15 or $i == 17 then ["lib/y.sh"] else [] end)
           + (if $i == 8 or $i == 9 then ["CHANGELOG.md"] else [] end)
           + (if $i == 12 or $i == 13 then ["lib/z.sh"] else [] end)
           + (if $i == 21 then [".ai/next-steps.md"] else [] end)) ]
    + [ pr(101; $base + 50000; 600; [".ai/next-steps.md"]),
        pr(102; $base + 60000; 600; [".ai/next-steps.md", ".ai/parked/x-state.json"]),
        pr(103; ("2026-08-01T00:00:00Z" | fromdateiso8601); 600; ["old.txt"]),
        {number: 104, createdAt: ($base | t), mergedAt: null, files: [{path: "unmerged.txt"}]} ]
' >"$fixture"

fail=0

# field <output> <key> -> the value column of that key's line
field() { printf '%s\n' "$1" | awk -F '\t' -v k="$2" '$1 == k { print $2; exit }'; }

assert_eq() {
  desc="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$expected], got [$actual]" >&2
    fail=1
  fi
}

out="$(bash "$script" --from-json "$fixture" --days 10 --until 2026-10-10)"

assert_eq "merged PRs: the old and the unmerged PR are outside the count" 24 "$(field "$out" merged_prs)"
assert_eq "work PRs: the mixed ledger-plus-code PR counts as work" 22 "$(field "$out" work_prs)"
assert_eq "cursor PRs: ledger-only and ledger-plus-parked" 2 "$(field "$out" cursor_prs)"
assert_eq "cursor PRs per work PR" 0.1 "$(field "$out" cursor_prs_per_work_pr)"
assert_eq "median open-to-merge ignores the one long-open PR" 10 "$(field "$out" median_open_to_merge_min)"
assert_eq "likely dependent at 6h: only the lib/x.sh pair" 4.5% "$(field "$out" likely_dependent_share_6h)"
assert_eq "likely dependent at 24h adds the lib/y.sh pair" 9.1% "$(field "$out" likely_dependent_share_24h)"
assert_eq "wave overlap risk: the lib/z.sh pair, both sides" 9.1% "$(field "$out" wave_overlap_risk)"
assert_eq "open-to-merge minutes per work PR: every merged PR's open time over the work count" 26.8 "$(field "$out" open_to_merge_min_per_work_pr)"
assert_eq "the window line names the days and end date" "10d ending 2026-10-10 (merged PRs only)" "$(field "$out" window)"

# --dependent-hours replaces the 6/24 defaults.
out="$(bash "$script" --from-json "$fixture" --days 10 --until 2026-10-10 --dependent-hours 12)"
assert_eq "custom threshold: 12h catches the 7h50m pair too" 9.1% "$(field "$out" likely_dependent_share_12h)"
assert_eq "custom threshold replaces the defaults" "" "$(field "$out" likely_dependent_share_6h)"

# No work PRs in the window: every ratio is n/a, never a divide-by-zero.
out="$(bash "$script" --from-json "$fixture" --days 1 --until 2026-09-01)"
assert_eq "empty window: zero work PRs" 0 "$(field "$out" work_prs)"
assert_eq "empty window: ratios read n/a" n/a "$(field "$out" open_to_merge_min_per_work_pr)"

# Fewer than 21 work PRs: any shared file is already "hot" (2 of N is 10%+), so a share would be
# a false 0%; the script prints n/a.
small="$tmp/small.json"
jq -n '
  ("2026-10-01T00:00:00Z" | fromdateiso8601) as $b
  | [ {number: 1, createdAt: ($b | todate), mergedAt: ($b + 600 | todate), files: [{path: "a.sh"}]},
      {number: 2, createdAt: ($b + 3600 | todate), mergedAt: ($b + 4200 | todate), files: [{path: "a.sh"}]},
      {number: 3, createdAt: ($b + 7200 | todate), mergedAt: ($b + 7800 | todate), files: null} ]' >"$small"
out="$(bash "$script" --from-json "$small" --days 10 --until 2026-10-10)"
assert_eq "small window: the shares read n/a, not a false 0%" n/a "$(field "$out" likely_dependent_share_6h)"
assert_eq "small window: the overlap share reads n/a too" n/a "$(field "$out" wave_overlap_risk)"
bash "$script" --from-json "$small" --until 2026-02-30 >/dev/null 2>&1 && rc=0 || rc=$?
assert_eq "an impossible --until date exits 2" 2 "$rc"

# Bad arguments exit 2 and print nothing on stdout.
for bad in "--days 0" "--days x" "--until 2026-1-1" "--dependent-hours 0" "--nope"; do
  # shellcheck disable=SC2086
  stdout="$(bash "$script" --from-json "$fixture" $bad 2>/dev/null)" && rc=0 || rc=$?
  assert_eq "bad argument [$bad] exits 2" "2|" "$rc|$stdout"
done
stdout="$(bash "$script" 2>/dev/null)" && rc=0 || rc=$?
assert_eq "no repo and no --from-json exits 2" "2|" "$rc|$stdout"

[ "$fail" -eq 0 ] || exit 1
echo "all loop-baseline fixtures passed"
