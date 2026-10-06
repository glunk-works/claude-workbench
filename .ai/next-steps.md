# Cursor — claude-workbench

**Now:** **Sprint 10** (cursor id `sprint-10`), milestone 12 *Session-start hardening:
banner and branch prune* (due 2026-10-13). Status: **done** — both tasks merged and
closed, milestone has no open issues.

**Just done (2026-10-06):**
- Task #270 shipped as PR #275: the banner strips control characters from the fields it
  injects (critic pass: 2 rounds, converged).
- Task #271 shipped as PR #278 (`542827e`): `bin/prune-verdict.sh` lets the resume and
  archive-sprint prune delete a merged branch whose tip is the merged commit or an
  ancestor of it; fixtures, CI step, README, CHANGELOG updated. Critic pass
  (security-critic, architect, docs-consistency): 2 rounds, converged; one small
  `GIT_SSH_COMMAND` fix landed after round 2 without a further critic re-read.

**Next:** `/way-of-working:archive-sprint sprint-10` — archive the sprint, close milestone
12, seed the next planning cursor. On **opus** (`architect`). Then
`/way-of-working:plan-sprint` for what follows.

**HITL Gate: NONE OPEN** — the next gate is the human's go on archiving.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 12](https://github.com/glunk-works/claude-workbench/milestone/12) ·
[.ai/parked/](parked/)
