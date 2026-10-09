# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16) ([WB-D24](../docs/decisions.md)). Status: **implementing**.

**Just done (2026-10-09):**
- Task #439 closed (PR #441, `8cf7fc6`): session 4 in `docs/proposals/IDENTITY-SCRATCH-RESULTS.md`. Immutable releases locks assets and the tag but leaves notes, title and release deletion to the dev App; the maintainer accepted that residual, and WB-D24 now says so.
- An approver's merge commit with an extra change is blocked, and the reviewer App's repository narrowing holds with two repos installed (items 11-12).
- Turning immutable releases on per repo moved to #433 (retitled) and #395; `wb-ruleset-scratch-3` was deleted.
- Critic pass: none, the session's only diff was docs-only (no `code_paths`).

**Next:** task #377 — prove org-ruleset behaviour on a 603-Identity scratch repo (cases a, b, c, e and the App-token reads of the rulesets), on **sonnet** (coder). Append the output as session 5.
- Record every call through a helper that refuses any non-installation token; read the acting login from responses.
- The maintainer creates the repo and org ruleset, installs the Apps and mints admin tokens; 603-Identity calls use a per-process `GH_TOKEN`, never an account switch.

**HITL Gate: OPEN.** #377 needs the human's repo and org-ruleset setup, App installs, admin mints and approvals. The human says "go" at the next `/way-of-working:resume`.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
