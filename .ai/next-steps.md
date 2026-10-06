# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #283 built and merged as PR #302 (`294edc4`): the no-op handoff ends with a synced switch to
  `{pr_base}`, and resume's review-step auto-start requires the base at `origin/{pr_base}`, clean,
  with `last_commit` equal to the pin (`review-step.sh decide` gained `branch`, `base`, `base_head`,
  `last_commit` and the reason `last-commit`). `architect-review` rewrites the local cursor's
  `next_action` once its post succeeds, leaving `pointers.review_pr` intact. Residuals are in
  `WB-D22`. Critic pass (architect, security-critic, docs-consistency): 3 rounds, converged;
  second-opinion round offered and skipped.
- Milestone 9 re-planned: #303 (the v0.17.0 release) and #273 (live smoke) added; its description
  now lists them as steps 14 and 15 and was re-anchored.
- Three local branches were skipped by the resume prune (merged, but their tips are not what
  GitHub merged): `docs/sync-cursor-271-next-b`, `docs/sync-cursor-sprint-08-orchestrator-plan`,
  `fix/hook-exec-bit-214` — check for unpushed work.

**Next:** task #303 — build the v0.17.0 release on **sonnet** (`coder`): a `chore(release)` PR
bumping the plugin version and moving `CHANGELOG.md` `[Unreleased]` under 0.17.0 (rewrite the #283
pin warning, carry any Migration line), per the v0.16.0 procedure and the spec in issue #303; one
PR, never tag or merge it. Then #236, a human task on the loop host, and #273 once the pin is
bumped.

**HITL Gate: NONE OPEN** — next gate: the human merge of the release PR, then the tag and this
repo's pin bump (no review CI gate in this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
