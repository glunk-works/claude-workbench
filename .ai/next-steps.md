# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16) ([WB-D24](../docs/decisions.md)). Status: **implementing**.

**Just done (2026-10-08):**
- Task #373 merged (PR #423, `c5e1a36`): `scripts/identity/mint.sh` and its fixtures in `tests/identity-mint.test.sh`.
- Critic pass on #373: architect and security-critic, 3 rounds, converged, on their default models. Two small edits after convergence (`mktemp --` and the `--out` race fixture) were not re-reviewed.
- Hermetically verified; the live smoke ("mints a working token for the scratch repo") is deferred to #372 (the Apps) and #375 (the scratch repo).
- Left for the maintainer: a policy ceiling on which installations and permissions a caller may mint, and whether `tests/identity-mint.test.sh` joins `scripts/loop/protected-paths.txt`.

**Next:** task #374 — add `wow-admin` and `wow-review-mint` under `scripts/identity/` as the issue specifies, on **sonnet** (coder).
- Build on `mint.sh`; test against a stub curl (no App credentials needed).
- The issue leaves open where the keys live, how the passphrase is supplied and how a token reaches a container. If the body does not settle one, stop and ask.
- Ship through `/way-of-working:ship` after the green gate and `/way-of-working:critic-gate` (Closes #374).
- In parallel the human does #371 (remove the stale host MCP entry) and #372 (create the three glunk-works Apps).

**HITL Gate: OPEN.** First anchor for milestone 16 on this cursor (description sha `59b25d4…`, unchanged from the one confirmed earlier today). It re-opened only because the previous resume never ran `plan-anchor.sh verify`, so there was no valid baseline. The human confirms with a "go" at the next `/way-of-working:resume`; after that the gates are #371 and #372 (the human's) and the merge of each PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
