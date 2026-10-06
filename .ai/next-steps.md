# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #295 built and merged as PR #300 (`e5b7a4f`): `review-step.sh decide` takes `login` and
  `loop_identity` and prints `none`
  ahead of every other verdict when they match (case and one trailing `[bot]` folded, as
  `plan-anchor.sh` does; `-` = null = no guard; a malformed value exits 2). Resume reads the value
  from the default branch's copy and treats an absent or malformed value as a failed read. Critic
  pass (architect, security-critic, docs-consistency): 2 rounds; round 2's one substantive finding
  (a quoted `"-"` colliding with the null sentinel) was fixed and hand-tested, not re-run through a
  critic; second-opinion round not run.
- Unverified: `gh api user` may be refused for an App installation token, which would make the
  guard mainly a machine-user control.
- Three local branches were skipped by the resume prune (merged, but their tips are not what
  GitHub merged): `docs/sync-cursor-271-next-b`, `docs/sync-cursor-sprint-08-orchestrator-plan`,
  `fix/hook-exec-bit-214` — check for unpushed work.

**Next:** task #283 — build the WB-D22 residual on **sonnet** (`coder`): the pinned review
session starts from the base branch, not the PR's tree (spec in issue #283). Then
`/way-of-working:critic-gate` (architect, security-critic, plus docs-consistency for skill prose)
and `/way-of-working:ship` one PR closing #283. After it: #236, a human task on the loop host.

**HITL Gate: NONE OPEN** — next gate: the human merge of #283's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
