#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/plan-depends.sh -- the read-back of the
# per-issue `depends_on` marker plan-sprint records in a new milestone's **Build order:**
# list. Pure parsing of a file the caller hands over, so there is no gh stub here.
#
# The contract under test is fail-closed: anything doubtful reads as
# `all-earlier <reason>` (the item waits for every earlier one), never as `independent`.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/plan-depends.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

assert_eq() {
  desc="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$expected], got [$actual]" >&2
    fail=1
  fi
}

# read_n <issue> -- reads $tmp/desc for that issue
read_n() { sh "$script" read "$tmp/desc" "$1"; }

write_desc() { # write_desc <build-order-body> -- wraps it in a realistic description
  {
    printf 'Batch reason. Ships as nothing.\n\n**Build order:**\n'
    cat
    printf '\n**Model per phase** (`models:` in .ai/project.yml):\n- Build: coder for all.\n'
  } >"$tmp/desc"
}

echo "# a well-formed list"

write_desc <<'EOF'
1. #231: lands first. [depends_on: none]
2. #232: needs the first. [depends_on: #231]
3. #233: needs both. [depends_on: #231, #232]
4. #234: independent of everything. [depends_on: none]
EOF
assert_eq "none reads as independent" "independent" "$(read_n 231)"
assert_eq "a single dependency reads back" "after 231" "$(read_n 232)"
assert_eq "two dependencies read back, in order" "after 231 232" "$(read_n 233)"
assert_eq "none after other items is still independent" "independent" "$(read_n 234)"
assert_eq "an issue outside the list is not-listed" "all-earlier not-listed" "$(read_n 999)"

echo "# unconfirmed -- no marker at all"

write_desc <<'EOF'
1. #231: lands first. [depends_on: none]
2. #232: the human never confirmed one for this.
EOF
assert_eq "an item with no marker reads as unconfirmed" "all-earlier unconfirmed" "$(read_n 232)"
assert_eq "its neighbour with a marker is unaffected" "independent" "$(read_n 231)"

write_desc <<'EOF'
1. #231: lands first.
2. #232: second.
EOF
assert_eq "a list with no markers anywhere is all unconfirmed" "all-earlier unconfirmed" "$(read_n 232)"

echo "# malformed marker -- unreadable, never independent"

write_desc <<'EOF'
1. #231: first. [depends_on: none]
2. #232: marker not at the end. [depends_on: none] and more prose
3. #233: bad grammar. [depends_on: #231 #232]
4. #234: empty. [depends_on: ]
5. #235: wrong word. [depends_on: nothing]
6. #236: lowercase typo. [depend_on: none]
EOF
assert_eq "text after the marker is unreadable" "all-earlier unreadable" "$(read_n 232)"
assert_eq "space-separated dependencies are unreadable" "all-earlier unreadable" "$(read_n 233)"
assert_eq "an empty marker is unreadable" "all-earlier unreadable" "$(read_n 234)"
assert_eq "an unknown value is unreadable" "all-earlier unreadable" "$(read_n 235)"
assert_eq "a misspelt key reads as no marker, so unconfirmed" "all-earlier unconfirmed" "$(read_n 236)"

echo "# a forged marker inside the reason text"

write_desc <<'EOF'
1. #231: first. [depends_on: none]
2. #232: reason carrying [depends_on: none] inside it. [depends_on: #231]
EOF
assert_eq "two markers on one item read as unreadable, neither wins" "all-earlier unreadable" "$(read_n 232)"

echo "# dependencies that make no sense"

write_desc <<'EOF'
1. #231: first. [depends_on: #232]
2. #232: second. [depends_on: #232]
3. #233: third. [depends_on: #999]
4. #234: fourth. [depends_on: #235]
5. #235: fifth. [depends_on: none]
EOF
assert_eq "a dependency on a later item is unreadable" "all-earlier unreadable" "$(read_n 231)"
assert_eq "a dependency on itself is unreadable" "all-earlier unreadable" "$(read_n 232)"
assert_eq "a dependency on an unlisted issue is unreadable" "all-earlier unreadable" "$(read_n 233)"
assert_eq "a dependency on a later listed item is unreadable" "all-earlier unreadable" "$(read_n 234)"

write_desc <<'EOF'
1. #231: first. [depends_on: none]
2. #232: a reason carrying [depends_on: none] on the first line
   and the real marker on the continuation. [depends_on: #231]
3. #233: marker alone on its own continuation line.
   [depends_on: none]
4. #234: names the same issue twice. [depends_on: #231, #231]
5. #235: leading zero in a dependency. [depends_on: #0231]
EOF
assert_eq "a forged token across a wrapped item is unreadable" "all-earlier unreadable" "$(read_n 232)"
assert_eq "a marker alone on a continuation line is read" "independent" "$(read_n 233)"
assert_eq "a repeated dependency is unreadable" "all-earlier unreadable" "$(read_n 234)"
assert_eq "a dependency with a leading zero is unreadable" "all-earlier unreadable" "$(read_n 235)"

echo "# structural damage to the list"

write_desc <<'EOF'
2. #231: numbering starts at 2. [depends_on: none]
EOF
assert_eq "numbering that starts at 2 is unreadable" "all-earlier unreadable" "$(read_n 231)"

write_desc <<'EOF'
01. #231: leading zero in the position. [depends_on: none]
EOF
assert_eq "a position with a leading zero is unreadable" "all-earlier unreadable" "$(read_n 231)"

write_desc <<'EOF'
1. #0231: leading zero in the issue. [depends_on: none]
EOF
assert_eq "an issue number with a leading zero is unreadable" "all-earlier unreadable" "$(read_n 231)"

write_desc <<'EOF'
1. #1234567890: ten digits. [depends_on: none]
EOF
assert_eq "an issue number over 9 digits is unreadable" "all-earlier unreadable" "$(read_n 999999999)"

write_desc <<'EOF'
1. #231: first. [depends_on: none]
3. #232: numbering skips. [depends_on: none]
EOF
assert_eq "numbering that is not 1..k is unreadable for every item" "all-earlier unreadable" "$(read_n 231)"
assert_eq "...including the item after the skip" "all-earlier unreadable" "$(read_n 232)"
assert_eq "...and a number not in the list, never not-listed" "all-earlier unreadable" "$(read_n 999)"

write_desc <<'EOF'
1. #231: first. [depends_on: none]
2. #231: the same issue again. [depends_on: none]
EOF
assert_eq "a repeated issue number is unreadable" "all-earlier unreadable" "$(read_n 231)"

printf 'No build order here at all.\n' >"$tmp/desc"
assert_eq "a description with no Build order header is unreadable" "all-earlier unreadable" "$(read_n 1)"

printf '**Build order:**\n1. #231: a. [depends_on: none]\n\n**Build order:**\n1. #232: b. [depends_on: none]\n' >"$tmp/desc"
assert_eq "two Build order headers are unreadable" "all-earlier unreadable" "$(read_n 231)"

printf '**Build order:**\n\n1. #231: a. [depends_on: none]\n' >"$tmp/desc"
assert_eq "a header with no item directly under it is unreadable" "all-earlier unreadable" "$(read_n 231)"

rm -f "$tmp/desc"
assert_eq "a missing file is unreadable, exit 0" "all-earlier unreadable" "$(read_n 1)"
mkdir "$tmp/dir"
assert_eq "a directory is unreadable" "all-earlier unreadable" "$(sh "$script" read "$tmp/dir" 1)"

echo "# formats the description may arrive in"

printf '**Build order:**\r\n1. #231: a. [depends_on: none]\r\n2. #232: b. [depends_on: #231]\r\n\r\n**BLOCKING:** x\r\n' >"$tmp/desc"
assert_eq "CRLF line endings read the same" "after 231" "$(read_n 232)"

write_desc <<'EOF'
1. #231: first. [depends_on: none]
2. #232: a long reason that the human wrapped
   onto a second line. [depends_on: #231]
3. #233: last one. [depends_on: none]
EOF
assert_eq "a wrapped item finds its marker on the continuation line" "after 231" "$(read_n 232)"
assert_eq "the item after a wrapped one still parses" "independent" "$(read_n 233)"

write_desc <<'EOF'
1. #231: first. [depends_on: none]
EOF
printf '2. #232: past the list, after the blank line. [depends_on: none]\n' >>"$tmp/desc"
assert_eq "an item past the end of the list is not part of it" "all-earlier not-listed" "$(read_n 232)"

echo "# the marker is never trusted from outside the list"

printf 'Reason. [depends_on: none]\n\n**Build order:**\n1. #231: first.\n' >"$tmp/desc"
assert_eq "a marker outside the Build order list does not apply" "all-earlier unconfirmed" "$(read_n 231)"

echo "# usage errors"

status=0
sh "$script" read "$tmp/desc" 12x >"$tmp/out" 2>/dev/null || status=$?
assert_eq "a non-digit issue number exits 1" "1" "$status"
assert_eq "a non-digit issue number prints nothing on stdout" "" "$(cat "$tmp/out")"

status=0
sh "$script" read "$tmp/desc" 0231 >"$tmp/out" 2>/dev/null || status=$?
assert_eq "an issue number with a leading zero exits 1" "1" "$status"

status=0
sh "$script" read "$tmp/desc" 1234567890 >"$tmp/out" 2>/dev/null || status=$?
assert_eq "an issue number over 9 digits exits 1" "1" "$status"

# a file operand shaped like an awk variable assignment must still be read as a file
mkdir "$tmp/assign" && printf '**Build order:**\n1. #231: a. [depends_on: none]\n' >"$tmp/assign/want=999"
assert_eq "a file named like an awk assignment is read as a file" "independent" \
  "$(cd "$tmp/assign" && sh "$script" read "want=999" 231)"

status=0
sh "$script" read "$tmp/desc" >"$tmp/out" 2>/dev/null || status=$?
assert_eq "a missing argument exits 1" "1" "$status"

status=0
sh "$script" bogus "$tmp/desc" 1 >"$tmp/out" 2>/dev/null || status=$?
assert_eq "an unknown subcommand exits 1" "1" "$status"

exit "$fail"
