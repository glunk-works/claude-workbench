#!/usr/bin/env bash
# The regression gate: the invariants that have already been got wrong, in prose.
#
# This repo's skills describe MECHANICAL procedures in English, and English has no
# compiler. Every check below exists because the described procedure shipped wrong at
# least once -- twice, in the first case -- and nothing in `lint` or `coupling` could
# have caught it. A grep cannot prove a procedure is right; it can stop a specific
# known-wrong form from coming back, which is exactly what happened here.
#
# Adding a check: it must correspond to a defect that actually shipped. Speculative
# invariants belong in the skill's own prose, not in a gate.
set -euo pipefail

fail=0
SKILLS=(plugins/*/skills/*/SKILL.md)
AGENTS=(plugins/*/agents/*.md)
BIN_SCRIPTS=(plugins/*/bin/*.sh)
HOOK_SCRIPTS=(plugins/*/hooks/*.sh)
REFERENCE_DOCS=(plugins/*/reference/*.md)

report() {
  echo "INVARIANT FAIL: $1" >&2
  shift
  printf '%s\n' "$@" >&2
  fail=1
}

# --- 1. Cursor freshness is compared by CONTENT, never by commit range -------------
#
# `git diff A..HEAD` and `git rev-list --count A..HEAD` are commit RANGES, and a range
# only means what you want when A is an ancestor of HEAD. Under squash-merge -- this
# project's default -- the recorded `last_commit` frequently never becomes an ancestor
# of the base branch at all, so a range-based check fails closed forever. Shipped wrong
# in v0.3.0 (SHA equality) and again in v0.4.0 (the range form); see WB-D7.
#
# The classifier itself now lives in plugins/*/bin/cursor-drift.sh (issue #21) rather
# than in skill prose, so this scans that script too -- it is where the bug would
# actually regress. tests/cursor-drift.test.sh is the authoritative behavioral guard
# (a fixture, not a regex, catches a wrong answer the regex's shape doesn't cover);
# this stays as a cheap, independent static check on top of it.
#
# Comments are stripped first ON PURPOSE: cursor-drift.sh's own comment carries
# `# TWO arguments -- never <last_commit>..HEAD`, which is the warning against this
# exact mistake and must not trip the gate that enforces it. Same reasoning as the
# coupling check's note about check names in illustrative output.
# Per file, not over a concatenated stream, so a hit names the file it is in.
range_hits=""
for f in "${SKILLS[@]}" "${AGENTS[@]}" "${BIN_SCRIPTS[@]}"; do
  h=$(sed 's/#.*//' "$f" | grep -nE 'git (diff|rev-list).*last_commit[^ ]*\.\.' || true)
  [ -n "$h" ] && range_hits+="  $f:$h"$'\n'
done
if [ -n "$range_hits" ]; then
  report "cursor freshness compared by commit range, not content" \
    "$range_hits" \
    "Use a TWO-ARGUMENT diff -- 'git diff --name-only <last_commit> HEAD' -- which" \
    "compares trees and survives squash-merge. See docs/decisions.md WB-D7."
fi

# --- 2. `gh auth status` is never parsed ------------------------------------------
#
# It reports token SCOPE, and scope is not reach: an account with no membership in the
# owning org can advertise a broader scope list than the one that actually works, so it
# prints green while reach is zero. The question a skill actually wants is answered by
# `gh api repos/OWNER/REPO --jq .permissions`. Mentioning the command in prose (to warn
# against it) is fine; piping or capturing its output is the defect. See issue #13.
auth_hits=$(grep -nE 'gh auth status[^`]*(\||\$\()' "${SKILLS[@]}" "${AGENTS[@]}" || true)
if [ -n "$auth_hits" ]; then
  report "'gh auth status' output is being parsed" \
    "$auth_hits" \
    "Scope is not reach. Ask the repo what the token can do:" \
    "  gh api repos/{repo} --jq .permissions"
fi

# --- 3. The reach check precedes the ruleset call in /resume ----------------------
#
# An identity that cannot see a ruleset gets 404, NOT 403 -- so the ruleset preflight
# reads "that ruleset does not exist", which is indistinguishable from the security
# finding it exists to raise and points the wrong way. The reach call is only useful
# BEFORE the call whose answer it qualifies. Ordering, not presence, is the invariant.
RESUME=$(printf '%s\n' "${SKILLS[@]}" | grep '/resume/SKILL.md$' || true)
if [ -n "$RESUME" ]; then
  # `|| true` is load-bearing: under `set -o pipefail` a grep that legitimately finds
  # nothing kills the script, and `set -e` makes that a SILENT exit -- a gate that dies
  # quietly reports the same "nothing to see" as a gate that passed. Caught by running
  # the deliberate regression below rather than by reading the code.
  reach=$(grep -n 'gh api repos/{repo} --jq .permissions' "$RESUME" | head -1 | cut -d: -f1 || true)
  ruleset=$(grep -n 'gh api repos/{repo}/rules/branches' "$RESUME" | head -1 | cut -d: -f1 || true)
  if [ -z "$reach" ]; then
    report "/resume has no repo-reach preflight" \
      "  expected: gh api repos/{repo} --jq .permissions" \
      "Without it, a 404 from the ruleset call cannot be told from 'wrong identity'."
  elif [ -n "$ruleset" ] && [ "$reach" -gt "$ruleset" ]; then
    report "/resume checks the ruleset before establishing reach" \
      "  reach check at line $reach, ruleset call at line $ruleset" \
      "The reach call must come FIRST -- it is what makes the ruleset result mean anything."
  fi
fi

# --- 4. /handoff guards WHOSE sprint it is before it determines the new cursor -----
#
# Handoff regenerates .ai/state.json and .ai/next-steps.md WHOLESALE (its *Write
# `.ai/state.json`* and *Regenerate `.ai/next-steps.md`* steps), so
# a handoff for work on some other sprint overwrites the cursor's sprint's in-flight
# state, with nothing left to restore it from. Shipped wrong: the guard-less prose ran in
# a consuming repo, whose cursor-sync PR would have done exactly that over a `blocked`
# sprint and was closed instead -- the evidence WB-D12 records, and the reason
# /way-of-working:park-sprint exists. The fix is a guard that names that way out BEFORE
# the step that decides the new cursor. As with check 3, ordering is the invariant, not
# presence: a guard after the rewrite guards nothing. Issue #89.
#
# The guard is matched by its own bullet, not by any mention of park-sprint: a mention in
# the frontmatter description would pin the first hit above the fold forever, and the
# guard could then be deleted without tripping the gate. Rewording the bullet means
# updating this pattern deliberately -- say so in the commit.
#
# `rewrite` is anchored to the numbered HEADING itself (a list item whose bold text is
# exactly "Determine the new cursor"), not a bare substring search: since issue #61's
# name-based step references (check 6, below), the step's own name is legitimately cited
# in prose earlier in the file too (the sprint-guard paragraph above it does exactly
# that), and a bare substring search would grab the first such mention instead of the
# heading -- reporting "determines before guarding" for a file where the guard is
# correctly first. The number itself is not pinned -- `[0-9]+` matches whatever position
# the step currently holds, so renumbering does not retrigger this note.
HANDOFF=$(printf '%s\n' "${SKILLS[@]}" | grep '/handoff/SKILL.md$' || true)
if [ -n "$HANDOFF" ]; then
  guard=$(grep -nF '**Park the cursor'"'"'s sprint first**' "$HANDOFF" | head -1 | cut -d: -f1 || true)
  rewrite=$(grep -nE '^[0-9]+\.[[:space:]]+\*\*Determine the new cursor\*\*' "$HANDOFF" | head -1 | cut -d: -f1 || true)
  if [ -z "$guard" ]; then
    report "/handoff has no parked-sprint guard" \
      "  expected: a '**Park the cursor's sprint first**' way out before 'Determine the new cursor'" \
      "Without it a handoff for another sprint's work overwrites the cursor's in-flight state."
  elif [ -z "$rewrite" ]; then
    report "/handoff's 'Determine the new cursor' heading could not be found" \
      "  expected a numbered list item whose bold text is exactly 'Determine the new cursor'" \
      "The ordering check below can't run without it -- a silent pass here is worse than a" \
      "loud one. If the step was renamed, update this anchor to match, deliberately."
  elif [ "$guard" -gt "$rewrite" ]; then
    report "/handoff determines the new cursor before guarding whose sprint it is" \
      "  park guard at line $guard, 'Determine the new cursor' at line $rewrite" \
      "The guard must come FIRST -- a wholesale rewrite has already lost the state it guards."
  fi
fi

# --- 5. The two prune-block copies stay byte-identical ----------------------------
#
# docs/decisions.md asserts the branch-prune block in resume/SKILL.md and
# archive-sprint/SKILL.md is byte-identical, and a future bin/ extraction of that block
# depends on it staying that way. Nothing enforced it: #60 roughly doubled the block's
# intricacy, and three critic rounds each verified parity BY HAND -- the third round
# flagged the invariant as prose-only. A hand check repeated every round is the
# definition of something to mechanize. See issue #62.
extract_prune_block() {
  local file="$1" hit fence_start fence_end
  hit=$(grep -n 'base=\$(yq -r \.pr_base' "$file" | head -1 | cut -d: -f1 || true)
  [ -n "$hit" ] || return 1
  fence_start=$(head -n "$hit" "$file" | grep -n '^ *```bash$' | tail -1 | cut -d: -f1 || true)
  fence_end=$(tail -n "+$((hit + 1))" "$file" | grep -n '^ *```$' | head -1 | cut -d: -f1 || true)
  [ -n "$fence_start" ] && [ -n "$fence_end" ] || return 1
  # fence_end here is a line number in the tail STREAM, whose line 1 is file line
  # hit+1 -- so file_line = hit + stream_line, not hit + stream_line - 1. Getting
  # this wrong silently drops the block's last line (its closing `fi`) from the
  # comparison, which is exactly the shape of divergence this check exists to catch.
  fence_end=$((hit + fence_end))
  sed -n "$((fence_start + 1)),$((fence_end - 1))p" "$file"
}
RESUME_FILE=$(printf '%s\n' "${SKILLS[@]}" | grep '/resume/SKILL.md$' || true)
ARCHIVE_FILE=$(printf '%s\n' "${SKILLS[@]}" | grep '/archive-sprint/SKILL.md$' || true)
if [ -z "$RESUME_FILE" ] || [ -z "$ARCHIVE_FILE" ]; then
  report "could not find resume/SKILL.md and/or archive-sprint/SKILL.md to compare" \
    "  resume: ${RESUME_FILE:-<not found>}" \
    "  archive-sprint: ${ARCHIVE_FILE:-<not found>}" \
    "A rename or move here would otherwise silently turn this check off."
else
  resume_block=$(extract_prune_block "$RESUME_FILE" || true)
  archive_block=$(extract_prune_block "$ARCHIVE_FILE" || true)
  if [ -z "$resume_block" ] || [ -z "$archive_block" ]; then
    report "could not locate the prune block in resume and/or archive-sprint" \
      "  expected a fenced bash block containing 'base=\$(yq -r .pr_base' in both files"
  elif [ "$resume_block" != "$archive_block" ]; then
    diff_out=$(diff <(printf '%s\n' "$resume_block") <(printf '%s\n' "$archive_block") || true)
    report "the two prune-block copies have diverged" \
      "$(printf '%s\n' "$diff_out" | sed 's/^/  /')" \
      "resume/SKILL.md and archive-sprint/SKILL.md must carry byte-identical prune" \
      "blocks -- see docs/decisions.md and issue #62."
  fi
fi

# --- 6. A skill step is cited by name, never by position ---------------------------
#
# Skill steps are referenced by position (the word "step" or "steps" followed by a
# number), so inserting a step silently breaks every reference to the ones after it --
# including references in OTHER files, which the person doing the renumbering never sees.
# Shipped wrong repeatedly: a recount during Sprint 2 planning found the form in 66 places
# across 15 files, up from 34 across 8 when first raised, because nothing stopped it from
# coming back. The fix, approved 2026-09-23: cite a step by its own bolded name in prose
# (e.g. "the *Prune squash-merged local branches* step"), with no exception for a
# reference to a step within the SAME file -- a single rule with no exceptions is
# checkable by grep, and "except when it's the same file" is not.
#
# The pattern covers three shapes, not just "step N": "step 5", "steps 3 and 4" (a plural
# citing more than one position), and "step-5" (a hyphenated form). The first version of
# this check only caught the singular space-separated form and shipped with a live plural
# ("steps 3 and 4") and a live hyphenated one ("step-5") still in the tree, caught only by
# a critic pass reviewing the very PR that added this check -- exactly the shape of defect
# this check exists to make impossible. No left word-boundary is enforced, so a real
# compound like "lockstep 2" would also match; no such text exists in this plugin's prose
# today, and a false positive here just means an unnecessary rename, never a missed one.
#
# Comments are NOT stripped here, unlike check 1 -- a bin/ script's own comment is exactly
# where a cross-file "step N" reference tends to live (it is prose describing another
# skill's procedure, not code), so it must count. Scanned over every prose surface this
# plugin ships: skills, agents, bin/ and hooks/ scripts, and reference/ -- docs/decisions.md
# is a historical log of decisions as they read AT THE TIME and is intentionally out of
# scope; rewriting its past tense would misrepresent what was actually approved when.
step_hits=""
for f in "${SKILLS[@]}" "${AGENTS[@]}" "${BIN_SCRIPTS[@]}" "${HOOK_SCRIPTS[@]}" "${REFERENCE_DOCS[@]}"; do
  h=$(grep -inE 'steps?[-[:space:]]*#?[0-9]+' "$f" || true)
  [ -n "$h" ] && step_hits+="  $f:"$'\n'"$(printf '%s\n' "$h" | sed 's/^/    /')"$'\n'
done
if [ -n "$step_hits" ]; then
  report "a skill step is cited by number, not by name" \
    "$step_hits" \
    "Cite the step's own bolded name instead, e.g. 'the *Prune squash-merged local" \
    "branches* step' -- never a number, including within the same file. See issue #61."
fi

if [ "$fail" -ne 0 ]; then
  cat >&2 <<'EOF'

One or more shipped-defect invariants regressed. Each check above corresponds to a
real defect this repo has already released at least once. If a check is wrong rather
than the code, fix the check deliberately and say so in the commit -- do not weaken it
to make a diff pass.
EOF
  exit 1
fi

echo "Invariant check passed: no known-wrong form has returned."
