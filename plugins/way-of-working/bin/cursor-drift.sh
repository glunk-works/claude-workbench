#!/bin/sh
# Classify .ai/state.json's `last_commit` against the current HEAD.
#
# This is a deterministic predicate with a correctness argument, not a judgment
# call, so it is a tested script that /way-of-working:resume step 2 invokes
# rather than a computation described in skill prose -- prose shipped the wrong
# answer here twice: first by comparing `last_commit` to HEAD with plain SHA
# equality, then by replacing that with a commit-*range* form that only means
# what it looks like when `last_commit` is an ancestor of HEAD. Squash-merge
# routinely makes it not one, since it replays a branch as a brand-new commit
# object the original tip never becomes an ancestor of.
#
# Usage: cursor-drift.sh <last_commit>
# Prints exactly one of, to stdout, and always exits 0 (the caller decides policy):
#   clean        -- last_commit IS the current HEAD
#   cursor-sync  -- HEAD differs from last_commit only in .ai/next-steps.md
#   drift        -- HEAD differs from last_commit in some other way too
#   unreadable   -- last_commit is not a commit git has (treat as drift; wait)
#
# Deliberately NOT part of this script's job: whether the working tree is clean.
# That is a separate, single-command check (`git status --short`) with no
# multi-step correctness argument -- it stays a one-liner in the skill.
#
# Permitted toolset: git, POSIX sh. No jq, no yq, no python -- this must run on
# any maintainer machine without an extra interpreter installed.
set -eu

last_commit="${1:?usage: cursor-drift.sh <last_commit>}"

if ! git cat-file -e "${last_commit}^{commit}" 2>/dev/null; then
  echo unreadable
  exit 0
fi

head_sha="$(git rev-parse HEAD)"
last_sha="$(git rev-parse "$last_commit")"

if [ "$head_sha" = "$last_sha" ]; then
  echo clean
  exit 0
fi

# TWO arguments -- never <last_commit>..HEAD (see the top-of-file note). This
# compares trees, not history, and does not care whether last_commit is an
# ancestor of HEAD. diff.relative is pinned off: a caller with that set in
# their git config would otherwise get paths relative to cwd, not repo root,
# silently breaking the .ai/next-steps.md comparison below.
paths="$(git -c diff.relative=false diff --name-only "$last_commit" HEAD)"

if [ "$paths" = ".ai/next-steps.md" ]; then
  echo cursor-sync
  exit 0
fi

echo drift
