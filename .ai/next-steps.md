# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `97c03c6`. Status: **implementing**.

**Just done (2026-10-09):**
- Task #378 merged (PR #453, `97c03c6`): `identities` key, optional `rulesets` list, nullable `orchestration.restrict_updates`. The legacy `ruleset.*` keys stay required for this release because no reader understands the list yet.
- Critic pass on #378: architect, docs-consistency and security-critic, 3 rounds, converged; all on the critics' own default models, no second-opinion round.
- Follow-ups filed: #451 (bind `ruleset.name` as a value in resume's ruleset check) and #452 (validate `identities` and `rulesets` entries in the checker).
- Migration for the v0.18.0 release notes: every adopting repo adds `identities: null` to `.ai/project.yml`.

**Next:** task #379 — add `bin/gh-identity.sh` to classify the acting identity (milestone 17 build-order step 2), run the local green gate, then `/way-of-working:critic-gate` and `/way-of-working:ship`. On **sonnet** (coder).

**HITL Gate: NONE OPEN — the human's merge of each task PR is the next gate.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
