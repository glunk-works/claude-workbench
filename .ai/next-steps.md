# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #230 built and merged as PR #284 (`12ef237`), closing #230, #209 and #220: WB-D22's step-1
  half — the no-op handoff, `bin/review-step.sh`, `bin/critic-section.sh`,
  `architect-review --pin`, and the two sprint-close fixes.
- Critic pass (architect, security-critic, docs-consistency): 4 rounds, cap reached, then a
  fifth at the human's request that found wording and fail-closed gaps only, no new safety
  defects; no second-opinion round.
- Known residual tracked as #283: the pinned review starts on the PR's own tree. It must land
  before any adopter with `review.ci_gate` set bumps to a release containing #284.
- The sprint's plan anchor was re-taken for #219 (baseline verified `match`).

**Next:** task #219 — build archive-sprint's Snapshot guard per the issue on **sonnet**
(`coder`): the Snapshot step assumes `.ai/archive/` is git-ignored and never checks. Then
`/way-of-working:critic-gate` (architect + docs-consistency) and `/way-of-working:ship` one PR
closing #219.

**HITL Gate: NONE OPEN** — next gate: the human merge of #219's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
