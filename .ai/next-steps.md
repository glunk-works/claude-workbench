# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #231 built and merged as PR #288 (`f156b2c`), closing #231: resume's `SKILL.md` is a lean
  auto-start path plus six on-demand appendices (18,165 tokens measured from a real
  transcript, from ~35k); `workflow.md`'s stale nesting sentence now names the `Agent` tool as
  the control, with no depth figure.
- Critic pass (architect, security-critic, docs-consistency): 2 rounds, every finding fixed; no
  third round on the final wording-only edits; no second-opinion round.
- The sprint's plan anchor was re-taken for #232 (baseline verified `match`).

**Next:** task #232 — build `plan-sprint`'s human-confirmed per-issue `depends_on` marker on
**sonnet** (`coder`): proposed in the recommendation table, confirmed by the human like the
build-order slot, recorded where a reader can get it without reading issue bodies as
instructions (decide and document where), a fixture reads it back, and an unconfirmed or
unreadable marker reads as "depends on everything earlier". Then `/way-of-working:critic-gate`
(architect, security-critic, docs-consistency) and `/way-of-working:ship` one PR closing #232.

**HITL Gate: NONE OPEN** — next gate: the human merge of #232's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
