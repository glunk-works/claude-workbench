# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`), no milestone picked yet: planning orchestrator
milestone 2. Status: **planning**.

**Just done (2026-10-06):**
- Sprint 11 (milestone 9, `v0.17.0`) archived; snapshot in `.ai/archive/sprint-11-next-steps.md`.
  Its roadmap entry is merged (#310), and #273 and #236 are closed.
- Orchestrator milestone 2 was analysed one decision at a time with architect and research
  subagents; the outcome, the PR-flow data from four repos and the proposed three-milestone cut are
  in `docs/proposals/orchestrator-m2-decisions.md` (#311, merged).
- The maintainer confirmed all nine decisions; recorded in the brief by PR #314 (open, awaiting
  the human's merge). Merge-triggered dispatch moved from M2b to M2c, after the lock-scope decision.
- `/way-of-working:plan-sprint` pass: 20 issues filed (#315–#334) and three milestones created
  with build orders and `depends_on` markers — milestone 13 *Orchestrator M2a: loop container
  proven* (11 issues incl. #296, due 2026-11-06), 14 *Orchestrator M2b: first waves on
  claude-workbench* (4, due 2026-11-27), 15 *Orchestrator M2c: governor and eval* (5, due
  2026-12-18). #223, #227, #313 and #334 left unmilestoned on purpose; triage comments posted.

**Milestone close:** closed — milestone 9, *Sprint 8: orchestrator milestone 1*, 0 open issues,
read-back `closed`.

**Next:** after #314 merges, the human picks sprint 12's milestone (milestone 13, M2a, is the
planned first) and `/way-of-working:handoff` anchors it, with build-order step 1, #315 (plan sync
and the `scripts/` WB-D), as the first task on **opus** (architect).

**HITL Gate: NONE OPEN** — the next gate is the plan anchor at the handoff that picks the milestone.
No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[.ai/parked/](parked/)
