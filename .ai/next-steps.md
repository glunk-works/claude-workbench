# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `072eeb2`. Status: **implementing**.

**Just done (2026-10-09):**
- Task #436 merged (PR #460, `072eeb2`): `token-check.sh` (`file`, `token`, `verify`) refuses an empty, expired, malformed or user token, and `verify` requires the installation to reach the repo; `gh-identity.sh role` is the lookup it uses. Fixtures in `tests/token-check.test.sh`, wired into CI.
- Critic pass on #436: security-critic, architect and docs-consistency, 3 rounds, converged; all on their own default models, no second-opinion round (offered, skipped).
- No consumer calls `token-check.sh` yet; #389 is the first. `verify`'s `app` result is unreachable for real callers until an installation token's `{login, id}` source is measured, so they use `any` or `admin`.
- `tests/invariants-gh-pipe.test.sh` still does not finish locally (over nine minutes); CI's `tests` check passed on #460. `CLAUDE.md`'s one-line description of the gh-identity test is stale (it also covers `author` and `role`), left to the human.

**Next:** task #388 — make `scripts/loop/preflight.sh` accept the approval rule in place of the update-rule precondition and read the App's own `current_user_can_bypass` in place of the admin-only `bypass_actors` read (milestone 17 build-order step 5), update the README and loop-preflight fixtures, run the local green gate, then `/way-of-working:critic-gate` and `/way-of-working:ship`. On **sonnet** (coder).

**HITL Gate: NONE OPEN — the human's merge of each task PR is the next gate.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
