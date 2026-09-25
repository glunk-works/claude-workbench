# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **done** — build-order
steps 1-5 (#126, #113, #125, #150, #153) all shipped and merged; milestone 4 has 0 open issues.
Not yet archived.

**Just done (2026-09-25, Sonnet):**
- Task #153 shipped as [PR #167](https://github.com/glunk-works/claude-workbench/pull/167)
  (merged): `archive-sprint`'s milestone-close outcome now reaches a fixed, greppable
  `**Milestone close:**` line in `.ai/next-steps.md`, written or preserved by whichever of
  `archive-sprint`'s Seed step, its own unpark-branch note, `park-sprint`'s seed override,
  `handoff`'s carry-forward rule, or `unpark-sprint`'s Restore step last touched the ledger.
  `bin/milestone-close-line.sh` is the new deterministic predicate; `/way-of-working:resume`
  echoes the recorded outcome into its pick-up summary whenever `present`, and flags the gap
  explicitly whenever `missing`.
- Also set `models.second_opinion: fable` in `.ai/project.yml` (bundled into the same PR; no
  second-opinion round was run against this PR's own critic-gate pass — the config was added
  after that pass had already converged).
- `/way-of-working:critic-gate` — `architect` + `docs-consistency`, run across **3 rounds**,
  converged. Round 1 found the check's applicability claim was too narrow (`park-sprint` and a
  within-planning `handoff` both produce `planning` cursors it would falsely flag `missing`),
  `resume` staying silent on a recorded blocked/failed-read/pending outcome, an
  empty-value/bulleted-line gap in the grep, a stale README `bin/` listing, and a
  non-executable git mode on this `core.filemode=false` checkout — all fixed. Round 2 found the
  fix itself could leave two `Milestone close:` lines in a restored ledger — fixed by making
  `archive-sprint`'s unpark branch replace rather than append, and conditioning `handoff`'s
  carry-forward on the new `sprint_status` also being `planning`. Round 3 (the gate's 2-round
  cap) found the replace fix could discard a still-unresolved outcome inherited by a sprint
  that never itself closed anything — fixed with explicit human sign-off past the cap (no
  further critic re-spawn), `park-sprint` now carries an existing line forward verbatim and
  only writes the placeholder when none exists.

**Next:** run `/way-of-working:archive-sprint` — on **opus** (`architect`): sprint-03
(milestone 4) is complete (0 open issues); close it out and plan sprint-04.

**HITL Gate: NONE OPEN** — no design decision is pending; the next action is archiving a
sprint that has already passed each build-order task's own review/merge.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4)
