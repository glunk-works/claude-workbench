# Cursor — claude-workbench

**Now:** No sprint in flight (issue-driven, single-task PRs). Status: **implementing** —
[#66](https://github.com/glunk-works/claude-workbench/issues/66) is built and on
[PR #69](https://github.com/glunk-works/claude-workbench/pull/69), open and unmerged.

**Just done (2026-09-01):**
- **[#69](https://github.com/glunk-works/claude-workbench/pull/69) opened** (`3170794`) —
  `bin/entry-anchor.sh` + `tests/entry-anchor.test.sh`, the tested anchor-matcher `#66`
  asked for, wired into the `tests` CI job, plus the `ship` step-1 rule that consumes it and
  `WB-D11`.
- **`ship` no longer acts on exit `0`.** Every branch keeps both sides; the predicate's
  answer only *ranks* the removals reported to the human. The issue asked for per-entry
  **resolution** and got per-entry **ranking**, and step-1 prose grew where `#66` said
  shrink — a deliberate reduction, recorded in `WB-D11` and the CHANGELOG rather than
  papered over. Both critics said close `#66` on this PR and file a follow-up for the prose.
- **The rule was wrong four times inside the critic gate**, each in a new direction and each
  a *citation* answering `0` — markup on a wrapped continuation line, the same inside a
  blockquote, a nested list item, a fence closed early. It is now positional: an entry
  marker at **column 0, outside every tracked container**. `WB-D11` carries the sequence.
- **`archive-sprint` corrected** — it promised `ship`'s rule *prevents* a compaction's
  entries being resurrected. Nothing mechanical does; the rule surfaces and a human decides.
  That claim sat one file outside the diff.

**Critic gate: 8 rounds, `architect` + `docs-consistency`. Cap (2) reached at round 3; the
human authorized every round past it.** Round 8 returned *"nothing here changes what the
operator does"* (architect) and *"ship it"* (docs-consistency) — the first converged round.
Severity fell only after the exit-`0` wiring was removed; before that, every round found a
new unrecoverable-direction false match.

**Next:** Finish the **owed mutation sweep** — the check `WB-D11` prescribes and the suite
header now instructs. It ran through the comment scanner only; it is targeted-only over the
match loop and `END`, and a fifth unpinned guard turned up in the part that *was* swept, so
"four unpinned, two reasons" is measured in part and asserted in part. `.ai/state.json`'s
`next_action` carries the full procedure and stopping rule. Then critic-gate round 9 on #69.
Model: **opus** — it ends in a judgment about what the record may claim.

**HITL Gate: NONE OPEN** for that next action. Two decisions sit with the human: whether to
merge #69, and whether closing #66 on it is right given the recorded scope reduction.
[#61](https://github.com/glunk-works/claude-workbench/issues/61) and
[#62](https://github.com/glunk-works/claude-workbench/issues/62) remain open and unchanged.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D11` is this work's record; no
sprint plan — `sprints_dir` empty by design) ·
[#69](https://github.com/glunk-works/claude-workbench/pull/69) ·
[#66](https://github.com/glunk-works/claude-workbench/issues/66)
