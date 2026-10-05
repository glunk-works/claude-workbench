#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/blocked-state.sh.
#
# Issue #224: /way-of-working:pr-checks must tell GitHub re-evaluation lag from the
# standing effect of a restrict-updates ruleset. Under that ruleset every green PR reads
# `mergeStateStatus: BLOCKED` to every viewer, so "BLOCKED + green" is lag only when no
# `update` rule applies to the base branch. This suite covers both shapes the issue names,
# and the fail-closed edges around them.
#
# The script reads rule types on stdin and two arguments; there is no gh to stub.
#
# Permitted toolset: POSIX sh and its standard utilities. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/blocked-state.sh"

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

# run <state> <green> <stdin-text>  -> "<stdout>|<exit>"
run() {
  out="$(printf '%s' "$3" | sh "$script" "$1" "$2" 2>/dev/null)" && rc=0 || rc=$?
  printf '%s|%s' "$out" "$rc"
}

# run_raw <state> <green> <printf-format>: pipes printf's output straight in, so bytes a
# command substitution would strip (Git Bash's bash drops CR from $(...)) reach the script.
run_raw() {
  out="$(printf "$3" | sh "$script" "$1" "$2" 2>/dev/null)" && rc=0 || rc=$?
  printf '%s|%s' "$out" "$rc"
}

restrict="$(printf 'deletion\nnon_fast_forward\npull_request\nrequired_status_checks\nupdate\n')"
plain="$(printf 'deletion\nnon_fast_forward\npull_request\nrequired_status_checks\n')"

assert_eq "BLOCKED + green + an update rule -> admin-merge-ready" \
  "admin-merge-ready|0" "$(run BLOCKED 1 "$restrict
")"
assert_eq "BLOCKED + green + no update rule -> lag" \
  "lag|0" "$(run BLOCKED 1 "$plain
")"
assert_eq "BLOCKED + green + no rules at all -> lag" "lag|0" "$(run BLOCKED 1 "")"
assert_eq "BLOCKED + not green + an update rule -> blocked (checks, not the restriction)" \
  "blocked|0" "$(run BLOCKED 0 "$restrict
")"
assert_eq "BLOCKED + not green + no update rule -> blocked" \
  "blocked|0" "$(run BLOCKED 0 "$plain
")"

for st in BEHIND CLEAN DIRTY DRAFT HAS_HOOKS UNKNOWN UNSTABLE; do
  assert_eq "$st -> not-blocked, whatever the rules and checks say" \
    "not-blocked|0" "$(run "$st" 1 "$restrict
")"
done

assert_eq "a final rule line with no trailing newline is still read" \
  "admin-merge-ready|0" "$(run BLOCKED 1 "pull_request
update")"

assert_eq "a CRLF-terminated update line (Windows gh) still counts" \
  "admin-merge-ready|0" "$(run_raw BLOCKED 1 'pull_request\r\nupdate\r\n')"

assert_eq "only the exact type 'update' counts (not 'update_x', not 'required_update')" \
  "lag|0" "$(run BLOCKED 1 "$(printf 'update_x\nrequired_update\nupdates\n')")"

# --- fail closed: cannot answer -> no stdout, exit 2 ---------------------
assert_eq "no arguments -> exit 2, no stdout" "|2" \
  "$(printf '' | sh "$script" 2>/dev/null && echo "|0" || printf '|%s' "$?")"
assert_eq "an unrecognised state -> exit 2" "|2" "$(run MERGEABLE 1 "")"
assert_eq "green other than 0/1 -> exit 2" "|2" "$(run BLOCKED yes "")"
assert_eq "green empty -> exit 2" "|2" "$(run BLOCKED '' "")"
assert_eq "a stdin line that is not a bare token -> exit 2" "|2" \
  "$(run BLOCKED 1 "pull_request
update; rm -rf /
")"
assert_eq "an uppercase UPDATE is not the rule type (and not a token) -> exit 2" "|2" \
  "$(run BLOCKED 1 "UPDATE
")"
assert_eq "a CR-only line -> exit 2" "|2" "$(run_raw BLOCKED 1 'update\n\r\n')"
assert_eq "a blank line in the rule list -> exit 2" "|2" \
  "$(run BLOCKED 1 "update

pull_request
")"
assert_eq "a JSON error body where rule types belong -> exit 2" "|2" \
  "$(run BLOCKED 1 '{"message":"Not Found"}
')"

if [ "$fail" -ne 0 ]; then
  echo "blocked-state.test.sh: FAILED" >&2
  exit 1
fi
echo "blocked-state.test.sh: all passed"
