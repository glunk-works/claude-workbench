#!/usr/bin/env bash
# The regression gate: three invariants that have already been got wrong, in prose.
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
