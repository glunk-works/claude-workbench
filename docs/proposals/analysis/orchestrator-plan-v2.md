# Sprint orchestrator for the way-of-working plugin — plan v2 (for a second critical review)

Author: a Claude session, 2026-10-04, for the maintainer of glunk-works/claude-workbench.
v1 was reviewed by four independent agents; v2 incorporates their findings. Read
orchestrator-plan-v1.md in this directory first for the repo context, trust rules and measured
problem (80 cursor PRs per 53 work PRs in devcontainers in one week; 9-minute merge cadence; 79%
of cache-read tokens spent on turns above 150k context; stale premises corrected below).

## New hard constraint (from the maintainer)

Everything must run on the maintainer's Claude subscription (claude.ai login / OAuth), never on
API-key billing or purchased usage credits. Consequences already known from current docs:
- `claude --bare` is OUT: bare mode never reads OAuth credentials and needs ANTHROPIC_API_KEY.
  Headless runs must be plain `claude -p` with the subscription login, which loads the project's
  hooks, plugins, CLAUDE.md as an interactive session would.
- GitHub Action `anthropics/claude-code-action` accepts `claude_code_oauth_token` (from
  `claude setup-token`), billed to the subscription. The token is tied to one person's subscription.
- Routines (cloud scheduled sessions) run on subscription usage; when the usage limit is hit and
  usage credits are off, further runs are rejected until the window resets. Routines commit and
  open PRs as the maintainer's own GitHub identity, push to `claude/` branches, are research
  preview, GitHub triggers cover pull_request and release events only (not issues), API trigger
  exists, hourly caps apply.
- Agent SDK docs steer toward API-key auth; treat SDK as unavailable under this constraint unless
  verified otherwise.
- Subscription usage is a shared pool: an unattended loop competes with the maintainer's own
  interactive sessions for the same 5-hour and weekly limits. Opus and Fable draw it down faster
  than Sonnet.
- Prompt-cache TTL: 1 hour for the main conversation on subscription within plan usage, falling
  back to 5 minutes on usage credits; subagents default 5 minutes.
- Fable 5.1 / Sonnet 5 run with the 1M context window on every plan, which is how sessions reached
  500k–780k context; `--autocompact <tokens>` (100k–1M, per launch) caps that.

## Corrections carried from the v1 review

- Subagents CAN nest (default 3 levels, CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH). The "cannot spawn
  subagents" sentence in workflow.md and critic-gate SKILL.md is stale. Fresh sessions per task are
  justified by context spend, not by that limit.
- Budget controls exist as CLI flags: `--max-budget-usd` (counts subagent spend; stops spawning at
  the cap; client-side estimate), `--max-turns`, `--autocompact`, `--json-schema`,
  `--permission-prompts none` (removes AskUserQuestion entirely), `--permission-mode dontAsk|auto`,
  `--allowedTools`/`--disallowedTools`, `--exclude-dynamic-system-prompt-sections`,
  `--append-subagent-system-prompt`, `--forward-subagent-text`, `--restricted`.
- Hooks: PreToolUse can deny deterministically (exit 2); devcontainers already ships a
  `merge-guard.sh` PreToolUse hook allowing exactly one merge shape (resume's confirmed cursor-sync
  merge). Stop/SubagentStop/PreCompact/SessionEnd exist.
- The devcontainers review gate counts a review only from REVIEWER_IDS = the owner's numeric user
  ID; issues #93/#122 (decision due 2026-10-17) cover that any writer or a same-repo PR can mint
  the status. The plugin's trust predicates (review-sandbox.sh trust, resume author check) admit
  only OWNER|MEMBER|COLLABORATOR, so a GitHub App author reads as untrusted unless made a
  collaborator (then it is a trusted writer — the #122 question).
- plan-anchor.sh requires the issue's updated_at to equal the anchor; any comment moves it.
- 603-Identity is on GitHub Team; glunk-works is on the free plan. Merge-queue availability for
  private Team repos: not yet verified.

## Design principles (v2)

1. The orchestrator never merges to `pr_base`. Every approval that lands on main is a human merge
   of a task-sized PR. No sprint branch; no driver merges anywhere.
2. Deterministic driver (fixture-tested bin/ scripts, WB-D10). LLM judgment only in named slots
   with structured output (`--json-schema`): classify a stop; nothing else.
3. One fresh `claude -p` session per task, capped by `--max-turns`, `--max-budget-usd` and
   `--autocompact`, with `--permission-prompts none`, a narrow `--allowedTools` list and the repo's
   deny rules/hooks. Interactive skills stay interactive; the driver resolves policy BEFORE the
   session by calling the existing predicates (plan-anchor, review-base-anchor, spawn-model,
   cursor-drift) and hands the session a narrow task prompt.
4. Plan-then-execute: the set of steps and writable locations is fixed before any session reads
   issue text. Issue text reaches the coder only as a typed spec (title, acceptance criteria,
   files) extracted by a tool-less quarantined call, never raw. Anchor per task at dispatch.
5. A task PR touching the human-only path set (`.ai/project.yml`, `.claude/`, `CLAUDE.md`,
   `.github/workflows/`, the plugin pin, hooks) stops the batch; the driver reads every config it
   depends on from `origin/{pr_base}`, never from a task branch.
6. Author ≠ approver ≠ gate-minter: the identity that posts the fresh-session review is never in
   REVIEWER_IDS; the human's merge remains the only control the gate records. No bot identity until
   #122 decides its trust class.
7. Acceptance test first: derived from the spec, pinned before the coder session, the coder may not
   edit it (deny rule on that path). Digest derived mechanically (files, tests added, critic rounds
   and stop condition, cost), never written by the session.
8. Budgets are a subscription-usage budget: per-task and per-day caps sized so the loop cannot
   exhaust the maintainer's weekly usage. Critics default to Sonnet; Opus/Fable only where a
   human-authored policy says so. Context cap per session via `--autocompact`.
9. Observability: per-step audit line (session id, model, SHA, usage, stop reason) appended to the
   task PR body; usage exported per task from the transcript's usage fields; kill file checked
   before every dispatch; lock file against a concurrent human session on the same checkout.

## Steps

| step | what changes | trust surface |
|---|---|---|
| 1 | handoff writes the ledger (.ai/next-steps.md) into the open task PR; a cursor-sync PR only when no task PR is open. cursor-drift already admits that path. | none: the human's merge approves ledger + code together |
| 2 | fix #209 (roadmap entry written before close) and #220 (dirty ledger) so a sprint close is one PR | none |
| 3 | the fresh-session architect-review is dispatched by an event (label `review-ready` or ready_for_review) on a Linux runner (GitHub Action with the subscription OAuth token, or a routine on PR events) under an identity the gate does NOT count. Human merge remains the control. | none until #122 is decided; then re-decide |
| 4 | fix the stale nesting sentence (workflow.md, critic-gate); split resume into a lean auto-start path + on-demand appendices (target <20k tokens of plugin prose per task session); `--exclude-dynamic-system-prompt-sections` for cache reuse | none |
| 5 | headless coder loop, AFTER #93/#122 are decided: driver (bin/run-sprint.sh) resolves policy and anchors per task; spawns one capped `claude -p` session per task with narrow allowlist; task PR to pr_base; human merges in one batched sitting (merge queue if available); human-only-path stop; pinned acceptance test; derived digest | one explicit WB-D naming which human authorizations become plan-time policy |
| 6 | eval set of 20–50 real past tasks re-run per driver release; driver state as a tracked JSON with idempotent step markers; lock + kill file; per-step audit line; usage export | none |

Where the loop runs: first on the maintainer's machine while present but not typing (Windows,
Git Bash; GPG passphrase cached or signing off for the loop's commits); then in the devcontainers
image on a Linux host or GitHub Actions. Routines are a candidate only for step 3 (PR-event review).

## Open questions v2 does not settle
- Does `--max-budget-usd` enforce on subscription auth (it is a client-side estimate)?
- `claude setup-token` lifetime, rotation, and the blast radius if the Actions secret leaks
  (someone burns the maintainer's subscription and acts as them on GitHub).
- Usage-limit math: how many task sessions per day fit in the subscription alongside interactive
  work; what happens to a `-p` run that hits the 5-hour limit mid-task (wedge vs error).
- Whether per-task PRs to main with the human merging in a batch re-introduces "green on a stale
  base" without a merge queue; whether merge queue is available on 603-Identity's Team plan.
- Whether the quarantined-extraction step (principle 4) is overkill for a solo maintainer whose
  issues are all self-authored, versus checking author_association and stopping on outsiders.
