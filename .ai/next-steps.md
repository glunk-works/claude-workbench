# Cursor — claude-workbench

**Now:** **Sprint 5** — [milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5),
*every config key is an explicit decision*. Status: **planning**.

**Just done (2026-09-28, resync + pre-build design review, no code diff):**
- Confirmed the cursor had drifted behind reality: task #152's
  [PR #187](https://github.com/glunk-works/claude-workbench/pull/187), its cursor-sync
  [PR #188](https://github.com/glunk-works/claude-workbench/pull/188), the
  [v0.13.0 release](https://github.com/glunk-works/claude-workbench/pull/190), and this
  repo's own [pin bump](https://github.com/glunk-works/claude-workbench/pull/191) were all
  merged without the ledger being resynced in between. Milestone 5 has exactly one open
  issue left: **#158**.
- Ran a pre-build design review on #158: three independent architect (opus) reviews, plus
  one fable second-opinion review (confirmed via `spawn-model.sh`) that checked their
  convergence rather than re-deriving from scratch. All four posted on the issue.
- Consolidated the four reviews into **13 ranked open design decisions, each with a
  recommendation**, posted as
  [issue #158, comment](https://github.com/glunk-works/claude-workbench/issues/158#issuecomment-5868070762).
  None found the issue's one-paragraph recipe buildable as written.

**Next:** work through the 13 open decisions on #158 with the human, **one question at a
time** — each already has a recommendation. Get the human's call on each (starting with
#1, the scope question nearly everything else depends on: does a non-null
`review.sandbox.image` route *every* execution through the container, or only untrusted
PRs?), then post an anchored spec comment on #158 recording the answers before any build
starts. On **opus** (`architect`).

**HITL Gate: OPEN** — 13 design decisions need a human call before #158 is buildable.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5) ·
[issue #158](https://github.com/glunk-works/claude-workbench/issues/158)
