# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-07):**
- Task #324 shipped as PR #342 (`67c0ed7`), merged: `scripts/loop/baseline.sh` derives a repo's
  PR-flow numbers read-only from merged-PR history, with a fixture test
  (`tests/loop-baseline.test.sh`) and the run-before-enabling adoption step in
  `scripts/loop/README.md`. On this repo it reproduces the brief's ratios (cursor PRs per work PR,
  dependent share, overlap); work-PR count and median differ slightly, cause unconfirmed.
- Its `open_to_merge_min_per_work_pr` is wait-to-merge time, **not** the M2b exit metric; #341 files
  the replacement (human actions and sittings per work PR) under milestone 14. The new test is not
  wired into `ci.yml` (human-only path).
- Critic pass on #342: architect, security-critic and docs-consistency; 3 fix-and-re-run rounds,
  converged; no second-opinion round. This repo has no review CI gate, so that was the only critic
  look before the merge.
- Tasks #316 and #315 merged earlier the same day.

**Next:** task #317 — assemble the full plan v9 § 7.3 loop container as one piece under
`scripts/loop/`, per the issue body: one scripted build-and-launch runs a trivial task; the attack
pass is #318, not this issue. Ship it as one PR. On **sonnet** (coder). Next in the milestone's
build order; `depends_on: #315`, which is merged. The issue has one comment, a triage note, not
anchored as a spec comment.

**HITL Gate: OPEN** — no verified baseline for milestone 13's anchor: this session's resume never
ran `verify`, so handoff's rule treats the prior anchor as no baseline (description sha
`ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`, unchanged from the prior
anchor). The human confirms and starts #317 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
