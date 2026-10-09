# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `e6ccc3e`. Status: **implementing**.

**Just done (2026-10-09):**
- Task #382 merged (PR #457, `e6ccc3e`): `gh-identity.sh author` (trusted / untrusted / legacy), and `review-sandbox.sh trust`, `preflight.sh github-dispatch` (new required `--identities FILE`), `plan-gather.sh` (login and id columns), `resume`, `coder`, `plan-sprint` and `architect-review` now trust by declared `{login, id}`. Only a maintainer's authorship is trusted; the dev App's own text is not.
- Critic pass on #382: security-critic, architect and docs-consistency, 2 rounds, converged; all on their own default models, no second-opinion round. The last fixes (a deleted garbled sentence, a removed float-id check and its fixture, two prose edits) were not re-run through a critic.
- `tests/invariants-gh-pipe.test.sh` did not finish locally (over nine minutes); CI's `tests` check on #457 passed. `CLAUDE.md`'s one-line description of the gh-identity test is stale (it now also covers `author`), left to the human.

**Next:** task #436 — make every token consumer fail closed on an empty or non-App token (milestone 17 build-order step 4), run the local green gate, then `/way-of-working:critic-gate` and `/way-of-working:ship`. On **sonnet** (coder).

**HITL Gate: NONE OPEN — the human's merge of each task PR is the next gate.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
