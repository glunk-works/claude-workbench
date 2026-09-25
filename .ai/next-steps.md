# Cursor — claude-workbench

**Now:** **Sprint 5** — [milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5),
*every config key is an explicit decision*. Status: **implementing**.

**Just done (2026-09-25, Fable, architect):**
- Task #142 design pass: spec posted on the issue as
  [revision 1](https://github.com/glunk-works/claude-workbench/issues/142#issuecomment-5833700944),
  then critic-reviewed before approval (`architect` + `security-critic` + `docs-consistency`,
  1 round each, read-only — a design-prose pass, not `/way-of-working:critic-gate`). Blocking
  finding: revision 1's "staged in the working tree, never believed" had no mechanism —
  every skill reads the working-tree `.ai/project.yml`. Fixed in
  [revision 2](https://github.com/glunk-works/claude-workbench/issues/142#issuecomment-5833883159):
  the interview's output is a pull request opened by resume step 0 itself, checkout
  restored; plus the 14 skill/agent default sites, the key-set derivation, and
  `migration_base: null` in the build PR. **Revision 2 approved by the human.**
- Plan anchor re-anchored to revision 2 as `spec_comment` (baseline re-verified `match`).

**Next:** task #142 — implement the approved design spec, revision 2
([comment 5833883159](https://github.com/glunk-works/claude-workbench/issues/142#issuecomment-5833883159)),
as one PR: `bin/schema-complete.sh` + `tests/schema-complete.test.sh` first, then resume
step 0 + the auto-start clause, the 14 default sites, `project-schema.md`, the two
`migration_base` readers, `invariants-check.sh`, `ci.yml`, `CLAUDE.md`, WB-D17 + Status,
the CHANGELOG migration line, and `migration_base: null` here. Green gate, then
`/way-of-working:critic-gate` (`architect` + `docs-consistency` + `security-critic`), then
`/way-of-working:ship`. On **sonnet** (`coder`) — the milestone's *Build* line.

**HITL Gate: NONE OPEN** — spec approved 2026-09-25. Next gates: the human picks critics at
`/way-of-working:critic-gate` and merges the build PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5)
