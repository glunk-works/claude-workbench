# Cursor — claude-workbench

**Now:** **Sprint 7** — [milestone 7](https://github.com/glunk-works/claude-workbench/milestone/7),
*the local green gate checks what it claims, in reasonable time*. Status: **implementing**.

**Just done (2026-09-29):**
- Rewrote milestone 7's description: #197 had already merged in #198, so it moved out of the
  build order and into a "done ahead of the build" line; the 0.14.0 release step stays.
- The human confirmed the edited description as the Sprint 7 plan.
- First anchor for milestone 7, description sha `3c373465bc9b46757d47e874f6e00777396963b710c94809024c81cee8c8865b`,
  task #162 (planning session, no code diff, so no critic pass).

**Next:** task #162 — fix `invariants-check.sh`'s reach-precedes-ruleset check for /resume
so its regex matches the real `gh api --paginate repos/...` form, add the fixture the issue
names, run the local green gate, then `/way-of-working:critic-gate` (architect) and
`/way-of-working:ship`. On **sonnet** (`coder`).

**HITL Gate: NONE OPEN.** The human confirmed the Sprint 7 plan on 2026-09-29. Next gate:
the human merges #162's PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 7](https://github.com/glunk-works/claude-workbench/milestone/7) ·
[.ai/parked/](parked/)
