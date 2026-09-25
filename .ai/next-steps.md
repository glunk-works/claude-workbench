# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **implementing** —
build-order steps 1 (#126), 2 (#113) and 3 (#125) shipped; step 4 (#150) next.

**Just done (2026-09-24/25, Sonnet):**
- Task #125 shipped as [PR #163](https://github.com/glunk-works/claude-workbench/pull/163)
  (merged) and issue closed: `/way-of-working:resume` step 4 now also verifies the default
  branch's own protection whenever `migration_base` is live (not gated on `{pr_base}`
  differing from it, which would miss a session resuming *on* the default branch
  mid-migration). `migration_base` and the ci_gate check name are read only from the default
  branch's own git-committed copy (`git fetch` + `git show`, matching
  `bin/review-base-anchor.sh`'s technique) — never this checkout's local copy, which is
  untrusted on the integration branch. Repo/default-branch identity is likewise derived from
  the checkout's own `origin` remote, not the local `{repo}` value.
- `/way-of-working:critic-gate` — `architect` + `security-critic`, run across **3 rounds**,
  converged. Round 1 found the `{pr_base}`-drift trigger's blind spot and required mechanized
  (`jq`) matching. Round 2 found the redesign still read `review.ci_gate` and the default
  branch's own name from the untrusted local copy — the same trust inversion the fix was
  meant to close, one layer down — fixed via the `origin`-derived resolution above. Round 3
  came back tightenings-only. No `models.second_opinion` round attempted (not set in
  `.ai/project.yml`).
- Filed [#162](https://github.com/glunk-works/claude-workbench/issues/162) (a pre-existing,
  unrelated bug the architect pass surfaced: `invariants-check.sh`'s reach-precedes-ruleset
  check for `/resume` never actually fires — its grep pattern doesn't tolerate `--paginate`),
  unmilestoned, for the next triage.

**Next:** task #150 — on **sonnet** (`coder`): give `archive-sprint`'s precondition 3 (the
roadmap status-row-and-commit-hash update, done before archiving) a branch procedure — either
mirror step 2's own branch-cut chain (`git fetch origin {pr_base} && git checkout {pr_base} &&
git merge --ff-only origin/{pr_base} && git checkout -b docs/<name>`) before making the
roadmap edit, or require that fix to ship as its own small PR against `{pr_base}` rather than
being committed on whatever branch the session happens to be standing on. Pick one shape and
say which in the PR — the issue's own *Shape* section is the design, no separate plan needed.
Run `/way-of-working:critic-gate` (`architect` + `docs-consistency` — not trust chain, per the
milestone's own critic-gate guidance) before `/way-of-working:ship`.

**HITL Gate: NONE OPEN** — next gate is the human's merge of #150's PR; no design decision is
pending (the issue's two shape options are the coder's own call, stated in the PR).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[issue #150](https://github.com/glunk-works/claude-workbench/issues/150)
