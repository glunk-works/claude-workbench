#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/blocked-state.sh.
#
# Issue #224: /way-of-working:pr-checks must tell GitHub re-evaluation lag from the
# standing effect of a restrict-updates ruleset. Under that ruleset every green PR reads
# `mergeStateStatus: BLOCKED` to every viewer, so "BLOCKED + green" is lag only when no
# `update` rule applies to the base branch. This suite covers both shapes the issue names,
# and the fail-closed edges around them.
#
# The script reads rule lines on stdin and two arguments; there is no gh to stub.
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

pr0='pull_request approvals=0 threads=false codeowner=false reviewers=0'
rsc0='required_status_checks app_pinned=0'
restrict="$(printf 'deletion\nnon_fast_forward\n%s\n%s\nupdate\n' "$pr0" "$rsc0")"
plain="$(printf 'deletion\nnon_fast_forward\n%s\n%s\n' "$pr0" "$rsc0")"

# --- #248: a rule this script cannot evaluate is never read as absent --------
# Each is BLOCKED + green with an `update` rule present, i.e. exactly the shape that used
# to say admin-merge-ready. It must be exit 2, no stdout, and name the rule on stderr.
run_err() {   # run_err <state> <green> <stdin-text> -> stderr text
  printf '%s' "$3" | sh "$script" "$1" "$2" 2>&1 >/dev/null || true
}
unseen_case() {   # unseen_case <desc> <extra rule lines> <expected stderr fragment>
  desc="$1"; extra="$2"; frag="$3"
  in="$(printf 'deletion\nupdate\n%s\n%s\n%s\n' "$pr0" "$rsc0" "$extra")"
  assert_eq "$desc -> exit 2, no stdout" "|2" "$(run BLOCKED 1 "$in
")"
  case "$(run_err BLOCKED 1 "$in
")" in
    *"$frag"*) echo "ok - $desc: stderr names [$frag]" ;;
    *) echo "FAIL - $desc: stderr does not name [$frag]" >&2; fail=1 ;;
  esac
}
unseen_case "an approvals-required pull_request rule" \
  "$(printf 'pull_request approvals=2 threads=false codeowner=false reviewers=0')" "requires 2 approving review"
unseen_case "review-thread resolution on" \
  "$(printf 'pull_request approvals=0 threads=true codeowner=false reviewers=0')" "review-thread resolution"
unseen_case "code-owner review on" \
  "$(printf 'pull_request approvals=0 threads=false codeowner=true reviewers=0')" "code-owner review"
unseen_case "a required_deployments rule" "required_deployments" "required_deployments"
unseen_case "a code_scanning rule" "code_scanning" "code_scanning"
unseen_case "a required_signatures rule" "required_signatures" "required_signatures"
unseen_case "a merge_queue rule" "merge_queue" "merge_queue"
unseen_case "a required_status_checks context pinned to an app (integration_id; the script cannot tell a mismatch from a match)" \
  "required_status_checks app_pinned=1" "integration_id"
assert_eq "a bare pull_request line (parameters dropped) -> exit 2" "|2" \
  "$(run BLOCKED 1 "update
pull_request
")"
assert_eq "a bare required_status_checks line (parameters dropped) -> exit 2" "|2" \
  "$(run BLOCKED 1 "update
required_status_checks
")"
unseen_case "required reviewers named on a pull_request rule" \
  "$(printf 'pull_request approvals=0 threads=false codeowner=false reviewers=1')" "required reviewers"
assert_eq "a pull_request line missing a word (reviewers) -> exit 2" "|2" \
  "$(run BLOCKED 1 "update
pull_request approvals=0 threads=false codeowner=false
")"
assert_eq "an overlong approvals count refuses rather than reading as zero" "|2" \
  "$(run BLOCKED 1 "update
pull_request approvals=99999999999999999999 threads=false codeowner=false reviewers=0
")"
assert_eq "a repeated key (last one would win) -> exit 2" "|2" \
  "$(run BLOCKED 1 "update
pull_request approvals=5 approvals=0 threads=false codeowner=false reviewers=0
")"
assert_eq "a key on the wrong type -> exit 2" "|2" \
  "$(run BLOCKED 1 "update
required_status_checks app_pinned=0 threads=true
")"
assert_eq "a key on a type that takes none -> exit 2" "|2" "$(run BLOCKED 1 "update approvals=5
")"
assert_eq "a CRLF rule line that must refuse still refuses" "|2" \
  "$(run_raw BLOCKED 1 'update\r\nmerge_queue\r\n')"
assert_eq "an unseen rule with no update rule is not lag either -> exit 2" "|2" \
  "$(run BLOCKED 1 "$(printf '%s\nrequired_deployments' "$pr0")
")"
assert_eq "an unseen rule does not mask a red check -> blocked" "blocked|0" \
  "$(run BLOCKED 0 "$(printf 'update\nmerge_queue')
")"
assert_eq "an unseen rule says nothing about a PR that is not BLOCKED" "not-blocked|0" \
  "$(run CLEAN 1 "$(printf 'update\nmerge_queue')
")"
assert_eq "a rule type outside the lists is ignored, not unseen" "admin-merge-ready|0" \
  "$(run BLOCKED 1 "$(printf 'update\nworkflows')
")"
assert_eq "an unrecognised key=value word -> exit 2" "|2" \
  "$(run BLOCKED 1 "pull_request approvals=0 bogus=1
")"
assert_eq "a non-numeric count -> exit 2" "|2" \
  "$(run BLOCKED 1 "pull_request approvals=x threads=false codeowner=false reviewers=0
")"
assert_eq "a doubled space between words -> exit 2" "|2" \
  "$(run BLOCKED 1 "pull_request  approvals=0 threads=false codeowner=false reviewers=0
")"

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
  "admin-merge-ready|0" "$(run BLOCKED 1 "$pr0
update")"

assert_eq "a CRLF-terminated update line (Windows gh) still counts" \
  "admin-merge-ready|0" "$(run_raw BLOCKED 1 'pull_request approvals=0 threads=false codeowner=false reviewers=0\r\nupdate\r\n')"

assert_eq "only the exact type 'update' counts (not 'update_x', not 'required_update')" \
  "lag|0" "$(run BLOCKED 1 "$(printf 'update_x\nrequired_update\nupdates\n')")"

# --- fail closed: cannot answer -> no stdout, exit 2 ---------------------
assert_eq "no arguments -> exit 2, no stdout" "|2" \
  "$(printf '' | sh "$script" 2>/dev/null && echo "|0" || printf '|%s' "$?")"
assert_eq "an unrecognised state -> exit 2" "|2" "$(run MERGEABLE 1 "")"
assert_eq "green other than 0/1 -> exit 2" "|2" "$(run BLOCKED yes "")"
assert_eq "green empty -> exit 2" "|2" "$(run BLOCKED '' "")"
assert_eq "a stdin line with a character outside the rule-line alphabet -> exit 2" "|2" \
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
