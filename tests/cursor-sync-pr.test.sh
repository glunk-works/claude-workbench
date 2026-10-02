#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/cursor-sync-pr.sh.
#
# Issue #215: /way-of-working:resume offers to merge a forgotten handoff cursor-sync
# PR. This predicate decides which PR, if any, may be offered.
#
# `gh` is stubbed the same way tests/plan-gather.test.sh stubs it: it does NOT
# interpret --jq, it returns pre-formed TSV standing in for what the real --jq
# would emit. So this suite tests the script's own shell code -- the shape checks,
# the candidate count, and each refusal -- not GitHub's field semantics. The stub
# does assert the call's own arguments (the base, `--state open`, the branch-prefix
# filter), so a regression there fails a fixture instead of passing silently.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/cursor-sync-pr.sh"

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

# --- the fake gh -------------------------------------------------------
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
cat >"$fakebin/gh" <<'FAKE_GH'
#!/bin/sh
set -eu
[ "$1" = pr ] && [ "$2" = list ] || { echo "fake gh: unsupported command $*" >&2; exit 1; }
args=" $* "
case "$args" in *" --base $FAKE_BASE "*) ;; *) echo "fake gh: base not $FAKE_BASE: $*" >&2; exit 1 ;; esac
case "$args" in *" --repo $FAKE_REPO "*) ;; *) echo "fake gh: repo not $FAKE_REPO: $*" >&2; exit 1 ;; esac
case "$args" in *" --state open "*) ;; *) echo "fake gh: not --state open: $*" >&2; exit 1 ;; esac
case "$args" in *'startswith("docs/sync-cursor-")'*) ;; *) echo "fake gh: prefix filter missing" >&2; exit 1 ;; esac
[ -z "${FAKE_FAIL:-}" ] || { echo "fake gh: HTTP 502" >&2; exit 1; }
cat "$FAKE_ROWS"
FAKE_GH
chmod +x "$fakebin/gh"

export FAKE_REPO=acme/widgets FAKE_BASE=main
oid_a=0123456789abcdef0123456789abcdef01234567
oid_b=89abcdef0123456789abcdef0123456789abcdef

# row <number> <oid> <cross> <state> <nfiles> <path>
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; }

run() { # run <rows-file> [extra env assignments are set by the caller]
  FAKE_ROWS="$1" PATH="$fakebin:$PATH" sh "$script" acme/widgets main 2>/dev/null
}

: >"$tmp/empty"
assert_eq "no candidate PR -> none" "none" "$(run "$tmp/empty")"

row 210 "$oid_a" false CLEAN 1 .ai/next-steps.md >"$tmp/clean"
assert_eq "one same-repo, one-file, CLEAN PR -> offer" "offer 210 $oid_a" "$(run "$tmp/clean")"

row 210 "$oid_a" false BEHIND 1 .ai/next-steps.md >"$tmp/behind"
assert_eq "BEHIND is still offered (gh pr merge refuses if the ruleset requires up-to-date)" \
  "offer 210 $oid_a" "$(run "$tmp/behind")"

row 210 "$oid_a" true CLEAN 1 .ai/next-steps.md >"$tmp/fork"
assert_eq "a fork PR is refused, whatever else it passes" \
  "refuse 210 cross-repository" "$(run "$tmp/fork")"

row 210 "$oid_a" false CLEAN 2 .ai/next-steps.md >"$tmp/twofiles"
assert_eq "a PR touching more than the cursor is refused" \
  "refuse 210 files" "$(run "$tmp/twofiles")"

row 210 "$oid_a" false CLEAN 1 docs/decisions.md >"$tmp/otherfile"
assert_eq "a one-file PR on some other file is refused" \
  "refuse 210 files" "$(run "$tmp/otherfile")"

row 210 "$oid_a" false CLEAN 0 "" >"$tmp/nofiles"
assert_eq "a PR with no changed files is refused" \
  "refuse 210 files" "$(run "$tmp/nofiles")"

row 210 "$oid_a" false BLOCKED 1 .ai/next-steps.md >"$tmp/blocked"
assert_eq "checks not green -> refused with the state named" \
  "refuse 210 state-blocked" "$(run "$tmp/blocked")"

row 210 "$oid_a" false DIRTY 1 .ai/next-steps.md >"$tmp/dirty"
assert_eq "a conflicted (stale) sync -> refused with the state named" \
  "refuse 210 state-dirty" "$(run "$tmp/dirty")"

row 210 "$oid_a" false UNKNOWN 1 .ai/next-steps.md >"$tmp/unknown"
assert_eq "GitHub still computing mergeability -> refused, not guessed" \
  "refuse 210 state-unknown" "$(run "$tmp/unknown")"

{ row 205 "$oid_a" false CLEAN 1 .ai/next-steps.md
  row 210 "$oid_b" false CLEAN 1 .ai/next-steps.md; } >"$tmp/two"
assert_eq "two candidates -> ambiguous, neither offered" \
  "ambiguous 205 210" "$(run "$tmp/two")"

{ row 205 "$oid_a" true CLEAN 1 .ai/next-steps.md
  row 210 "$oid_b" false CLEAN 1 .ai/next-steps.md; } >"$tmp/two-one-bad"
assert_eq "two candidates, one of them a fork -> still ambiguous (the human sorts it out)" \
  "ambiguous 205 210" "$(run "$tmp/two-one-bad")"

assert_eq "gh failure -> unreadable, never none" "unreadable" \
  "$(FAKE_FAIL=1 run "$tmp/clean")"

row 210 not-a-sha false CLEAN 1 .ai/next-steps.md >"$tmp/badoid"
assert_eq "a malformed head oid -> unreadable" "unreadable" "$(run "$tmp/badoid")"

row 210 0123456789abcdef >"$tmp/shortoid"
assert_eq "a short head oid -> unreadable" "unreadable" "$(run "$tmp/shortoid")"

row 21x "$oid_a" false CLEAN 1 .ai/next-steps.md >"$tmp/badnum"
assert_eq "a non-numeric PR number -> unreadable" "unreadable" "$(run "$tmp/badnum")"

row 210 "$oid_a" maybe CLEAN 1 .ai/next-steps.md >"$tmp/badcross"
assert_eq "a non-boolean isCrossRepository -> unreadable" "unreadable" "$(run "$tmp/badcross")"

{ row 210 "$oid_a" false CLEAN 1 .ai/next-steps.md | tr -d '\n'; printf '\textra\n'; } >"$tmp/extra"
assert_eq "an extra field -> unreadable" "unreadable" "$(run "$tmp/extra")"

assert_eq "no arguments -> unreadable" "unreadable" \
  "$(PATH="$fakebin:$PATH" sh "$script" 2>/dev/null)"

FAKE_BASE=develop
assert_eq "the base argument reaches gh (stub expects develop, script given main)" \
  "unreadable" "$(run "$tmp/clean")"
FAKE_BASE=main

if [ "$fail" -ne 0 ]; then
  echo "cursor-sync-pr.test.sh: FAILED" >&2
  exit 1
fi
echo "cursor-sync-pr.test.sh: all passed"
