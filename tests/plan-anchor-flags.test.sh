#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/plan-anchor-flags.sh: the one place the identity flags for
# `plan-anchor.sh verify` are built from a project.yml (#1221).
#
# The real gh-identity.sh is copied beside the helper in a temp bin (neither script calls `gh`, so no stub).
# Each case writes a project.yml and asserts the helper's stdout and exit code; a refusal is exit 2 with empty stdout.
# Needs yq (mikefarah v4); skips, loudly, without it.
# Permitted toolset: POSIX sh, plus yq.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
bin_src="$root_dir/plugins/way-of-working/bin"

if ! command -v yq >/dev/null 2>&1; then
  echo "SKIP - yq not on PATH; plan-anchor-flags.test.sh needs it" >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
cp "$bin_src/plan-anchor-flags.sh" "$bin_src/gh-identity.sh" "$tmp/bin/"
script="$tmp/bin/plan-anchor-flags.sh"

fail=0
assert_eq() { # <desc> <want> <got>
  if [ "$2" = "$3" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$2], got [$3]" >&2
    fail=1
  fi
}

n=0
# run_ <file> [args...]: sets out and rc
run_() {
  rc=0
  out="$(sh "$script" "$@" 2>/dev/null)" || rc=$?
}
# ok_ <desc> <want-stdout> <yaml>
ok_() {
  n=$((n + 1))
  printf '%s\n' "$3" >"$tmp/p$n.yml"
  run_ "$tmp/p$n.yml"
  assert_eq "$1 (stdout)" "$2" "$out"
  assert_eq "$1 (exit)" 0 "$rc"
}
# refuse_ <desc> <yaml>
refuse_() {
  n=$((n + 1))
  printf '%s\n' "$2" >"$tmp/p$n.yml"
  run_ "$tmp/p$n.yml"
  assert_eq "$1 (stdout)" "" "$out"
  assert_eq "$1 (exit)" 2 "$rc"
}

ORCH='orchestration:
  loop_identity: "loop-app[bot]"'
MAINT='  maintainer:
    - { login: maint1, id: 101 }
    - { login: maint2, id: 102 }'
DEV='  dev_app: { login: "dev-app[bot]", id: 201 }'
REV='  reviewer_app: { login: "rev-app[bot]", id: 202 }'
LOOP='  loop_app: { login: "loop-app[bot]", id: 203 }'
full="$ORCH
identities:
$MAINT
$DEV
$REV
$LOOP"

nl='
'
ok_ "full map" "--loop-identity${nl}loop-app[bot]${nl}--maintainer-ids${nl}101,102${nl}--dev-app-id${nl}201${nl}--declared-app-ids${nl}201,202,203" "$full"
ok_ "legacy with a loop identity" "--loop-identity${nl}loop-app[bot]" "$ORCH
identities: null"
ok_ "legacy with a null loop identity" "" "orchestration:
  loop_identity: null
identities: null"
ok_ "orchestration null, legacy" "" "orchestration: null
identities: null"
ok_ "orchestration null, map" "--maintainer-ids${nl}101,102${nl}--dev-app-id${nl}201${nl}--declared-app-ids${nl}201,202,203" "orchestration: null
identities:
$MAINT
$DEV
$REV
$LOOP"
ok_ "dev_app null" "--loop-identity${nl}loop-app[bot]${nl}--maintainer-ids${nl}101,102${nl}--declared-app-ids${nl}202,203" "$ORCH
identities:
$MAINT
  dev_app: null
$REV
$LOOP"
ok_ "all three Apps null" "--loop-identity${nl}loop-app[bot]${nl}--maintainer-ids${nl}101,102" "$ORCH
identities:
$MAINT
  dev_app: null
  reviewer_app: null
  loop_app: null"
ok_ "a bare-slug loop identity" "--loop-identity${nl}loop-app${nl}--maintainer-ids${nl}101,102${nl}--dev-app-id${nl}201${nl}--declared-app-ids${nl}201,202,203" "orchestration:
  loop_identity: loop-app
identities:
$MAINT
$DEV
$REV
$LOOP"
ok_ "anchors inside identities expand" "--loop-identity${nl}loop-app[bot]${nl}--maintainer-ids${nl}101${nl}--dev-app-id${nl}201${nl}--declared-app-ids${nl}201" "$ORCH
identities:
  maintainer:
    - &m { login: maint1, id: 101 }
  dev_app: &d { login: \"dev-app[bot]\", id: 201 }
  reviewer_app: null
  loop_app: null"

refuse_ "identities itself an alias" "$ORCH
base: &b
  maintainer:
    - { login: maint1, id: 101 }
  dev_app: null
  reviewer_app: null
  loop_app: null
identities: *b"
refuse_ "a missing orchestration key" "identities:
$MAINT
$DEV
$REV
$LOOP"
refuse_ "a missing loop_identity key" "orchestration:
  round_cap: 2
identities: null"
refuse_ "an empty loop_identity" "orchestration:
  loop_identity: \"\"
identities: null"
refuse_ "a loop_identity with an embedded newline" "orchestration:
  loop_identity: \"loop\\nother\"
identities: null"
refuse_ "a loop_identity with a trailing newline" "orchestration:
  loop_identity: \"loop\\n\"
identities: null"
refuse_ "a loop_identity starting with --" "orchestration:
  loop_identity: \"--maintainer-ids\"
identities: null"
refuse_ "a loop_identity that is not a string" "orchestration:
  loop_identity: 7
identities: null"
refuse_ "a missing identities key" "$ORCH"
refuse_ "identities a string" "$ORCH
identities: nope"
refuse_ "an empty maintainer list" "$ORCH
identities:
  maintainer: []
$DEV
$REV
$LOOP"
refuse_ "a maintainer with a string id" "$ORCH
identities:
  maintainer:
    - { login: maint1, id: \"101\" }
$DEV
$REV
$LOOP"
refuse_ "one malformed maintainer among good ones" "$ORCH
identities:
  maintainer:
    - { login: maint1, id: 101 }
    - { login: maint2 }
$DEV
$REV
$LOOP"
refuse_ "a hex maintainer id" "$ORCH
identities:
  maintainer:
    - { login: maint1, id: 0x65 }
$DEV
$REV
$LOOP"
refuse_ "a maintainer id of 0 among good entries" "$ORCH
identities:
  maintainer:
    - { login: maint1, id: 101 }
    - { login: maint2, id: 0 }
$DEV
$REV
$LOOP"
refuse_ "no maintainer key" "$ORCH
identities:
$DEV
$REV
$LOOP"
refuse_ "orchestration a scalar" "orchestration: 5
identities: null"
refuse_ "a 40-character loop_identity" "orchestration:
  loop_identity: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
identities: null"
ok_ "a 39-character loop_identity" "--loop-identity${nl}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa[bot]" "orchestration:
  loop_identity: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa[bot]
identities: null"
ok_ "orchestration expanded from an alias" "--loop-identity${nl}loop-app[bot]" "o: &o
  loop_identity: loop-app[bot]
orchestration: *o
identities: null"
refuse_ "a missing dev_app key" "$ORCH
identities:
$MAINT
$REV
$LOOP"
refuse_ "a missing reviewer_app key" "$ORCH
identities:
$MAINT
$DEV
$LOOP"
refuse_ "a missing loop_app key" "$ORCH
identities:
$MAINT
$DEV
$REV"
refuse_ "a malformed App entry" "$ORCH
identities:
$MAINT
  dev_app: { login: \"dev-app[bot]\" }
$REV
$LOOP"
refuse_ "an App id also on the maintainer list" "$ORCH
identities:
$MAINT
  dev_app: { login: \"dev-app[bot]\", id: 101 }
$REV
$LOOP"
refuse_ "one id declared twice" "$ORCH
identities:
$MAINT
$DEV
  reviewer_app: { login: \"rev-app[bot]\", id: 201 }
$LOOP"

# --- argument and sibling refusals ---
printf '%s\n' "$full" >"$tmp/good.yml"
run_
assert_eq "no argument (stdout)" "" "$out"
assert_eq "no argument (exit)" 2 "$rc"
run_ "$tmp/good.yml" extra
assert_eq "two arguments (stdout)" "" "$out"
assert_eq "two arguments (exit)" 2 "$rc"
run_ "$tmp/missing.yml"
assert_eq "a missing file (stdout)" "" "$out"
assert_eq "a missing file (exit)" 2 "$rc"
printf 'a: [unclosed\n' >"$tmp/bad.yml"
run_ "$tmp/bad.yml"
assert_eq "a non-YAML file (stdout)" "" "$out"
assert_eq "a non-YAML file (exit)" 2 "$rc"

rc=0
out="$(cd "$tmp/bin" && PATH="$tmp/bin:$PATH" sh -c '. /dev/null; exec sh plan-anchor-flags.sh "$1"' x "$tmp/good.yml" 2>/dev/null)" || rc=$?
# `sh plan-anchor-flags.sh` has a slash-less $0: it must refuse rather than look in the current directory.
assert_eq "a slash-less invocation (stdout)" "" "$out"
assert_eq "a slash-less invocation (exit)" 2 "$rc"

mkdir "$tmp/lone"
cp "$bin_src/plan-anchor-flags.sh" "$tmp/lone/"
rc=0
out="$(sh "$tmp/lone/plan-anchor-flags.sh" "$tmp/good.yml" 2>/dev/null)" || rc=$?
assert_eq "a missing gh-identity.sh sibling (stdout)" "" "$out"
assert_eq "a missing gh-identity.sh sibling (exit)" 2 "$rc"

[ "$fail" -eq 0 ] || exit 1
echo "plan-anchor-flags: all cases passed"
