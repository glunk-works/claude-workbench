# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **planning** — the
milestone description lays out the build order and model-per-phase note; this phase
reviews and confirms it before build starts.

**Just done (2026-09-24, Fable):**
- Triage landed. The human ran the staged milestone writes: milestone 4 now lists #150 as
  build-order step 4 and is dated 2026-10-27; milestone 3's stale "#104 if late" clause is
  gone; milestone 5 is dated 2026-12-08; **Sprint 6**
  ([milestone 6](https://github.com/glunk-works/claude-workbench/milestone/6), trigger-gated,
  undated) exists with #124 in it; milestone 2 is closed. The open milestones now sort
  3 → 4 → 5 → 6. Cursor sync merged as [PR #151](https://github.com/glunk-works/claude-workbench/pull/151).
- Filed [#152](https://github.com/glunk-works/claude-workbench/issues/152) (`plan-sprint`
  skill: the planning pass, mechanized; ranking stays human) → Sprint 5, and
  [#153](https://github.com/glunk-works/claude-workbench/issues/153) (archive-sprint's
  milestone close reached neither the ledger nor the gate; second occurrence, #128's prose
  did not prevent it) → unmilestoned for the next triage. #153 is worth pulling into
  Sprint 3 since that is the next sprint to run an archive.

**Next:** on **fable** (`architect` — the milestone's own model-per-phase note and the human's
standing Fable routing for design put #113's spec on Fable, not the `models:` map's opus):
write #113's isolation-mechanism design spec on the issue (options + recommendation, human
picks). Then `/way-of-working:handoff` → sonnet `coder` starts build order step 1, #126
(design settled in the issue, no plan needed).

**HITL Gate: OPEN** — one staged milestone write: Sprint 5's description gains #152 as
build-order step 2. Run
`sh "$LOCALAPPDATA/Temp/claude/c--Users-SR116-projects-personal-claude-workbench/1fbccbaa-7e1a-40ed-b0a2-f011244e846e/scratchpad/milestone-writes-2.sh"`;
the proposed text is also on #152 as the 2026-09-24 comment. Small, and it does not block
Sprint 3's next action; clear it whenever convenient.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
