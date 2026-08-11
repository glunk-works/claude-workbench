#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/cursor-drift.sh.
#
# Each fixture is a throwaway git repo built in a tempdir so the assertions run
# against real git plumbing, not a mock of it -- the bug class this guards
# against (v0.3.0 SHA equality, v0.4.0 the commit-range form) was a wrong
# argument to real git commands, which only a real repo can catch. See issue #21
# and docs/decisions.md WB-D7.
#
# Permitted toolset: git, POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/cursor-drift.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

assert_eq() {
  desc="$1"
  expected="$2"
  actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$expected], got [$actual]" >&2
    fail=1
  fi
}

new_repo() {
  repo="$tmp/$1"
  git init -q "$repo"
  cd "$repo"
  git config user.email test@example.com
  git config user.name test
  git config core.autocrlf false
}

base_branch() {
  git symbolic-ref --short HEAD
}

# --- clean: last_commit IS HEAD --------------------------------------------
new_repo clean
echo a >a.txt && git add a.txt && git commit -qm a
last="$(git rev-parse HEAD)"
assert_eq "clean: last_commit == HEAD" "clean" "$("$script" "$last")"

# --- cursor-sync: the v0.4.0 regression fixture -----------------------------
# A branch's tip (commit A) is recorded as last_commit BEFORE a follow-up commit
# (B) adds only .ai/next-steps.md on top of it. The branch (A+B) then
# squash-merges into main as a brand-new commit object C -- A never becomes an
# ancestor of C, which is exactly the case the range form `A..HEAD` gets wrong
# (A is not an ancestor of C, so the range is empty/nonsensical) and the
# two-argument tree diff gets right (it only compares content).
new_repo cursor-sync
base="$(base_branch)"
mkdir -p .ai
echo a >a.txt && git add a.txt && git commit -qm "initial"
git checkout -qb work
echo work >a.txt && git add a.txt && git commit -qm "commit A: the work"
last="$(git rev-parse HEAD)" # last_commit, captured before the cursor-sync commit
echo cursor >.ai/next-steps.md && git add .ai/next-steps.md && git commit -qm "commit B: cursor sync"
git checkout -q "$base"
git merge --squash work -q >/dev/null
git commit -qm "squash-merged"
if git merge-base --is-ancestor "$last" HEAD 2>/dev/null; then
  echo "FAIL - fixture invariant broken: last_commit IS an ancestor of HEAD (squash-merge simulation is wrong)" >&2
  fail=1
fi
assert_eq "cursor-sync: only .ai/next-steps.md differs, last_commit not an ancestor" \
  "cursor-sync" "$("$script" "$last")"

# --- drift: negative control -- an unrelated file changed too --------------
new_repo drift
base="$(base_branch)"
mkdir -p .ai
echo a >a.txt && git add a.txt && git commit -qm "initial"
git checkout -qb work
echo work >a.txt && git add a.txt && git commit -qm "commit A: the work"
last="$(git rev-parse HEAD)"
echo cursor >.ai/next-steps.md
echo b >b.txt
git add .ai/next-steps.md b.txt && git commit -qm "commit B: cursor sync + unrelated file"
git checkout -q "$base"
git merge --squash work -q >/dev/null
git commit -qm "squash-merged"
assert_eq "drift: an unrelated path changed alongside the cursor" \
  "drift" "$("$script" "$last")"

# --- unreadable: last_commit is not an object git has -----------------------
new_repo unreadable
echo a >a.txt && git add a.txt && git commit -qm a
assert_eq "unreadable: last_commit is not a commit git has" \
  "unreadable" "$("$script" 0000000000000000000000000000000000dead)"

exit "$fail"
