# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `6d23664`. Status: **implementing**.

**Just done (2026-10-09):**
- Task #388 merged (PR #462, `6d23664`): `preflight.sh github-dispatch` requires the approval gate (count >= 1, code owner, last push, each met by some applicable rule) in place of the `update` rule; the dispatch `bypass_actors` read is gone, `github-push`'s `current_user_can_bypass` is the only bypass read. `--rulesets`/`--app-id` are usage faults on dispatch.
- Critic pass on #388: architect, security-critic and docs-consistency, 2 rounds, converged; all on their own default models, no second-opinion round (offered, skipped). The PR merged **without** the fresh-session `architect-review` (the human merged before one was run).
- Recorded gaps, in the `preflight.sh` header: `current_user_can_bypass` is unmeasured for an App that is a bypass actor; stale-approval dismissal, CODEOWNERS coverage, active-rulesets-only and the push-time approval check are not checked.

**Next:** task #380 — make resume, ship, handoff and the planning skills use `gh-identity.sh` instead of assuming a user token (milestone 17 build-order step 6; depends on #379, merged). Read `#380`'s body once under resume's TOCTOU rule; it has one issue comment that is **not** anchored as a spec. Run the local green gate, then `/way-of-working:critic-gate` and `/way-of-working:ship`. On **sonnet** (coder).

**HITL Gate: NONE OPEN — the human's merge of each task PR is the next gate.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
