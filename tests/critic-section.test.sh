#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/critic-section.sh (WB-D22, `#230`).
#
# The script replaces, or reads back, the `## Critic pass` section of a PR body. The ways
# that goes wrong are quiet, so each is a fixture: a heading inside a code fence taken for
# the real one (on either path), a replacement that eats the section after it or loses the
# blank line before it, an append that glues onto the last line, a deeper heading
# (`### Critic pass`) taken for the section, a CRLF body whose other lines must survive byte
# for byte, a later duplicate being edited instead of the first, and a section file that
# would make `get` truncate the record. stdout is compared byte for byte through files, so a
# stray trailing newline is visible, which command substitution would hide.
#
# Mutations to run by hand when this suite changes (each restored before the next): drop the
# fence tracking in `track` (the fence fixtures go red); drop the `print ""` before a heading
# that ends a replaced section; match `### Critic pass` as well; drop the `!replaced` test so
# a later duplicate is replaced too. Checked by doing it, not by reading.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/critic-section.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

fail=0
BT='```'

# check <desc> <expected-file> <actual-file> [<expected-exit> <actual-exit>]
same() {
  if cmp -s "$2" "$3"; then echo "ok - $1"; else
    echo "FAIL - $1" >&2
    echo "--- expected" >&2; od -c "$2" | head -20 >&2
    echo "--- got" >&2; od -c "$3" | head -20 >&2
    fail=1
  fi
}

# put_case <desc> <body-printf-format> <section-printf-format> <expected-printf-format>
put_case() {
  desc="$1"
  printf "$2" >"$work/body"
  printf "$3" >"$work/sec"
  printf "$4" >"$work/want"
  st=0
  sh "$script" put "$work/sec" <"$work/body" >"$work/got" 2>/dev/null || st=$?
  if [ "$st" != 0 ]; then echo "FAIL - $desc: exit $st" >&2; fail=1; return; fi
  same "put: $desc" "$work/want" "$work/got"
}

# get_case <desc> <body-printf-format> <expected-exit> <expected-printf-format>
get_case() {
  desc="$1"
  printf "$2" >"$work/body"
  printf "$4" >"$work/want"
  st=0
  sh "$script" get <"$work/body" >"$work/got" 2>/dev/null || st=$?
  if [ "$st" != "$3" ]; then echo "FAIL - get: $desc: expected exit $3, got $st" >&2; fail=1; return; fi
  same "get: $desc" "$work/want" "$work/got"
}

# refuse <desc> <body-printf-format> <section-printf-format|--> <args...>
# Expects exit 2 and nothing on stdout.
refuse() {
  desc="$1"; shift
  printf "$1" >"$work/body"; shift
  printf "$1" >"$work/sec"; shift
  st=0
  sh "$script" "$@" <"$work/body" >"$work/got" 2>/dev/null || st=$?
  if [ "$st" = 2 ] && [ ! -s "$work/got" ]; then echo "ok - $desc"; else
    echo "FAIL - $desc: expected exit 2 and no stdout, got exit $st / $(wc -c <"$work/got") bytes" >&2
    fail=1
  fi
}

NEW='## Critic pass\n2 rounds, converged.\n'

# --- put: replace ---------------------------------------------------------------------

put_case "replaces a section in the middle, keeping the blank line before the next heading" \
  '# Title\n\n## Critic pass\nold\nold2\n\n## Test plan\n- x\n' "$NEW" \
  '# Title\n\n## Critic pass\n2 rounds, converged.\n\n## Test plan\n- x\n'
put_case "replaces a section at the end of the body" \
  'intro\n\n## Critic pass\nold\n' "$NEW" \
  'intro\n\n## Critic pass\n2 rounds, converged.\n'
put_case "replaces a body that is only the section" \
  '## Critic pass\nold\n' "$NEW" '## Critic pass\n2 rounds, converged.\n'
put_case "heading with trailing whitespace is the section" \
  'a\n\n## Critic pass  \nold\n## Next\nz\n' "$NEW" \
  'a\n\n## Critic pass\n2 rounds, converged.\n\n## Next\nz\n'
put_case "a deeper heading inside the old section does not end it" \
  '## Critic pass\nold\n### detail\nmore\n## Next\nz\n' "$NEW" \
  '## Critic pass\n2 rounds, converged.\n\n## Next\nz\n'

# --- put: append ----------------------------------------------------------------------

put_case "appends after one blank line when absent" \
  'intro line\n' "$NEW" 'intro line\n\n## Critic pass\n2 rounds, converged.\n'
put_case "appends with no extra blank when the body already ends in one" \
  'intro line\n\n' "$NEW" 'intro line\n\n## Critic pass\n2 rounds, converged.\n'
put_case "an empty body becomes just the section" '' "$NEW" '## Critic pass\n2 rounds, converged.\n'
put_case "a body with no trailing newline still gets a clean append" \
  'intro line' "$NEW" 'intro line\n\n## Critic pass\n2 rounds, converged.\n'
put_case "a deeper Critic pass heading is not the section: append" \
  '### Critic pass\nold\n' "$NEW" '### Critic pass\nold\n\n## Critic pass\n2 rounds, converged.\n'
put_case "a longer heading is not the section: append" \
  '## Critic pass notes\nold\n' "$NEW" '## Critic pass notes\nold\n\n## Critic pass\n2 rounds, converged.\n'
put_case "an indented heading is not the section: append" \
  ' ## Critic pass\nold\n' "$NEW" ' ## Critic pass\nold\n\n## Critic pass\n2 rounds, converged.\n'

# --- put: code fences -----------------------------------------------------------------

put_case "a heading inside a backtick fence is not the section: append" \
  "intro\n\n$BT\n## Critic pass\nexample\n$BT\n" "$NEW" \
  "intro\n\n$BT\n## Critic pass\nexample\n$BT\n\n## Critic pass\n2 rounds, converged.\n"
put_case "a heading inside a tilde fence is not the section: append" \
  'intro\n\n~~~\n## Critic pass\nexample\n~~~\n' "$NEW" \
  'intro\n\n~~~\n## Critic pass\nexample\n~~~\n\n## Critic pass\n2 rounds, converged.\n'
put_case "the real heading after a fenced decoy is the one replaced" \
  "$BT\n## Critic pass\ndecoy\n$BT\n\n## Critic pass\nold\n" "$NEW" \
  "$BT\n## Critic pass\ndecoy\n$BT\n\n## Critic pass\n2 rounds, converged.\n"
put_case "a ## inside a fence in the old section does not end the replacement" \
  "## Critic pass\nold\n$BT\n## not a heading\n$BT\nstill old\n## Next\nz\n" "$NEW" \
  '## Critic pass\n2 rounds, converged.\n\n## Next\nz\n'
put_case "a tilde line does not close a backtick fence" \
  "$BT\n~~~\n## Critic pass\nx\n$BT\n" "$NEW" \
  "$BT\n~~~\n## Critic pass\nx\n$BT\n\n## Critic pass\n2 rounds, converged.\n"
put_case "a fence indented by three spaces still counts" \
  "intro\n   $BT\n## Critic pass\nx\n   $BT\n" "$NEW" \
  "intro\n   $BT\n## Critic pass\nx\n   $BT\n\n## Critic pass\n2 rounds, converged.\n"
put_case "a fence-like line indented by four spaces is not a fence" \
  "    $BT\n## Critic pass\nold\n" "$NEW" "    $BT\n## Critic pass\n2 rounds, converged.\n"

# --- put: duplicates, CRLF ------------------------------------------------------------

put_case "only the FIRST section is replaced; a later copy is left alone" \
  '## Critic pass\nfirst\n## Mid\nm\n## Critic pass\nsecond\n' "$NEW" \
  '## Critic pass\n2 rounds, converged.\n\n## Mid\nm\n## Critic pass\nsecond\n'
# CRLF: the heading must match through a trailing carriage return. Byte-for-byte survival of
# the OTHER lines' CRs is a property of the awk, not of this script's logic: the authoring
# machine's gawk (MSYS) swallows the CR before the script sees it, so the comparison strips
# CRs from both sides and pins only the matching and the structure.
printf 'a\r\n\r\n## Critic pass\r\nold\r\n## Next\r\nz\r\n' >"$work/body"
printf "$NEW" >"$work/sec"
sh "$script" put "$work/sec" <"$work/body" | tr -d '\r' >"$work/got"
printf 'a\n\n## Critic pass\n2 rounds, converged.\n\n## Next\nz\n' >"$work/want"
same "put: a CRLF body's heading matches and the next section survives" "$work/want" "$work/got"

# a section file with its own fence carrying a ## line is allowed, and survives a round trip
printf '## Critic pass\nrounds\n%s\n## inside a fence\n%s\n' "$BT" "$BT" >"$work/fsec"
printf 'x\n' | sh "$script" put "$work/fsec" >"$work/b1"
sh "$script" get <"$work/b1" >"$work/g1"
printf 'rounds\n%s\n## inside a fence\n%s\n' "$BT" "$BT" >"$work/w1"
same "put then get round-trips a section whose fence carries a ## line" "$work/w1" "$work/g1"

# --- get ------------------------------------------------------------------------------

get_case "reads the section up to the next heading, dropping the trailing blank" \
  'intro\n\n## Critic pass\n2 rounds, converged.\n+1 on fable.\n\n## Test plan\nx\n' 0 \
  '2 rounds, converged.\n+1 on fable.\n'
get_case "reads a section that runs to the end of the body" \
  '## Critic pass\nonly line\n' 0 'only line\n'
get_case "absent: exit 3, nothing printed" 'no section here\n' 3 ''
get_case "empty body: exit 3" '' 3 ''
get_case "a fenced decoy is not the section" "$BT\n## Critic pass\nx\n$BT\n" 3 ''
get_case "a deeper heading is not the section" '### Critic pass\nx\n' 3 ''
get_case "a ## inside a fence does not end the section" \
  "## Critic pass\na\n$BT\n## not a heading\n$BT\nb\n## Next\nz\n" 0 \
  "a\n$BT\n## not a heading\n$BT\nb\n"
get_case "only the first section is read" \
  '## Critic pass\nfirst\n## Critic pass\nsecond\n' 0 'first\n'
get_case "CRLF is stripped from what is read back" '## Critic pass\r\nrounds\r\n' 0 'rounds\n'
get_case "a section with an empty body prints nothing and still exits 0" '## Critic pass\n## Next\n' 0 ''
get_case "a fence line with an info string does not close a fence" \
  "$BT\n${BT}bash\n## Critic pass\nfake\n$BT\n## Other\n" 3 ''
get_case "a shorter fence line does not close a longer one" \
  "$BT$BT\n$BT\n## Critic pass\nfake\n$BT$BT\n" 3 ''
get_case "a longer closing fence with trailing spaces does close" \
  "$BT\ncode\n$BT$BT  \n## Critic pass\nreal\n" 0 'real\n'
refuse "a section file that leaves a code fence open" 'x\n' "## Critic pass\nrounds\n$BT\nunclosed\n" put "$work/sec"
refuse "a body that ends inside an open fence (append would be swallowed)" "Summary
$BT
echo hi
" "$NEW" put "$work/sec"
refuse "an existing section whose body ends inside an open fence" "## Critic pass
old
$BT
open
## Testing
x
" "$NEW" put "$work/sec"

# --- refusals -------------------------------------------------------------------------

refuse "a section file whose first line is not the heading" 'x\n' 'rounds\n' put "$work/sec"
refuse "a section file carrying another ## heading" 'x\n' '## Critic pass\na\n## Other\nb\n' put "$work/sec"
refuse "an empty section file" 'x\n' '' put "$work/sec"
refuse "put with no section file argument" 'x\n' '' put
refuse "a missing section file" 'x\n' '' put "$work/does-not-exist"
refuse "get with an extra argument" 'x\n' '' get extra
refuse "an unknown mode" 'x\n' '' bogus
refuse "no mode" 'x\n' ''

exit "$fail"
