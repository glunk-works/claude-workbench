# Cursor — claude-workbench

**Now:** **Sprint 16** (cursor id `sprint-16`) on [milestone 19, *Identity M4: claude-workbench cutover*](https://github.com/glunk-works/claude-workbench/milestone/19). Status: **implementing**.

**Just done (2026-10-14):**
- Task #567: reworded the no-spec-comment comment in `plugins/way-of-working/bin/plan-anchor.sh` (comment only), shipped as [PR #608](https://github.com/glunk-works/claude-workbench/pull/608) (`af76898`). Auto-merge not armed (repo disallows it), so the merge is the human's.
- Critic pass: `architect`, 1 round, converged (no false statements; two optional wording tightenings left unapplied). Subagent pre-review only.
- Green gate passed locally: lint, coupling, invariants, `tests/plan-anchor.test.sh`.

**Next:** merge PR #608, then take #566 (next in milestone 19's build order): post a spec comment on it, get a maintainer reaction, and re-anchor with `/way-of-working:handoff`. On **sonnet** (coder).

**HITL Gate: NONE OPEN** — next gate: the human merges PR #608, and a maintainer reacts to the spec comment for the next task

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 19](https://github.com/glunk-works/claude-workbench/milestone/19) · [.ai/parked/](parked/)
