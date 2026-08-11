#!/bin/sh
# Classify .ai/state.json's `last_commit` against the current HEAD.
#
# Extracted from /way-of-working:resume step 2 (see issue #21): that step is a
# deterministic predicate with a correctness argument, not a judgment call, so it
# belongs in a tested script rather than in skill prose -- prose already shipped
# the wrong answer here twice (v0.3.0 SHA equality, v0.4.0 the commit-*range* form).
# See tests/cursor-drift.test.sh and docs/decisions.md WB-D7.
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

# TWO arguments -- never <last_commit>..HEAD. A range only means what you want
# when last_commit is an ancestor of HEAD, and squash-merge routinely makes it
# not one: see docs/decisions.md WB-D7. This compares trees, not history.
paths="$(git diff --name-only "$last_commit" HEAD)"

if [ "$paths" = ".ai/next-steps.md" ]; then
  echo cursor-sync
  exit 0
fi

echo drift
