#!/bin/sh
# May /way-of-working:resume (and archive-sprint) `git branch -D` a local branch whose
# PR GitHub reports merged -- or is its local tip carrying work the merge never saw?
#
# Issue #271: the prune used to delete only when the local tip EQUALS the `headRefOid`
# GitHub merged. A branch whose PR picked up more commits after the local copy stopped
# (pushed from another checkout, edited on GitHub) has a local tip BEHIND the merged
# head: every local commit is in what merged, so `-D` loses nothing -- yet the equality
# test skipped it, and the skip was re-reported as possible stranded work, session after
# session. The real stranded-work case is the opposite shape (the local tip has commits
# the merged head lacks) and must keep being skipped. Which of the two a branch is, is a
# deterministic predicate, so it lives here, tested, rather than in skill prose -- the
# same shape as cursor-drift.sh. The loop around it (which branches are candidates,
# `{pr_base}` and the current branch excluded, the `-D` itself, the report) stays in the
# skills; this script never deletes anything.
#
# Usage: prune-verdict.sh <branch> <merged_oid>   (run from inside the checkout)
#   <merged_oid> is the PR's `headRefOid` as GitHub reported it. It must be a full
#   lowercase-hex object name: it is handed to `git fetch`, and anything else (a
#   leading `-` becomes an option, `--upload-pack=...` runs a command) is refused
#   before git sees it.
# Prints exactly one line, to stdout, and always exits 0 (the caller decides policy):
#   delete             -- the local tip IS <merged_oid>, or is an ancestor of it:
#                         every local commit is in what GitHub merged
#   skip-ahead         -- the local tip has a commit <merged_oid> lacks (it is ahead of,
#                         or diverged from, the merged head): stranded work
#   skip-unfetchable   -- the tips differ and <merged_oid> is neither in this checkout
#                         nor fetchable from `origin`, so nothing can be said about the
#                         local commits; keep the branch
#   unreadable         -- wrong arguments, <merged_oid> is not a full hex object name,
#                         or <branch> is not a local branch
#
# Fetching by SHA does not depend on the PR's head branch still existing on the remote:
# GitHub serves a merged PR's head commit by its SHA after the branch is deleted -- the
# reason the `origin/$b`-based "is my tip pushed?" test is the wrong one (see resume's
# *Prune squash-merged local branches* step, and skills/resume/appendices/prune-rationale.md). The fetch writes only FETCH_HEAD; no ref
# the caller has is moved.
#
# Permitted toolset: git, POSIX sh. No jq, no yq, no python.
set -eu

if [ "$#" -ne 2 ]; then
  echo unreadable
  exit 0
fi
branch="$1"
oid="$2"

case "$oid" in
  *[!0-9a-f]*) echo unreadable; exit 0 ;;
esac
case "${#oid}" in
  40 | 64) ;;
  *) echo unreadable; exit 0 ;;
esac

# Fully qualified, so a branch whose name starts with `-` or collides with a tag or a
# remote ref is read as the local branch it is.
if ! tip="$(git rev-parse --verify -q "refs/heads/${branch}^{commit}" 2>/dev/null)"; then
  echo unreadable
  exit 0
fi

if [ "$tip" = "$oid" ]; then
  echo delete
  exit 0
fi

if ! git cat-file -e "${oid}^{commit}" 2>/dev/null; then
  # Bounded and non-interactive: the prune must never block a session. No credential
  # or host-key prompt (a failed fetch is just skip-unfetchable), no auto-gc on the
  # caller's checkout, and a hard timeout where one exists.
  if command -v timeout >/dev/null 2>&1; then
    set -- timeout 30 git
  else
    set -- git
  fi
  # Batch-mode ssh only when the operator has configured no ssh of their own -- a
  # custom key or wrapper must not be overridden into a permanent skip-unfetchable.
  if [ -z "${GIT_SSH_COMMAND:-}" ] && [ -z "${GIT_SSH:-}" ] \
    && [ -z "$(git config core.sshCommand 2>/dev/null || true)" ]; then
    export GIT_SSH_COMMAND='ssh -o BatchMode=yes'
  fi
  GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never \
    "$@" -c gc.auto=0 -c maintenance.auto=false fetch -q origin "$oid" >/dev/null 2>&1 </dev/null || true
  if ! git cat-file -e "${oid}^{commit}" 2>/dev/null; then
    echo skip-unfetchable
    exit 0
  fi
fi

# 0 = ancestor, 1 = not an ancestor; anything else is git failing, which is not a
# reason to delete.
rc=0
git merge-base --is-ancestor "$tip" "$oid" 2>/dev/null || rc=$?
case "$rc" in
  0) echo delete ;;
  1) echo skip-ahead ;;
  *) echo unreadable ;;
esac
