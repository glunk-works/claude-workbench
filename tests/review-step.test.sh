#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/review-step.sh (WB-D22, `#230`).
#
# Two predicates, both pure, so every verdict is a fixture:
#
#   derive -- which open PR, if any, is "the review step" for the anchored task. The four
#     cases the issue names are here by name: a match; a disagreement (a PR that does not
#     qualify, and a state.json that names another PR, in the decide block); no state.json
#     (decide: `show ... no-state`); and an App-authored PR, which never matches because its
#     author is not the running login (plan v9 § 8.13c, option A).
#   decide -- whether the derived step may auto-start, or must be shown and waited on.
#
# The bug classes this guards:
#   - a lookalike mention naming the task (`foo#230`, `#2301`, `a/b#230`, a URL ending
#     `/repo#230`) deriving a PR that is not the task's;
#   - @tsv's `\n` escape reading as the word character `n`, so a body line that begins `#230`
#     is missed -- and its mirror, an escaped backslash followed by `n` being decoded as a
#     newline and manufacturing a mention;
#   - the author check passing for a bot, a fork, a closed PR, or another login;
#   - auto-start firing on one source alone: no state.json, a different review_pr, a moved
#     head, a next_action that does not begin `review PR #M — task #N — `, a dirty tree or a
#     checkout off the pin, an assigned_model that is not the architect, a same-conversation
#     switch.
#
# Records are built with printf '%s' and a literal backslash held in a variable, not with
# `\\` inside a format string, which this repo's shells and the tool layer around them
# disagree about (the "heredocs eat backslashes" lesson).
#
# Mutations to run by hand when this suite changes (each restored before the next): drop the
# `before != "/"` test (the URL fixture goes red); drop the digit test (`#2301` goes red);
# decode `\\` as itself (the escaped-backslash fixture goes red); drop the isCrossRepository
# test; compare the author case-sensitively; skip the head-moved check; skip the checkout
# check; compare the model to the running model's name instead of architect. Checked by
# doing it, not by reading.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/review-step.sh"

fail=0
BS='\'
TAB="$(printf '\t')"

O1=1111111111111111111111111111111111111111
O2=2222222222222222222222222222222222222222
O3=3333333333333333333333333333333333333333
REPO=glunk-works/claude-workbench
ME=Seuss27

# rec <number> <state> <isCrossRepository> <author> <oid> <title> <body>
rec() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; }

# assert_derive <desc> <expected-stdout> <expected-exit> <login> <repo> <backlog> <N> <records>
assert_derive() {
  desc="$1"; want_out="$2"; want_st="$3"; login="$4"; repo="$5"; brepo="$6"; n="$7"; records="$8"
  st=0
  out="$(printf '%s' "$records" | sh "$script" derive "$login" "$repo" "$brepo" "$n" "${LIMIT:-200}" 2>/dev/null)" || st=$?
  if [ "$out" = "$want_out" ] && [ "$st" = "$want_st" ]; then
    echo "ok - derive: $desc"
  else
    echo "FAIL - derive: $desc: expected [$want_out]/exit $want_st, got [$out]/exit $st" >&2
    fail=1
  fi
}

D() { assert_derive "$@"; }

# --- the match ------------------------------------------------------------------------

D "body names the task: one" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 'feat: a thing' 'Closes #230')
"
D "title names the task" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 'feat(x): a thing (#230)' 'no mention')
"
D "owner/repo#N names the task when the backlog is this repo" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "Part of $REPO#230.")
"
D "an explicit backlog equal to repo behaves as null" "one 12 $O1" 0 "$ME" "$REPO" "$REPO" 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'Closes #230')
"
D "the login match is case-insensitive" "one 12 $O1" 0 seuss27 "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'Closes #230')
"
D "a body line that BEGINS with the mention (escaped newline before it)" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "intro${BS}n#230 first")
"
D "a tab and a carriage return decode to separators too" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "a${BS}t#230${BS}rb")
"
D "the mention at the very start of the body" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 '' '#230 is the task')
"
D "CRLF line ends and blank lines are tolerated" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "
$(rec 12 OPEN false "$ME" $O1 't' 'Closes #230')
"
D "a later occurrence still counts after an earlier lookalike" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'was foo#230, really #230')
"

# --- lookalikes and non-matches ---------------------------------------------------------

D "no PR at all" none 0 "$ME" "$REPO" - 230 ""
D "a PR that does not mention the task" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'Closes #229')
"
D "foo#230 is a word character before the hash" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'see foo#230')
"
D "#2301 is another issue (followed by a digit)" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'Closes #2301')
"
D "another repo's issue: a/b#230" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'see other-org/other-repo#230')
"
D "a URL ending in this repo's name is preceded by a slash" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "see https://github.com/$REPO#230")
"
D "the slash before a bare hash" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'see x/#230')
"
D "an underscore before the hash is a word character" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'see _#230')
"
D "an escaped backslash then n is NOT a newline" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "a${BS}${BS}n#230")
"

# --- the author, the repository, the state ---------------------------------------------

D "a fork PR never matches (isCrossRepository)" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN true "$ME" $O1 't' 'Closes #230')
"
D "another login never matches" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false someone-else $O1 't' 'Closes #230')
"
D "an App-pushed PR never matches: app/ login" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false app/loop-driver $O1 't' 'Closes #230')
"
D "an App-pushed PR never matches: [bot] login" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false 'loop-driver[bot]' $O1 't' 'Closes #230')
"
D "a closed PR never matches" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 CLOSED false "$ME" $O1 't' 'Closes #230')
"
D "a merged PR never matches" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 MERGED false "$ME" $O1 't' 'Closes #230')
"
D "an App PR beside the maintainer's: only the maintainer's derives" "one 14 $O2" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false app/loop-driver $O1 't' 'Closes #230')
$(rec 14 OPEN false "$ME" $O2 't' 'Closes #230')
"

# --- several ---------------------------------------------------------------------------

D "two qualify: all are named, ascending" "many 9 12" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'Closes #230')
$(rec 9 OPEN false "$ME" $O2 't' 'part of #230')
"
D "three qualify: sorted numerically, not as text" "many 9 12 100" 0 "$ME" "$REPO" - 230 \
  "$(rec 100 OPEN false "$ME" $O3 't' '#230')
$(rec 12 OPEN false "$ME" $O1 't' '#230')
$(rec 9 OPEN false "$ME" $O2 't' '#230')
"

# --- a backlog in another repo ---------------------------------------------------------

D "other backlog: the bare #N names THIS repo's issue, not the task" none 0 "$ME" "$REPO" 603-identity/hub 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'Closes #230')
"
D "other backlog: its owner/repo#N form names the task" "one 12 $O1" 0 "$ME" "$REPO" 603-identity/hub 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'Closes 603-identity/hub#230')
"
D "other backlog: this repo's own owner/repo#N does not" none 0 "$ME" "$REPO" 603-identity/hub 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "Closes $REPO#230")
"

# --- inputs it must refuse (exit 2, nothing on stdout) ---------------------------------

D "a record with the wrong field count" "" 2 "$ME" "$REPO" - 230 "12${TAB}OPEN${TAB}false
"
D "a head that is not 40 hex" "" 2 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" abc123 't' '#230')
"
D "an uppercase head oid" "" 2 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" 1111111111111111111111111111111111111AAA 't' '#230')
"
D "a PR number that is not a number" "" 2 "$ME" "$REPO" - 230 \
  "$(rec twelve OPEN false "$ME" $O1 't' '#230')
"
D "a PR number of zero" "" 2 "$ME" "$REPO" - 230 \
  "$(rec 0 OPEN false "$ME" $O1 't' '#230')
"
D "a state outside the vocabulary" "" 2 "$ME" "$REPO" - 230 \
  "$(rec 12 DRAFT false "$ME" $O1 't' '#230')
"
D "an isCrossRepository outside the vocabulary" "" 2 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN maybe "$ME" $O1 't' '#230')
"
D "one bad record poisons the answer even beside a good one" "" 2 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' '#230')
$(rec 13 OPEN false "$ME" nothex 't' '#230')
"
D "an empty login" "" 2 "" "$REPO" - 230 ""
D "a malformed repo" "" 2 "$ME" "no-slash" - 230 ""
D "a malformed backlog repo" "" 2 "$ME" "$REPO" "a/b/c" 230 ""
D "a task issue that is not a number" "" 2 "$ME" "$REPO" - "23x" 230 ""
D "a task issue of zero" "" 2 "$ME" "$REPO" - 0 ""

# --- another repo whose owner or name merely ENDS in this one's ----------------------------

D "an owner with a hyphen prefix is another repo" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "see evil-$REPO#230")
"
D "an owner with a dot prefix is another repo" none 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "see evil.$REPO#230")
"
D "other backlog: a hyphen-prefixed lookalike owner does not name it" none 0 "$ME" "$REPO" 603-identity/hub 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' 'see x-603-identity/hub#230')
"
D "a legitimate owner/repo#N after a space and punctuation still matches" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' "(see $REPO#230), thanks")
"

# --- the --limit: a list that may be truncated is not an answer -----------------------------

LIMIT=2; D "records equal to the limit may be truncated: refuse" "" 2 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' '#230')
$(rec 13 OPEN false "$ME" $O2 't' 'x')
"
LIMIT=3; D "records below the limit are an answer" "one 12 $O1" 0 "$ME" "$REPO" - 230 \
  "$(rec 12 OPEN false "$ME" $O1 't' '#230')
$(rec 13 OPEN false "$ME" $O2 't' 'x')
"
LIMIT=abc; D "a limit that is not a number" "" 2 "$ME" "$REPO" - 230 ""
LIMIT=0; D "a limit of zero" "" 2 "$ME" "$REPO" - 230 ""
LIMIT=200

# bad arity
st=0; out="$(printf '' | sh "$script" derive "$ME" "$REPO" - 2>/dev/null)" || st=$?
if [ "$out" = "" ] && [ "$st" = 2 ]; then echo "ok - derive: wrong argument count"; else
  echo "FAIL - derive: wrong argument count: [$out]/exit $st" >&2; fail=1; fi

# --- decide ---------------------------------------------------------------------------

# The baseline repeats keys when a fixture overrides one, and the script rejects a
# repeated key (a silent last-writer-wins would hide a caller mistake) -- so
# build the argument vector properly instead: baseline minus the overridden keys, plus them.
assert_decide() {
  desc="$1"; want_out="$2"; want_st="$3"; shift 3
  base_derived="derived=one 12 $O1"; base_gate=gate=set; base_gs=gate_state=absent
  base_state=state=present; base_srn=sr_number=12; base_srh="sr_head=$O1"
  base_na="next_action=review PR #12 — task #230 — run the architect review on it"
  base_ti=task_issue=230; base_br=backlog_repo=-; base_repo="repo=$REPO"; base_head="head=$O1"
  base_tree=tree=clean; base_model=model=opus; base_arch=architect=opus; base_fresh=fresh=yes
  for kv in "$@"; do
    case "$kv" in
      derived=*) base_derived="$kv" ;; gate=*) base_gate="$kv" ;; gate_state=*) base_gs="$kv" ;;
      state=*) base_state="$kv" ;; sr_number=*) base_srn="$kv" ;; sr_head=*) base_srh="$kv" ;;
      next_action=*) base_na="$kv" ;; task_issue=*) base_ti="$kv" ;; backlog_repo=*) base_br="$kv" ;;
      repo=*) base_repo="$kv" ;; head=*) base_head="$kv" ;; tree=*) base_tree="$kv" ;;
      model=*) base_model="$kv" ;; architect=*) base_arch="$kv" ;; fresh=*) base_fresh="$kv" ;;
    esac
  done
  st=0
  out="$(sh "$script" decide "$base_derived" "$base_gate" "$base_gs" "$base_state" "$base_srn" \
    "$base_srh" "$base_na" "$base_ti" "$base_br" "$base_repo" "$base_head" "$base_tree" \
    "$base_model" "$base_arch" "$base_fresh" 2>/dev/null)" || st=$?
  if [ "$out" = "$want_out" ] && [ "$st" = "$want_st" ]; then
    echo "ok - decide: $desc"
  else
    echo "FAIL - decide: $desc: expected [$want_out]/exit $want_st, got [$out]/exit $st" >&2
    fail=1
  fi
}

A() { assert_decide "$@"; }

A "every source agrees: auto-start, built from the derived number and head" "auto 12 $O1" 0

# no state.json: the fresh-machine case
A "no state.json: show the step, wait" "show 12 no-state" 0 \
  state=absent sr_number=- sr_head=- 'next_action=-'

# disagreement
A "state.json names a different PR" "show 12 review-pr,token" 0 \
  sr_number=13 'next_action=review PR #13 — task #230 — x'
A "state.json names no PR (an older cursor)" "show 12 review-pr,token" 0 \
  sr_number=null sr_head=null 'next_action=task #230 — build it'
A "review_pr is the PR but the head moved since the pin" "show 12 head-moved,checkout" 0 \
  "derived=one 12 $O2"
A "the pin matches the derived head but this checkout is behind it" "show 12 checkout" 0 \
  "head=$O3"
A "a dirty tree is not the checkout the handoff left" "show 12 checkout" 0 tree=dirty

# the token
A "next_action is the old task-first form" "show 12 token" 0 'next_action=task #230 — build the thing'
A "next_action names a different PR number" "show 12 token" 0 'next_action=review PR #13 — task #230 — x'
A "next_action names a different task" "show 12 token" 0 'next_action=review PR #12 — task #231 — x'
A "next_action does not START with the token" "show 12 token" 0 \
  'next_action=Please review PR #12 — task #230 — x'
A "next_action is the bare token with nothing after it" "show 12 token" 0 'next_action=review PR #12'
A "next_action is a merge-form token while a gate is set" "show 12 token" 0 \
  'next_action=merge PR #12 — task #230 — x'
A "PR #12 must not be read as a prefix of PR #123" "show 12 token" 0 \
  'next_action=review PR #123 — task #230 — x'
A "task #230 must not be read as a prefix of task #2301" "show 12 token" 0 \
  'next_action=review PR #12 — task #2301 — x'
A "task_issue from the anchor disagrees with the token" "show 12 token" 0 task_issue=231

A "another backlog repo: the repo-prefixed task token is the form" "auto 12 $O1" 0 \
  backlog_repo=603-identity/hub 'next_action=review PR #12 — task 603-identity/hub#230 — x'
A "another backlog repo: the bare task token is refused" "show 12 token" 0 \
  backlog_repo=603-identity/hub
A "backlog equal to repo uses the bare token" "auto 12 $O1" 0 "backlog_repo=$REPO"

# the model and the fresh session
A "assigned_model is not the architect" "show 12 model" 0 model=sonnet
A "a same-conversation switch is not a fresh session" "show 12 not-fresh" 0 fresh=no
A "every failure is named, in a fixed order" "show 12 review-pr,token,checkout,model,not-fresh" 0 \
  sr_number=13 'next_action=x' tree=dirty model=sonnet fresh=no

# reports: nothing to start (a green gate is head-moved, not reviewed, when the pin names another head)
A "gate set and already success on the head: a report, never offered again" "reviewed 12" 0 \
  gate_state=success
A "success is a report even with no state.json" "reviewed 12" 0 \
  gate_state=success state=absent sr_number=- sr_head=- 'next_action=-'
A "success on a head the pin does not name is head-moved, never reviewed" "show 12 head-moved" 0 \
  gate_state=success "derived=one 12 $O2"
A "success on the pinned head is reviewed" "reviewed 12" 0 gate_state=success
A "gate null: a merge report, nothing to auto-start" "merge 12" 0 gate=null gate_state=-
A "gate null with state.json disagreeing is still the same report" "merge 12" 0 \
  gate=null gate_state=- sr_number=99 'next_action=whatever'
A "gate unreadable: derive nothing" unreadable 0 gate=unreadable gate_state=-
A "pending and failure gate states are still a review to run" "auto 12 $O1" 0 gate_state=pending
A "failure gate state is still a review to run" "auto 12 $O1" 0 gate_state=failure

# derived verdicts that never reach the checks
A "nothing derived" none 0 derived=none
A "nothing derived with no gate state read" none 0 derived=none gate_state=-
A "nothing derived, even with a perfect-looking state.json" none 0 derived=none
A "several qualify: show all, wait" "many 9 12" 0 'derived=many 9 12'
A "several qualify with no gate state read" "many 9 12" 0 "derived=many 9 12" gate_state=-

# next_action is data, never interpreted
A "a next_action carrying shell syntax is only compared" "show 12 token" 0 \
  'next_action=review PR #12 — $(false) task #230 — x'
A "a next_action with an equals sign survives the key=value split" "auto 12 $O1" 0 \
  'next_action=review PR #12 — task #230 — set a=b and c=d'

# refusals
A "an unknown derived kind" "" 2 'derived=some 12'
A "derived one with a malformed oid" "" 2 'derived=one 12 abc'
A "derived one with a non-numeric PR" "" 2 "derived=one x $O1"
A "derived many with one number" "" 2 'derived=many 9'
A "derived none with trailing words" "" 2 'derived=none 1'
A "gate outside the vocabulary" "" 2 gate=maybe
A "gate set with no gate_state" "" 2 gate_state=-
A "gate_state outside the vocabulary" "" 2 gate_state=green
A "state outside the vocabulary" "" 2 state=maybe
A "tree outside the vocabulary" "" 2 tree=untracked
A "fresh outside the vocabulary" "" 2 fresh=maybe
A "head that is not an oid" "" 2 head=abc
A "task_issue that is not a number" "" 2 task_issue=abc
A "an empty value" "" 2 model=

# missing / unknown / not key=value, straight against the script
st=0; out="$(sh "$script" decide "derived=none" 2>/dev/null)" || st=$?
if [ "$out" = "" ] && [ "$st" = 2 ]; then echo "ok - decide: a missing key refuses"; else
  echo "FAIL - decide: a missing key refuses: [$out]/exit $st" >&2; fail=1; fi
st=0; out="$(sh "$script" decide "derived=none" "derived=none" 2>/dev/null)" || st=$?
if [ "$out" = "" ] && [ "$st" = 2 ]; then echo "ok - decide: a repeated key refuses"; else
  echo "FAIL - decide: a repeated key refuses: [$out]/exit $st" >&2; fail=1; fi
st=0; out="$(sh "$script" decide "bogus=1" 2>/dev/null)" || st=$?
if [ "$out" = "" ] && [ "$st" = 2 ]; then echo "ok - decide: an unknown key refuses"; else
  echo "FAIL - decide: an unknown key refuses: [$out]/exit $st" >&2; fail=1; fi
st=0; out="$(sh "$script" decide "derived" 2>/dev/null)" || st=$?
if [ "$out" = "" ] && [ "$st" = 2 ]; then echo "ok - decide: a bare word refuses"; else
  echo "FAIL - decide: a bare word refuses: [$out]/exit $st" >&2; fail=1; fi
st=0; out="$(sh "$script" bogus 2>/dev/null)" || st=$?
if [ "$out" = "" ] && [ "$st" = 2 ]; then echo "ok - an unknown mode refuses"; else
  echo "FAIL - an unknown mode refuses: [$out]/exit $st" >&2; fail=1; fi

# --- the two halves end to end: App-authored PR -> derive none -> decide none ----------

d="$(printf '%s\n' "$(rec 12 OPEN false app/loop-driver $O1 't' 'Closes #230')" \
  | sh "$script" derive "$ME" "$REPO" - 230 200)"
a="$(sh "$script" decide "derived=$d" gate=set gate_state=absent state=present sr_number=12 \
  "sr_head=$O1" "next_action=review PR #12 — task #230 — x" task_issue=230 backlog_repo=- \
  "repo=$REPO" "head=$O1" tree=clean model=opus architect=opus fresh=yes)"
if [ "$a" = none ]; then echo "ok - end to end: an App-authored PR derives nothing and auto-starts nothing"; else
  echo "FAIL - end to end: App-authored PR: got [$a]" >&2; fail=1; fi

d="$(printf '%s\n' "$(rec 12 OPEN false "$ME" $O1 't' 'Closes #230')" \
  | sh "$script" derive "$ME" "$REPO" - 230 200)"
a="$(sh "$script" decide "derived=$d" gate=set gate_state=absent state=present sr_number=12 \
  "sr_head=$O1" "next_action=review PR #12 — task #230 — x" task_issue=230 backlog_repo=- \
  "repo=$REPO" "head=$O1" tree=clean model=opus architect=opus fresh=yes)"
if [ "$a" = "auto 12 $O1" ]; then echo "ok - end to end: a maintainer PR derives and auto-starts"; else
  echo "FAIL - end to end: maintainer PR: got [$a]" >&2; fail=1; fi

exit "$fail"
