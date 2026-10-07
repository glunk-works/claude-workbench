# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-07):**
- Task #317 shipped as PR #344 (`7b07b01`), **open, awaiting the human's merge**:
  `scripts/loop/launch.sh` assembles the whole plan v9 § 7.3 container (base provenance check, loop
  layer, isolated network with the allowlisting proxy, outside and inside preflight, the coder launch
  line); a trivial task ran to completion in it several times. Proxy fixtures:
  `tests/loop-proxy.test.sh` (not wired into `ci.yml`, not yet in CLAUDE.md's gate list).
- Critic pass on #344: architect, security-critic and docs-consistency; 2 fix-and-re-run rounds, the
  second still returning real findings, then a third fix round that **no critic re-checked**
  (stopped by the human's call to ship; no second-opinion round). This repo has no review CI gate,
  so that was the only critic look before the merge.
- Known residual: the allowed `git` subcommands can read `/proc/<pid>/environ`, where the session's
  credential sits. No secret was committed or pushed. Filed as #345 (milestone 13), to land before
  the attack pass #318.

**Next:** task #345 — keep the credential out of the loop session container (a credential-injecting
proxy plus fixed git tools in place of the free-form git allows, under `scripts/loop/`), per the
issue body; ship it as one PR. On **sonnet** (coder). It depends on #344 being merged.

**HITL Gate: OPEN** — (1) PR #344 awaits the human's merge; (2) first anchor for milestone 13:
this session's resume never ran `verify`, so handoff treats the prior anchor as no baseline
(description sha `ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`, unchanged);
(3) the human confirms #345 comes before #318 and settles whether the proxy's credential injection
works for the subscription OAuth token (decision 4). The human merges #344, confirms, and starts
#345 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
