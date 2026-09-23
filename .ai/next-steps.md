# Cursor — claude-workbench

**Now:** **Sprint 1** — [milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1),
*stabilize v0.8.0 and close the live-observed gaps*. Status: **awaiting_review** — milestone
1 has 0 open issues; the closing PR is open, HITL Gate is open on its merge.

**Just done (2026-09-23):**
- Confirmed via `gh` (not assumed) that both conditions the previous HITL Gate named had
  landed: [PR #119](https://github.com/glunk-works/claude-workbench/pull/119) merged, and
  `release.yml` was dispatched dry-run-first-then-real, cutting `v0.9.0` at `aa6793f`
  (published, non-draft, ancestor of `main`).
- Pruned 3 squash-merged local branches (`chore/release-0.9.0`,
  `docs/sync-cursor-99-shipped-release-next`, `docs/sync-cursor-101-release-open`) and
  fast-forwarded local `main`.
- Ruleset check: healthy (4 rule types, 3 required checks).
- Opened this repo's own pin-bump PR, `d8982e2`,
  [PR #121](https://github.com/glunk-works/claude-workbench/pull/121) (bumps
  `.claude/settings.json`'s plugin ref to `v0.9.0`), per
  [PR #102](https://github.com/glunk-works/claude-workbench/pull/102)'s precedent.
  Docs/config-only — touches none of `code_paths`, so no critic-gate pass; local green
  gate (lint, coupling, invariants) ran clean.

**Next:** Once the human merges [PR #121](https://github.com/glunk-works/claude-workbench/pull/121),
Sprint 1 is complete. Run `/way-of-working:archive-sprint` to retire sprint-01 and advance
the cursor to **Sprint 2** ([milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files* — 4 open issues, including #61 and #104). Then begin Sprint 2
planning on **opus** (`architect`). **Do not start #104 unattended** — it changes the
`protected-release-tags` ruleset's security surface.

**HITL Gate: OPEN.** The human must merge
[PR #121](https://github.com/glunk-works/claude-workbench/pull/121), which closes Sprint 1.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D12`) ·
[milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[open issues by milestone](https://github.com/glunk-works/claude-workbench/milestones)
