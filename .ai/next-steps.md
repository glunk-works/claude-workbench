# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-08):**
- Task #320 shipped as PR #361 (`67db4f2`): `scripts/loop/preflight.sh`, the container and GitHub
  preflight evaluators (pure over captured JSON), with `tests/loop-preflight.test.sh`.
- Critic pass: `security-critic` and `architect` on their default models, 4 rounds, converged
  (round 4 returned only tightenings). No second-opinion round (declined). This repo has no review
  CI gate, so that was the only critic look before the merge.
- Left as tightenings, not filed: an inline `--mount` volume with bind options, a bare numeric
  `User` with no group, and requiring `no-new-privileges` rather than only allowing it. The real
  `launch.sh` session shape passes; on a cgroup v1 daemon it would be refused (`CgroupnsMode`).

**Next:** task #296 — driver post-exit check: hard-stop diffs touching the trust predicates and
their fixtures, per the issue body; ship it as one PR. On **sonnet** (coder). Next in the build
order whose dependency (#319) is done; #321, #322 and #323 follow.

**HITL Gate: OPEN** — milestone 13's anchor has no verified baseline: this session's resume waited
on the open gate and never ran `verify`, so handoff treats the prior anchor as no baseline (description
sha `ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`, unchanged). The human merges
this cursor-sync PR, then starts #296 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
