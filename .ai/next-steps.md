# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16) ([WB-D24](../docs/decisions.md)). Status: **implementing**.

**Just done (2026-10-08):**
- Task #374 merged (PR #426, `75d151e`): `wow-admin` and `wow-review-mint` under `scripts/identity/`, with `tests/identity-wow.test.sh`.
- Critic pass on #374: `security-critic`, `architect` and `docs-consistency`, 3 rounds, converged, all on their default models; no second-opinion round.
- Hermetically verified; the live smoke (mint, expiry, 401 after revoke) is deferred to #376, which needs #375's scratch repo.
- Human tasks #371 and #372 are complete: the Apps exist and `apps.json` is in `~/.config/glunk-identity`.
- Left for the maintainer: `wow-review-mint --out` accepts any writable path (a future broker must not forward it), the reviewer token has no revoke, and a lock left by a killed run needs a manual `rmdir`.

**Next:** task #375 — recreate `wb-ruleset-scratch` with the target ruleset shape and save the ruleset JSON, on **sonnet** (coder).
- The issue's Who is the maintainer: the admin token comes from `wow-admin <repo>` run by the human (passphrase), and org-repo writes go per approval, never via a gh account switch.
- The issue does not say which org owns the repo; ask.
- The live smoke of the new commands is #376, not this task.

**HITL Gate: OPEN.** #375 creates a repo and rulesets with admin writes and needs the human's passphrase. The human confirms the repo's owner and says "go" at the next `/way-of-working:resume`. The milestone-16 anchor re-verified as `match` (description sha `59b25d4…`).

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
