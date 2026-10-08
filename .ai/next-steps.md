# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-08):**
- Task #321 partly shipped as PR #366 (`63e8f0c`): `scripts/loop/critic.sh` stages the critic bundle,
  launches one critic with the plan v9 § 7.3 line, and checks the `system/init` event, stopping the
  session on a mismatch; fixtures in `tests/loop-critic.test.sh`. Merged as `Refs #321`, so **#321
  stays open**: its last acceptance item, one real critic run in the loop container, is not done.
- Critic pass: `security-critic` and `architect` on their default models, 3 rounds, converged on
  defects; a final doc and wording pass after round 3 had no critic look. No second-opinion round.
  This repo has no review CI gate, so that was the only critic look before the merge.
- A real critic run on the Windows host (not the container) matched the init event on tools, model,
  agent and plugin version and was refused only on a `C:\` vs `/c/` path; it proved nothing about the
  container. Open points only the container settles: the plan's `--strict-mcp-config` against the
  managed MCP config (`claude` refuses it there), and whether `--json-schema` adds a tool to init
  `tools`. (None appeared on the host.)
- The credential is at `~/.loop/credential.txt`; Docker and WSL2 are up on this host.

**Next:** task #321 — write a one-page spec for the in-container critic run and put it in front of the
human; build nothing until they approve it. On **opus** (architect). Questions the spec answers: how the
pinned plugin and the bundle reach the session container when the preflight refuses bind mounts,
whether `critic.sh run` launches through `docker run` or a harness wraps it, and what to do about
`--strict-mcp-config`. Then a **sonnet** coder session builds the harness from the approved spec and
does the run (one `architect` at a $2 cap through the injecting proxy), recorded on #321.

**HITL Gate: NONE OPEN** — milestone 13's anchor re-verified against the prior baseline. Next gate: the
human's approval of the spec. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
