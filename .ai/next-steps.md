# Cursor — claude-workbench

**Now:** **Sprint 5** — [milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5),
*every config key is an explicit decision*. Status: **awaiting_review**.

**Just done (2026-09-25, Sonnet, coder):**
- Task #152 built: a new `/way-of-working:plan-sprint` skill (triage the backlog into
  milestones, mechanically) — `plugins/way-of-working/bin/plan-gather.sh` (the tested
  read-only gather step, four subcommands: `unmilestoned`, `milestones`, `titles`,
  `milestone-issues`), `plugins/way-of-working/skills/plan-sprint/SKILL.md`, `WB-D18` in
  `docs/decisions.md`, plus updates to `project-schema.md`, `workflow.md`,
  `milestone-close-line.sh`, `handoff`/`archive-sprint`/`resume` SKILL.md (pointer
  sentences and Milestone-close-line list entries), and the usual
  README/CLAUDE.md/marketplace.json/plugin.json mentions. Local green gate and all
  `tests/*.test.sh` suites pass, **except `tests/schema-complete.test.sh`, which hangs on
  this machine** — confirmed pre-existing and unrelated (reproduces on `main` too,
  untouched by this diff).
- The plan itself went through **three independent adversarial architect reviews before
  any code was written** (pre-build critiques), catching a `--jq` per-page sort bug, an
  empty denied-write fallback location, the wrong `gh` write channel, an `hitl_gate`
  overwrite risk, an unconstrained shell-injection surface, and several cross-fix
  interaction bugs.
- Critic gate on the built diff: `architect` + `security-critic` + `docs-consistency`, **5
  rounds (1 initial + 4 fix-and-re-run, the round cap), converged.** Real, fixed findings
  across rounds: a `-f`/`-F` bug that silently wrote the literal string `@<path>` instead of
  a file's contents (found independently by all three critics), a missing
  milestone-description template the docs claimed existed, two stale
  Milestone-close-line lists, a self-contradictory staged-script file-naming rule that
  could have let a write land on the wrong milestone with no error, a triage-comment
  build-order claim with no basis for existing-milestone placements, and a false safety
  claim about what quoting does and doesn't guard against. Final round came back
  tightenings-only from all three critics.
- Shipped as [PR #187](https://github.com/glunk-works/claude-workbench/pull/187)
  (`sprint/05-plan-sprint`, `248b7cb`) — **not yet merged**. CI green (coupling, invariants,
  lint, tests, zizmor).

**Next:** review and merge PR #187. Once merged, pick up the last milestone 5 task — #158
(container the PR-execution sandbox) — no other task remains in this milestone. On
**sonnet** (`coder`) for the build; a planning pass first if #158 needs one (its own issue
already flags one). Separately worth a look: `tests/schema-complete.test.sh` hangs locally
on this machine, pre-existing and unrelated to #152.

**HITL Gate: OPEN** — review and merge PR #187 (four independent critic re-runs converged
at the round cap; CI green), then decide on the plugin-pin bump and pick up #158.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5) ·
[PR #187](https://github.com/glunk-works/claude-workbench/pull/187)
