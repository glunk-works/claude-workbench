# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**; every build item is done.

**Just done (2026-10-06):**
- The #273 live smoke ran on the retry: resume's `--admin` offer for cursor-sync PR #308 printed
  `offer`, named Seuss27 before asking, and the `--admin --match-head-commit` merge succeeded.
  Items 1 and 2 are ticked on #273; that resume ran the 0.16.0 skill (loaded at session start),
  fixed with `/reload-plugins`.
- Item 3 (`/way-of-working:pr-checks` naming the identity in its READY (admin merge) verdict) is
  still open: #308 had merged by then, and 0.16.0's `pr-checks` has no identity check.
- The human confirmed the milestone 9 anchor (description sha `ec4c025e76a0`).
- Three local branches stay skipped by the resume prune (merged, but their tips are not what
  GitHub merged): `docs/sync-cursor-271-next-b`, `docs/sync-cursor-sprint-08-orchestrator-plan`,
  `fix/hook-exec-bit-214` — check for unpushed work.

**Next:** finish #273 item 3 on **sonnet** — observed, not built, so there is no `task #N` token
and a resume will wait for a "go". Run `/way-of-working:pr-checks` on this cursor-sync PR in a
session whose skill Base directory ends in `0.17.0`, confirm the READY (admin merge) verdict names
the identity (Seuss27, `current_user_can_bypass` true), tick item 3, record the date and PR number
on #273 and close it. #236 (Claude Code ≥ 2.1.259 on the loop host) is a separate human task.

**HITL Gate: NONE OPEN** — the next gate is the human's merge of this cursor-sync PR. No review
CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
