#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/prune-verdict.sh.
#
# Each fixture is a throwaway git repo plus a throwaway bare `origin` built in a tempdir,
# so the assertions run against real git plumbing -- including a real `git fetch <oid>`
# -- not a mock of it. See issue #271.
#
# Permitted toolset: git, POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/prune-verdict.sh"

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

# A bare origin that serves any object by SHA (a local-path remote refuses a fetch of a
# non-tip SHA otherwise; GitHub serves a merged PR's head by SHA), and a clone of it on
# `main` with one commit. Leaves cwd in the clone. $1 names the fixture.
new_repo() {
  git init -q --bare "$tmp/$1-origin.git"
  git -C "$tmp/$1-origin.git" config uploadpack.allowAnySHA1InWant true
  git init -q "$tmp/$1"
  cd "$tmp/$1"
  git config user.email test@example.com
  git config user.name test
  git config core.autocrlf false
  git checkout -q -b main
  git remote add origin "$tmp/$1-origin.git"
  echo a >a.txt && git add a.txt && git commit -qm initial
  git push -q origin main
}

commit_file() {
  echo "$1" >"$1.txt" && git add "$1.txt" && git commit -qm "$1"
}

# --- the local tip IS the merged head ----------------------------------------
new_repo equal
git checkout -qb feat
commit_file one
assert_eq "tip equals merged oid -> delete" delete \
  "$(sh "$script" feat "$(git rev-parse feat)")"

# --- local BEHIND the merged head: the oid is only on origin (#271) -----------
new_repo behind
git checkout -qb feat
commit_file one
local_tip="$(git rev-parse feat)"
commit_file two
merged="$(git rev-parse feat)"
git push -q origin feat
git reset -q --hard "$local_tip"
git checkout -q main
git push -q origin --delete feat
git update-ref -d refs/remotes/origin/feat 2>/dev/null || true
git reflog expire --expire=now --all
git gc -q --prune=now
if git cat-file -e "${merged}^{commit}" 2>/dev/null; then
  echo "FAIL - fixture invariant broken (behind): merged oid is already local" >&2
  fail=1
fi
assert_eq "local behind a merged head that needs fetching, remote branch deleted -> delete" delete \
  "$(sh "$script" feat "$merged")"

# --- local BEHIND, the oid already in this checkout --------------------------
new_repo behind-local
git checkout -qb feat
commit_file one
local_tip="$(git rev-parse feat)"
commit_file two
merged="$(git rev-parse feat)"
git reset -q --hard "$local_tip"
assert_eq "local behind a merged head already present -> delete" delete \
  "$(sh "$script" feat "$merged")"

# --- local AHEAD of the merged head: stranded work ---------------------------
new_repo ahead
git checkout -qb feat
commit_file one
merged="$(git rev-parse feat)"
git push -q origin feat
commit_file extra
assert_eq "local has a commit past the merged head -> skip-ahead" skip-ahead \
  "$(sh "$script" feat "$merged")"

# --- DIVERGED from the merged head -------------------------------------------
new_repo diverged
git checkout -qb feat
commit_file one
base="$(git rev-parse feat)"
commit_file theirs
merged="$(git rev-parse feat)"
git push -q origin feat
git reset -q --hard "$base"
commit_file mine
git checkout -q main
git push -q origin --delete feat
git update-ref -d refs/remotes/origin/feat 2>/dev/null || true
git reflog expire --expire=now --all
git gc -q --prune=now
if git cat-file -e "${merged}^{commit}" 2>/dev/null; then
  echo "FAIL - fixture invariant broken (diverged): merged oid is already local" >&2
  fail=1
fi
git checkout -q feat
assert_eq "local and merged head diverged, oid must be fetched first -> skip-ahead" skip-ahead \
  "$(sh "$script" feat "$merged")"

# --- merged oid neither local nor on origin ----------------------------------
new_repo unfetchable
git checkout -qb feat
commit_file one
assert_eq "merged oid nowhere to be had -> skip-unfetchable" skip-unfetchable \
  "$(sh "$script" feat "1111111111111111111111111111111111111111")"

# --- no origin remote at all -------------------------------------------------
new_repo no-origin
git checkout -qb feat
commit_file one
git remote remove origin
assert_eq "tips differ, oid absent, no origin -> skip-unfetchable" skip-unfetchable \
  "$(sh "$script" feat "1111111111111111111111111111111111111111")"

# --- fail-closed argument handling -------------------------------------------
new_repo args
git checkout -qb feat
commit_file one
tip="$(git rev-parse feat)"
assert_eq "no arguments -> unreadable" unreadable "$(sh "$script")"
assert_eq "one argument -> unreadable" unreadable "$(sh "$script" feat)"
assert_eq "three arguments -> unreadable" unreadable "$(sh "$script" feat "$tip" x)"
assert_eq "unknown branch -> unreadable" unreadable "$(sh "$script" nope "$tip")"
assert_eq "short oid -> unreadable" unreadable "$(sh "$script" feat "$(printf %.7s "$tip")")"
assert_eq "uppercase oid -> unreadable" unreadable \
  "$(sh "$script" feat "$(printf %s "$tip" | tr a-f A-F)")"
assert_eq "option-shaped oid is never handed to git -> unreadable" unreadable \
  "$(sh "$script" feat "--upload-pack=touch$tmp/pwned")"
if [ -e "$tmp/pwned" ]; then
  echo "FAIL - option-shaped oid reached git" >&2
  fail=1
fi
# feat is one commit past main. A bare `feat` would resolve to the tag (main) and read
# "tip equals merged oid"; the branch itself is ahead of main.
git tag feat main
assert_eq "a tag of the branch's name does not shadow it" skip-ahead \
  "$(sh "$script" feat "$(git rev-parse main)")"

exit "$fail"
