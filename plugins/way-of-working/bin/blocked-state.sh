#!/bin/sh
# Read a PR's `mergeStateStatus: BLOCKED` correctly: is it GitHub re-evaluation lag, or
# the standing effect of an `update` rule that only a bypass actor can get past?
#
# Issue #224: /way-of-working:pr-checks read "BLOCKED with nothing red or pending" as
# GitHub re-evaluation lag and said to wait. Under a restrict-updates ruleset (an
# `update` rule whose only bypass actor is the repository admin role) every green PR
# reads BLOCKED to every viewer, the admin included -- measured on a scratch repo (this
# plugin's own sprint-orchestrator test, 2026-10-05) -- so on any repo carrying that rule
# the lag reading never
# clears and pr-checks could never again return a merge-ready verdict. Whether such a
# rule applies is a deterministic question with a correctness argument, so it is a
# tested script the skill invokes rather than a rule described in prose (WB-D10).
#
# Usage: blocked-state.sh <mergeStateStatus> <green>      (rule types on stdin; the
#        caller captures `gh`'s output first -- see the failed-gh warning below -- and
#        never pipes `gh` itself, whose exit status a pipe would hide)
#
#   <mergeStateStatus>  the PR's mergeStateStatus, as `gh pr view --json` prints it
#   <green>             1 only when the caller has established ALL of: every required
#                       check green (or legitimately skipped) with none pending, red or
#                       missing a run -- over the union of {ruleset.required_checks} and
#                       the contexts the branch's own required_status_checks rule names;
#                       a non-empty {ruleset.required_checks}; and a reviewDecision that
#                       is neither REVIEW_REQUIRED nor CHANGES_REQUESTED. Else 0. The
#                       caller computes it; this script cannot see any of it, so a wrong
#                       1 is a wrong verdict.
#
# stdin is the rule types that apply to the PR's own base branch (its baseRefName, not
# the configured {pr_base}), one per line, from:
#
#   gh api --paginate "repos/{repo}/rules/branches/<baseRefName>" --jq '.[].type'
#
# `gh` embeds jq, so neither the caller nor this script needs a separate jq. Only the
# exact line `update` counts; every other type is ignored. The caller must not let a
# failed `gh api` reach this script: a rule list that never arrived is indistinguishable
# from one with no `update` rule, and the answer would be `lag` -- a fail-open. It
# captures the call's output first (`T=$(gh api ...) &&`) or redirects it to a file, and
# only then feeds this script, never `gh api | blocked-state.sh`, whose exit status a pipe
# discards (the same principle review-gate-state.sh states for its own input).
#
# Prints exactly one word to stdout and exits 0:
#   not-blocked        -- the state is not BLOCKED; this script has nothing to say
#   admin-merge-ready  -- BLOCKED, `green` is 1, and an `update` rule applies: that rule
#                         alone keeps a green PR BLOCKED, and a bypass actor can get past
#                         it. This script does not read bypass actors, so whether the
#                         human holds the bypass is theirs to know. NOT "bypass the
#                         checks": where the checks sit in a ruleset the admin cannot
#                         bypass, --admin still enforces them (measured: --admin was
#                         refused on a red PR where the checks sat in such a ruleset) -- which
#                         is why `green` must be 1 first -- but whether the admin can
#                         bypass that ruleset is not visible from here
#   lag                -- BLOCKED, `green` is 1, and no `update` rule applies: nothing
#                         this script can see explains it, so usually GitHub is still
#                         re-evaluating -- but a rule nobody passes it (an unresolved
#                         conversation, a required deployment) holds a PR at BLOCKED the
#                         same way, so a `lag` that does not clear is not proof of lag
#   blocked            -- BLOCKED, and `green` is 0 (a check red, pending or missing, an
#                         empty check list, or a blocking review): what the caller found
#                         wrong, not the restriction, is what to report
# Exits 2, printing NOTHING to stdout, when the question cannot be answered: a wrong
# argument count, a state outside GitHub's documented vocabulary, a <green> that is not
# 0 or 1, or a stdin line that is not a bare rule-type token. The stderr line says why.
# The CALLER decides policy for 2; pr-checks treats it as no admin-merge verdict.
#
# What `admin-merge-ready` does not establish: an `update` rule applying says why the
# PR can read BLOCKED, not that it is the ONLY unmet rule. A rule nobody passed in (an
# unresolved conversation, a required deployment, code scanning, a merge queue, or a
# same-named check posted by a different app than the one the rule requires) would
# read the same, and the admin's bypass would skip it. The verdict is "required checks
# green and review not blocking", never "safe". `rules/branches/<branch>` is believed to
# list only active rulesets; whether an evaluate-mode `update` rule would also appear is
# unverified.
#
# Permitted toolset: POSIX sh and its standard utilities. No jq, no yq, no python.
LC_ALL=C; export LC_ALL        # the [a-z_] token class below must not depend on locale
set -u

if [ "$#" -ne 2 ]; then
  echo "blocked-state.sh: usage: blocked-state.sh <mergeStateStatus> <green>  (rule types on stdin; see its header)" >&2
  exit 2
fi
state="$1"; green="$2"

case "$state" in
  BEHIND | BLOCKED | CLEAN | DIRTY | DRAFT | HAS_HOOKS | UNKNOWN | UNSTABLE) ;;
  *) echo "blocked-state.sh: unrecognised mergeStateStatus: $state" >&2; exit 2 ;;
esac
case "$green" in
  0 | 1) ;;
  *) echo "blocked-state.sh: <green> must be 0 or 1, got: $green" >&2; exit 2 ;;
esac

has_update=0
# `|| [ -n "$rule" ]` keeps a final line that lacks a trailing newline.
while IFS= read -r rule || [ -n "$rule" ]; do
  rule="${rule%$(printf '\r')}"      # a Windows gh may end lines in CR
  case "$rule" in
    '' | *[!a-z_]*) echo "blocked-state.sh: stdin line is not a rule-type token: $rule" >&2; exit 2 ;;
  esac
  [ "$rule" = update ] && has_update=1
done

if [ "$state" != BLOCKED ]; then
  echo not-blocked
elif [ "$green" != 1 ]; then
  echo blocked
elif [ "$has_update" = 1 ]; then
  echo admin-merge-ready
else
  echo lag
fi
exit 0
