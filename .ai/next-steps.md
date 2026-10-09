# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16) ([WB-D24](../docs/decisions.md)). Status: **implementing**.

**Just done (2026-10-09):**
- Task #435 merged (PR #438, `08447af`): items 1-8 recorded in `docs/proposals/IDENTITY-SCRATCH-RESULTS.md` as session 3. None of items 1-3 weakens the merge gate, so no blocking issue; WB-D24 gained four accepted residuals.
- Follow-up #439 filed: restrict the dev App's writes to published releases (maintainer chose restrict, not accept).
- Maintainer deleted `wb-ruleset-scratch-2`; `wb-ruleset-scratch` stays for #439. `glunk-dev`'s temporary `statuses: write` was reverted by the maintainer.
- Milestone 16 description edited on the maintainer's instruction: #439 inserted at step 8, #377 now step 9. Re-anchored at sha `2b5f3b8`.
- Critic pass: none, the session's only diff was docs-only (no `code_paths`).

**Next:** task #439 — prove the release-write restriction on `wb-ruleset-scratch`, then the two #435 cases still untested (an approver's merge push with extra changes; the reviewer App's narrowing with two repos installed), on **sonnet** (coder). Append the output as session 4 and update WB-D24's release residual.
- Record every call through a helper that refuses any non-installation token; read the acting login from responses.
- The human mints admin tokens (`wow-admin`, passphrase), makes the approver push and the UI changes.

**HITL Gate: OPEN.** #439 needs the human's admin mints, the approver push and the UI changes. The human says "go" at the next `/way-of-working:resume`.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
