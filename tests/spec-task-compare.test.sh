#!/bin/sh
# spec-task's refresh carry-forward compare (`norm()`, `anorm()`, `head_ok()`) as the skill loader hands it
# over with an argument (#1470). Before the fix the loader replaced the bare `$0` in those awk
# programs with the argument, so two drafts with the same number of lines and different text would compare equal.
#
# The three function lines are extracted from spec-task's SKILL.md, each `$0` is replaced with a
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
a=$(line anorm)
h=$(line head_ok)
ns=$(line nasec)
[ -n "$n" ] || { echo "FAIL - no norm() { line in spec-task's SKILL.md" >&2; exit 1; }
[ -n "$a" ] || { echo "FAIL - no anorm() { line in spec-task's SKILL.md" >&2; exit 1; }
[ -n "$h" ] || { echo "FAIL - no head_ok() { line in spec-task's SKILL.md" >&2; exit 1; }
[ -n "$ns" ] || { echo "FAIL - no nasec() { line in spec-task's SKILL.md" >&2; exit 1; }

# The loader's substitution: a bare $0 becomes the argument (a fixed number here).
n=$(printf '%s\n' "$n" | sed 's/\$0/7/g')
h=$(printf '%s\n' "$h" | sed 's/\$0/7/g')
a=$(printf '%s\n' "$a" | sed 's/\$0/7/g')
ns=$(printf '%s\n' "$ns" | sed 's/\$0/7/g')
eval "$n"
eval "$a"
eval "$h"
eval "$ns"

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

NA='### Not applied (tightenings)'
mkna() { # <file> <line-before-goal> <body-line> <section-heading-or-empty>: a draft whose section, if any, trails
  { printf 'spec-task: issue=1 base=main sha=abc\nModel provenance: x\n\n%s\n### Goal\n\n%s\n\nmore\n' "$2" "$3"
    [ -z "$4" ] || printf '\n%s\n\nTightenings the critic gate did not apply.\n- a bullet\n' "$4"
  } >"$1"
}
cmp_ap() { # <approved> <draft>: equal or different, the compare's verdict
  anorm "$1" >"$tmp/x.a" && norm "$2" >"$tmp/x.d" && cmp -s "$tmp/x.a" "$tmp/x.d" && echo equal || echo different
}

mkna "$tmp/ap" '' 'text' "$NA"
mkna "$tmp/dr" '' 'text' ''
[ "$(cmp_ap "$tmp/ap" "$tmp/dr")" = equal ] && ok "a trailing section on the approved side only compares equal" || no "a trailing section on the approved side only compares equal"
mkna "$tmp/dr2" '' 'changed' ''
[ "$(cmp_ap "$tmp/ap" "$tmp/dr2")" = different ] && ok "a changed line before the section compares different" || no "a changed line before the section compares different"
mkna "$tmp/dr3" '' 'text' "$NA"
[ "$(cmp_ap "$tmp/ap" "$tmp/dr3")" = different ] && ok "a draft that keeps the section compares different" || no "a draft that keeps the section compares different"
mkna "$tmp/ap4" "$NA" 'text' ''
mkna "$tmp/dr4" "$NA" 'text' ''
[ "$(cmp_ap "$tmp/ap4" "$tmp/dr4")" = equal ] && ok "a section heading before Goal does not cut the approved side" || no "a section heading before Goal does not cut the approved side"
grep -q 'more' "$tmp/x.a" && ok "the approved side kept its text after Goal" || no "the approved side kept its text after Goal"

# nasec: the approved comment's section, carried forward (#1533)
mkna "$tmp/n1" '' 'text' "$NA"
printf '\n\n' >>"$tmp/n1"
rc=0; nasec "$tmp/n1" >"$tmp/n1.out" || rc=$?
exp=$(printf '%s\n\nTightenings the critic gate did not apply.\n- a bullet\n' "$NA")
[ "$rc" -eq 0 ] && [ "$(cat "$tmp/n1.out")" = "$(printf '%s' "$exp")" ] && [ "$(tail -n 1 "$tmp/n1.out")" = '- a bullet' ] && ok "nasec prints the trailing section with trailing empty lines dropped" || no "nasec prints the trailing section with trailing empty lines dropped"
mkna "$tmp/n2" '' 'text' ''
rc=0; nasec "$tmp/n2" >"$tmp/n2.out" || rc=$?
[ "$rc" -eq 0 ] && [ ! -s "$tmp/n2.out" ] && ok "nasec prints nothing when there is no section" || no "nasec prints nothing when there is no section"
mkna "$tmp/n3" "$NA" 'text' ''
rc=0; nasec "$tmp/n3" >"$tmp/n3.out" || rc=$?
[ "$rc" -eq 0 ] && [ ! -s "$tmp/n3.out" ] && ok "nasec does not take a section heading before Goal" || no "nasec does not take a section heading before Goal"
mkna "$tmp/n4" '' 'text' "$NA"
sed 's/$/\r/' "$tmp/n4" >"$tmp/n4crlf"
rc=0; nasec "$tmp/n4crlf" >"$tmp/n4.out" || rc=$?
if [ "$rc" -eq 0 ] && [ -s "$tmp/n4.out" ] && ! grep -q "$(printf '\r')" "$tmp/n4.out"; then ok "nasec strips CR from CRLF line ends"; else no "nasec strips CR from CRLF line ends"; fi
printf 'no goal here\n%s\n' "$NA" >"$tmp/n5"
rc=0; nasec "$tmp/n5" >/dev/null || rc=$?
[ "$rc" -eq 3 ] && ok "nasec exits 3 without a Goal heading" || no "nasec exits 3 without a Goal heading (exit $rc)"

[ "$fail" -eq 0 ]
