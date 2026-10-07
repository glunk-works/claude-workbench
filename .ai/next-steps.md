# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-07):**
- Task #319 shipped as PR #356 (`21b812b`): `scripts/loop/driver-core.sh`, the hermetic tree copy,
  checks and commit against stub docker and gh, with `tests/driver-core.test.sh`. PR #358
  (`d6645cf`) pointed its liveness caveat at the follow-up.
- Critic pass: `security-critic` and `architect` on their default models, 4 rounds, converged
  (rounds 3-4 found only operator-side input validation and docs wording). One
  `--human-only-path` validation fix landed after round 4 and no critic re-reviewed it. No
  second-opinion round (declined). This repo has no review CI gate, so that was the only critic
  look before the merge.
- Follow-up filed in milestone 13: #357 (the launcher must label the session container
  `loop.session`; until it does, the driver's liveness check cannot see a running session).

**Next:** task #320 — driver preflight evaluators: container and GitHub, refusing a repo without
the update rule, hermetic against stub docker and gh, per the issue body; ship it as one PR. On
**sonnet** (coder). Next in the build order whose dependency (#315) is done.

**HITL Gate: OPEN** — milestone 13's anchor has no verified baseline: this session's resume waited
on the open gate and never ran `verify`, so handoff treats the prior anchor as no baseline (its own
pre-overwrite verify printed `match`; description sha
`ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`, unchanged). The human merges
this cursor-sync PR, then starts #320 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
