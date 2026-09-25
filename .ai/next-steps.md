# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **implementing** —
build-order steps 1 (#126) and 2 (#113) shipped; step 3 (#125) next.

**Just done (2026-09-24/25, Sonnet):**
- Task #113 shipped as [PR #160](https://github.com/glunk-works/claude-workbench/pull/160)
  (merged) and issue closed: `bin/review-sandbox.sh` (`trust`/`make`/`run`/`destroy`)
  replaces architect-review's shared-`.git` `git worktree add` step with an isolated
  PR-execution sandbox; `tests/review-sandbox.test.sh` fixtures it; `skills/architect-review/
  SKILL.md`, the three agent files' `git worktree add` exemption, `reference/workflow.md`,
  `docs/decisions.md` (new `WB-D13`), `CLAUDE.md` and `README.md` updated to match.
- `/way-of-working:critic-gate` — `architect` + `security-critic` + `docs-consistency`, run
  across **6 rounds** (well past the normal 2-round cap, each round explicitly authorized and
  scoped to verifying the previous round's own fixes). Human called it after round 6, not a
  clean converge: round 6 found and fixed a real disclosure gap (the origin-redirect
  completeness note only named `review-sandbox.sh`'s own trust read, missing that
  `bin/review-base-anchor.sh` resolves `origin` the same way, earlier and worse — verified
  live) plus wording nits; not independently re-verified by a round 7. Earlier rounds found
  and fixed two real functional bugs, both reproduced live: a wall-clock-bypass hang when
  `run`'s wrapped command backgrounds a detached child holding its output pipe open (round
  3), and a broken kill mechanism — `kill -TERM -- "-$child"`'s `--` is rejected by dash,
  silently swallowed, making the leftover-process kill a no-op on every real Linux host
  (round 5, fix independently verified on WSL Ubuntu: 0 fails/0 skips, up from failing). No
  `models.second_opinion` round attempted (not set in `.ai/project.yml`). Full round-by-round
  record in `docs/decisions.md`'s `WB-D13`.
- Filed [#158](https://github.com/glunk-works/claude-workbench/issues/158) (the container
  option, B) into Sprint 5's build order.

**Next:** task #125 — on **sonnet** (`coder`): verify the default branch's protection during
a migration in `/way-of-working:resume` step 4. When `{pr_base}` is not the repo's default
branch, also confirm the default branch carries a ruleset requiring `pull_request` and, where
`{review.ci_gate}` is set, `required_status_checks` including `{review.ci_gate.check}` —
reported on the same single line, reusing step 4's existing reach check. Fix shape is fully
specified on the issue; no separate plan needed. Run `/way-of-working:critic-gate` (`architect`
+ `security-critic` — trust-chain work, per the milestone's own critic-gate guidance) before
`/way-of-working:ship`.

**HITL Gate: OPEN** — the `plan_anchor` baseline could not be verified this session:
`/way-of-working:resume` short-circuited past the anchor check both this session and the one
before it (an unrelated gate was already open each time), so `plan-anchor.sh verify` never
actually ran against the prior (#113) anchor. Per the mechanical re-anchor rule, an unverified
baseline is treated as no baseline — a fresh anchor was written for #125 (same milestone
description hash as #113's, so the description itself hasn't changed, but that wasn't
established via the formal verify chain). Confirm and clear before the next resume auto-starts
#125.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[issue #125](https://github.com/glunk-works/claude-workbench/issues/125)
