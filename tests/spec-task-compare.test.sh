#!/bin/sh
# spec-task's refresh carry-forward compare (`norm()`, `head_ok()`) as the skill loader hands it
# over with an argument (#1470). Before the fix the loader replaced the bare `$0` in those awk
# programs with the argument, so two drafts with the same number of lines and different text would compare equal.
#
# The two function lines are extracted from spec-task's SKILL.md, each `$0` is replaced with a
# fixed number (the loader's substitution, the one #1466 saw), then they are defined and run.
#
# Permitted toolset: POSIX sh and its standard utilities.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
skill=$(ls "$root_dir"/plugins/*/skills/spec-task/SKILL.md)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
ok() { echo "ok - $1"; }
no() { echo "FAIL - $1" >&2; fail=1; }

line() { # <name>: the function's line, leading spaces and a trailing && removed
  grep "^ *$1() {" "$skill" | sed -n -e 's/^ *//' -e 's/ *&& *$//' -e 1p
}

n=$(line norm)
h=$(line head_ok)
[ -n "$n" ] || { echo "FAIL - no norm() { line in spec-task's SKILL.md" >&2; exit 1; }
[ -n "$h" ] || { echo "FAIL - no head_ok() { line in spec-task's SKILL.md" >&2; exit 1; }

# The loader's substitution: a bare $0 becomes the argument (a fixed number here).
n=$(printf '%s\n' "$n" | sed 's/\$0/7/g')
h=$(printf '%s\n' "$h" | sed 's/\$0/7/g')
eval "$n"
eval "$h"

mk() { # <file> <second-line-before-goal> <body-line>
  printf 'spec-task: issue=1 base=main sha=abc\n%s\n\n### Goal\n\n%s\n\nmore\n' "$2" "$3" >"$1"
}

mk "$tmp/a" 'Model provenance: x' 'first text'
mk "$tmp/b" 'Model provenance: x' 'other text'
cp "$tmp/a" "$tmp/a2"

norm "$tmp/a" >"$tmp/na" || { no "norm exits 0 on a"; }
norm "$tmp/b" >"$tmp/nb" || { no "norm exits 0 on b"; }
norm "$tmp/a2" >"$tmp/na2" || { no "norm exits 0 on a2"; }

if cmp -s "$tmp/na" "$tmp/nb"; then no "same-length drafts with different text compare different"; else ok "same-length drafts with different text compare different"; fi
if cmp -s "$tmp/na" "$tmp/na2"; then ok "identical drafts compare equal"; else no "identical drafts compare equal"; fi

mk "$tmp/good" 'Model provenance: x' 't'
mk "$tmp/bad" 'Something else' 't'
rc=0; head_ok "$tmp/good" || rc=$?
[ "$rc" -eq 0 ] && ok "a Model provenance second line passes head_ok" || no "a Model provenance second line passes head_ok (exit $rc)"
rc=0; head_ok "$tmp/bad" || rc=$?
[ "$rc" -eq 1 ] && ok "another second line fails head_ok" || no "another second line fails head_ok (exit $rc)"

[ "$fail" -eq 0 ]
