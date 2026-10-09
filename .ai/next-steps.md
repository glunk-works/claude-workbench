# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16) ([WB-D24](../docs/decisions.md)). Status: **implementing**.

**Just done (2026-10-08):**
- Task #375 merged (PR #428, `a15a5ce`): the ruleset JSON for `glunk-works/wb-ruleset-scratch` saved under `docs/identity/scratch-rulesets/`.
- The scratch repo is configured: public (rulesets need it on this plan), `allow_auto_merge`, CODEOWNERS naming Seuss27 and JaredGroves-603, a workflow posting the `scratch/status` commit status, and the `wb-checks`, `wb-approval` and `wb-tags` rulesets with no bypass. The `wb-tags` rules (deletion, non_fast_forward, update) were my choice; the issue lists none.
- No critic pass: the diff was docs-only, outside `code_paths`.
- Not yet verified: that the Actions-app pin on `wb-checks` matches a commit status. The workflow had not posted when #375 shipped.

**Next:** task #376 — prove the identity model on the scratch repo (cases a-k) and record the raw output in `docs/proposals/IDENTITY-SCRATCH-RESULTS.md`, on **sonnet** (coder).
- Settle the Actions-app pin question first.
- The human mints the App tokens (`wow-admin`, `wow-review-mint`, passphrase) and plays the second code owner; scratch-repo writes go per approval, never via a gh account switch.
- Also covers the live smoke of the two host commands that #374 deferred.

**HITL Gate: OPEN.** #376 needs the human's passphrase and the second code-owner account. The human says "go" at the next `/way-of-working:resume`. The milestone-16 anchor verified as `match` (description sha `59b25d4…`).

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
