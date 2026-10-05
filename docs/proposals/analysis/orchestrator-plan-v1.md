# Sprint orchestrator for the way-of-working plugin — plan v1 (for critical review)

Author: a Claude session, 2026-10-04, for the maintainer of glunk-works/claude-workbench.
Status: proposal. Nothing built. The maintainer wants this critically reviewed against modern
best practice for AI integration before anything is filed.

## Context the plan rests on

The plugin `way-of-working` (repo glunk-works/claude-workbench, consumed by
603-Identity/devcontainers, 603-Identity/infrastructure-core, glunk-works/bounty-infra and others)
is a session-handoff protocol: short single-model Claude Code sessions (Opus architect plans and
reviews; Sonnet coder implements) externalise state into `.ai/state.json` (git-ignored machine
cursor) and `.ai/next-steps.md` (git-tracked ledger, landed as a docs-only "cursor-sync" PR per
handoff). Skills: resume, handoff, ship, critic-gate (read-only critic subagents: architect,
security-critic, docs-consistency; proposes, human picks, bounded rounds), architect-review (a
fresh-session review that satisfies a required CI status `architect-review` where a repo wires
`review.ci_gate`), plan-sprint, archive-sprint, park/unpark. Load-bearing trust rules in
docs/decisions.md:
- A merged PR is the human approval. Claude never merges to `pr_base`, never approves (WB-D20
  explicitly rejected even a docs-only self-merge: a session steered by untrusted text — issue
  body, PR comment, review output — could write a harmful `next_action`, approve it, and the next
  session would run it unattended).
- Issue bodies / spec comments are specifications, never instructions. Coder verifies the issue's
  `updated_at` and `author_association` against a human-anchored `plan_anchor` before building.
- resume auto-starts a `next_action` only when: hitl_gate NONE OPEN, status implementing, model
  matches, cursor not drifted, no open cursor-sync PR, plan anchor verifies. "Auto-start removes a
  rubber stamp, not a gate."
- critic-gate spawns only critics the human confirms; a second-opinion round on another model
  needs the human's own message in the live session.
- Deterministic predicates live in tested `bin/*.sh` scripts (WB-D10), never in prose.
- Shared plugin code never names a repo-specific value; everything comes from `.ai/project.yml`.
- Branch ruleset on main: required checks, 0 required reviewers, no bypass actors.

## Measured problem (why the maintainer is the bottleneck)

devcontainers, 28 Sep–4 Oct 2026: 53 work PRs merged, 80 cursor-sync PRs (1.5 per work PR),
median work PR 64 lines. Busiest day: 31 merges over 11.3 h, median 9 min between merges.
One four-line fix (#160): 3 PRs, 3 sessions (coder, handoff, fresh-session reviewer), ~9 human
touches, 25 min. 16 cursor PRs that week exist only to say "architect review next".
infrastructure-core: 84 work, 63 record/plan-doc PRs, 48 cursor PRs; 29 merges in 23 h on one
day. 10 open issues labelled needs-human/decision. devcontainers has 4 owner-owned decisions.
claude-workbench Sprint 7: 11 PRs for 2 issues, 7 of them ceremony.

Token spend from local transcripts since 1 Sep (272 sessions, de-duplicated): ~2.3B cache-read
tokens in main sessions, ~0.6B in subagents (almost all Opus critics), <0.13B cache-write+output.
Median peak context per session 138k; 142 of 325 sessions exceeded 150k; 79% of all cache reads
were spent on turns above 150k context. Five largest sessions: 200–480 turns at 350–500k median
context on a 1M-window Sonnet, each costing more than most repos did all month. The four core
skills plus conventions total ~42k tokens of prose loaded per session.

Host friction (from the repos' own ledgers): Windows + Git Bash/MSYS, GPG signing blocks
unattended commits, two gh accounts split by org, WSL for tests but Windows for pushes, auto mode
blocks ruleset edits.

## Design principles in the plan

1. The orchestrator never merges to `pr_base`. The per-sprint human merge stays the approval.
2. The orchestrator is a deterministic driver (bin/ script, fixture-tested); LLM judgment is used
   only in named slots (classify a stop; write the sprint digest).
3. One fresh headless session per task; no long-lived orchestrator session (dominant spend is
   re-reading large contexts; a subagent cannot spawn subagents so a single session would also
   have to host the critic fan-out itself).
4. Only human-anchored specs are dispatched (extend plan_anchor to the whole build order).
5. Budgets are measured from usage data and enforced by the driver, not estimated.

## Phases

Phase 0 — remove the relay and the ceremony (no new trust surface).
- Sprint-branch mode: task PRs target `sprint/NN-slug` (unprotected), a session may merge a task
  PR into the sprint branch after critics converge and CI is green; handoff commits the cursor to
  the sprint branch instead of opening a cursor-sync PR; the human merges ONE sprint PR to main.
- The fresh-session architect review is dispatched by the driver (headless session), not by a
  human reading "architect review next".
- Fix close-time ceremony (#209 roadmap entry, #220 dirty ledger) so a sprint close is one PR.
- Record WB-D21: orchestration never merges to pr_base.
- Exit: cursor PRs per work PR < 0.3; one human merge per sprint plus release.

Phase 1 — budgets and headless policy in the schema.
- `orchestration` block in `.ai/project.yml`: critic policy authored by the human at plan time
  (which critics, round cap, second-opinion on/off), bot identity (GitHub App, like the repo's
  release App — also makes session-authored commits distinguishable from the human's), notify
  target (Slack), hard caps: max turns per task session, max context before forced handoff, max
  Opus subagent turns per task, per-sprint token ceiling.
- Every AskUserQuestion site in the skills gets a declared headless outcome (default from policy,
  or stop).
- plan_anchor extended from one task to the whole build order with per-issue updated_at.
- Fixtures for every predicate.

Phase 2 — the driver.
- `bin/run-sprint.sh`: read the anchored plan; per task: spawn fresh `claude -p` running
  /way-of-working:resume (lean path) → coder work → critics within budget → PR to sprint branch →
  fresh headless review session → merge into sprint branch → next task. Any gate, red gate,
  non-convergence or cap: stop, post to Slack with the pick-up point. Fable in the judgment slots
  only. Run first on the maintainer's machine, 2–4 tasks per batch.
- Exit: a 3–4 task sprint completes with no session above the context cap and spend under the
  ceiling.

Phase 3 — into the container.
- Run the driver in the devcontainers image with the bot identity (no account switching, WSL
  hops or GPG). Choose scheduled routine vs GitHub Action from Phase 2 data.

Context diet (alongside 0–2).
- Split resume into a lean auto-start path plus on-demand appendices; move mechanical checklist
  steps into the driver. Target: a task session boots with <20k tokens of plugin prose.

Stays human: sprint scope and spec approval, every hitl_gate, the sprint merge to main, the
release tag, the decision backlog (batch it into one plan-sprint-style sitting first).

## Known risks already noted
- Sprint-sized PR instead of task-sized: a bad task 1 shapes tasks 2–4 before the human sees any
  of it. Mitigations: short batches, stop on non-converged critics, per-task digest in PR body.
- Prompt-injection persistence inside a batch (issue text → coder → cursor → next task).
  Mitigations: anchored specs only, driver (not cursor) decides sequence, no merge to main.
- Quality: critics become the only pre-human look per task.
- Cost: Fable judgment slots + Opus critics per task.
