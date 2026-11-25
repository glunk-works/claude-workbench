#!/bin/sh
# Static checks on the ship skill's head verification and its separate arm call (#1378, #1372).
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
ship="$root_dir/plugins/way-of-working/skills/ship/SKILL.md"

fail=0

assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$2], got [$3]" >&2
    fail=1
  fi
}

first_line() { grep -n -e "$1" "$ship" | head -n 1 | cut -d: -f1; }

create_at=$(first_line 'gh pr create --repo')
verify_at=$(first_line '--json state,headRefOid')
arm_at=$(first_line '^[0-9]*\. \*\*Arm auto-merge')
cross_at=$(first_line 'isCrossRepository')

ordered=no
if [ -n "$create_at" ] && [ -n "$verify_at" ] && [ -n "$arm_at" ] &&
   [ "$create_at" -lt "$verify_at" ] && [ "$verify_at" -lt "$arm_at" ]; then ordered=yes; fi
assert_eq "the head check sits after gh pr create and before the Arm auto-merge step" yes "$ordered"

ordered=no
commit_at=$(first_line '^2\. \*\*Review the diff')
if [ -n "$cross_at" ] && [ -n "$create_at" ] && [ -n "$commit_at" ] &&
   [ "$cross_at" -lt "$commit_at" ] && [ "$cross_at" -lt "$create_at" ]; then ordered=yes; fi
assert_eq "the branch's PR is read (same-repo only) before the commit step and gh pr create" yes "$ordered"

denied=no
grep -qF -- "Auto-merge: not armed (denied by the repo's permission rules)" "$ship" && denied=yes
assert_eq "the denied-arm outcome line is spelled out" yes "$denied"

assert_eq "the single arm call stays single" 1 \
  "$(grep -cF -- 'gh pr merge <N> --repo {repo} --auto' "$ship" | tr -d ' ')"

assert_eq "ship names workflow-gap.sh" yes "$(grep -qF -- 'workflow-gap.sh' "$ship" && echo yes || echo no)"
assert_eq "ship carries Expected red: none" yes "$(grep -qF -- 'Expected red: none' "$ship" && echo yes || echo no)"
assert_eq "ship carries Expected red: unread" yes "$(grep -qF -- 'Expected red: unread' "$ship" && echo yes || echo no)"

gap_at=$(first_line 'workflow-gap.sh')
push_at=$(first_line '^3\. \*\*Push the branch')
ordered=no
if [ -n "$gap_at" ] && [ -n "$commit_at" ] && [ -n "$push_at" ] &&
   [ "$commit_at" -lt "$gap_at" ] && [ "$gap_at" -lt "$push_at" ]; then ordered=yes; fi
assert_eq "workflow-gap.sh is named between the commit step and the Push the branch step" yes "$ordered"

open_at=$(first_line '^5\. \*\*Open the PR against')
title_at=$(first_line '^6\. \*\*Verify the PR head')
red_at=$(grep -n -F -- 'the body carries the same `Expected red:` line' "$ship" | head -n 1 | cut -d: -f1)
ordered=no
if [ -n "$open_at" ] && [ -n "$title_at" ] && [ -n "$red_at" ] &&
   [ "$open_at" -lt "$red_at" ] && [ "$red_at" -lt "$title_at" ]; then ordered=yes; fi
assert_eq "the Open the PR step names the Expected red: paragraph" yes "$ordered"

exit "$fail"
