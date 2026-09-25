# Cursor — claude-workbench

**Now:** **Sprint 5** — [milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5),
*every config key is an explicit decision*. Status: **awaiting_review**.

**Just done (2026-09-25, Sonnet, coder):**
- Task #142 built: `bin/schema-complete.sh` (the `.ai/project.yml` completeness checker),
  `/way-of-working:resume`'s new *Ensure the schema is complete* step (interview → completion
  PR, never a believed working-tree value), the `migration_base` absent-vs-null fix in both
  readers, the 14 default-removal prose sites, `project-schema.md`, two new
  `scripts/invariants-check.sh` assertions, and `WB-D17` in `docs/decisions.md`. Local green
  gate and all 12 `tests/*.test.sh` suites pass.
- Critic gate: `architect` + `security-critic` + `docs-consistency`, 5 rounds (1 initial + 4
  fix-and-re-run, the round cap), converged. Real, fixed findings across rounds: a
  shell-metacharacter gap in the four routing-key shape checks, a `..` path-traversal bypass
  in the owner/name check (confirmed live against the real GitHub API), a YAML type-tag gap,
  a regression in `review-base-anchor.sh`'s human override for an absent `migration_base`,
  and a git branch-tracking bug in the completion-PR mechanism's happy path — the last one
  independently reproduced and verified before landing. Offered one more round on
  `models.second_opinion` (`fable`) per the round-cap rule; the human declined it, finalize
  as-is.
- Shipped as [PR #185](https://github.com/glunk-works/claude-workbench/pull/185)
  (`sprint/05-schema-complete`, `23c43b2`) — **not yet merged**.

**Next:** review and merge PR #185. Once merged, pick the next milestone 5 task — #158
(container the PR-execution sandbox) or #152 (add a plan-sprint skill) — no ordering between
them; a human call, not a mechanical one. On **sonnet** (`coder`) for the build once a task
is picked; a planning pass first if either needs one.

**HITL Gate: OPEN** — review and merge PR #185, then pick #158 or #152.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5) ·
[PR #185](https://github.com/glunk-works/claude-workbench/pull/185)
