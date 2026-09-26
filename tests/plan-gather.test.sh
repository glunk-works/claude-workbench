#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/plan-gather.sh.
#
# `gh` is stubbed the same way tests/plan-anchor.test.sh stubs it: keyed only by
# the API PATH, trusting the --jq expression the real script sends for that
# endpoint (pinned by construction -- this file and the script under test are
# maintained together). It does NOT interpret --jq, so it cannot exercise
# plan-gather.sh's own --jq filter or gh's own pagination -- both run inside the
# real `gh` binary. This suite therefore tests only what plan-gather.sh's own
# shell code does: the `LC_ALL=C sort` step (fed pre-shuffled rows standing in
# for whatever --jq already emitted) and the gh-failure-vs-legitimately-empty
# distinction. It makes no claim about pagination correctness or the live
# per-page `--jq` sort bug this script's design avoids -- that correctness
# argument lives in the script's own header comment, verified live against a
# real repo, not re-verified per test run.
#
# The fake `gh` scans its OWN ARGUMENTS for the request path rather than
# assuming a fixed position -- plan-anchor.sh's calls put the path right after
# `api`, but plan-gather.sh's calls put `--paginate` before the path, so a stub
# keyed on `$2` would break here.
#
# The stub also asserts the caller's EXPECTED query fragment (`FAKE_EXPECT`)
# actually appears in the path -- e.g. `titles` and `milestones` hit the same
# `repos/*/milestones?...` shape and would otherwise be indistinguishable to a
# stub that only routes on the endpoint, which would silently let `titles`
# regress from `state=all` to `state=open` (bringing back the closed-milestone
# naming-collision bug this subcommand exists to fix) with every fixture still
# passing.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/plan-gather.sh"

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

assert_status() {
  desc="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected exit [$expected], got [$actual]" >&2
    fail=1
  fi
}

# --- the fake gh -------------------------------------------------------
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
cat >"$fakebin/gh" <<'FAKE_GH'
#!/bin/sh
set -eu
[ "$1" = api ] || { echo "fake gh: unsupported command $1" >&2; exit 1; }
shift
path=""
for a in "$@"; do
  case "$a" in
    repos/*) path="$a"; break ;;
  esac
done
[ -n "$path" ] || { echo "fake gh: no repos/* path found in args: $*" >&2; exit 1; }
case "$path" in
  repos/*/issues\?*) ;;
  repos/*/milestones\?*) ;;
  *) echo "fake gh: unrecognised path $path" >&2; exit 1 ;;
esac
if [ -n "${FAKE_EXPECT:-}" ]; then
  case "$path" in
    *"$FAKE_EXPECT"*) ;;
    *) echo "fake gh: expected '$FAKE_EXPECT' in path, got: $path" >&2; exit 1 ;;
  esac
fi
[ "${FAKE_FAIL:-0}" = 1 ] && { echo "fake gh: simulated failure" >&2; exit 1; }
printf '%s' "${FAKE_ROWS-}"
FAKE_GH
chmod +x "$fakebin/gh"

run() { # run <args...> -- invokes the script under test with the fake gh on PATH
  PATH="$fakebin:$PATH" "$script" "$@"
}

REPO="o/r"
tab="$(printf '\t')"

echo "# usage / argument validation"

out=0; "$script" >/dev/null 2>&1 || out=$?
assert_status "no arguments at all exits non-zero" 1 "$out"

out=0; "$script" bogus "$REPO" >/dev/null 2>&1 || out=$?
assert_status "an unrecognised subcommand exits non-zero" 1 "$out"

out=0; "$script" unmilestoned >/dev/null 2>&1 || out=$?
assert_status "unmilestoned with no repo argument exits non-zero" 1 "$out"

out=0; "$script" unmilestoned "$REPO" extra >/dev/null 2>&1 || out=$?
assert_status "unmilestoned with an extra argument exits non-zero" 1 "$out"

echo "# unmilestoned -- ascending issue-number sort"

# Pre-shuffled rows, as if --jq had already projected them (unsorted) --
# out of numeric order on purpose.
shuffled="42${tab}2026-09-01T00:00:00Z${tab}MEMBER${tab}z issue
7${tab}2026-09-02T00:00:00Z${tab}OWNER${tab}a issue
150${tab}2026-09-03T00:00:00Z${tab}COLLABORATOR${tab}m issue"
expected="7${tab}2026-09-02T00:00:00Z${tab}OWNER${tab}a issue
42${tab}2026-09-01T00:00:00Z${tab}MEMBER${tab}z issue
150${tab}2026-09-03T00:00:00Z${tab}COLLABORATOR${tab}m issue"
# FAKE_EXPECT makes the stub itself abort (loudly, non-zero) if the script
# doesn't actually send `milestone=none` -- a silent behavior change here would
# otherwise pass every assertion below unchanged, since the stub ignores the
# query string except for this check.
out="$(FAKE_EXPECT="milestone=none" FAKE_ROWS="$shuffled" run unmilestoned "$REPO")"
assert_eq "unmilestoned: rows sort ascending by issue number, not input order" "$expected" "$out"

echo "# unmilestoned -- gh failure vs. legitimately empty"

status=0
FAKE_EXPECT="milestone=none" FAKE_FAIL=1 run unmilestoned "$REPO" >"$tmp/out" 2>"$tmp/err" || status=$?
assert_status "unmilestoned: a failed gh call exits non-zero" 1 "$status"
assert_eq "unmilestoned: a failed gh call prints nothing on stdout" "" "$(cat "$tmp/out")"

status=0
out="$(FAKE_EXPECT="milestone=none" FAKE_ROWS="" run unmilestoned "$REPO")" || status=$?
assert_status "unmilestoned: a successful call with zero rows exits zero" 0 "$status"
assert_eq "unmilestoned: zero rows is legitimately empty output, not an error" "" "$out"

echo "# milestones -- due-date-ascending sort, undated last, numeric tie-break"

shuffled="6${tab}Sprint 6${tab}none${tab}2${tab}0
5${tab}Sprint 5${tab}2026-12-08T00:00:00Z${tab}3${tab}1
4${tab}Sprint 4${tab}2026-10-01T00:00:00Z${tab}0${tab}9
9${tab}Sprint 9 (tie)${tab}2026-10-01T00:00:00Z${tab}1${tab}0"
expected="4${tab}Sprint 4${tab}2026-10-01T00:00:00Z${tab}0${tab}9
9${tab}Sprint 9 (tie)${tab}2026-10-01T00:00:00Z${tab}1${tab}0
5${tab}Sprint 5${tab}2026-12-08T00:00:00Z${tab}3${tab}1
6${tab}Sprint 6${tab}none${tab}2${tab}0"
# FAKE_EXPECT="state=open" catches a regression that would send `state=all`
# here instead -- the two subcommands hit the same endpoint shape and would
# otherwise be indistinguishable to the stub.
out="$(FAKE_EXPECT="state=open" FAKE_ROWS="$shuffled" run milestones "$REPO")"
assert_eq "milestones: dated rows sort by due_on ascending, undated sorts last, same-date ties break by number" \
  "$expected" "$out"

echo "# milestones -- gh failure vs. legitimately empty"

status=0
FAKE_EXPECT="state=open" FAKE_FAIL=1 run milestones "$REPO" >"$tmp/out" 2>"$tmp/err" || status=$?
assert_status "milestones: a failed gh call exits non-zero" 1 "$status"
assert_eq "milestones: a failed gh call prints nothing on stdout" "" "$(cat "$tmp/out")"

status=0
out="$(FAKE_EXPECT="state=open" FAKE_ROWS="" run milestones "$REPO")" || status=$?
assert_status "milestones: a successful call with zero rows exits zero" 0 "$status"
assert_eq "milestones: zero rows is legitimately empty output, not an error" "" "$out"

echo "# titles -- ascending number sort, open and closed both present"

shuffled="6${tab}open${tab}Sprint 6
1${tab}closed${tab}Sprint 1
5${tab}open${tab}Sprint 5"
expected="1${tab}closed${tab}Sprint 1
5${tab}open${tab}Sprint 5
6${tab}open${tab}Sprint 6"
# FAKE_EXPECT="state=all" is the regression this subcommand exists to prevent:
# if it silently sent `state=open` instead, the closed-milestone naming-
# collision check plan-sprint relies on this for would go blind again, and
# every assertion below would still pass unchanged without this check.
out="$(FAKE_EXPECT="state=all" FAKE_ROWS="$shuffled" run titles "$REPO")"
assert_eq "titles: rows sort ascending by milestone number, open and closed both included" \
  "$expected" "$out"

echo "# titles -- gh failure vs. legitimately empty"

status=0
FAKE_EXPECT="state=all" FAKE_FAIL=1 run titles "$REPO" >"$tmp/out" 2>"$tmp/err" || status=$?
assert_status "titles: a failed gh call exits non-zero" 1 "$status"
assert_eq "titles: a failed gh call prints nothing on stdout" "" "$(cat "$tmp/out")"

status=0
out="$(FAKE_EXPECT="state=all" FAKE_ROWS="" run titles "$REPO")" || status=$?
assert_status "titles: a successful call with zero rows exits zero" 0 "$status"
assert_eq "titles: zero rows is legitimately empty output, not an error" "" "$out"

echo "# milestone-issues -- argument validation"

out=0; "$script" milestone-issues "$REPO" >/dev/null 2>&1 || out=$?
assert_status "milestone-issues with no milestone-number argument exits non-zero" 1 "$out"

out=0; "$script" milestone-issues "$REPO" abc >/dev/null 2>&1 || out=$?
assert_status "milestone-issues with a non-digit milestone number exits non-zero" 1 "$out"

out=0; "$script" milestone-issues "$REPO" 5 extra >/dev/null 2>&1 || out=$?
assert_status "milestone-issues with an extra argument exits non-zero" 1 "$out"

echo "# milestone-issues -- ascending issue-number sort"

shuffled="42${tab}z issue
7${tab}a issue"
expected="7${tab}a issue
42${tab}z issue"
out="$(FAKE_EXPECT="milestone=5" FAKE_ROWS="$shuffled" run milestone-issues "$REPO" 5)"
assert_eq "milestone-issues: rows sort ascending by issue number" "$expected" "$out"

echo "# milestone-issues -- gh failure vs. legitimately empty"

status=0
FAKE_EXPECT="milestone=5" FAKE_FAIL=1 run milestone-issues "$REPO" 5 >"$tmp/out" 2>"$tmp/err" || status=$?
assert_status "milestone-issues: a failed gh call exits non-zero" 1 "$status"
assert_eq "milestone-issues: a failed gh call prints nothing on stdout" "" "$(cat "$tmp/out")"

status=0
out="$(FAKE_EXPECT="milestone=5" FAKE_ROWS="" run milestone-issues "$REPO" 5)" || status=$?
assert_status "milestone-issues: a successful call with zero rows exits zero" 0 "$status"
assert_eq "milestone-issues: zero rows is legitimately empty output, not an error" "" "$out"

exit "$fail"
