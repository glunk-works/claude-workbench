# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #235 built and merged as PR #298 (`f1526f4`): `plan-anchor.sh verify` takes
  `--loop-identity <login>` and prints `untrusted` before any drift comparison;
  `review-sandbox.sh trust` reads `orchestration.loop_identity` from the default branch's copy
  and refuses that author before any association check (output gains `loop=0|1`; needs `yq`);
  resume waits on `untrusted`, handoff and archive-sprint refuse it. Critic pass (security-critic,
  architect, docs-consistency): 3 rounds, converged; second-opinion round not run.
- Known residuals, recorded in the PR: the `--loop-identity` flag is optional for callers (a
  forgotten flag disables the rule); the rule checks creator/author, not last editor; a stale
  `loop_identity` protects only its own old name.
- The installed plugin cache predates #298, so `plan-anchor.sh` there rejects the new flag until
  the pin is bumped.

**Next:** task #295 — build the WB-D22 guard on **sonnet** (`coder`): resume's review-step
derivation (`bin/review-step.sh`, the decide path) derives nothing when the running login
equals `orchestration.loop_identity` (REST `user.login` form, case-insensitive, `null` = no
guard; read from the default branch's trusted copy), with fixtures, WB-D22 in `docs/decisions.md`
and the schema doc's "no skill reads these keys yet" sentence updated. Then
`/way-of-working:critic-gate` (architect, security-critic, plus docs-consistency for skill prose)
and `/way-of-working:ship` one PR closing #295. After it: #283, #236.

**HITL Gate: NONE OPEN** — next gate: the human merge of #295's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
