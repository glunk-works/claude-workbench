#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/review-gate-state.sh.
#
# The bug class this guards against is a gate reader that answers from one surface
# when the gate is on the other (issue #91: pr-checks read check-runs only, so a
# status-shaped gate was invisible to it). So the fixtures are record streams in the
# exact TAB-separated shape the script's own header tells the caller to produce with
# `gh api --jq ... @tsv`, fed to the real script -- both shapes, each alone; absent;
# the issue's mixed case (status success beside a stale check-run failure); the
# superseded-run trap on check-runs alone; the precedence rule between pending and
# failure; exact, byte-for-byte name matching (a runner job with the gate's name as a
# prefix, an escaped name, a name with a backslash or a space); other contexts' records
# and input hygiene (CRLF, blank lines, no trailing newline); the exit-0 stderr line;
# and every path that must refuse to answer. stdout is asserted as exactly the one word
# (command substitution strips trailing newlines, so a stray trailing blank line is the
# one thing this shape cannot see), together with the exit status.
#
# Seven mutations were run by hand when this suite was written, each restored before
# the next: swapping the success/pending precedence (1 red), swapping pending/failure
# (2 red), changing the name test to a prefix match (2 red), re-mapping `skipped` to
# failure (1 red), deleting the status arity guard (1 red), the check-run arity guard
# (1 red), and the blank-line skip (1 red). Checked by doing it, not by reading, and
# not a claim about any other line. One line is NOT pinned here: the `\r` strip. On the
# authoring machine's gawk (MSYS) the CR is swallowed before the script sees it, so the
# CRLF fixture passes with the strip deleted; it pins the line on a Linux awk only.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/review-gate-state.sh"

fail=0

# assert_verdict <desc> <expected-stdout> <expected-exit> <gate> <records>
# <records> is a printf %b string: `\t` for the field separator, `\n` between lines.
assert_verdict() {
  desc="$1"; want_out="$2"; want_st="$3"; gate="$4"; records="$5"
  st=0
  out="$(printf '%b' "$records" | sh "$script" "$gate" 2>/dev/null)" || st=$?
  if [ "$out" = "$want_out" ] && [ "$st" = "$want_st" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$want_out]/exit $want_st, got [$out]/exit $st" >&2
    fail=1
  fi
}

G=review-gate   # stands where {review.ci_gate.check} would be -- never a real repo's name

# The exit-0 stderr line is load-bearing -- both callers report "which shape carried the
# gate" from it -- so its shape is pinned once here, on the mixed case.
diag="$(printf 'status\t%s\tsuccess\ncheck-run\t%s\tcompleted\tfailure\n' "$G" "$G" \
  | sh "$script" "$G" 2>&1 >/dev/null)"
if [ "$diag" = "review-gate-state.sh: $G: status=[success] check-run=[failure]" ]; then
  echo "ok - stderr names what each surface carried"
else
  echo "FAIL - stderr names what each surface carried: got [$diag]" >&2
  fail=1
fi

# --- one surface at a time --------------------------------------------------------------

assert_verdict "status-shaped gate: success" success 0 "$G" \
  "status\t$G\tsuccess\n"
assert_verdict "status-shaped gate: pending" pending 0 "$G" \
  "status\t$G\tpending\n"
assert_verdict "status-shaped gate: failure" failure 0 "$G" \
  "status\t$G\tfailure\n"
assert_verdict "status-shaped gate: error is a failure" failure 0 "$G" \
  "status\t$G\terror\n"

assert_verdict "check-run-shaped gate: completed success" success 0 "$G" \
  "check-run\t$G\tcompleted\tsuccess\n"
assert_verdict "check-run-shaped gate: in_progress is pending" pending 0 "$G" \
  "check-run\t$G\tin_progress\t\n"
assert_verdict "check-run-shaped gate: queued is pending" pending 0 "$G" \
  "check-run\t$G\tqueued\t\n"
assert_verdict "check-run-shaped gate: completed failure" failure 0 "$G" \
  "check-run\t$G\tcompleted\tfailure\n"
assert_verdict "check-run-shaped gate: cancelled is a failure" failure 0 "$G" \
  "check-run\t$G\tcompleted\tcancelled\n"
assert_verdict "check-run-shaped gate: timed_out is a failure" failure 0 "$G" \
  "check-run\t$G\tcompleted\ttimed_out\n"
assert_verdict "check-run-shaped gate: stale is a failure" failure 0 "$G" \
  "check-run\t$G\tcompleted\tstale\n"

# GitHub's required-check evaluation counts these as passing; the script agrees, and
# its header states the error direction that buys.
assert_verdict "check-run-shaped gate: neutral counts as success" success 0 "$G" \
  "check-run\t$G\tcompleted\tneutral\n"
assert_verdict "check-run-shaped gate: skipped counts as success" success 0 "$G" \
  "check-run\t$G\tcompleted\tskipped\n"

# --- absent -----------------------------------------------------------------------------

assert_verdict "absent: empty input" absent 0 "$G" ""
assert_verdict "absent: only other contexts and names on both surfaces" absent 0 "$G" \
  "status\tlint\tsuccess\ncheck-run\ttest\tcompleted\tsuccess\n"
# The runner job's check-run carries the gate's name as a PREFIX. It is not the gate.
assert_verdict "absent: a runner job named <gate>-runner is not the gate" absent 0 "$G" \
  "check-run\t$G-runner\tcompleted\tfailure\n"
assert_verdict "absent: a status context with the gate as a prefix is not the gate" absent 0 "$G" \
  "status\t$G-runner\tsuccess\n"
# The name is compared byte for byte and nothing is unescaped: a name @tsv had to
# escape reads as absent, and a gate name with a backslash reaches awk intact (ENVIRON,
# not -v, which would turn `\b` into a backspace before the compare). Escaping here is
# two layers deep -- double quotes, then printf %b -- so 8 backslashes below reach the
# record as 2 and 4 reach it as 1; the gate argument is single-quoted and literal.
assert_verdict "absent: a name @tsv escaped does not match its unescaped form" absent 0 'a\b' \
  "status\ta\\\\\\\\b\tsuccess\n"
assert_verdict "exact: a gate name with a backslash matches the same bytes" success 0 'a\b' \
  "status\ta\\\\b\tsuccess\n"
assert_verdict "exact: a gate name with a space is one argument" success 0 "Review Gate" \
  "status\tReview Gate\tsuccess\n"

# --- both surfaces ----------------------------------------------------------------------

# The issue's mixed case: the status posted against the resolved head is green, the
# runner's own check-run is red and stays red until re-run.
assert_verdict "mixed: status success beside a check-run failure is success" success 0 "$G" \
  "status\t$G\tsuccess\ncheck-run\t$G\tcompleted\tfailure\n"
assert_verdict "mixed: check-run success beside a status failure is success" success 0 "$G" \
  "status\t$G\tfailure\ncheck-run\t$G\tcompleted\tsuccess\n"
assert_verdict "mixed: status success beside a check-run still running is success" success 0 "$G" \
  "status\t$G\tsuccess\ncheck-run\t$G\tin_progress\t\n"
assert_verdict "mixed: status failure beside a check-run still running is pending" pending 0 "$G" \
  "status\t$G\tfailure\ncheck-run\t$G\tqueued\t\n"
assert_verdict "mixed: both surfaces red is failure" failure 0 "$G" \
  "status\t$G\tfailure\ncheck-run\t$G\tcompleted\tfailure\n"

# The superseded-run trap on check-runs alone: pull_request run failed before the review
# existed, pull_request_review run passed after. The failed one never self-clears.
assert_verdict "superseded run: check-run failure then success is success" success 0 "$G" \
  "check-run\t$G\tcompleted\tfailure\ncheck-run\t$G\tcompleted\tsuccess\n"
assert_verdict "superseded run: order does not matter" success 0 "$G" \
  "check-run\t$G\tcompleted\tsuccess\ncheck-run\t$G\tcompleted\tfailure\n"
assert_verdict "superseded run: stale failure beside a re-run in progress is pending" pending 0 "$G" \
  "check-run\t$G\tcompleted\tfailure\ncheck-run\t$G\tin_progress\t\n"

# Records for other checks never influence the gate's verdict.
assert_verdict "other checks red, gate green: success" success 0 "$G" \
  "status\tlint\tfailure\ncheck-run\ttest\tcompleted\tfailure\nstatus\t$G\tsuccess\n"
assert_verdict "other checks green, gate red: failure" failure 0 "$G" \
  "status\tlint\tsuccess\ncheck-run\ttest\tcompleted\tsuccess\ncheck-run\t$G\tcompleted\tfailure\n"

# --- input hygiene ----------------------------------------------------------------------

assert_verdict "CRLF line endings are tolerated" success 0 "$G" \
  "status\t$G\tsuccess\r\n"
assert_verdict "blank lines are tolerated" success 0 "$G" \
  "\nstatus\t$G\tsuccess\n\n"
assert_verdict "no trailing newline on the last record" success 0 "$G" \
  "status\t$G\tsuccess"

# --- cannot answer: exit 2, nothing on stdout -------------------------------------------

st=0; out="$(printf 'status\t%s\tsuccess\n' "$G" | sh "$script" 2>/dev/null)" || st=$?
if [ "$out" = "" ] && [ "$st" = 2 ]; then echo "ok - no gate name: exit 2"; else
  echo "FAIL - no gate name: expected []/exit 2, got [$out]/exit $st" >&2; fail=1; fi
assert_verdict "empty gate name: exit 2" "" 2 "" \
  "status\t$G\tsuccess\n"
assert_verdict "malformed status record (two fields): exit 2" "" 2 "$G" \
  "status\t$G\n"
assert_verdict "malformed check-run record (three fields): exit 2" "" 2 "$G" \
  "check-run\t$G\tcompleted\n"
# Over-long records pin the arity guards on their own: a SHORT record is also caught by
# the vocabulary check (its state field reads as empty), so only a long one can tell the
# two guards apart. Found by mutation, not by reading.
assert_verdict "malformed status record (four fields): exit 2" "" 2 "$G" \
  "status\t$G\tsuccess\textra\n"
assert_verdict "malformed check-run record (five fields): exit 2" "" 2 "$G" \
  "check-run\t$G\tcompleted\tsuccess\textra\n"
assert_verdict "unknown record kind: exit 2" "" 2 "$G" \
  "commit\t$G\tsuccess\n"
assert_verdict "unknown status state: exit 2" "" 2 "$G" \
  "status\t$G\tgreen\n"
assert_verdict "unknown check-run status: exit 2" "" 2 "$G" \
  "check-run\t$G\trunning\t\n"
assert_verdict "unknown check-run conclusion: exit 2" "" 2 "$G" \
  "check-run\t$G\tcompleted\tpassed\n"
assert_verdict "completed check-run with no conclusion: exit 2" "" 2 "$G" \
  "check-run\t$G\tcompleted\t\n"
# A malformed record refuses even when an earlier record already answered: a stream
# this script cannot fully read is a stream it does not report on.
assert_verdict "a malformed record after a success still refuses: exit 2" "" 2 "$G" \
  "status\t$G\tsuccess\ncheck-run\t$G\n"
# Vocabulary is checked only on the gate's own records: an unknown state on some OTHER
# context is that context's problem, not a reason to refuse an answer about the gate.
assert_verdict "unknown state on another context does not refuse" success 0 "$G" \
  "status\tlint\tgreen\nstatus\t$G\tsuccess\n"

if [ "$fail" -ne 0 ]; then
  echo "review-gate-state.sh fixtures: FAILED" >&2
  exit 1
fi
echo "review-gate-state.sh fixtures: all passed"
