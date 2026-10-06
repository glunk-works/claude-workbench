# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**; every build item is done.

**Just done (2026-10-06):**
- The first #273 smoke attempt missed: its cursor-sync PR (#307) was merged on GitHub before the
  next resume ran, so `cursor-sync-pr.sh` printed `none` and no `--admin` offer was ever shown.
  This is a retry with a fresh cursor-sync PR. #273 and #236 stay open.
- Earlier today: #303 shipped, v0.17.0 released (PRs #305, #306), no critic pass (version and
  changelog only).
- Three local branches stay skipped by the resume prune (merged, but their tips are not what
  GitHub merged): `docs/sync-cursor-271-next-b`, `docs/sync-cursor-sprint-08-orchestrator-plan`,
  `fix/hook-exec-bit-214` — check for unpushed work.

**Next:** the live smoke for #273 on **sonnet** — observed, not built, so there is no `task #N`
token and a resume will wait for a "go". **Do NOT merge this cursor-sync PR on GitHub — leave it
open**: the next `/way-of-working:resume` must be the one to offer the `--admin` merge. At that
resume, tick #273's checklist as it offers the merge, run `/way-of-working:pr-checks` on the PR for
the identity in its READY (admin merge) verdict, record the date and PR number in #273 and close
it. #236 (Claude Code ≥ 2.1.259 on the loop host) is a separate human task.

**HITL Gate: OPEN** — first anchor for milestone 9, description sha `ec4c025e76a0`; no baseline
this session, so the human confirms it at the next resume (the same sitting as the merge offer —
the #273 smoke). No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
