# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `9f2fbed`. Status: **implementing**.

**Just done (2026-10-10):**
- **#381 merged** ([#469](https://github.com/glunk-works/claude-workbench/pull/469), `9f2fbed`). Under an installation token resume's derive chain and handoff's no-op handoff now run as the declared `identities.dev_app` (new `review-step.sh login` mode); a `null`, absent or malformed `dev_app` derives nothing. `decide` takes a required `mode` key and **App mode never reaches `auto`** (`show <M> app-mode`), since the App holding the token is unproven. Recorded as a WB-D24 amendment to WB-D22.
- Critic pass (security-critic, architect, docs-consistency): 2 rounds, converged; round 1 found the uncapped-App-mode hole, round 2 tightenings only. All on the critics' default models; no second-opinion round.
- **Not done, for a follow-up:** a stub-`gh` test of the resume/handoff shell blocks; a no-op handoff in App mode followed by a user-mode resume derives `none` silently.

**Next:** task #464 — PR 1 per the [plan comment](https://github.com/glunk-works/claude-workbench/issues/464#issuecomment-6097114231): in App mode ship's Push-reach preflight runs `git push --dry-run` instead of reading `.permissions.push`, and the opened PR's author must equal `identities.dev_app` (via `gh-identity.sh classify`), else stop and touch nothing further. Fixtures for the actor-check predicate, then the green gate, `/way-of-working:critic-gate` (architect + security-critic at least) and `/way-of-working:ship` with `Refs #464`. PR 2, the end-to-end runs, is human-attended. Build on **sonnet** (coder).

**HITL Gate: NONE OPEN — the next gate is the human's merge of the #464 PR 1.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
