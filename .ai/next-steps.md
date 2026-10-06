# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #232 built and merged as PR #290 (`0cc364f`), closing #232: `plan-sprint` proposes and the
  human confirms a per-issue `depends_on` marker, recorded as a `[depends_on: …]` token in a new
  milestone's Build order list; new `bin/plan-depends.sh` reads it back and reads anything
  unconfirmed or doubtful as `all-earlier`, with fixtures in CI.
- Critic pass (architect, security-critic, docs-consistency): 2 rounds, converged — round 2
  returned wording tightenings only, all swept; no second-opinion round.
- The sprint's plan anchor was re-taken for #233 (baseline verified `match`).

**Next:** task #233 — build `resume`'s driver-lock auto-start condition on **sonnet**
(`coder`): a fixture-tested `bin/` predicate (like `cursor-drift.sh`) reporting present /
absent / unreadable for the orchestrator driver's lock file; where resume finds the driver
directory is decided and documented (the driver's config, never a literal in shared plugin code
— `coupling-check.sh`); resume waits on anything but absent and names it in the pick-up line.
Then `/way-of-working:critic-gate` (architect, security-critic, docs-consistency) and
`/way-of-working:ship` one PR closing #233.

**HITL Gate: NONE OPEN** — next gate: the human merge of #233's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
