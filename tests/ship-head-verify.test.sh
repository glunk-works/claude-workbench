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

exit "$fail"
