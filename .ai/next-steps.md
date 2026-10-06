# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), milestone 11 *v0.16.0 follow-ups: merge-flow
hardening*. Status: **done**. No open issues remain in the milestone; it is still open on
GitHub until archive-sprint closes it.

**Just done (2026-10-06):**
- Decided #247 with the maintainer: `hooks/hooks.json` keeps invoking the SessionStart hook
  directly, not through `bash`. Recorded as `WB-D21`; merged as PR #268 (`7be385a`), which
  closed #247.
- No code diff this session, so no critic pass applied.
- Still open from last session: `cap` bounds banner fields' length, not content (a newline
  can still forge banner lines; not yet filed); two local branches the prune skipped again
  (`docs/sync-cursor-sprint-08-orchestrator-plan`, `fix/hook-exec-bit-214`) may hold
  stranded work.

**Next:** run `/way-of-working:archive-sprint` for sprint-09. Milestone 11's work ships with
the milestone 9 release, so no release here. On **opus** (`architect`).

**HITL Gate: OPEN** — the human confirms sprint-09 is complete before archive-sprint runs
and closes milestone 11; the milestone 11 description verified `match` against the prior
anchor this session.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[.ai/parked/](parked/)
