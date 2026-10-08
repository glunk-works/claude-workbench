# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-08):**
- Task #321: the spec for the in-container critic run was written, reviewed and approved by the
  human. It is posted as [the spec comment on #321](https://github.com/glunk-works/claude-workbench/issues/321#issuecomment-6060514332)
  and anchored in the cursor. No code changed.
- It decides three things:
  - The plugin, the bundle and the work tree reach the container as named volumes, filled by
    tar over stdin and mounted read-only.
  - `critic.sh run --docker` creates, preflights and starts the container, then judges the
    init event and kills the container from the host.
  - A separate critic image with no managed MCP config keeps `--strict-mcp-config`.
- It also fixes an existing bug: `critic.sh` bundle drops dot-path base copies under Git Bash.
- Critic pass, on the spec rather than a code diff: `security-critic` and `architect`, 5 rounds,
  converged after the human approved going past the cap. Then +1 on `fable` (second_opinion),
  confirmed for both agents, with two delta re-runs. The final rev 9 edits were not
  re-reviewed. This repo has no review CI gate.
- Follow-up issues the spec proposes, not yet filed:
  - the attack pass against the critic image;
  - a Linux CI job for the loop fixture suites;
  - `.mcp.json` in `human_only_paths`.

**Next:** task #321 — build the in-container critic run from the anchored spec comment, on
**sonnet** (coder).
- Part 1: `pin`, `stage-work` and `bundle --stage-log` with their fixtures.
- Part 2: `run --docker`, the `launch.sh` critic step, the `Dockerfile`, `preflight.sh`, the in-image
  fixture run and the recorded architect run on #366's diff.
- Each part ships as its own PR, `Refs #321`. #321 closes only on a `completed` run.

**HITL Gate: NONE OPEN.** Milestone 13's anchor re-verified (`match`) and now carries the spec
comment. Next gates:
- the human's merge of each #321 PR;
- the human's call on any first-run refusal the spec names in §4.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
