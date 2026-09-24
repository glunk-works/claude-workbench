# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **planning** — the
milestone description lays out the build order and model-per-phase note; this phase
reviews and confirms it before build starts.

**Just done (2026-09-24):**
- Archived Sprint 2 ([milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2));
  the Status-section update merged as [PR #149](https://github.com/glunk-works/claude-workbench/pull/149)
  (`3bdf226`). The archive run did **not** close milestone 2 on GitHub — that close is staged below.
- Triaged the open issues (Fable, at the human's request). Done on GitHub: **#150**
  (archive-sprint precondition 3 has no branch procedure) → Sprint 3, labelled `bug` +
  `area/way-of-working`. Decided, but **staged for the human** because the auto-mode
  classifier denies `gh api` writes to this org: #150 becomes Sprint 3 build-order step 4
  (before the release); **#124** → a new trigger-gated **Sprint 6** (starts when a gated
  repo is about to declare `migration_base`, no due date, sorts last); Sprint 4's stale
  "#104 if late" clause dropped; due dates on Sprints 3 and 5 so the milestone list sorts
  3 → 4 → 5 → 6 (it currently shows Sprint 4 first — only it has a date). Sprint sequence
  itself confirmed unchanged: trust chain → decisions → schema → trigger-gated.

**Next:** after the gate clears, on **fable** (`architect` — the milestone's own model-per-phase
note and the human's standing Fable routing for design put #113's spec on Fable, not the
`models:` map's opus): write #113's isolation-mechanism design spec on the issue (options +
recommendation, human picks). Then `/way-of-working:handoff` → sonnet `coder` starts build
order step 1, #126 (design settled in the issue, no plan needed).

**HITL Gate: OPEN** — run the staged milestone writes:
`sh "$LOCALAPPDATA/Temp/claude/c--Users-SR116-projects-personal-claude-workbench/1fbccbaa-7e1a-40ed-b0a2-f011244e846e/scratchpad/milestone-writes.sh"`
(five `gh api` calls plus one `gh issue edit`; the new milestone texts sit beside it). Until
it runs, milestone 4's description does not list #150, Sprint 6 does not exist, #124 is
unmilestoned, and milestone 2 is still open. If the scratchpad is gone, the Sprint 6 text is
on [#124](https://github.com/glunk-works/claude-workbench/issues/124) as the 2026-09-24
triage comment.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
