# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16). This is the first sprint of the identity rollout ([WB-D24](../docs/decisions.md)). Status: **implementing**.

**Just done (2026-10-08):**
- Milestone 16 is picked as the sprint and anchored. This is its first anchor: description sha `59b25d41d49e86c6e9cbe17308ce83d37cb05801735d6ae2b2d2e7f4022309ab`, task issue #373.
- Earlier this session (all merged): WB-D24 (#370); the backlog filed across the repos; Identity M1–M8 placed (#421); sprint-12 parked (#420); every required check in both orgs pinned to GitHub Actions.
- No code changed this session, so no critic pass was needed.

**Next:** task #373 — add `scripts/identity/mint.sh` as the issue body specifies, on **sonnet** (coder).
- It's a POSIX script: an openssl-signed App JWT, then `POST /app/installations/{id}/access_tokens` with a repositories and permissions subset, writing the token and its expiry.
- Fixtures go in `tests/identity-mint.test.sh`, with a stub curl.
- Add `scripts/identity/` to `orchestration.human_only_paths`.
- Ship it through `/way-of-working:ship` after the green gate and `/way-of-working:critic-gate` (Closes #373).
- In parallel the human does #371 (remove the stale host MCP entry) and #372 (create the three glunk-works Apps). Those are build-order items 1–2.

**HITL Gate: OPEN.** This is the first anchor for milestone 16 (description sha `59b25d4…`). The human confirms it with a "go" at the next `/way-of-working:resume`. After that, the gates are #371 and #372 (the human's) and the merge of each PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
