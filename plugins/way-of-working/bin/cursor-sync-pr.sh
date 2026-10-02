#!/bin/sh
# Is there exactly one open /way-of-working:handoff cursor-sync PR that
# /way-of-working:resume may offer the human to merge?
#
# Issue #215: handoff opens the `.ai/next-steps.md` sync as its own docs-only PR and
# never merges it -- the human's merge is the approval of the `next_action` the next
# session may run unattended. In practice that PR was regularly forgotten, so resume
# now finds it at session start and offers the merge on one explicit confirmation,
# with the PR's **Next:** line in view. Deciding WHICH PR is safe to offer is a
# deterministic predicate, so it lives here, tested, rather than in skill prose --
# the same shape as cursor-drift.sh and milestone-close-line.sh. The confirmation,
# the display, and the merge itself stay in the skill; this script never merges.
#
# Usage: cursor-sync-pr.sh <repo> <pr_base>
# Prints exactly one line, to stdout, and always exits 0 (the caller decides policy):
#   none                 -- no open PR against <pr_base> whose head branch starts with
#                           `docs/sync-cursor-` (the name handoff's own step cuts)
#   offer <N> <oid>      -- exactly one such PR, and it passes every check below; <oid>
#                           is the head commit the caller must show AND merge (with
#                           `gh pr merge --match-head-commit <oid>`), so what the human
#                           saw is what lands
#   refuse <N> <reason>  -- exactly one such PR, failing a check; <reason> is one of
#                           cross-repository | files | state-<mergeStateStatus, lowercased>
#   ambiguous <N> <N>... -- more than one such PR (e.g. a forgotten earlier sync plus a
#                           newer one). Never pick one: two syncs regenerate the same
#                           file wholesale, so which is right is the human's call
#   unreadable           -- wrong arguments, the `gh` call failed, or its output was not
#                           in the shape this script asked for
#
# The checks, and why each is the one it is:
#   - Same repository (`isCrossRepository` false). This is the trust check. A head
#     branch in <repo> itself could only have been pushed by an identity with push
#     access, and the caller merges exactly <oid>, so the content that lands came from
#     a writer. A fork PR is the outsider path and is refused. The PR AUTHOR is
#     deliberately NOT checked: `author_association` is viewer-relative, and on a
#     machine whose active `gh` account differs from the one that opened the PR it
#     reads `CONTRIBUTOR` for the repo's own maintainer (observed live, PR #210) -- a
#     check that refuses the common case would train the human to merge by hand again.
#   - Changed files are exactly `.ai/next-steps.md`. Handoff keeps its PR to that one
#     file (its *Commit `.ai/next-steps.md` as its own docs-only PR* step calls that
#     load-bearing); anything wider is not a cursor sync, whatever its branch is named.
#     Park and unpark PRs share the branch prefix but also touch `.ai/parked/`, so they
#     land here too, on purpose.
#   - `mergeStateStatus` is CLEAN or BEHIND. BEHIND is mergeable unless the ruleset
#     requires up-to-date branches, and `gh pr merge` refuses on its own if it does.
#     Everything else -- BLOCKED (checks not green), DIRTY (conflicts, the usual shape
#     of a stale sync), DRAFT, UNSTABLE, UNKNOWN (GitHub still computing) -- is refused
#     with its name, for the human.
#
# The branch prefix selects candidates; it is not a trust signal. A same-repo PR
# that merely borrows the name still has to pass every check, and the human still
# sees its **Next:** line before anything merges.
#
# Permitted toolset: POSIX sh, `gh` (using only its own embedded --jq). No jq, no
# yq, no python, no awk -- same bar as plan-gather.sh.
set -u

tab="$(printf '\t')"

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "cursor-sync-pr.sh: usage: cursor-sync-pr.sh <repo> <pr_base>" >&2
  echo unreadable
  exit 0
fi
repo="$1"; base="$2"

tmp="$(mktemp -d)" || { echo unreadable; exit 0; }
trap 'rm -rf "$tmp"' EXIT

# `--limit 100` is far past any realistic count of open PRs against one base; the
# prefix filter runs inside --jq so non-candidate titles and bodies never reach here.
if ! gh pr list --repo "$repo" --base "$base" --state open --limit 100 \
     --json number,headRefName,headRefOid,isCrossRepository,mergeStateStatus,files \
     --jq '.[] | select(.headRefName | startswith("docs/sync-cursor-")) |
           [.number, .headRefOid, .isCrossRepository, .mergeStateStatus,
            (.files | length), (.files[0].path // "")] | @tsv' \
     >"$tmp/rows" 2>"$tmp/err"; then
  echo "cursor-sync-pr.sh: gh pr list failed for $repo (base $base):" >&2
  cat "$tmp/err" >&2
  echo unreadable
  exit 0
fi

count=0
numbers=""
while IFS="$tab" read -r number oid cross state nfiles path rest; do
  [ -n "$number" ] || continue
  # Shape checks: anything not exactly what --jq was asked for is unreadable, never
  # a best-effort guess.
  case "$number" in '' | *[!0-9]*) echo unreadable; exit 0 ;; esac
  case "$oid" in
    *[!0-9a-f]*) echo unreadable; exit 0 ;;
  esac
  [ "${#oid}" -eq 40 ] || { echo unreadable; exit 0; }
  case "$cross" in true | false) ;; *) echo unreadable; exit 0 ;; esac
  case "$nfiles" in '' | *[!0-9]*) echo unreadable; exit 0 ;; esac
  [ -z "${rest:-}" ] || { echo unreadable; exit 0; }
  count=$((count + 1))
  numbers="$numbers $number"
  c_number="$number"; c_oid="$oid"; c_cross="$cross"; c_state="$state"
  c_nfiles="$nfiles"; c_path="$path"
done <"$tmp/rows"

if [ "$count" -eq 0 ]; then
  echo none
  exit 0
fi
if [ "$count" -gt 1 ]; then
  echo "ambiguous$numbers"
  exit 0
fi

if [ "$c_cross" != false ]; then
  echo "refuse $c_number cross-repository"
  exit 0
fi
if [ "$c_nfiles" != 1 ] || [ "$c_path" != ".ai/next-steps.md" ]; then
  echo "refuse $c_number files"
  exit 0
fi
case "$c_state" in
  CLEAN | BEHIND) ;;
  *)
    lower="$(printf '%s' "$c_state" | tr 'A-Z' 'a-z')"
    echo "refuse $c_number state-${lower:-empty}"
    exit 0
    ;;
esac

echo "offer $c_number $c_oid"
exit 0
