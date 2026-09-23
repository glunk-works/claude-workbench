#!/bin/sh
# Resolve a review gate's state on one commit from BOTH surfaces GitHub can carry it on.
#
# A review gate ({review.ci_gate.check} in .ai/project.yml) reaches a commit one of two
# ways: as a CHECK-RUN -- the implicit one a workflow job creates, named after the job --
# or as a COMMIT STATUS -- the Statuses API, posted explicitly against a resolved head
# SHA by a job that may be named something else, which a repo does precisely because the
# implicit check-run attaches to the wrong commit on an issue_comment event. A reader
# that looks at only one surface reports "absent" for a gate that is right there on the
# other. /way-of-working:pr-checks step 3 read only check-runs, so on a status-shaped
# gate its stale-run verdict could never fire (issue #91). This is a deterministic
# predicate with a correctness argument, so it is a tested script the skills invoke
# rather than a rule described in prose (WB-D10).
#
# Usage: <records> | review-gate-state.sh <gate-name>
#
# stdin is one record per line, TAB-separated, produced by these two calls. `gh` embeds
# jq, so the caller needs no separate jq, and this script needs none either:
#
#   gh api --paginate "repos/{repo}/commits/$SHA/status" \
#     --jq '.statuses[] | ["status", .context, .state] | @tsv'
#   gh api --paginate "repos/{repo}/commits/$SHA/check-runs" \
#     --jq '.check_runs[] | ["check-run", .name, .status, (.conclusion // "")] | @tsv'
#
# Records whose context/name is not <gate-name> are ignored, so the caller does NOT
# filter in jq -- "absent" is this script's answer, and it is only testable here if the
# non-matching records reach it. The match is exact, byte for byte: a job named
# <gate-name>-runner is not the gate. Nothing is unescaped, so a name @tsv had to escape
# (one carrying a backslash, tab, or newline) never matches and reads as absent -- the
# closed direction, and a name no real gate has.
#
# Prints exactly one word to stdout and exits 0:
#   success  -- some record for the gate is a success
#   pending  -- no success, and some record is not yet terminal
#   failure  -- every record for the gate is terminal and none succeeded
#   absent   -- no record carries the gate's name on either surface
# On exit 0 one diagnostic line also goes to stderr naming what each surface said, so
# the caller can report WHICH shape carried the gate without re-reading the records.
# Exits 2, printing NOTHING to stdout, when the question cannot be answered: no gate
# name, a malformed record, or a state/conclusion outside GitHub's documented
# vocabulary; the stderr line then says why, not what the surfaces carried. The CALLER
# decides policy for 2. Both callers in this plugin treat it as they treat any word but
# "success": the gate is not green.
#
# The caller must not let a failed `gh api` or a missing record file reach this script:
# a document that never arrived is indistinguishable from one with no matching record,
# and the answer would be "absent" -- a fail-open. Both callers chain every step that
# produces the input with `&&` and redirect from the file rather than piping through
# `cat`, whose exit status a pipeline discards.
#
# --- The resolution rule, and why -----------------------------------------------------
#
# 1. success beats everything. A review posted against a SHA cannot be un-posted, so one
#    success on either surface is evidence the gate accepted THIS commit. The records
#    that can coexist with it are the known stale shapes: the superseded check-run that
#    fails before the review exists and never self-clears, and a non-required runner job
#    that stays red beside the status it posted until re-run. The issue's mixed case --
#    status success, stale check-run failure -- is this rule.
# 2. pending beats failure. A non-terminal record means the gate is still deciding;
#    the right call is to poll, not to declare red.
# 3. failure only when every record is terminal and none succeeded.
# 4. absent only when nothing carries the name. For a required gate that is itself a
#    red for the merge (a required check that never ran), a verdict pr-checks makes.
#
# Neither surface outranks the other. Ranking status above check-run was considered and
# rejected: the one conflict it would decide differently -- a status failure beside a
# check-run success on the same SHA -- has no observed instance, and a rule with no
# ordering has fewer ways to be wrong.
#
# Vocabulary, GitHub's own, matched verbatim:
#   status.state           success | pending | failure | error
#   check-run.status       queued | in_progress | completed | waiting | requested | pending
#   check-run.conclusion   (completed only) success | failure | neutral | cancelled |
#                          timed_out | action_required | stale | skipped | startup_failure
# neutral and skipped count as SUCCESS, because GitHub's own required-check evaluation
# counts both as passing, so this predicate and the merge box agree. The error direction
# that buys: a `skipped` caused by a failed `needs:` reads as success here. Stated, and
# covered by pr-checks step 2, which decodes a skip on the same PR; a review-gate job has
# no `needs:` in any workflow observed so far.
#
# Permitted toolset: POSIX sh + awk. No jq, no yq, no python -- this must run on any
# maintainer machine without an extra interpreter installed.
set -eu

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: <records> | review-gate-state.sh <gate-name>" >&2
  exit 2
fi
gate="$1"

# The gate name travels through ENVIRON, not `-v`: `-v` runs escape processing on its
# value, so `a\b` would arrive as something else and the value checked would not be the
# value given. ENVIRON is byte for byte.
# `exit` inside a rule still runs END in awk; END is where the verdict is printed, so the
# `bad` flag is checked there first and the two paths cannot both print.
RGS_GATE="$gate" awk -F '\t' '
  BEGIN { gate = ENVIRON["RGS_GATE"]; s = 0; p = 0; f = 0; st = ""; cr = ""; bad = "" }
  { sub(/\r$/, "") }
  /^$/ { next }
  $1 == "status" {
    if (NF != 3) { bad = "malformed status record: " $0; exit }
    if ($2 != gate) next
    st = st (st == "" ? "" : ",") $3
    if ($3 == "success") s++
    else if ($3 == "pending") p++
    else if ($3 == "failure" || $3 == "error") f++
    else { bad = "unknown status state: " $3; exit }
    next
  }
  $1 == "check-run" {
    if (NF != 4) { bad = "malformed check-run record: " $0; exit }
    if ($2 != gate) next
    if ($3 != "completed") {
      cr = cr (cr == "" ? "" : ",") $3
      if ($3 == "queued" || $3 == "in_progress" || $3 == "waiting" || $3 == "requested" || $3 == "pending") p++
      else { bad = "unknown check-run status: " $3; exit }
    } else {
      cr = cr (cr == "" ? "" : ",") ($4 == "" ? "(no conclusion)" : $4)
      if ($4 == "success" || $4 == "neutral" || $4 == "skipped") s++
      else if ($4 == "failure" || $4 == "cancelled" || $4 == "timed_out" || $4 == "action_required" || $4 == "stale" || $4 == "startup_failure") f++
      else { bad = "unknown check-run conclusion: " ($4 == "" ? "(empty)" : $4); exit }
    }
    next
  }
  { bad = "unknown record kind: " $1; exit }
  END {
    if (bad != "") { print "review-gate-state.sh: " bad " -- cannot answer" > "/dev/stderr"; exit 2 }
    printf "review-gate-state.sh: %s: status=[%s] check-run=[%s]\n", gate, st, cr > "/dev/stderr"
    if (s > 0) print "success"
    else if (p > 0) print "pending"
    else if (f > 0) print "failure"
    else print "absent"
  }
'
