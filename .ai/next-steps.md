# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `131f155`. Status: **implementing**.

**Just done (2026-10-09):**
- Task #379 merged (PR #455, `131f155`): `bin/gh-identity.sh` with `classify` (user / app / exit 2) and the `reach` App-mode probe, matching on the numeric id; 120 fixtures, a CI step.
- Critic pass on #379: security-critic and architect, 3 rounds, converged; both on their own default models, no second-opinion round. The last fixes (a fixture and a header sentence) were not re-run.
- Known gaps, none filed yet: `GET /user` is refused to installation tokens, so where an App actor's `{login, id}` comes from is unmeasured and needs a real dev-App token before #380, #381 and #390; duplicate YAML keys pass `schema-complete.sh` and the last one wins; the architect suggested listing `gh-identity.sh` and its test in `scripts/loop/protected-paths.txt`, left to the human.

**Next:** task #382 — make review-sandbox.sh, architect-review, agents/coder.md, plan-gather.sh and scripts/loop/preflight.sh trust by declared identity (`{login, id}` from `identities`) instead of `author_association` (milestone 17 build-order step 3), run the local green gate, then `/way-of-working:critic-gate` and `/way-of-working:ship`. On **sonnet** (coder).

**HITL Gate: NONE OPEN — the human's merge of each task PR is the next gate.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
