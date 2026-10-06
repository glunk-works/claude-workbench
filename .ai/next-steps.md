# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), milestone 11 *v0.16.0 follow-ups: merge-flow
hardening*. Status: **implementing**; #247 is the last open issue and it is a Decide item.

**Just done (2026-10-06):**
- Built #246 (`ai-cursor-banner` caps every interpolated value, the `Parked:` id list
  included, at 200 characters; fixtures for both `assigned_model` sites and a long Parked
  list); merged as PR #266 (`ca6917f`).
- Critic pass on that diff: architect and security-critic, initial pass plus 1 fix-and-re-run
  round, **converged**, default models, no second-opinion round. No review CI gate exists, so
  that pass was the only critic look the diff had.
- Left open on purpose: `cap` bounds length, not content — a newline in a cursor field or a
  parked filename can still forge banner lines within the cap (not yet filed as an issue); two
  local branches the prune skipped (`docs/sync-cursor-sprint-08-orchestrator-plan`,
  `fix/hook-exec-bit-214`) may hold stranded work.

**Next:** decide #247 with the human — present both options from the issue, recommend one,
record the outcome as a WB-D entry or a comment on #247. Build nothing until they pick. On
**opus** (`architect`).

**HITL Gate: OPEN** — #247 needs the human's choice between invoking the hook directly and
running it through `bash` in `hooks/hooks.json`; the milestone 11 description verified `match`
against the prior anchor this session.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[.ai/parked/](parked/)
