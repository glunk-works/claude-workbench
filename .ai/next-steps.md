# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Status: **implementing**, on [#43](https://github.com/glunk-works/claude-workbench/issues/43).

**Just done (2026-08-13):**
- **#28's taxonomy half decided and #28 closed** — *partial go*, answering its own review
  item 15. Two of the eight decisions were defects with a live cost and were executed;
  decisions 2, 4, 5, 6 and 7 were declined on the record with the measurement behind them.
- **Decision 1 shipped** — PR **#42** (`fe41adf`). The machine-namespace rule said *namespace
  by the emitting system* and illustrated it with the **repo** name. Fixing the example alone
  would have left [`project-schema.md`](../plugins/way-of-working/reference/project-schema.md)
  teaching the wrong rule in three places, so all three surfaces moved together plus
  `/way-of-working:ship` step 6. No emitted label changed.
- **Decision 3's separator half executed** — `bounty-infra`'s `severity:high|medium` renamed
  in place to `severity/*`; all 12 assignments and both colours preserved. It was the org's
  only namespace using `:`.
- **The bedrock `docs`/`area/docs` "axis collision" was dropped** — the snapshot showed the
  two axes are orthogonal, not colliding: 9 items carry both, and every `area/docs`-only item
  is `chore` + `area/docs`. Folding them would have stripped the type axis from 13 items.
  #28 called it a collision from the counts alone, without checking overlap.
- **Three follow-ups filed** rather than left in a closed issue's comment: **#43**
  (coupling-check misses 4 of 8 org repos incl. this one), **#44** (secret-scanning validity
  checks off on all 8 — one PATCH each), **#45** (code scanning absent on 7 of 8 — a
  decision, not a task).
- `/way-of-working:critic-gate` ran on #42 (`docs-consistency`, human trimmed 3 proposals to
  1). **Three rounds, converged on tightenings-only — the stopping condition fired, not the
  cap.** Round 2's findings were *more severe* than round 1's, because the round-1 fixes
  introduced them: a dropped word made `{repo}` expand to `owner/name`, emitting
  `owner/name/*`. Shipping after round 1 would have released a malformed namespace to every
  consuming repo.

**Next:** Close **#43** — add the five unguarded literals to `TIER2` in
[`scripts/coupling-check.sh`](../scripts/coupling-check.sh) and rewrite that tier's comment
so its membership rule is stated rather than listed. Verify by deliberate regression (plant
a literal, confirm the gate fails, revert). Ship as `chore(ci)`. **Coder/sonnet** — this is
mechanical. Leave #43's *derive TIER2 from `gh repo list`* question alone; that is an opus
call, noted in the PR body, not started here.

**The backlog order is a recommendation, not a ratified decision.** #43 is first because it
is the smallest and it is a live hole in a gate meant to be mechanical. Redirect at resume if
**#44** (cheap, but the human must run the `PATCH` calls — the harness classifier declines
`gh api` writes to org repos) or **#45** should come first.

**HITL Gate: NONE OPEN.** Next gate: #43's derive-vs-hand-maintain question, and #45's
"which repos can CodeQL actually analyse" — both decisions for opus, neither to be started
as a task. No `review.ci_gate` in this repo.

**Pointers:** [`docs/decisions.md`](../docs/decisions.md) (roadmap/decisions of record) ·
[#43](https://github.com/glunk-works/claude-workbench/issues/43) ·
[#44](https://github.com/glunk-works/claude-workbench/issues/44) ·
[#45](https://github.com/glunk-works/claude-workbench/issues/45) ·
[#28](https://github.com/glunk-works/claude-workbench/issues/28) (closed, carries the full
disposition and the measurement)
