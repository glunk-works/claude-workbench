# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- HITL Gate closed: the human confirmed milestone 9's description (anchor sha unchanged).
- WB-D22 drafted on opus into `docs/decisions.md`, committed `72de2c6` on local branch
  `docs/wb-d-step1-230` (not pushed; it lands with the build PR). The human decided five
  points one at a time (author + head pin, running login + loop-identity guard,
  `pointers.review_pr`, `github_milestones` only with handoff writing `## Critic pass`,
  `ci_gate: null` report-only).
- Critic pass (architect, security-critic, docs-consistency): 6 rounds, converged; rounds
  5–6 past the cap on the human's authorization. A final fail-closed paragraph from round
  6's tightenings landed without a further re-read.

**Next:** task #230 — build WB-D22 on **sonnet** (`coder`), on `docs/wb-d-step1-230`
(switch to it first): the no-op handoff rule with `pointers.review_pr`, resume's
review-form token check and GitHub-derived review step (a fixture-tested `bin/`
predicate: match, disagreement, no `state.json`, App-authored PR), `architect-review
--pin`, `review_pr` nulled by the other `state.json` writers, and the #209 and #220
fixes. Then `/way-of-working:critic-gate` and `/way-of-working:ship` one PR closing
#230, #209 and #220.

**HITL Gate: NONE OPEN** — next gate is the human merge of #230's build PR (no review CI
gate in this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) (WB-D22) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
