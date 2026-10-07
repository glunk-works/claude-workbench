#!/usr/bin/env bash
# PR-flow baseline for one repo, derived read-only from GitHub's merged-PR history.
#
# Issue #324, decision 7 of docs/proposals/orchestrator-m2-decisions.md: the loop needs a real
# before-picture of a repo's PR flow (work PRs, cursor PRs, merge latency, how often PRs depend
# on each other), and the picture must stay re-derivable. So this script computes it on demand;
# the only thing ever recorded per repo is the enable date and the window (see
# scripts/loop/README.md), never the numbers it prints.
#
# Usage:
#   baseline.sh <owner/repo> [--days N] [--until YYYY-MM-DD] [--dependent-hours H]...
#   baseline.sh --from-json FILE [--days N] [--until YYYY-MM-DD]     # derive from canned data
#
#   --days N             window length, default 60 (merged PRs only)
#   --until DATE         window end, inclusive, default today (UTC); pass it to reproduce a run
#   --dependent-hours H  a "likely dependent" threshold, repeatable; default 6 and 24
#   --from-json FILE     skip GitHub; FILE is `gh pr list --json number,createdAt,mergedAt,files`
#
# Method (the one behind the brief's data table):
#   work PR       a merged PR that is not a cursor PR
#   cursor PR     every file it touches is the cursor ledger (.ai/next-steps.md) or .ai/parked/*
#   likely-dependent  a work PR created within H hours after another work PR merged, the two
#                 touching at least one file in common, after dropping the cursor ledger,
#                 changelogs, lockfiles and any file touched by 10% or more of the window's
#                 work PRs. Without that exclusion the brief's figure read 64-78%.
#   wave overlap risk  a work PR open at the same time as another work PR that shares a
#                 (non-excluded) file with it: what a wave of parallel PRs would collide on.
#   open_to_merge_min_per_work_pr  what GitHub offers in place of "human minutes": open-to-merge
#                 minutes summed over every merged PR in the window, cursor PRs included, divided
#                 by the work-PR count. GitHub does not record human attention, so this is
#                 wait-to-merge time, not keyboard time, and an away-block raises it by design.
#                 It is NOT the M2b exit metric; that needs a different source.
#   Limits: a dependency whose earlier PR merged before the window starts is not seen; the
#                 fetch is the newest 1000 merged PRs, and gh returns at most 100 files per PR.
#                 Under 21 work PRs a file shared by just two PRs already counts as hot, so
#                 the dependent and overlap shares print n/a.
#
# Read-only: one `gh pr list`, no writes. Needs gh (unless --from-json) and jq.
set -euo pipefail

repo=
from_json=
days=60
until_date=
hours=()

die() { echo "baseline.sh: $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --days)            [ $# -ge 2 ] || die "--days needs a value"; days=$2; shift 2 ;;
    --until)           [ $# -ge 2 ] || die "--until needs a value"; until_date=$2; shift 2 ;;
    --dependent-hours) [ $# -ge 2 ] || die "--dependent-hours needs a value"; hours+=("$2"); shift 2 ;;
    --from-json)       [ $# -ge 2 ] || die "--from-json needs a file"; from_json=$2; shift 2 ;;
    -*)                die "unknown option: $1" ;;
    *)                 [ -z "$repo" ] || die "one repo only"; repo=$1; shift ;;
  esac
done

case "$days" in ''|*[!0-9]*|0*) die "--days must be a positive integer" ;; esac
[ ${#hours[@]} -gt 0 ] || hours=(6 24)
for h in "${hours[@]}"; do
  case "$h" in ''|*[!0-9]*|0*) die "--dependent-hours must be a positive integer" ;; esac
done
if [ -z "$until_date" ]; then until_date=$(date -u +%Y-%m-%d); fi
case "$until_date" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) die "--until must be YYYY-MM-DD" ;;
esac
[ "$(jq -rn --arg d "${until_date}T00:00:00Z" '$d | fromdateiso8601 | todate | .[0:10]' 2>/dev/null)" = "$until_date" ] \
  || die "--until is not a real date: $until_date"

if [ -n "$from_json" ]; then
  [ -r "$from_json" ] || die "cannot read $from_json"
  data=$(cat "$from_json")
  label=${repo:-$from_json}
else
  [ -n "$repo" ] || die "usage: baseline.sh <owner/repo> [--days N] [--until YYYY-MM-DD]"
  case "$repo" in */*) ;; *) die "repo must be owner/name" ;; esac
  limit=1000
  data=$(gh pr list --repo "$repo" --state merged --limit "$limit" \
           --json number,createdAt,mergedAt,files) || die "gh pr list failed for $repo"
  if [ "$(printf '%s' "$data" | jq 'length')" -ge "$limit" ]; then
    echo "baseline.sh: warning: hit the $limit-PR fetch limit; the window may be truncated" >&2
  fi
  label=$repo
fi

hours_json=$(printf '%s\n' "${hours[@]}" | jq -R 'tonumber' | jq -s .)

printf '%s' "$data" | jq -r --arg until "${until_date}T23:59:59Z" --argjson days "$days" \
  --argjson hours "$hours_json" --arg label "$label" '
  def ts: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
  def median: sort | if length == 0 then null
              else (.[(length - 1) / 2 | floor] + .[length / 2 | floor]) / 2 end;
  def ledger: . == ".ai/next-steps.md" or startswith(".ai/parked/");
  def noise: ledger
    or test("(^|/)CHANGELOG[^/]*$"; "i")
    or test("(^|/)(package-lock|npm-shrinkwrap)\\.json$")
    or test("(^|/)(yarn\\.lock|pnpm-lock\\.yaml|Cargo\\.lock|go\\.sum|poetry\\.lock|Pipfile\\.lock|uv\\.lock|Gemfile\\.lock|composer\\.lock)$")
    or endswith(".lock");
  def pct: if . == null then "n/a" else "\(. * 1000 | round / 10)%" end;
  def r1: . * 10 | round / 10;

  ($until | ts) as $end
  | ($end - $days * 86400) as $start
  | [ .[] | select(.mergedAt != null)
      | {n: .number, c: (.createdAt | ts), m: (.mergedAt | ts), paths: [(.files // [])[].path]} ]
  | map(select(.m > $start and .m <= $end)) as $merged
  | ($merged | length) as $total
  | ($merged | map(select((.paths | length) > 0 and all(.paths[]; ledger)))) as $cursor
  | ($merged | map(select(((.paths | length) == 0) or (all(.paths[]; ledger) | not)))) as $work
  | ($work | length) as $nw
  # files touched by 10% or more of the window work PRs
  | ($work | map(.paths | unique[]) | group_by(.) | map({f: .[0], k: length})
      | map(select(.k * 10 >= $nw) | .f)) as $hot
  | ($work | map(. + {f: [.paths[] | select((noise | not) and (. as $f | any($hot[]; . == $f) | not))] | unique})) as $w
  | def shares($a; $b): ($a.f - ($a.f - $b.f)) | length > 0;
    def dep($h): [ $w[] as $p
      | select(any($w[]; . as $q | $q.n != $p.n and $q.m <= $p.c and ($p.c - $q.m) <= $h * 3600
                          and shares($p; $q))) ] | length;
    ([ $w[] as $p
      | select(any($w[]; . as $q | $q.n != $p.n and $q.c < $p.m and $p.c < $q.m
                          and shares($p; $q))) ] | length) as $overlap
  | ($merged | map((.m - .c) / 60) | add // 0) as $mins
  | "repo\t\($label)",
    "window\t\($days)d ending \($until[0:10]) (merged PRs only)",
    "merged_prs\t\($total)",
    "work_prs\t\($nw)",
    "cursor_prs\t\($cursor | length)",
    "cursor_prs_per_work_pr\t\(if $nw == 0 then "n/a" else ($cursor | length) / $nw | . * 10 | round / 10 end)",
    "median_open_to_merge_min\t\(if $nw == 0 then "n/a" else ($work | map((.m - .c) / 60) | median | round) end)",
    ($hours[] as $h | "likely_dependent_share_\($h)h\t\(if $nw < 21 then "n/a" else (dep($h) / $nw) | pct end)"),
    "wave_overlap_risk\t\(if $nw < 21 then "n/a" else ($overlap / $nw) | pct end)",
    "open_to_merge_min_per_work_pr\t\(if $nw == 0 then "n/a" else ($mins / $nw | r1) end)"
'
