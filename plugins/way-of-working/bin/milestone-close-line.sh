#!/bin/sh
# Does a `planning`-status .ai/next-steps.md name its milestone-close outcome?
#
# /way-of-working:archive-sprint's *Close the sprint's milestone* step can fail
# in three independent ways -- skipped, refused by the harness, or staged as
# pending -- and its own *Advance*/*Seed* steps are what carry that outcome into
# the durable ledger. Issue #153 (second occurrence after #128): that carry
# silently did not happen, and a `planning`-status cursor read as clean --
# `hitl_gate: NONE OPEN`, ledger reads "Archived Sprint N" -- while the
# milestone GitHub actually held stayed open. Nothing forced the omission to be
# visible.
#
# This is a deterministic predicate over the ledger's own text, not a judgment
# call, so it is a tested script /way-of-working:resume's pick-up-summary step
# invokes -- mirroring cursor-drift.sh's and plan-anchor.sh's shape -- rather
# than a check described in skill prose.
#
# Usage: milestone-close-line.sh <planning_kind> <sprint_status> <next-steps-file>
# Prints exactly one of, to stdout, and always exits 0 (the caller decides policy):
#   present        -- the file has a line opening with the literal `**Milestone close:**`,
#                      followed by a non-empty value (an empty or template-only label,
#                      `**Milestone close:**` with nothing after it, is NOT present -- a
#                      copied-but-unfilled template must read the same as a missing line)
#   missing        -- applicable, but no such line
#   not-applicable -- <planning_kind> is not `github_milestones`, or <sprint_status>
#                     is not `planning`. NOT the same test as "this cursor was just seeded
#                     by archive-sprint": every `planning`-status cursor under
#                     `github_milestones` is applicable, whichever skill produced or
#                     preserved its ledger -- archive-sprint's Seed step (fresh) and its own
#                     unpark-branch note (fresh, replacing), park-sprint's seed override
#                     (fresh or carried forward), handoff's carry-forward rule (preserved),
#                     and unpark-sprint's Restore step (preserved, from whatever the parked
#                     snapshot held):
#                     plugins/way-of-working/skills/{archive-sprint,park-sprint,handoff,unpark-sprint}/SKILL.md.
#                     Narrower phrasing here was itself a #153-shaped bug once (caught in
#                     this script's own review): it let some of those producers write a
#                     `planning` cursor this check silently never applied to.
#   unreadable     -- applicable, but <next-steps-file> cannot be read
#
# The line's shape is fixed by archive-sprint's own Seed step
# (plugins/way-of-working/skills/archive-sprint/SKILL.md) -- `**Milestone
# close:** <outcome>`, at column 0, the same paragraph (never list-item) shape
# `**Now:**`/`**Next:**`/`**Pointers:**` already use in this ledger. (`**HITL
# Gate:**` is NOT the same shape -- this ledger writes it
# `**HITL Gate: NONE OPEN**`, value INSIDE the bold, so it is not cited as a
# precedent here.) An optional leading `- ` bullet marker is tolerated (matched,
# not required) since a bullet is how handoff's own SKILL.md illustrates the
# ledger's OTHER sections (`- **Now:** ...`) even though the live ledger does not
# actually bullet its top-level labels -- a future line written in that
# documented-but-unused shape must not silently read as missing. Matched as a
# fixed, anchored prefix (an optional bullet, then the literal label, then "some
# content follows") rather than a free-form pattern: this plugin writes the
# line, nothing else in a repo's ledger legitimately produces it, and it does
# not need entry-anchor.sh's containment/continuation handling for a human's
# free-form ledger prose.
#
# Permitted toolset: POSIX sh + grep. No jq, no yq, no python -- this must run
# on any maintainer machine with nothing extra installed. `grep -E` (POSIX
# extended regular expressions) is required for the optional-bullet alternation
# below -- every `grep` on a maintainer machine's PATH supports `-E`.
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: milestone-close-line.sh <planning_kind> <sprint_status> <next-steps-file>" >&2
  exit 2
fi

planning_kind="$1"
sprint_status="$2"
file="$3"

if [ "$planning_kind" != "github_milestones" ] || [ "$sprint_status" != "planning" ]; then
  echo not-applicable
  exit 0
fi

if [ ! -f "$file" ] || [ ! -r "$file" ]; then
  echo unreadable
  exit 0
fi

# Column 0, optionally one bullet marker, the literal bold label, then AT LEAST
# one non-space character before end of line -- a bare `**Milestone close:**`
# with nothing (or only trailing whitespace) after it is `missing`, not
# `present`: an unfilled copy of the template names no outcome any more than an
# absent line does.
if grep -qE '^(- )?\*\*Milestone close:\*\*[[:space:]]*[^[:space:]]' "$file"; then
  echo present
else
  echo missing
fi
