# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #234 built and merged as PR #294 (`31973ea`): `orchestration` is a nullable map required of
  every adopting repo (`null` = no loop here), with `critics`, `round_cap`, `human_only_paths`,
  `restrict_updates` and a nullable `loop_identity`; `schema-complete.sh`, its fixtures, resume's
  interview appendix, the CHANGELOG migration line and this repo's answers all landed. Critic
  pass (architect, security-critic, docs-consistency): 2 rounds, converged; second-opinion round
  declined. This repo's `human_only_paths` leaves `plugins/way-of-working/bin/` off on purpose.
- Plan-sprint pass: #283 (the WB-D22 residual, release-blocking) placed in milestone 9; #295
  (WB-D22 guard on `loop_identity`) filed there; #296 (driver post-exit check on the trust
  predicates) filed unmilestoned; #273, #227, #223 left unmilestoned with reasons recorded as
  issue comments.
- Milestone 9's description was edited by hand to the new build order (#235, #295, #283, #236);
  the plan anchor was re-baselined `match` after that edit and re-taken for #235.

**Next:** task #235 — build the loop-identity name rule on **sonnet** (`coder`):
`plan-anchor.sh verify` gains an `untrusted` verdict (login passed as an argument, compared
case-insensitively before any other comparison; the script forbids `yq`) and handoff and
archive-sprint learn it; `review-sandbox.sh trust` refuses `orchestration.loop_identity` before
any association check; fixtures include a stale `loop_identity` on a machine user. Then
`/way-of-working:critic-gate` (architect, security-critic, plus docs-consistency for skill prose)
and `/way-of-working:ship` one PR closing #235. After it: #295, #283, #236.

**HITL Gate: NONE OPEN** — next gate: the human merge of #235's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
