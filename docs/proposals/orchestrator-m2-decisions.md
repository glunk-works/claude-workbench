# Orchestrator milestone 2: decisions, data and brief for planning

Written 2026-10-06 after milestone 9 (orchestrator milestone 1, `v0.17.0`) closed. Input to
`/way-of-working:plan-sprint`. Plan v9 (`sprint-orchestrator-plan-v9.md`) stays the source of
design; this file records what was decided or recommended since, and why.

**Status key.** *Maintainer* = stated or chosen by the maintainer. *Recommended* = advice from
architect, research or session analysis, **not yet confirmed**. The planning session confirms every
*Recommended* item with the maintainer before turning it into issues. The advisory reports were
model output and their citations were not all re-read; verify a claim before it goes into shipped prose.

## Priorities (maintainer)

1. Quality. 2. Traceability and ease of recovery: one PR and one commit per task; a single PR for a
sprint was rejected. 3. Convenience and speed. 4. Minimise API spend: use the subscription, and allow
small API tests to learn the real cost. Data-driven: measure first, then decide. The loop should
shrink the maintainer's own work; the human merge stays the only approval.

## Decisions

| # | Question | Status | Outcome |
|---|---|---|---|
| 1 | Cut of steps 4-6 | Maintainer (2026-10-06) | Three milestones by what each proves (below), after a plan-sync PR |
| 2 | Fewer PRs for dependent tasks | Maintainer (measure first; confirmed 2026-10-06) | Keep one PR per task. Waves of independent PRs, a human-run batch-merge helper, opt-in merge-triggered dispatch. Sprint branch and driver merge stay off until data justifies them |
| 3 | Model map under the loop | Maintainer (2026-10-06) | Keep `models` literal (judgment slots on Opus). Smoke-test `--model fable` headless in M2a; compare in M2c using a scratch `project.yml`, no new key. Fable routing is case by case, not blanket: `models.architect` stays Opus |
| 4 | Subscription or API key | Maintainer (subscription first; confirmed 2026-10-06) | Subscription for the loop. M2a is credential-agnostic (env name and path from driver config; prefix grep and Read deny cover both). Small bounded API test to measure cost. Decide again at M2c from M2b's audit-line costs |
| 5 | Driver location | Maintainer (2026-10-06) | A new directory under `scripts/`: already in `code_paths` (critic floor) and in `human_only_paths` (the loop cannot edit its own driver); off every adopter's PATH; outside the coupling gate. Departs from plan text `bin/run-sprint.sh`; needs a WB-D |
| 6 | #296 scope | Maintainer (2026-10-06) | Hard-stop diffs touching the trust predicates (`plan-anchor.sh`, `review-sandbox.sh`, `review-step.sh`, `driver-lock.sh`, `blocked-state.sh`, `cursor-sync-pr.sh`, `spawn-model.sh`, `review-base-anchor.sh`) and their `tests/` fixtures; not all of `tests/` |
| 7 | Baseline | Maintainer (2026-10-06) | A read-only script derives PR-flow numbers from GitHub history; record only the enable date and window per repo, never the numbers. Adoption step: run it before enabling the loop on a repo |
| 8 | M2c metric | Maintainer (2026-10-06) | Close M2c on deliverables; track the two-week "no limit hit" metric as a dated follow-up issue |
| 9 | Restrict-updates ruleset on other repos | Maintainer (2026-10-06) | The loop refuses to dispatch on a repo whose default-branch rules lack the `update` rule; the first wave is claude-workbench only |

## Cut (confirmed 2026-10-06, option C: split by proof)

- **M2a, loop container proven, driver core hermetic** (milestone: *Orchestrator M2a: loop container proven*). Assemble the whole plan § 7.3 container and
  attack it; close the plan's § 9 open live items; hermetic driver core with stub `docker`/`gh`
  fixtures (tree-copy then check then commit, the human-only-path check with renames, the critic
  staging bundle, preflight evaluators, result parsing and recovery); minimal per-task limits, kill
  file and recovery (the first dispatch needs them, though § 7.4 files them under step 5); #296;
  `--model fable` smoke test; the baseline script. Build the hermetic code beside the container proof.
- **M2b, first waves on claude-workbench** (milestone: *Orchestrator M2b: first waves on claude-workbench*). Live App preflight, one task per away-block, then a small
  wave; the batch-merge helper; merge-triggered dispatch (opt-in). Exit metric: human minutes per work PR
  not above baseline.
- **M2c, governor and eval** (milestone: *Orchestrator M2c: governor and eval*). Day caps, window and away-block, reserve, scoped lock decision, the
  20-50 task eval set (record resolved model ids per session); subscription-vs-key and Fable-vs-Opus
  comparisons.

Size honestly: milestone 1 was planned at five issues and closed 14.

## Data (PR flow, merged PRs, last 60 days, 2026-10-06; proxies, not true dependency counts)

| Repo | Work PRs | Cursor PRs per work PR | Median open to merge | Likely-dependent share (6h / 24h) | Wave overlap risk |
|---|---|---|---|---|---|
| claude-workbench | 128 | 0.6 | 6 min | 21% / 28% | 0% |
| 603-Identity/devcontainers | 89 | 1.3 | 18 min | 24% / 35% | 2% |
| 603-Identity/infrastructure-core | 161 | 0.4 | 12 min | 26% / 36% | 4% |
| glunk-works/loop-orchestrator | 1 | n/a | n/a | n/a | n/a (2 merged PRs, unusable) |

- "Likely dependent" = a work PR created within the window after another merged, touching the same
  files, with files touched by 10% or more of PRs and the cursor ledger, changelog and lockfiles
  excluded. Without that exclusion the figure read 64-78%; explicit "needs #N" markers in PR bodies
  appear in about one PR per repo and are unusable.
- A hand count of this repo's last three milestones (explicit build-order markers only) gave 5 of 23
  issues (22%); longest chain three links; about 3 of ~20 build tasks were loop-buildable dependents.
- The cursor-sync PR is the larger PR-count lever: 31-57% of merged PRs across the three busy repos (57% in devcontainers).
  Step 1 (`v0.17.0`) addresses it; whether devcontainers has adopted it is unchecked, and it decides
  whether 1.3 is a valid "before" baseline.
- Switch to stacking if loop-buildable dependents exceed roughly 30% or chains of three or more appear
  in most sprints (an architect's threshold, not the plan's).

## Alternatives weighed

- **Sprint branch, commit per task, one PR:** rejected by the maintainer (loses per-task
  traceability and revert). Architect findings: contradicts principle 1 and § 8.3; `sprint/*` is
  unprotected today (both rulesets cover only `main`); squash collapses K commits to one on `main`;
  unreviewed code persists across the batch.
- **Driver merge into a throwaway integration branch:** rejected for now; the App already holds
  write access repo-wide, so only driver code would stop it, against principle 2.
- **Stacked PRs (depth 1 or 2):** conditional stage 2. GitHub's native stacked PRs are a public
  preview (changelog 2026-07-30) with an acknowledged approvals bug when merging a stack
  (github/gh-stack discussion 212); pilot on a scratch repo first. A merged parent's deleted branch
  retargets the child PR but does not rebase it.
- **Merge queue:** public org repos or Enterprise Cloud only; it merges as GitHub itself, which plan
  § 8.5 made a precondition. Not pursued.
- **Ralph-style loops** (fresh context per iteration, state in files): the plan already does this
  (principle 4, state in `.ai/` and GitHub). Not researched in depth here.

## Confirmed with the maintainer (2026-10-06)

1. The three-milestone cut and its names (above), by content, not "Sprint N". Confirmed.
2. Driver under `scripts/`, with a WB-D for the departure from `bin/`. Confirmed.
3. #296 scope as above. Confirmed.
4. Baseline script and the adoption step. Confirmed.
5. Fable routing for architect work: case by case, not blanket; `models` unchanged.
6. The subscription terms for headless `-p`, and whether Fable is available through the API: unknown; an M2a verification issue settles both before M2b's first live dispatch. Answered 2026-10-07 (#316), see below: Fable is on the API; the terms are unsettled.

## Platform facts verified for item 6 (#316, 2026-10-07)

Verified by a sonnet session on the maintainer's host (CLI 2.1.289, logged in with `claude.ai`
OAuth, no `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` set). Sources are the pages as fetched
that day.

1. **Subscription terms for unattended `claude -p`: not settled by the published text; the
   maintainer accepted the risk (below).** Nothing says `-p` is forbidden and nothing says unattended driver-started
   `-p` is permitted.
   - For: `headless.md` documents `claude -p` as a normal mode and says only `--bare` skips the
     subscription login. `legal-and-compliance.md` says OAuth "is designed to support ordinary use
     of Claude Code", and that an end user may sign in to the unmodified binary with their own
     subscription.
   - Against, or at least a risk: Consumer Terms § 3 (effective 2025-10-08) bars access "through
     automated or non-human means, whether through a bot, script, or otherwise", except via an API
     key "or where we otherwise explicitly permit it". `legal-and-compliance.md` also says the
     advertised Pro and Max limits "assume ordinary, individual usage of Claude Code and the Agent
     SDK", and that developers building products should use API keys. The loop is the maintainer's
     own use, not a product offered to others, which the second sentence of that page does not
     address either way.
   - Sources: <https://code.claude.com/docs/en/headless.md>,
     <https://code.claude.com/docs/en/legal-and-compliance.md>,
     <https://www.anthropic.com/legal/consumer-terms>.
   - Consequence for M2b: decision 4's fallback (a Console API key) is the only path the terms
     clearly permit. Staying on the subscription is a risk the maintainer accepts, or closes by
     asking Anthropic (the compliance page points to sales). Not a technical blocker.
   - **Maintainer decision (2026-10-07):** accepts the subscription-terms risk for the loop. No
     question to Anthropic, no API-key switch now; decision 4's "decide again at M2c from M2b's
     audit-line costs" stands.
2. **Fable is available through the API.** Model id `claude-fable-5-1`, released 2026-09-01, status
   Active, retirement not sooner than 2027-09-01, on the Claude API and four other platforms; $10 /
   $50 per MTok, cache reads $0.25. No waitlist is stated for Fable; the sibling Mythos 5.1 is the
   verification-gated one. Source: <https://platform.claude.com/docs/en/models/fable-5-1/overview>.
3. **Headless `--model fable` smoke run: passed.** `claude -p "Reply with exactly: ok" --model
   fable --output-format json --max-turns 1`, run from a scratch directory: exit 0, `is_error`
   false, `terminal_reason` `completed`, result `ok`, 1.8 s.
   - **Where the resolved id is.** The alias `fable` resolved to `claude-fable-5-1`; it is the key in
     the result's `modelUsage` map (there is no top-level `model` field). A second key,
     `claude-haiku-4-5-20251001`, is Claude Code's own small-model call, so the driver must not take
     "the one key" as the session model. The `system/init` event also carries the model under
     `stream-json`; not checked here.
   - **Cost shape.** `total_cost_usd` was 0.26 (a `costBasis: "list"` estimate, not a bill) for one
     trivial turn, almost all of it a 12.7k-token cache write plus 26.8k cache reads: the run loaded
     this host's user plugins, CLAUDE.md and memory because it was not `--bare`. That is the
     per-session floor for M2b's budgets on an un-bare run, and `--bare` is not an option on the
     subscription login.
   - Not measured: Fable's own usage limit and its draw on the subscription pool (the smoke run
     did not hit one).

## Stale plan text (fixed in the same PR as this file, or left)

Fixed: § 7.1 steps 4-6 no longer claims to wait on § 8; § 9 no longer says the § 8.1 name rule is
unwritten. Left at first, as it is long, then dropped in #315: step 4's "prerequisite not in
the plugin today" sentence (`depends_on` shipped in #232, the resume lock in #233, the CLI floor
in #236). #315 also synced § 7.1 to the cut above, moved the driver to `scripts/loop/` (WB-D23),
and named the loop image's base (`devcontainer-base`, one loop image per toolchain; § 7.3).

## Could not verify

Fable's usage limit (headless `--model fable` itself is verified, see above); API prices; Console spend-limit and revocation
behaviour; the App's behaviour under a ruleset on `sprint/*`; whether devcontainers adopted the
no-op handoff; native stacked-PR behaviour under squash and restrict-updates.
