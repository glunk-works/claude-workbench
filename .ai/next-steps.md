# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **implementing** —
build-order steps 1-4 (#126, #113, #125, #150) shipped; step 5 (#153) next.

**Just done (2026-09-25, Sonnet):**
- Task #150 shipped as [PR #165](https://github.com/glunk-works/claude-workbench/pull/165)
  (open, awaiting merge): `archive-sprint`'s precondition 3 now checks `{roadmap}` against
  `origin/{pr_base}` after a fetch (never the working tree), and — if the status row is
  missing — cuts a fresh branch from `{pr_base}` (mirroring the *Compact the deep record*
  step's own chain, same failure handling and tracked-clean check), makes the edit there,
  ships it as its own PR, and stops until that PR merges. The *Compact the deep record*
  step's own content test was updated to read the same `origin/{pr_base}` tree.
- `/way-of-working:critic-gate` — `architect` + `docs-consistency`, run across **3 rounds**,
  converged. Round 1 found a wrong attribution (the stale branch is `/way-of-working:handoff`'s,
  not `/way-of-working:resume`'s), missing safety rails cloned from the Compact step, and the
  "unmet until merged" rule not actually enforced on a re-run (fixed by the origin-based
  check). Round 2 fixed those, surfaced one newly-introduced gap (the Compact step's content
  test going out of sync with precondition 3's new check) plus a tracked-clean-check
  exemption bug (both fixed), and its own re-check found one more real bug — a failed-commit
  path that could land an edit on `{pr_base}` — fixed with explicit human sign-off past the
  gate's 2-round cap (no further critic re-spawn needed, the finding was already precisely
  diagnosed). No `models.second_opinion` round attempted (not set in `.ai/project.yml`).
- This session also pruned `docs/sync-cursor-125-next` and
  `sprint/03-migration-default-branch-check`, and confirmed the branch-protection ruleset
  healthy (4 rule types, 3 required checks).
- Note: this docs-only cursor sync is cut from `{pr_base}`, which does not yet carry
  [PR #164](https://github.com/glunk-works/claude-workbench/pull/164) (the prior session's
  own cursor sync, still open) — this file is regenerated wholesale, not patched, so that is
  expected; PR #164 and this PR may merge in either order.

**Next:** task #153 — on **sonnet** (`coder`): `archive-sprint`'s milestone-close outcome
reaches neither the ledger nor the gate (second occurrence after #128). Give the seeded
`.ai/next-steps.md` a fixed `Milestone close: <outcome>` line, written unconditionally by the
Seed step (`no milestone to close` is a legal value); add a `bin/` check (alongside
`cursor-drift.sh` / `ai-cursor-banner.sh`) that flags a `planning`-status cursor under
`planning.kind: github_milestones` whose `next-steps.md` lacks that line, so the next
`resume` surfaces it instead of reading `NONE OPEN` as clean; add a `tests/*.test.sh` fixture
for the missing-line case. The issue's own *Shape* section is the design — no separate plan
needed. Run `/way-of-working:critic-gate` (`architect` + `docs-consistency` — not trust
chain, per the milestone's own critic-gate guidance) before `/way-of-working:ship`.

**HITL Gate: NONE OPEN** — next gate is the human's merge of
[#165](https://github.com/glunk-works/claude-workbench/pull/165) (#150's PR) and, after #153
ships, the human's merge of its PR; no design decision is pending (the issue's own Shape
section is the design).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[issue #153](https://github.com/glunk-works/claude-workbench/issues/153)
