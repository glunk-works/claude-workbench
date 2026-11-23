#!/bin/sh
# Fixture tests for the `Report this shard's run time against its timeout` step of the `tests` job
# in .github/workflows/ci.yml (#1724): with the job's `timeout-minutes` key present the step prints
# and summarizes the `tests-N ran` line; with the key missing it fails, naming the key.
#
# Needs yq (mikefarah v4); skips, loudly, when absent.
# Permitted toolset: POSIX sh, bash, yq and date.
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

STEP="Report this shard's run time against its timeout" yq -r \
  '.jobs.tests.steps[] | select(.name == strenv(STEP)) | .run' "$ci_yml" >"$tmp/step.sh"
check "the report step's run text was extracted" test -s "$tmp/step.sh"

run_step() { # run_step <dir>: rc in $rc, stdout+stderr in $out, the summary file is $tmp/summary
  : >"$tmp/summary"
  rc=0
  out=$(cd "$1" && SHARD=1 STARTED=$(date +%s) GITHUB_STEP_SUMMARY="$tmp/summary" bash -e "$tmp/step.sh" 2>&1) || rc=$?
}

mkdir -p "$tmp/ok/.github/workflows" "$tmp/nokey/.github/workflows"
cp "$ci_yml" "$tmp/ok/.github/workflows/ci.yml"
cp "$ci_yml" "$tmp/nokey/.github/workflows/ci.yml"
bound=$(yq -e '.jobs.tests."timeout-minutes"' "$ci_yml")
yq -i 'del(.jobs.tests."timeout-minutes")' "$tmp/nokey/.github/workflows/ci.yml"

run_step "$tmp/ok"
check "key present: exits 0" test "$rc" -eq 0
want="of its ${bound}m timeout"
case $out in "tests-1 ran "*"$want") e=0 ;; *) e=1 ;; esac
check "key present: stdout carries the tests-1 ran line with the bound" test "$e" -eq 0
case $(cat "$tmp/summary") in "tests-1 ran "*"$want") e=0 ;; *) e=1 ;; esac
check "key present: the summary carries the same line" test "$e" -eq 0

run_step "$tmp/nokey"
check "key missing: exits non-zero" test "$rc" -ne 0
case $out in *'.jobs.tests."timeout-minutes"'*) e=0 ;; *) e=1 ;; esac
check "key missing: the output names the key" test "$e" -eq 0
check "key missing: the summary gets no line" test ! -s "$tmp/summary"

exit "$fail"
