#!/bin/sh
# Is there exactly one open /way-of-working:handoff cursor-sync PR that
# /way-of-working:resume may offer the human to merge -- and if there is none, is
# this checkout standing on a sync branch nobody merged?
#
# Issue #215: handoff opens the `.ai/next-steps.md` sync as its own docs-only PR and
# never merges it -- the human's merge is the approval of the `next_action` the next
# session may run unattended. In practice that PR was regularly forgotten, so resume
# now finds it at session start and offers the merge on one explicit confirmation.
# Deciding WHICH PR is safe to offer is a deterministic predicate, so it lives here,
# tested, rather than in skill prose -- the same shape as cursor-drift.sh and
# milestone-close-line.sh. The display, the confirmation, and the merge itself stay
# in the skill; this script never merges.
#
# Usage: cursor-sync-pr.sh <repo> <pr_base>     (run from inside the checkout)
# Prints exactly one line, to stdout, and always exits 0 (the caller decides policy):
#   none                    -- no open PR against <pr_base> whose head branch starts
#                              with `docs/sync-cursor-` (the name handoff's own step
#                              cuts), and HEAD is not on an unmerged sync branch
#   offer <N> <oid> <branch> -- exactly one such PR, passing every check below; <oid>
#                              is its head commit, which the caller must both display
#                              from and merge with `gh pr merge --match-head-commit`
#   refuse <N> <reason>     -- exactly one such PR, failing a check; <reason> is one of
#                              cross-repository | files | not-local |
#                              state-<mergeStateStatus, lowercased>
#   ambiguous <N> <N>...    -- more than one such PR (e.g. a forgotten earlier sync plus
#                              a newer one). Never pick one: two syncs regenerate the same
#                              file wholesale, so which is right is the human's call
#   unmerged <branch>       -- no such PR is open, but HEAD is on a `docs/sync-cursor-`
#                              branch whose tip no merged PR carries: handoff's push or
#                              PR creation failed, or the human closed the PR unmerged.
#                              Either way the local cursor was never approved
#   unreadable              -- wrong arguments, not in a git checkout, a `gh` call
#                              failed, its output was not in the shape asked for, or the
#                              open-PR list hit its fetch limit (a candidate past the
#                              limit would otherwise read as `none`)
#
# The checks on a single candidate, and why each is the one it is:
#   - Same repository (`isCrossRepository` false). A fork PR is the outsider path.
#   - Changed files are exactly `.ai/next-steps.md`. Handoff keeps its PR to that one
#     file (its *Commit `.ai/next-steps.md` as its own docs-only PR* step calls that
#     load-bearing); anything wider is not a cursor sync, whatever its branch is named.
#     Park and unpark PRs share the branch prefix but also touch `.ai/parked/`, so they
#     land here too, on purpose.
#   - A LOCAL branch of the same name exists and its tip is exactly <oid> (`not-local`
#     otherwise). This is the binding that makes the offer mean something. Same-repo
#     alone is not enough on a public repo: anyone with read access can open a PR from
#     an existing branch, and a repo that keeps merged branches holds dozens of stale
#     `docs/sync-cursor-*` heads (50 on this plugin's own repo when this was written)
#     whose PRs pass every other check. And `.ai/state.json` -- where auto-start reads
#     the `next_action` it runs -- is git-ignored and machine-local, so only a sync PR
#     THIS machine's handoff produced describes it. A sync opened from another machine
#     is refused here; the human merges that one on GitHub. The PR AUTHOR is
#     deliberately not checked: `author_association` is viewer-relative, and read by a
#     `gh` account other than the PR's author it reports `CONTRIBUTOR` for the repo's
#     own maintainer (observed live on PR #210).
#   - `mergeStateStatus` is CLEAN. Everything else -- BEHIND, BLOCKED (checks not
#     green), DIRTY (conflicts, the usual shape of a stale sync), DRAFT, UNSTABLE,
#     UNKNOWN (GitHub still computing) -- is refused with its name, for the human.
#
# The branch prefix selects candidates; it is not a trust signal.
#
# Permitted toolset: POSIX sh, git, `gh` (using only its own embedded --jq), tr,
# mktemp. No jq, no yq, no python, no awk.
set -u

tab="$(printf '\t')"
limit=200
prefix=docs/sync-cursor-

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "cursor-sync-pr.sh: usage: cursor-sync-pr.sh <repo> <pr_base>" >&2
  echo unreadable
  exit 0
fi
repo="$1"; base="$2"

git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "cursor-sync-pr.sh: not inside a git checkout" >&2
  echo unreadable
  exit 0
}

tmp="$(mktemp -d)" || { echo unreadable; exit 0; }
trap 'rm -rf "$tmp"' EXIT

# Line 1 is the total count of open PRs against <base>, so a list that hit the limit
# is detected rather than silently truncated. The prefix filter runs inside --jq so
# non-candidate titles and bodies never reach this script.
if ! gh pr list --repo "$repo" --base "$base" --state open --limit "$limit" \
     --json number,headRefName,headRefOid,isCrossRepository,mergeStateStatus,files \
     --jq 'length, (.[] | select(.headRefName | startswith("docs/sync-cursor-")) |
           [.number, .headRefName, .headRefOid, .isCrossRepository, .mergeStateStatus,
            (.files | length), (.files[0].path // "")] | @tsv)' \
     >"$tmp/rows" 2>"$tmp/err"; then
  echo "cursor-sync-pr.sh: gh pr list failed for $repo (base $base):" >&2
  cat "$tmp/err" >&2
  echo unreadable
  exit 0
fi

is_digits() { case "$1" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }
is_oid() {
  case "$1" in *[!0-9a-f]*) return 1 ;; esac
  [ "${#1}" -eq 40 ]
}

total=""
count=0
numbers=""
# `|| [ -n "$number" ]` keeps a final row that lacks a trailing newline.
while IFS="$tab" read -r number branch oid cross state nfiles path rest || [ -n "$number" ]; do
  if [ -z "$total" ]; then
    is_digits "$number" && [ -z "$branch" ] || { echo unreadable; exit 0; }
    total="$number"
    continue
  fi
  [ -n "$number" ] || continue
  # Shape checks: anything not exactly what --jq was asked for is unreadable, never
  # a best-effort guess.
  is_digits "$number" || { echo unreadable; exit 0; }
  case "$branch" in "$prefix"?*) ;; *) echo unreadable; exit 0 ;; esac
  is_oid "$oid" || { echo unreadable; exit 0; }
  case "$cross" in true | false) ;; *) echo unreadable; exit 0 ;; esac
  is_digits "$nfiles" || { echo unreadable; exit 0; }
  [ -z "${rest:-}" ] || { echo unreadable; exit 0; }
  count=$((count + 1))
  numbers="$numbers $number"
  c_number="$number"; c_branch="$branch"; c_oid="$oid"; c_cross="$cross"
  c_state="$state"; c_nfiles="$nfiles"; c_path="$path"
done <"$tmp/rows"

[ -n "$total" ] || { echo unreadable; exit 0; }
if [ "$total" -ge "$limit" ]; then
  echo "cursor-sync-pr.sh: $total open PRs against $base reached the fetch limit" >&2
  echo unreadable
  exit 0
fi

if [ "$count" -gt 1 ]; then
  echo "ambiguous$numbers"
  exit 0
fi

if [ "$count" -eq 1 ]; then
  if [ "$c_cross" != false ]; then
    echo "refuse $c_number cross-repository"
    exit 0
  fi
  if [ "$c_nfiles" != 1 ] || [ "$c_path" != ".ai/next-steps.md" ]; then
    echo "refuse $c_number files"
    exit 0
  fi
  local_tip="$(git rev-parse -q --verify "refs/heads/$c_branch^{commit}" 2>/dev/null)" || local_tip=""
  if [ "$local_tip" != "$c_oid" ]; then
    echo "refuse $c_number not-local"
    exit 0
  fi
  if [ "$c_state" != CLEAN ]; then
    lower="$(printf '%s' "$c_state" | tr 'A-Z' 'a-z')"
    echo "refuse $c_number state-${lower:-empty}"
    exit 0
  fi
  echo "offer $c_number $c_oid $c_branch"
  exit 0
fi

# No open candidate. Is HEAD on a sync branch nobody merged?
current="$(git symbolic-ref -q --short HEAD 2>/dev/null)" || current=""
case "$current" in
  "$prefix"?*) ;;
  *) echo none; exit 0 ;;
esac
tip="$(git rev-parse -q --verify HEAD 2>/dev/null)" || { echo unreadable; exit 0; }
if ! gh pr list --repo "$repo" --base "$base" --state merged --head "$current" \
     --limit "$limit" --json headRefOid --jq '.[].headRefOid' \
     >"$tmp/merged" 2>"$tmp/err"; then
  echo "cursor-sync-pr.sh: gh pr list (merged) failed for $current:" >&2
  cat "$tmp/err" >&2
  echo unreadable
  exit 0
fi
while IFS= read -r merged_oid || [ -n "$merged_oid" ]; do
  if [ "$merged_oid" = "$tip" ]; then
    echo none
    exit 0
  fi
done <"$tmp/merged"
echo "unmerged $current"
exit 0
