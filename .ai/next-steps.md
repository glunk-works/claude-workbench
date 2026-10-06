# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #219 built and merged as PR #286 (`477591d`), closing #219: archive-sprint's Snapshot step
  now checks `.ai/archive/` is git-ignored before writing, and names the tracked-snapshot fix.
- Critic pass (architect, docs-consistency): 3 rounds, converged; no second-opinion round.
  security-critic not run (no new input flow).
- The sprint's plan anchor was re-taken for #231 (baseline verified `match`).

**Next:** task #231 — fix `workflow.md`'s stale nesting sentence and split resume's
`SKILL.md` into a lean auto-start path plus on-demand appendices on **sonnet** (`coder`), under
20k tokens of plugin prose measured from a real transcript (the measurement goes in the PR
body), no auto-start condition moved out. Then `/way-of-working:critic-gate` (architect,
security-critic, docs-consistency — it touches the fail-closed path) and
`/way-of-working:ship` one PR closing #231.

**HITL Gate: NONE OPEN** — next gate: the human merge of #231's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
