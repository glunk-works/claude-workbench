# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-07):**
- Task #345 shipped as PR #349 (`454a837`), **open, awaiting the human's merge**: the session
  container holds only a placeholder token and `ANTHROPIC_BASE_URL`; `scripts/loop/inject.py`, in
  its own container, holds the real credential and forwards exactly three requests to
  `api.anthropic.com`; `scripts/loop/git_tools.py` (a managed `loopgit` MCP server) replaces the
  free-form `Bash(git …)` allows. Tests: `tests/loop-inject.test.sh`, `tests/loop-git-tools.test.sh`
  (neither wired into `ci.yml`; both in CLAUDE.md's gate list).
- A live `launch.sh` run with a `claude setup-token` credential passed end to end, so the proxy's
  swap works for the subscription OAuth token (decision 4). Deviations from plan v9 § 7.3, both in
  `scripts/loop/README.md`: no `--strict-mcp-config` (claude refuses it beside a managed MCP
  config) and no `Bash` in `--tools`.
- Critic pass on #349: security-critic, architect and docs-consistency on their default models,
  2 rounds, converged (round 2 hygiene only). A second-opinion round on `fable` was offered and
  declined. This repo has no review CI gate, so that was the only critic look before the merge.
- PR #344 (task #317) merged earlier in the day.

**Next:** task #318 — attack the assembled loop container and close the plan's open live items,
per the issue body; ship it as one PR. On **sonnet** (coder). It needs PR #349 merged first, and
the credential file at `C:/Users/SR116/.loop/credential.txt` (`LOOP_CREDENTIAL_FILE`). Hand #318 by
name: the session can still *use* the credential through the proxy for the three allowed requests;
request bodies can still ask for server-side tools; which setting locks MCP down once `Bash` is
allowed; git option reads against the fixed tools; `.git`/config writes; the proxy's host-side
reachability.

**HITL Gate: OPEN** — (1) PR #349 awaits the human's merge; (2) first anchor for milestone 13:
this session's resume never ran `verify`, so handoff treats the prior anchor as no baseline
(description sha `ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`, unchanged).
The human merges #349, then starts #318 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
