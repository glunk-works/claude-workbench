# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-07):**
- Task #316 shipped as PR #339 (`5e3e900`), merged: Fable is on the API (`claude-fable-5-1`); the
  headless `--model fable` smoke run passed (resolved id is a key of `modelUsage`); the subscription
  terms for unattended `-p` are not settled by the published text, and the maintainer **accepted
  that risk** (recorded in `docs/proposals/orchestrator-m2-decisions.md`). #316 is closed.
- Task #315 (PR #337) merged earlier the same day.
- Critic pass: none needed, both diffs are docs only and touch no `code_paths`.

**Next:** task #324 — build the read-only PR-flow baseline script beside the driver under
`scripts/` with a fixture test on canned `gh` output, and the run-before-enabling adoption step,
per the issue body; ship it as one PR. On **sonnet** (coder). Next in the milestone's build order;
`depends_on: none`. The issue has one comment, which is not anchored as a spec comment.

**HITL Gate: OPEN** — no verified baseline for milestone 13's anchor: this session's resume never
ran `verify`, so handoff's rule treats the prior anchor as no baseline (description sha
`ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`, unchanged from the prior
anchor). The human confirms and starts #324 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
