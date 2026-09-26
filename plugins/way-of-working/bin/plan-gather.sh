#!/bin/sh
# The read-only gather step behind /way-of-working:plan-sprint's placement dialogue
# (reference/project-schema.md § `planning`) -- open issues with no milestone, and
# open milestones in due-date order. Milestone 5's own build-order text for this
# task is explicit that the gather step is a `bin/` script with fixtures, not skill
# prose -- the dialogue that CONSUMES this data stays in the skill body; this
# script only fetches and sorts it.
#
# Usage:
#   plan-gather.sh unmilestoned <repo>
#     Prints TSV, one row per open TRUE issue (pull requests excluded) with no
#     milestone: number\tupdated_at\tauthor_association\ttitle. Sorted ascending
#     by issue number. Empty stdout + exit 0 legitimately means none.
#   plan-gather.sh milestones <repo>
#     Prints TSV, one row per OPEN milestone: number\ttitle\tdue_on-or-none\t
#     open_issues\tclosed_issues. Sorted by due date ascending, undated LAST.
#     Empty stdout + exit 0 legitimately means no open milestones.
#
# Exit-code convention -- deliberately DIFFERENT from plan-anchor.sh/cursor-drift.sh's
# "always exit 0, the verdict is on stdout": this script has no match/drift/
# unreadable verdict to encode. A failed `gh api` call exits non-zero with a
# stderr message and prints nothing further on stdout; the caller must check the
# exit code, never infer failure from empty output, since empty output is also
# the legitimate "zero rows" answer.
#
# Why the sort happens HERE, in the shell, and not inside `gh api --jq`: `gh api
# --paginate ... --jq 'sort_by(...)'` runs the --jq filter ONCE PER PAGE, not once
# over the whole paginated result (verified live against this plugin's own
# consuming repo: a --per_page=1 call printed a distinct filter result for each
# page). A `sort_by` inside such a filter only sorts within each page, which is
# silently wrong the moment a repo has enough open milestones to paginate --
# "due-date order, undated last" would stay true on page 1 and false everywhere
# after it. `--slurp` is not supported together with `--jq` either. So both
# subcommands below fetch the full, unsorted result via direct redirection to a
# file (checking gh's own exit code before trusting the file), and sort it with a
# single `LC_ALL=C sort` pass over the complete data.
#
# The `C` locale sort is why `none` (the undated sentinel this script prints,
# never GitHub's own null) sorts after every real ISO-8601 date with no numeric
# sentinel needed: under byte-value ordering, every ASCII digit (0x30-0x39, the
# first character of any ISO date) sorts before the lowercase letter `n` (0x6E).
#
# Milestone descriptions are deliberately NOT part of `milestones`' output -- a
# multi-line description cannot be a TSV field, and the gather step only needs
# due date + issue counts to build the ordering report. A specific milestone's
# full description is fetched individually, on demand, by the calling skill, via
# the same direct-redirection pattern used below (never `$(...)`, which strips a
# trailing newline and would make a later edit's read-back disagree with what was
# actually written).
#
# Permitted toolset: POSIX sh, `gh` (using only its own embedded --jq), and
# whatever sort ships on the machine, invoked under `LC_ALL=C` for deterministic
# byte-value ordering -- same bar as plan-anchor.sh and cursor-drift.sh.
set -eu

tmp="$(mktemp -d)" || { echo "plan-gather.sh: could not create a temp dir" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT

tab="$(printf '\t')"

mode="${1:-}"
case "$mode" in
  unmilestoned | milestones) shift ;;
  *)
    echo "plan-gather.sh: usage: plan-gather.sh unmilestoned <repo>" >&2
    echo "                       plan-gather.sh milestones   <repo>" >&2
    exit 1
    ;;
esac

if [ "$#" -ne 1 ]; then
  echo "plan-gather.sh: $mode needs exactly one argument, <repo>" >&2
  exit 1
fi
repo="$1"

# =============================================================================
if [ "$mode" = unmilestoned ]; then
  if ! gh api --paginate "repos/$repo/issues?state=open&milestone=none" --jq \
       '.[] | select(has("pull_request") | not) |
        [.number, .updated_at, .author_association, .title] | @tsv' \
       >"$tmp/rows" 2>"$tmp/err"; then
    echo "plan-gather.sh: gh api failed fetching unmilestoned issues for $repo:" >&2
    cat "$tmp/err" >&2
    exit 1
  fi
  # Ascending issue number is mechanized here rather than left to skill prose --
  # the script already has the whole result in a file to check gh's exit status,
  # so sorting it too is free.
  LC_ALL=C sort -t "$tab" -k1,1n "$tmp/rows"
  exit 0
fi

# =============================================================================
# mode = milestones
if ! gh api --paginate "repos/$repo/milestones?state=open" --jq \
     '.[] | [.number, .title, (.due_on // "none"), (.open_issues|tostring),
             (.closed_issues|tostring)] | @tsv' \
     >"$tmp/rows" 2>"$tmp/err"; then
  echo "plan-gather.sh: gh api failed fetching open milestones for $repo:" >&2
  cat "$tmp/err" >&2
  exit 1
fi
# Field 3 (due_on-or-none), then field 1 (milestone number) as the tie-break for
# same-date rows.
LC_ALL=C sort -t "$tab" -k3,3 -k1,1n "$tmp/rows"
exit 0
