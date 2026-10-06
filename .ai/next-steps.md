# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**; every build item is done.

**Just done (2026-10-06):**
- #303 built and shipped: v0.17.0 released (PR #305, tag `v0.17.0`), the changelog's #283 pin
  warning rewritten, the `orchestration` Migration line carried; this repo's pin bumped (PR #306,
  `edc21d0`) and the plugin updated and mirrored onto both drive-letter casings. #303 closed.
  Version and changelog only, so no critic pass.
- Three local branches stay skipped by the resume prune (merged, but their tips are not what
  GitHub merged): `docs/sync-cursor-271-next-b`, `docs/sync-cursor-sprint-08-orchestrator-plan`,
  `fix/hook-exec-bit-214` — check for unpushed work.

**Next:** the live smoke for #273 on **sonnet** — observed, not built, so there is no `task #N`
token and a resume will wait for a "go". Leave this cursor-sync PR open; at the next
`/way-of-working:resume`, tick #273's checklist as that resume offers the `--admin` merge, run
`/way-of-working:pr-checks` on the PR for the identity in its READY (admin merge) verdict, record
the date and PR number in #273 and close it. #236 (Claude Code ≥ 2.1.259 on the loop host) is a
separate human task.

**HITL Gate: NONE OPEN** — next gate: the human confirmation of that merge offer (the #273
smoke); no review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
