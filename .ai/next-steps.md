# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), milestone 11 *v0.16.0 follow-ups: merge-flow
hardening*. Status: **implementing**.

**Just done (2026-10-05):**
- Built #250 (`resume` no longer offers an `--admin` merge the active `gh` identity cannot
  perform; `pr-checks` names the identity); merged as PR #256 (`c81f18f`).
- Critic pass on that diff: architect, security-critic and docs-consistency, 2 rounds,
  converged; no second-opinion round run. No review CI gate exists, so that pass was the
  only critic look the diff had.
- Pruned two squash-merged local branches; `fix/hook-exec-bit-214` and
  `docs/sync-cursor-sprint-08-orchestrator-plan` were skipped (tip is not what GitHub merged)
  and may be stranded work.

**Next:** task #245 — `cursor-sync-pr.sh` requires every named required check to appear green
in the rollup. Then the green gate, critic-gate (architect + security-critic) and ship;
#248, #244, #243, #246 and #247 follow in the milestone's build order. On **sonnet**
(`coder`).

**HITL Gate: OPEN** — first anchor for milestone 11 (no verified baseline this session),
description sha `267c67978b0a48a26b8706dd5fba09b5c9dd95c4b3c6841986140840fe8bded5`, unchanged
since the previous anchor: a human confirms the description is still the intended plan, then
says go.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[.ai/parked/](parked/)
