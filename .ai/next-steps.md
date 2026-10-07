# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-07):**
- Task #318 shipped as PR #351 (`1f111b7`): `scripts/loop/attack.sh`, sourced by `launch.sh` under
  `LOOP_ATTACK=1`, probes the assembled container for each of the issue's six items, and the pass
  closed plan v9 § 9's live items. One hole found and fixed: the injecting proxy forwarded any
  request body, so the session could ask the API for server tools, `mcp_servers`, or a `url`/`file`
  source; `inject.py` now refuses those. Results are in plan v9 § 9 and `scripts/loop/README.md`.
- PR #354 (`a18e7f3`): probe coverage for nested url sources and `mcp_toolset`.
- Critic pass: `security-critic` on its default model. #351: 2 rounds, converged (round 2 found no
  reachable bypass). #354: 1 round, tightenings only, fixed. No second-opinion round. This repo has
  no review CI gate, so that was the only critic look before the merge.
- Follow-ups filed in milestone 13: #352 (surface the proxy's deny lines in the driver report) and
  #353 (decide the allowlisted hosts' tunnel residual).

**Next:** task #319 — driver core: tree copy, checks and commit against stubbed docker and gh,
hermetic, per the issue body; ship it as one PR. On **sonnet** (coder). First in the build order
whose dependency (#315) is done.

**HITL Gate: OPEN** — first anchor for milestone 13: this session's resume never ran `verify`, so
handoff treats the prior anchor as no baseline (description sha
`ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`, unchanged). The human merges
this cursor-sync PR, then starts #319 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
