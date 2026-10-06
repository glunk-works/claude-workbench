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
# Usage: blocked-state.sh <mergeStateStatus> <green>      (rule lines on stdin; the
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
# stdin is the rules that apply to the PR's own base branch (its baseRefName, not the
# configured {pr_base}), one per line: the rule type, then for the two types whose
# parameters decide the answer, those parameters as `key=value` words. Issue #248: type
# names alone dropped every parameter, so a `pull_request` rule demanding approvals or
# thread resolution read the same as one demanding nothing.
#
#   gh api --paginate "repos/{repo}/rules/branches/<baseRefName>" --jq '.[] | .type +
#     (if .type=="pull_request" then " approvals=\(.parameters.required_approving_review_count // 0)
#        threads=\(.parameters.required_review_thread_resolution // false)
#        codeowner=\(.parameters.require_code_owner_review // false)
#        reviewers=\([.parameters.required_reviewers[]?] | length)"
#      elif .type=="required_status_checks"
#        then " app_pinned=\([.parameters.required_status_checks[]? | select(.integration_id != null)] | length)"
#      else "" end)'
#
# (one line per rule; the line breaks above are for reading: the pr-checks skill carries
# the exact, single-line form, and a break inside the output is a stdin line this script
# rejects.) A key may appear once, and only on the type that owns it. `gh`
# embeds jq, so neither the caller nor this script needs a separate jq. The exact type
# `update` is what makes `admin-merge-ready`. A rule this script cannot evaluate is
# never read as absent -- see "cannot evaluate" below. The caller must not let a
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
#   lag                -- BLOCKED, `green` is 1, no `update` rule applies, and every rule
#                         that does apply is one this script can evaluate and finds
#                         satisfied: usually GitHub is still re-evaluating. A rule type
#                         outside the list below (e.g. `workflows`) is ignored, so a
#                         `lag` that does not clear is still not proof of lag
#   blocked            -- BLOCKED, and `green` is 0 (a check red, pending or missing, an
#                         empty check list, or a blocking review): what the caller found
#                         wrong, not the restriction, is what to report
# Exits 2, printing NOTHING to stdout, when the question cannot be answered: a wrong
# argument count, a state outside GitHub's documented vocabulary, a <green> that is not
# 0 or 1, a stdin line that is not a rule-type token optionally followed by key=value
# words, or -- the case #248 adds -- the state is BLOCKED, `green` is 1, and a rule this
# script cannot evaluate applies. The stderr line says why and NAMES those rules, which
# the pr-checks skill puts in the verdict text (it captures stderr). The CALLER decides
# policy for 2; pr-checks treats it as no admin-merge verdict.
#
# Cannot evaluate (BLOCKED + green only; a not-BLOCKED state or a red check says nothing
# about these, so `not-blocked` and `blocked` are unchanged):
#   required_deployments, code_scanning, required_signatures, merge_queue
#                         -- no state of the PR visible here says whether they are met
#   pull_request          -- approvals>0, reviewers>0, threads=true, or codeowner=true. An
#                         unmet approval count also makes reviewDecision REVIEW_REQUIRED, which
#                         the caller folds into <green> (so that case is usually `blocked`
#                         first); it is refused here regardless rather than trusting that fold
#                         -- reviewDecision cannot see an unresolved conversation, and may not
#                         see required-reviewer teams. A `pull_request` line missing any of the
#                         four words means the caller dropped the parameters
#   required_status_checks -- app_pinned>0: a context's check must come from a named app
#                         (`integration_id`), and the rollup the caller reads by name
#                         cannot say which app posted it; a line without `app_pinned=`
#                         means the caller dropped the parameters
# Bypass actors are deliberately not read: `current_user_can_bypass` is `never` to a
# non-admin viewer, so for the viewers who most need the answer it cannot be reached
# from here; the pr-checks skill's block (c) names the identity and its value instead.
#
# What `admin-merge-ready` does not establish: an `update` rule applying says why the
# PR can read BLOCKED, not that it is the ONLY unmet rule. A rule type outside the lists
# above (`workflows`, `commit_message_pattern`, ...) is ignored, not evaluated, and would
# read the same, and the admin's bypass would skip it. The verdict is "required checks
# green, review not blocking, and no rule this script cannot evaluate", never "safe".
# `rules/branches/<branch>` is believed to list only active rulesets; whether an
# evaluate-mode `update` rule would also appear is unverified.
#
# Permitted toolset: POSIX sh and its standard utilities. No jq, no yq, no python.
LC_ALL=C; export LC_ALL        # the [a-z_] token class below must not depend on locale
set -u

if [ "$#" -ne 2 ]; then
  echo "blocked-state.sh: usage: blocked-state.sh <mergeStateStatus> <green>  (rule lines on stdin; see its header)" >&2
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
unseen=
# note <what>: record a rule this script cannot evaluate, once per distinct reason.
note() {
  case ", $unseen, " in *", $1, "*) ;; *) unseen="${unseen:+$unseen, }$1" ;; esac
}
set -f                                # the words below are validated, but never glob them
# `|| [ -n "$line" ]` keeps a final line that lacks a trailing newline.
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$(printf '\r')}"      # a Windows gh may end lines in CR
  case "$line" in
    '' | *[!a-z_=A-Z0-9\ ]* | ' '* | *' ' | *'  '*)
      echo "blocked-state.sh: stdin line is not a rule type plus key=value words: $line" >&2; exit 2 ;;
  esac
  rule="${line%% *}"; rest=
  case "$line" in *' '*) rest="${line#* }" ;; esac
  case "$rule" in
    '' | *[!a-z_]*) echo "blocked-state.sh: stdin line does not start with a rule-type token: $line" >&2; exit 2 ;;
  esac
  approvals= threads= codeowner= reviewers= pinned=
  for w in $rest; do
    # key=value, each key at most once and only on the type that owns it
    k="${w%%=*}"
    case "$rule:$k" in
      pull_request:approvals | pull_request:threads | pull_request:codeowner | pull_request:reviewers | required_status_checks:app_pinned) ;;
      *) echo "blocked-state.sh: a $rule line does not take the word: $w" >&2; exit 2 ;;
    esac
    case "$w" in
      approvals=[0-9]*) [ -z "$approvals" ] && approvals="${w#*=}" || approvals=dup ;;
      reviewers=[0-9]*) [ -z "$reviewers" ] && reviewers="${w#*=}" || reviewers=dup ;;
      app_pinned=[0-9]*) [ -z "$pinned" ] && pinned="${w#*=}" || pinned=dup ;;
      threads=true | threads=false) [ -z "$threads" ] && threads="${w#*=}" || threads=dup ;;
      codeowner=true | codeowner=false) [ -z "$codeowner" ] && codeowner="${w#*=}" || codeowner=dup ;;
      *) echo "blocked-state.sh: unrecognised word on a $rule line: $w" >&2; exit 2 ;;
    esac
  done
  case "$approvals$reviewers$pinned$threads$codeowner" in *dup*)
    echo "blocked-state.sh: a key is repeated on one line: $line" >&2; exit 2 ;;
  esac
  case "$approvals$reviewers$pinned" in *[!0-9]*)
    echo "blocked-state.sh: a count word is not a number: $line" >&2; exit 2 ;;
  esac
  # Counts are judged by pattern, never by `[ -gt ]`: an overlong count makes `[` error out,
  # which would skip the `note` below and read a non-zero requirement as zero.
  case "$rule" in
    update) has_update=1 ;;
    required_deployments | code_scanning | required_signatures | merge_queue) note "$rule" ;;
    pull_request)
      if [ -z "$approvals" ] || [ -z "$reviewers" ] || [ -z "$threads" ] || [ -z "$codeowner" ]; then
        note "pull_request (parameters not supplied)"
      else
        case "$approvals" in *[1-9]*) note "pull_request requires $approvals approving review(s)" ;; esac
        case "$reviewers" in *[1-9]*) note "pull_request names required reviewers" ;; esac
        [ "$threads" = true ] && note "pull_request requires review-thread resolution"
        [ "$codeowner" = true ] && note "pull_request requires code-owner review"
      fi ;;
    required_status_checks)
      if [ -z "$pinned" ]; then
        note "required_status_checks (parameters not supplied)"
      else
        case "$pinned" in *[1-9]*) note "required_status_checks pins a check to an app (integration_id)" ;; esac
      fi ;;
  esac
done

if [ "$state" != BLOCKED ]; then
  echo not-blocked
elif [ "$green" != 1 ]; then
  echo blocked
elif [ -n "$unseen" ]; then
  echo "blocked-state.sh: cannot judge a green BLOCKED PR past rules it cannot evaluate: $unseen" >&2
  exit 2
elif [ "$has_update" = 1 ]; then
  echo admin-merge-ready
else
  echo lag
fi
exit 0
