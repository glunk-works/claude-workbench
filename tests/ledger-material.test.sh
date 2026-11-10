#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/ledger-material.sh.
#
# Issue #1376: handoff syncs the ledger only when a material line kind changed. This is the
# predicate that decides it; `unreadable` is what a ledger in another shape must read.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/ledger-material.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$2], got [$3]" >&2
    fail=1
  fi
}

# base ledger: $1 = path; $2 = Just done line; $3 = Now text; $4 = Next text;
# $5 = HITL continuation text; $6 = extra trailing block
mk() {
  cat >"$1" <<EOT
# Cursor

**Now:** $3

**Just done:** $2

**Next:** $4

**HITL Gate: OPEN** — first line
$5

**Critic pass:** none

**Pointers:** a
$6
EOT
}

mk "$tmp/base" "x" "now" "next" "continuation" ""
mk "$tmp/same" "x" "now" "next" "continuation" ""
mk "$tmp/narr" "other bullets" "now" "next" "continuation" ""
sed 's/^\*\*Critic pass:\*\* none/**Critic pass:** pass 1 done/; s/^\*\*Pointers:\*\* a/**Pointers:** b/' "$tmp/base" >"$tmp/narr2"
mk "$tmp/now" "x" "now2" "next" "continuation" ""
mk "$tmp/next" "x" "now" "next2" "continuation" ""
mk "$tmp/cont" "x" "now" "next" "continuation changed" ""
mk "$tmp/mc0" "x" "now" "next" "continuation" "
**Milestone close:** closed"
mk "$tmp/mcb" "x" "now" "next" "continuation" "
- **Milestone close:** closed"
mk "$tmp/mc1" "x" "now" "next" "continuation" "
**Milestone close:** closed again"
mk "$tmp/ind" "x" "now" "next" "continuation" "
  **Next:** indented marker one
  **Milestone close:** indented"
mk "$tmp/ind2" "x" "now" "next" "continuation" "
  **Next:** indented marker two"

run() { sh "$script" "$@" 2>/dev/null; }

assert_eq "identical ledgers" same "$(run "$tmp/base" "$tmp/same")"
assert_eq "same ledger against itself" same "$(run "$tmp/base" "$tmp/base")"
assert_eq "Just done differs only" same "$(run "$tmp/base" "$tmp/narr")"
assert_eq "critic record and pointers differ only" same "$(run "$tmp/base" "$tmp/narr2")"
assert_eq "Now changed" changed "$(run "$tmp/base" "$tmp/now")"
assert_eq "Next changed" changed "$(run "$tmp/base" "$tmp/next")"
assert_eq "HITL continuation line changed" changed "$(run "$tmp/base" "$tmp/cont")"
assert_eq "Milestone close in the new file only, column 0" changed "$(run "$tmp/base" "$tmp/mc0")"
assert_eq "Milestone close in the old file only, column 0" changed "$(run "$tmp/mc0" "$tmp/base")"
assert_eq "Milestone close in the new file only, bullet form" changed "$(run "$tmp/base" "$tmp/mcb")"
assert_eq "Milestone close text changed" changed "$(run "$tmp/mc0" "$tmp/mc1")"
assert_eq "Milestone close column 0 vs bullet form" changed "$(run "$tmp/mc0" "$tmp/mcb")"
assert_eq "Milestone close equal" same "$(run "$tmp/mc0" "$tmp/mc0")"
assert_eq "indented marker lines are ignored" same "$(run "$tmp/base" "$tmp/ind")"
assert_eq "indented marker lines differ, still ignored" same "$(run "$tmp/ind" "$tmp/ind2")"

# Now and Next written as bullets: another shape, never same.
sed 's/^\*\*Now:\*\*/- **Now:**/; s/^\*\*Next:\*\*/- **Next:**/' "$tmp/base" >"$tmp/bullets"
assert_eq "bulleted Now and Next, both sides" unreadable "$(run "$tmp/bullets" "$tmp/bullets")"
assert_eq "bulleted Now and Next, new side" unreadable "$(run "$tmp/base" "$tmp/bullets")"
sed '/^\*\*HITL Gate/,/^$/d' "$tmp/base" >"$tmp/nohitl"
assert_eq "no HITL Gate line" unreadable "$(run "$tmp/nohitl" "$tmp/nohitl")"

# No trailing newline: the last line is read in full.
printf '**Now:** n\n\n**Next:** x\n\n**HITL Gate: OPEN** — a\nlast' >"$tmp/nonl1"
printf '**Now:** n\n\n**Next:** x\n\n**HITL Gate: OPEN** — a\nlast' >"$tmp/nonl2"
printf '**Now:** n\n\n**Next:** x\n\n**HITL Gate: OPEN** — a\nlast2' >"$tmp/nonl3"
assert_eq "no trailing newline, equal" same "$(run "$tmp/nonl1" "$tmp/nonl2")"
assert_eq "no trailing newline, last HITL line differs" changed "$(run "$tmp/nonl1" "$tmp/nonl3")"
printf '**Now:** n\n\n**Next:** x\n\n**HITL Gate: OPEN** — a\n' >"$tmp/nl"
printf '**Now:** n\n\n**Next:** x\n\n**HITL Gate: OPEN** — a' >"$tmp/nonl4"
assert_eq "trailing newline presence alone" same "$(run "$tmp/nl" "$tmp/nonl4")"

# Bad arguments.
assert_eq "missing file" unreadable "$(run "$tmp/base" "$tmp/absent")"
assert_eq "missing old file" unreadable "$(run "$tmp/absent" "$tmp/base")"
assert_eq "empty argument" unreadable "$(run "" "$tmp/base")"
assert_eq "one argument" unreadable "$(run "$tmp/base")"
assert_eq "three arguments" unreadable "$(run "$tmp/base" "$tmp/base" "$tmp/base")"
assert_eq "no arguments" unreadable "$(run)"
assert_eq "a directory" unreadable "$(run "$tmp" "$tmp/base")"

# Exit status is 0 on every word.
sh "$script" "$tmp/base" "$tmp/now" >/dev/null 2>&1 || { echo "FAIL - exit status on changed" >&2; fail=1; }
sh "$script" >/dev/null 2>&1 || { echo "FAIL - exit status on usage" >&2; fail=1; }

# The real ledger reads same against itself.
if [ -f "$root_dir/.ai/next-steps.md" ]; then
  assert_eq "this repo's ledger against itself" same "$(run "$root_dir/.ai/next-steps.md" "$root_dir/.ai/next-steps.md")"
fi

[ "$fail" -eq 0 ] || exit 1
echo "all ledger-material tests passed"
