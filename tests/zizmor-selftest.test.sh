#!/bin/sh
# Fixture tests for the `Gate step fails on a known finding` step of the `zizmor` job in
# .github/workflows/ci.yml (#1237): the step passes only when the self-test run's outcome is
# `failure` and the fixture exists. The action's own exit code on GitHub's runner cannot run
# locally; the PR's `zizmor` job run is the evidence for that part.
#
# Needs yq (mikefarah v4); skips, loudly, when absent.
# Permitted toolset: POSIX sh and yq.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
ci_yml="$root_dir/.github/workflows/ci.yml"

if ! command -v yq >/dev/null 2>&1; then
  echo "SKIP - yq not found"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
check() {
  desc=$1; shift
  if "$@"; then echo "ok - $desc"; else echo "FAIL - $desc" >&2; fail=1; fi
}

STEP='Gate step fails on a known finding' yq -r \
  '.jobs.zizmor.steps[] | select(.name == strenv(STEP)) | .run' "$ci_yml" >"$tmp/step.sh"
check "the assertion step's run text was extracted" test -s "$tmp/step.sh"
check "the step reads the outcome through env, not inline" \
  test "$(STEP='Gate step fails on a known finding' yq -r '.jobs.zizmor.steps[] | select(.name == strenv(STEP)) | .env.SELFTEST_OUTCOME' "$ci_yml")" = '${{ steps.selftest.outcome }}'

run_step() { # run_step <dir> <outcome>: rc in $rc, output in $out
  rc=0
  out=$(cd "$1" && SELFTEST_OUTCOME=$2 sh "$tmp/step.sh" 2>&1) || rc=$?
}

run_step "$root_dir" failure
check "failure with the fixture present exits 0" test "$rc" -eq 0

for v in success skipped cancelled ''; do
  run_step "$root_dir" "$v"
  check "outcome [$v] exits non-zero" test "$rc" -ne 0
  case $out in *'::error::'*) e=0 ;; *) e=1 ;; esac
  check "outcome [$v] prints the ::error:: line" test "$e" -eq 0
done

mkdir "$tmp/empty"
run_step "$tmp/empty" failure
check "failure with no fixture exits non-zero" test "$rc" -ne 0
case $out in *'::error::'*) e=0 ;; *) e=1 ;; esac
check "failure with no fixture prints the ::error:: line" test "$e" -eq 0

check "the fixture file exists" test -f "$root_dir/.github/zizmor-selftest/known-finding.yml"

exit "$fail"
