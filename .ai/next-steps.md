# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16) ([WB-D24](../docs/decisions.md)). Status: **implementing**.

**Just done (2026-10-09):**
- Task #376 merged (PR #434, `188837a`): cases a-k recorded in `docs/proposals/IDENTITY-SCRATCH-RESULTS.md`. f is Partial and g is consistent, not conclusive. Session 1's case f is void: it ran as JaredGroves-603, most likely an empty token falling back to the stored gh login.
- Surprises filed: #432 (auto-merge stalled once, blocking), #433 (tag-creation rule at cutover), #435 (approval-rule edge cases), #436 (token consumers must fail closed). #386 has a note: `gh pr merge --auto` merges a clean PR directly.
- Live changes: glunk-review gained contents, checks and statuses read; glunk-admin gained contents and pull_requests write; `wb-tags` gained a `creation` rule; JaredGroves-603 has write on scratch.
- Critic pass: docs-consistency + security-critic, 2 rounds, converged; second-opinion round on fable offered and declined.
- Milestone 16 description edited on the maintainer's instruction: #435 inserted at step 7, #377 now depends on #435. Re-anchored at sha `82dd58c`.

**Next:** task #435 — prove the approval-rule edge cases #376 left open (items 1-8 in the issue body) and append them to the results doc as session 3, on **sonnet** (coder).
- Record every call through a helper that refuses any non-installation token; read the acting login from responses.
- The human mints admin tokens (`wow-admin`, passphrase) and approves as both code owners; scratch writes go per approval, never via a gh account switch.

**HITL Gate: OPEN.** #435 needs the human's approvals and admin-mode mints. The human says "go" at the next `/way-of-working:resume`.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
