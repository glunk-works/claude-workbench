# Sprint orchestrator for `way-of-working` — plan v5, with its review history

**Status:** proposal, nothing built, nothing filed. Untracked file; not part of any release.
**Written:** 2026-10-04, by a Claude Code session running Fable 5.1, for the maintainer of
`glunk-works/claude-workbench` and for a *separate* Claude session that will review this
document for context and bias.
**Revised:** 2026-10-04 (v4), by a second Fable 5.1 session that reviewed v3 and applied the
corrections in § 6.3. **Revised again:** 2026-10-04 (v5), by a third Fable 5.1 session that
reviewed v4 against primary sources and applied the corrections in § 6.4. **Every pass so far
has been same-family.** The v4 header asked for a different family and did not get one; the
next reviewer must be on another model family (Opus is the natural choice), or the maintainer
should treat § 6.3 and § 6.4 as one voice.
**Supersedes:** plan v1, v2, v3 and v4 (all summarised in § 6; none was filed).
**Decisions:** § 8 lists four, **all decided by the maintainer on 2026-10-04** after the v4
review, each marked *Decided* with the reasoning and the alternatives weighed. § 8.2's answer
(a hardened container on Docker Desktop) and § 8.4a's (model routing from the repo's existing
`models` map with no loop default; critic selection as a judgment slot) changed the plan's
text; § 5, § 6.2, § 7.1, § 7.3, § 7.4 and § 9 say where.

---

## 0. How to review this document

You are reading this because the maintainer wants an independent check. The authoring
session had these properties, which a reviewer should treat as potential bias:

- It ran on **Fable 5.1**. Its eight critic and research subagents ran on Fable 5.1 (2), Opus 5.5 (2),
  the `claude-code-guide` agent (3), and a general web-research agent (1). No human reviewed
  any intermediate finding. Same-family judges are known to inflate agreement.
- It **selected which critic claims to verify**. Claims marked *verified by author* below were
  checked by the authoring session against the file or URL named. Claims marked *reported by
  subagent* were not independently re-read. Everything else is the author's own reasoning.
- The measured data (§ 3) comes from **local transcripts on one machine** and from GitHub PR
  metadata. The transcript scan de-duplicated one mirrored project directory; it did not
  reconcile against Anthropic's own usage accounting, which is not exposed to tools.
- The author produced v1, then argued against parts of v1 in v2 and v3. Watch for
  over-correction in both directions: v3 was more conservative than the evidence required in
  places; v4 swung back on one point (§ 8.3) further than the evidence allows; v5 reversed it.
- The author never ran a headless `claude -p` session, never ran a GitHub Action with the
  plugin, and never tested a hook under `--permission-prompts none`. **Neither did the v3 or
  v4 reviewer.** All feasibility claims about those paths are from documentation, and § 4
  treats the documentation as stable when it is not (see the `--bare` note in § 4.1 and § 9).
- **v4 and v5 are same-family revisions.** The v3 reviewer re-verified every § 2 row, re-ran
  `pr_analysis.py` and `daily_usage.py`, and fetched the § 4 URLs; its corrections are in § 6.3
  and its claims are marked **[R]** in § 4. The v4 reviewer did the same again, read the raw
  hooks.md, settings.md, permissions.md and Microsoft's wsl-config page, and checked the
  consuming repos for `.husky/`, `package.json` and `.gitmodules`; its corrections are in § 6.4
  and its claims are marked **[V]**. Where v5 disagrees with v4's framing (§ 6.1 note, § 8.3),
  that is one reviewer's reading against another's, and § 6.4 gives the evidence for each.

Suggested checks for the reviewer:
1. Re-derive the § 3 PR counts from GitHub (`gh pr list --state all --limit 200 --json …`)
   for one repo and compare. Two reviewers have reproduced them; a third is cheap.
2. Re-read the four load-bearing repo claims in § 2 against the files named.
3. Spot-check the URLs a step depends on (`--permission-prompts`, `setup-token`, hook
   fail-open behaviour, the settings file watcher).
4. Ask whether § 8.3 now states the trade-off fairly. v3 said "accept a ceiling"; v4 said
   "nothing to accept"; v5 says the ceiling is real for dependent chains and names why.
5. The § 8 decisions are now the maintainer's, made after reading the v4 review. Check each
   against the rest of the plan: is it consistent, what does it foreclose, and did the
   recommendation that preceded it steer the answer? § 8.2 was answered with an option the
   plan had not offered (a container), which is some evidence the maintainer was not steered;
   § 8.4a was answered against the recommendation, then clarified once when the first
   recording over-read it as "Opus by default".
6. Check § 6.3 and § 6.4 against the same primary sources; neither reviser had a human check.
7. Read § 7.3 as an attacker: the v4 reviewer found one live widening path the v3 reviewer
   missed (the settings file watcher). Look for the next one.

---

## 1. The request and the constraint

**Request (2026-10-04).** The maintainer is the bottleneck for getting sprint work done
across several repos that consume the `way-of-working` plugin. They asked whether a
Fable-driven sprint/milestone orchestrator could direct subagent-based task execution to the
same quality bar without them dispatching each item, acknowledging it would change merge
rules and more. They then added two requirements and asked for repeated critical review:

- **Context management and token spend control are first-class design requirements.**
- **Everything must run on the maintainer's Claude subscription.** No API-key billing, no
  purchased usage credits.

**What the maintainer did NOT ask for.** Nothing here was approved. Every "decision" in § 8 is
theirs to make. The maintainer has not said whether a dedicated Linux host is acceptable.

---

## 2. Repo context and the trust rules the plan must hold

Source repo: `glunk-works/claude-workbench` (public). Consumers read in this analysis:
`603-Identity/devcontainers` (public, GitHub Team org), `603-Identity/infrastructure-core`
(private, Team org), `glunk-works/bounty-infra` (public, free org). Both orgs are visible to
the `JaredGroves-603` gh account; the `Seuss27` account cannot see 603-Identity private repos.
Pins on 2026-10-04: devcontainers and bounty-infra at `v0.15.0`, infrastructure-core at
`v0.14.0`. *Verified by v4 reviewer.*

### 2.1 What the plugin is

A session-handoff protocol: short single-model Claude Code sessions externalise state into
`.ai/state.json` (git-ignored machine cursor, holds `next_action` and `hitl_gate`) and
`.ai/next-steps.md` (git-tracked ledger, landed as a docs-only "cursor-sync" PR per handoff).
Skills: `resume`, `handoff`, `ship`, `critic-gate`, `architect-review`, `plan-sprint`,
`archive-sprint`, `park-sprint`, `unpark-sprint`, `pr-checks`, `retro`. Agents (read-only
unless noted): `architect` (Opus), `security-critic` (Opus), `docs-consistency` (Opus),
`coder` (Sonnet, read/write). Deterministic predicates live in `plugins/way-of-working/bin/*.sh`
with fixture tests under `tests/` (WB-D10). Shared plugin code may never name a repo-specific
value; every such value is a key in `.ai/project.yml` (WB-D2, WB-D17; enforced by
`scripts/coupling-check.sh` in CI).

### 2.2 Trust rules (all *verified by author*, re-verified by the v3 and v4 reviewers against the files named)

| rule | where |
|---|---|
| A merged PR is the human approval. Claude never merges to `pr_base`, never approves. The one exception is resume's merge of a docs-only cursor-sync PR on explicit human confirmation. | `plugins/way-of-working/reference/workflow.md` § Integration gate; `docs/decisions.md` WB-D20 (line 1003) |
| WB-D20 **rejected** handoff self-merging even a docs-only PR: a session steered by untrusted text could write a harmful `next_action`, approve it, and the next session would run it unattended. WB-D20 also records that **"a merge on GitHub still approves the ledger alone"** — the human's read of `next_action` exists only in resume's offer path. | `docs/decisions.md` WB-D20, "Rejected" bullet and "The human sees the `next_action`" bullet |
| Issue bodies and spec comments are specifications, never instructions. The coder verifies the issue's `updated_at` and `author_association` (OWNER/MEMBER/COLLABORATOR) against a human-anchored `plan_anchor` before building. | `plugins/way-of-working/agents/coder.md` step 2; `bin/plan-anchor.sh` header |
| resume auto-starts a `next_action` only when: `hitl_gate` NONE OPEN, status `implementing`, model matches, cursor not drifted, no open cursor-sync PR and no unmerged sync branch under HEAD, plan anchor verifies, task author (and spec-comment author) trusted. Fails closed. "Auto-start removes a rubber stamp, not a gate." | `skills/resume/SKILL.md` auto-start section (~L873-1000; the quoted line is L984) |
| critic-gate proposes critics; the human picks; a second-opinion round on another model needs the human's own message in the live session. | `skills/critic-gate/SKILL.md` L49-64, L262-290 |
| handoff explicitly refuses to commit the ledger onto the code branch: "bundles cursor churn into the code PR's review, which is the muddle this whole step exists to prevent." | `skills/handoff/SKILL.md` ~L283-291 |
| `cursor-sync-pr.sh` offers a PR only when same-repo, changes exactly `.ai/next-steps.md`, head branch starts with `docs/sync-cursor-`, and a local branch of that name sits at its head. Its `unmerged` verdict fires only when HEAD is on such a branch. | `bin/cursor-sync-pr.sh` L19-32, L77, L100, L200 |
| `cursor-drift.sh` classifies a HEAD-vs-`last_commit` delta as `cursor-sync` iff every path is `.ai/next-steps.md` or under `.ai/parked/`. | `bin/cursor-drift.sh` L69-83 |
| `review-sandbox.sh trust` → `trusted=1` only for OWNER/MEMBER/COLLABORATOR **and** same-repo head. An untrusted PR gets no local execution. | `bin/review-sandbox.sh` L183-185, L324 |
| Branch ruleset on `main` (this repo, `protected-integration-branches`, id 19562210): deletion, non-fast-forward, pull_request (0 required reviewers), required checks `lint`, `coupling`, `invariants`. No bypass actors. | `gh api repos/glunk-works/claude-workbench/rulesets/19562210` |

### 2.3 devcontainers specifics (the consumer with the fresh-session review gate)

*Verified by author* and re-verified by both reviewers unless noted.

- `review.ci_gate.check: architect-review` is a **required status**. The gate workflow
  (`.github/workflows/architect-review-gate.yml`) counts a review comment only when its
  author's numeric user ID is in `REVIEWER_IDS: "281693088"` (the owner), and posts the status
  against the PR head SHA. It is an **existence** gate, not a verdict gate: it checks that a
  review was posted, not what it concluded. Triggers: `pull_request` (opened/synchronize/
  reopened), `issue_comment`, `pull_request_review`. Its own header notes that `pull_request*`
  runs use the PR's **own copy** of the workflow (issue #93), while `issue_comment` runs use
  the default branch's copy.
- Open decisions on that gate: **#93** (a same-repo PR can edit the gate it is checked by) and
  **#122** (review-gate trust model, F9b: any writer can mint the status from their own PR
  workflow; decide before auto-merge is turned on). devcontainers' own ledger (L21-22) commits
  the owner to deciding both by **2026-10-17**; on GitHub both sit in the milestone *Repo
  hardening: review gate and CI*, due **2026-12-15**. The earlier date is a ledger promise, not
  a GitHub deadline. **#139** (turn on auto-merge for verified image bumps, milestone *P2:
  adoption waves*, due 2027-01-29) names #122 as its prerequisite in its body.
- `.ai/project.yml` `code_paths` includes `images/`, `template/`, `tests/`, `tools/`,
  `.github/`, `.trivyignore.yaml`, `.gitattributes`, `.ai/project.yml`, `.claude/` — with
  comments saying an edit weakening any of them must route to review.
- `gates.green` is eight shell commands. Three of them execute **tree-resident scripts**:
  `bash tools/tests/run-gate-tests.sh`, `bash .github/scripts/build-and-test.sh local`,
  `bash tests/template-proof.sh`. The other five run pinned container images or Go tests
  against the tree. This matters for § 6.1 and § 8.3. *Verified by v4 reviewer.*
- `.claude/settings.json`: deny rules cover only `git push --force*`,
  `git push --force-with-lease*`, `git push -f`, `git commit --no-verify`, `-n`,
  `git push --no-verify` (Bash and PowerShell forms). One PreToolUse hook:
  `bash "$CLAUDE_PROJECT_DIR/.claude/hooks/merge-guard.sh"` on Bash|PowerShell.
- `merge-guard.sh` blocks command segments starting with `gh pr merge` except resume's exact
  cursor-sync shape; its own comments list residuals: `python -c`, `xargs`, and "if this script
  cannot run at all (no bash), the call is not blocked. The main ruleset still requires every
  check." A merge via `gh api -X PUT repos/…/pulls/N/merge` is **not** matched. Its header
  also records the platform rule this plan leans on in § 7.3: "a deny rule wins over every
  allow rule and hook."
- Ruleset `main-required-checks` (id 24183176): pull_request + required_status_checks. Required
  checks: `hadolint (Dockerfiles)`, `Trivy misconfiguration (Dockerfiles)`,
  `shellcheck (scripts)`, `zizmor (workflow security)`, `Build and smoke-test (no push)`,
  `architect-review`, `selftest`.
- None of the four repos (this one and the three consumers) has `.husky/`, `package.json`, or
  `.gitmodules`. *Verified by v4 reviewer via `gh api …/contents/…` (404 on each).*

---

## 3. The measured problem

### 3.1 Where the human's time goes (GitHub PR metadata, *verified by author*, reproduced by both reviewers)

Classification by PR title prefix: `docs(cursor)`/`docs: sync cursor`/park/anchor → **cursor**;
`docs: mark`/`docs(roadmap|sprint|decisions|ledger)`/`chore(release|claude|ai)` → **record**;
dependabot; everything else → **work**. Script: `pr_analysis.py` (see § 10).

| repo | window | work PRs | cursor PRs | record PRs | cursor per work | median open→merge (work) | median work PR size |
|---|---|---|---|---|---|---|---|
| devcontainers | 2026-09-28 → 10-04 | 55 (53 merged) | 81 (68 merged) | 7 | **1.53** | 15 min | 64 lines |
| infrastructure-core | 2026-08-14 → 10-01 | 84 | 48 | 63 | 0.57 | 11 min | 166 lines |
| claude-workbench | 2026-07-22 → 10-02 | 71 | 52 | 31 | 0.73 | 12 min | 129 lines |

Busiest day, devcontainers (2026-10-02): **31 merges over 11.3 h, median 9 min between
merges**, 13 of them work. The merges run from 12:22 to 23:37 UTC, with at least one merge
in every hour but 17:00: **the human was present for the whole window.** infrastructure-core
2026-09-07: 29 merges over 22.8 h.

One issue end to end (devcontainers #160, a +4/−1 fix): PR 237 cursor → PR 238 code →
PR 239 cursor "shipped; architect review next" → PR 241 cursor "reviewed and merged". Three
PRs, three sessions (coder, handoff, fresh-session reviewer), ~9 human touches, 25 minutes.
**14 cursor PRs in the last 200 exist only to say "architect review next"** (title match on
"review next"; v3 said 16 without a reproducible rule).

Sprint 7 on this repo (PRs #200–#208): 9 PRs for 2 issues (#162, #189), 7 of them ceremony.
v3 said 11; the extra two were sprint-06 close-out PRs.

Decision backlog the loop cannot clear: devcontainers' ledger lists 4 owner-owned items;
infrastructure-core has 15 open issues labelled `status/needs-human` (13) or `decision` (8),
counted 2026-10-04 (v3 said 10).

Where the human-time baseline actually sits: today's flow is already **one task per human
merge**, with 9–15 minutes between merges on a busy day, and dependent tasks already wait on
that merge. **But today the human is present while that happens**, so a chain of dependent
tasks advances at the human's pace and a four-task chain finishes in an afternoon. Any design
that keeps the human merge as the approval inherits the one-task-per-merge rule; what changes
is *when* the merges happen. A loop that runs while the human is away (§ 7.4's dispatch window)
advances a chain by one task per sitting, and sittings are daily, not every nine minutes.
§ 8.3 states that trade-off. Neither the cursor-PR count nor the touch count measures reading
time; nothing in this document does.

Host friction recorded in devcontainers' own ledger (L35-37): `GH_TOKEN` per repo (two gh
accounts), commits from Windows but tests in WSL, "WSL's `gh` is Seuss27, no push", auto mode
blocks ruleset edits, host GPG cache TTL for long sessions.

### 3.2 Where the tokens go (local transcripts, *verified by author*, scripts in § 10)

`~/.claude/projects/<proj>/*.jsonl`; each `assistant` line carries `message.usage`.
Subagent transcripts live under `<proj>/<session>/subagents/`. The
`personal-claude-workbench` directory mirrors the `glunk-works-claude-workbench` one
(identical session files) and was excluded.

Since 2026-09-01 (272 main sessions, 848 subagent files):

| measure | value |
|---|---|
| cache-read tokens, main sessions | ≈ 2.3 B |
| cache-read tokens, subagents (critics) | ≈ 0.6 B, almost all Opus (654 of 848 files Opus 5.5, 156 Opus 5) |
| cache writes + output, all | < 0.13 B |
| median peak context per session | 138 k |
| sessions whose peak context passed 150 k | 142 of 325 |
| share of all cache reads on turns above 150 k context | **79 %** |
| five largest sessions | claude-workbench coder sessions 2026-09-23..25, 200–480 turns, 350–505 k median context, Sonnet 5 (1 M window) |
| plugin prose loaded per session (resume+handoff+ship+critic-gate+conventions) | ≈ 169 KB ≈ 42 k tokens |

Daily envelope, last 14 days (de-duplicated; reproduced by the v3 and v4 reviewers on
2026-10-04): mean **≈ 195 M cache-read/day**, 0.9 M output/day, ≈ 52 sessions/day (incl.
≈ 34 Opus critic subagents/day). Opus ≈ 60 M/day of cache reads, Sonnet ≈ 124 M, Fable ≈ 11 M.
Per-session medians: main Sonnet 5.1 M cache-read / 49 turns (p90 47.5 M); main Opus 2.6 M /
29 turns; Opus critic subagent 0.2 M / 10 turns.

Reading: spend is dominated by re-reading large contexts; four-fifths of it happens in
sessions past 150 k. A capped task session (≈100 k context, ≤60 turns) is about one of today's
median Sonnet sessions, so a wave of four tasks ≈ one current afternoon.

**These are API-token figures used as a proxy.** Under the subscription constraint the binding
quantity is consumption of the 5-hour and weekly windows, which Anthropic does not expose as a
number. Cache-read tokens track that consumption in direction (a long-context turn costs more
of the window than a short one) but not in units, and `--max-budget-usd` is a list-price
estimate of the same proxy. The governor in § 7.4 is sized on the proxy and must be re-sized
from observed limit errors once anything runs.

---

## 4. Platform facts the plan depends on

Legend: **[A]** verified by author from the URL on 2026-10-04; **[S]** reported by a subagent
with the URL, not re-read by the author; **[R]** re-verified by the v3 reviewer from the URL
on 2026-10-04; **[V]** re-verified by the v4 reviewer from the URL on 2026-10-04 (raw page
where noted, not a summary).

### 4.1 Headless and budgets (`claude -p`)
- `--max-budget-usd` exists, print mode only, subagent spend counts, spawning stops at the cap;
  it is a **client-side list-price estimate**. [A][R][V] https://code.claude.com/docs/en/cli-reference.md
- `--max-turns` (exits with error at the limit), `--json-schema` (structured output in
  `structured_output`), `--autocompact <100k..1M>` (per-launch auto-compact window, capped at
  the model's window), `--fork-session`, `--forward-subagent-text`, `--plugin-dir`,
  `--exclude-dynamic-system-prompt-sections`, `--restricted`, `--setting-sources`,
  `--settings`, `--strict-mcp-config`, `--append-subagent-system-prompt`. [A][V] same URL
- `--permission-prompts none` removes tools that need a person (AskUserQuestion) and denies
  anything that would prompt **"unless a `PermissionRequest` hook allows it"**. **Requires
  v2.1.259+.** `dontAsk` mode also denies AskUserQuestion. [A][R][V] https://code.claude.com/docs/en/headless.md
- **Installed CLI on the maintainer's machine is 2.1.228** (`claude --version`). The version
  floor comes from headless.md, not from `--help`: cli-reference.md says `--help` does not list
  every flag, so a flag's absence there proves nothing. [A][R][V]
- `--bare` skips hooks/skills/plugins/CLAUDE.md **and never reads OAuth credentials or
  `CLAUDE_CODE_OAUTH_TOKEN`**; it needs `ANTHROPIC_API_KEY`. So bare mode is out under the
  subscription constraint. [A][R][V] headless.md; authentication.md
  **headless.md also says `--bare` "is the recommended mode for scripted and SDK calls, and
  will become the default for `-p` in a future release."** When that lands, plain `-p` on a
  subscription login needs an explicit opt-out that is not documented today. The plan's
  launch line (§ 7.3) depends on that opt-out existing. [V]
- Plain `-p` without `--bare` runs the project's hooks and connects its `.mcp.json` servers
  "even in a folder you've never trusted", with no trust dialog. [A][R][V] headless.md
- `--setting-sources user` makes Claude Code read "neither the project's settings files nor
  its `.mcp.json`". The page says nothing about project `CLAUDE.md`, so that effect stays
  unverified. [V] https://code.claude.com/docs/en/permissions.md § What runs before you trust a folder
- `--output-format json` includes `total_cost_usd`, per-model usage, `permission_denials`. [A][V]
- Background subagents hold a `-p` process open up to 10 min idle by default
  (`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`). [A][V]

### 4.2 Subagents, hooks, settings
- Subagents **can** spawn subagents, default 3 levels (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`).
  `isolation: worktree` is a documented frontmatter field. Subagent requests count toward the
  same usage limits. [A][R][V] https://code.claude.com/docs/en/sub-agents.md
  → The sentence "a subagent cannot spawn subagents" at `reference/workflow.md` L140 is
  **stale**. [A][R][V] It is not in `skills/critic-gate/SKILL.md` (no "spawn/nest/sibling"
  phrasing in the nesting sense there). [R][V]
- **Settings files are watched and reloaded live.** settings.md: "Claude Code watches your
  settings files and reloads them when they change, so it applies most edits to the running
  session without a restart, including edits to `permissions`, `hooks`, and credential helpers
  … The reload covers user, project, local, and managed settings." A missing/non-executable
  hook, a timed-out hook, and any exit code other than 0 or 2 are **non-blocking: the action
  proceeds** ("for most hook events"). Managed-settings hooks cannot be disabled from
  user/project/local settings; `allowManagedHooksOnly` in managed settings blocks user,
  project, local and plugin hooks entirely. [A][R][V] https://code.claude.com/docs/en/hooks.md ;
  https://code.claude.com/docs/en/settings.md (raw)
- **`PermissionRequest` hooks are an allow path under `--permission-prompts none`, and the
  path is bounded.** hooks.md (raw): "PermissionRequest hooks run only when Claude Code is
  about to ask you for permission, or when it would otherwise auto-deny a call that can't
  prompt"; "if no hook returns a decision, it denies the tool call." Exit code 2 is not
  honoured for this event; the decision goes through the `decision` object. A call an explicit
  deny rule matches never reaches the prompt stage, so it never reaches this hook (the
  `PermissionDenied` section lists deny-rule matches as a separate path; devcontainers'
  merge-guard header records the same rule). **Consequence for § 7.3:** a hook in any loaded
  settings source can widen the session from "denied because nobody can answer" to "allowed",
  for every call the driver did not explicitly deny. So the driver must (a) own every settings
  source the session loads, (b) keep them unwritable by the session for the session's
  lifetime, because the watcher applies edits live, and (c) enumerate the dangerous surface in
  deny rules rather than lean on `dontAsk`'s default. v3 had this inverted ("can deny, not
  allow"); v4 fixed the direction; v5 adds the bound and the watcher. [R][V]
- Deny rules win over allow rules and over `bypassPermissions`. [S] permissions.md; the same
  rule is stated in devcontainers' `merge-guard.sh` header. [V]

### 4.3 Subscription authentication and limits
- `claude setup-token` mints a **one-year** OAuth token, subscription-billed, Pro/Max/Team/
  Enterprise, "can only make model requests" (no Remote Control, no claude.ai connectors). No
  revocation procedure is documented. Deleting a GitHub Actions secret does not invalidate the
  credential it held ("If you delete a secret, the credential it held stays valid").
  [A][R][V] https://code.claude.com/docs/en/authentication.md ;
  https://code.claude.com/docs/en/github-actions.md (Uninstall)
- `CLAUDE_CONFIG_DIR` gives each login its own credentials/settings directory; on Linux the
  credential file is `.credentials.json` under that directory, mode 0600. [A][R][V] authentication.md
- Subscription usage: rolling **5-hour** window plus a **weekly** window, shared across all
  models (plus model-specific Opus/Sonnet limits). Subagents, background sessions, routines,
  `-p` runs and `/insights` all draw from the same pool. Without usage credits, further runs
  are rejected until the window resets. `autoContinueAtUsageLimit` exists for interactive
  sessions. [A][R][V] https://code.claude.com/docs/en/costs.md
- Prompt cache TTL: **1 h** for the main conversation on subscription within plan usage,
  **5 min** on usage credits [A][V] costs.md; 5 min for subagents/workflows by default [S]
  prompt-caching.md. `/usage` shows hit ratio (main conversation only). [A][V]
- `/usage` plan breakdown attributes usage to skills, subagents, plugins, MCP servers, and
  flags long-context/cache-miss behaviours ≥10 %. Computed from local history. [A][V] costs.md
- A `-p` run that hits the limit exits with an error. [S] errors.md, headless.md
- **Agent SDK is API-key only**: "Unless previously approved, Anthropic does not allow third
  party developers to offer claude.ai login or rate limits for their products, including agents
  built on the Claude Agent SDK." [S][R][V] https://code.claude.com/docs/en/agent-sdk/overview.md
- Auto mode is available on subscription, in `-p`, on Sonnet 5.5 / Opus 5.5 / Fable 5.1 /
  Opus 4.7+. [S] auto-mode-config.md
- No documented terms statement restricting subscription use to interactive sessions; the
  reviewer should check https://www.anthropic.com/legal/commercial-terms. [S]

### 4.4 GitHub Action, routines, merge queue
- `anthropics/claude-code-action`: accepts `claude_code_oauth_token`; automation mode runs on
  any event when `prompt` is set; on issue/PR events the triggering user must have write
  access; bot actors rejected unless `allowed_bots`; **commits pushed with `GITHUB_TOKEN` do
  not trigger CI**; inputs `plugins`, `plugin_marketplaces`, `claude_args`, `settings`.
  [A][R][V] https://code.claude.com/docs/en/github-actions.md
  The docs do **not** say the Action cannot merge or approve (v3 claimed that). The Claude
  GitHub App's installed permission set is: Actions RW, Checks RW, **Contents RW**, Discussions
  RW, Issues RW, Members R, Metadata R, **Pull requests RW**, Repository hooks RW,
  **Statuses R**, **Workflows RW**. Contents + Pull requests write is enough to merge through
  the API; only the tool allowlist in `claude_args` prevents it. Workflows RW means an
  Action-placed loop could edit the gate workflow (#93's exact gap) unless the allowlist
  forbids it. Statuses R means the App itself cannot mint a commit status. GitHub does not let
  an installer accept a subset; a custom App with Contents/Issues/Pull requests only is the
  documented alternative. Treat "cannot merge" as a configuration property, never an identity
  property. [R][V]
- Its security doc restores a **fixed list** from the PR base branch before running:
  `.claude/`, `.mcp.json`, `.claude.json`, `.gitmodules`, `.ripgreprc`, `CLAUDE.md`,
  `CLAUDE.local.md`, `.husky/`; base-absent paths are removed and PR versions kept under
  `.claude-pr/`. It sanitises HTML comments, invisible characters, image alt text, hidden
  attributes and entities; scrubs Anthropic/cloud/GitHub secrets from subprocess env (best
  effort; bubblewrap PID isolation on Linux); warns "Do not check out an untrusted ref into
  the workspace root" and "Do not use a personal access token". [S][R][V]
  https://github.com/anthropics/claude-code-action/blob/main/docs/security.md
- Routines: research preview; subscription usage; commits and PRs **carry the maintainer's
  GitHub user**; push to `claude/` branches; GitHub triggers cover **pull_request and release
  only** (not issues); API trigger exists; hourly caps (100 scheduled/h per account, 30/h per
  routine shared by Run-now and API fires). [A][R][V] https://code.claude.com/docs/en/routines.md
- Merge queue: public org repos, or private repos on Enterprise Cloud; **not** private repos
  on Team. [S] docs.github.com + community discussion. **Unverified either way:** the cited
  docs.github.com page, fetched by the v3 and v4 reviewers, contains no availability
  statement. If true → available for claude-workbench, devcontainers, bounty-infra; not
  infrastructure-core. [A][R][V] repo visibility via `gh api`
- 603-Identity is on GitHub **Team**; glunk-works has no paid plan. [A][R][V] `gh api orgs/…`

### 4.5 WSL2 defaults (added in v5; bears on § 6.2 and § 8.2)
From https://learn.microsoft.com/en-us/windows/wsl/wsl-config, per-distro `/etc/wsl.conf`
defaults. [V]
- `[automount] enabled = true`: fixed Windows drives are mounted under `/mnt`, so a process in
  the distro can read `/mnt/c/Users/<user>/.config/gh/hosts.yml`, `.gnupg/`,
  `.claude/.credentials.json` and every repo checkout.
- `[interop] enabled = true` and `appendWindowsPath = true`: the distro can launch Windows
  executables and the Windows `PATH` is appended, so `gh` or `git` can resolve to the Windows
  binaries carrying the maintainer's authentication and signing identity.
- `[user] default` = the first user created, which on the stock Ubuntu image has passwordless
  `sudo`; `wsl.exe --user root` also exists from the Windows side.
- `[wsl2] firewall = true` (Windows 11 22H2+) lets Windows Firewall and Hyper-V firewall
  rules filter WSL traffic; without those rules egress is unrestricted NAT.
- The distro's filesystem is reachable from Windows at `\\wsl.localhost\<distro>\…`, so a
  file inside the distro is readable by any Windows process running as the maintainer.
- **Docker Desktop on this machine uses the WSL2 backend** (`docker info` on 2026-10-04:
  server 29.5.3, kernel `6.18.33.1-microsoft-standard-WSL2`, distros `Ubuntu` and
  `docker-desktop`). A container therefore runs inside the `docker-desktop` distro: it has
  no `/mnt/c`, no Windows interop and no Windows `PATH` unless a bind mount supplies them, its
  volumes live in that distro's disk image (reachable from Windows as above), and the Docker
  socket is root-equivalent for the Windows user who runs Docker Desktop. [V] `docker info`,
  `wsl -l -v`; architecture per Docker Desktop's documentation, not re-fetched.

---

## 5. Design principles (unchanged from v3)

1. **The orchestrator never merges to `pr_base`.** Every approval that lands on main is a
   human merge of a task-sized PR. No sprint branch, no driver merges anywhere.
2. **The human's merge is the only approval, as a property of credentials, not prose.** The
   loop's GitHub identity cannot merge, cannot post commit statuses, cannot push to `main`,
   has no admin. Hooks and deny rules are defence in depth, never the control.
3. **Deterministic driver** (fixture-tested `bin/` scripts, WB-D10). LLM judgment only in
   **two named slots**, each with `--json-schema` output: (a) **critic selection** — which
   critics the diff warrants, using critic-gate's own table, filtered by the
   `orchestration.critics` allowlist (§ 8.4a); (b) **stop classification**. Nothing else.
   (v3–v4 named only slot b; the maintainer added slot a in § 8.4a.)
4. **One fresh capped session per task.** `claude -p` on the subscription login with
   `--max-turns`, `--max-budget-usd` (as a proxy), `--autocompact ≤ 100k`,
   `--permission-prompts none`, a narrow `--allowedTools` list. Justified by § 3.2 (context
   spend), *not* by subagent nesting.
5. **Policy resolved before the session, by the driver, from existing predicates**
   (`plan-anchor.sh` per task at dispatch, `review-base-anchor.sh`, `spawn-model.sh`,
   `cursor-drift.sh`). The interactive skills stay interactive; the session gets a narrow task
   prompt. One WB-D names which human authorizations become plan-time policy.
6. **The session's own configuration is driver-owned and unwritable by the session.** Config
   dir, `--settings`, `--plugin-dir` (pinned copy), managed-settings hooks on the host; config
   paths restored from `origin/{pr_base}` before every launch; the restored and driver-owned
   files are read-only to the session user for the session's lifetime; hashes recorded after
   exit.
7. **Plan-then-execute.** The step set and writable locations are fixed before any session
   reads issue text. Only human-anchored issues by trusted authors are dispatched (existing
   stop). No quarantined-extraction layer (see § 7).
8. **Human-only paths** are a schema key (`orchestration.human_only_paths`, WB-D17 style:
   present, explicit). Enforced twice: in-session deny rules supplied by the driver, and a
   post-exit `git diff --name-only origin/{pr_base}...head` check. Either failing stops the
   wave.
9. **Author ≠ approver ≠ gate-minter.** No identity the loop controls is ever in a review
   gate's reviewer allowlist.
10. **Budgets are subscription-usage budgets**, sized from § 3.2 and enforced by the driver:
    per-day session cap, human-hours window, per-model daily caps (Opus, Fable), model routing
    taken from the repo's existing `models` map and each agent's frontmatter with **no loop
    default** (§ 8.4a), transcript-metered token ceiling, stop on any limit error.
    (v3–v4 said "Sonnet critics by default"; the loop now imposes no model of its own.)
11. **Evidence over assertion.** Digest derived mechanically by the driver (files, tests
    added, critic rounds and stop reason, usage, hook denials), mirrored into the PR body by the
    driver's identity. Per-task audit line in an append-only log outside any worktree.
12. **Fixture on `bin/` change.** A task touching `plugins/*/bin` or `scripts/` must add or
    change a fixture; the driver checks the diff.

v5 reworded three principles. Principle 6 gained "unwritable by the session", forced by the
settings watcher (§ 4.2). Principles 3 and 10 changed at the maintainer's decision in § 8.4a:
critic selection became a second judgment slot, and the loop stopped carrying a model default
of its own; routing comes from the repo's `models` map and agent frontmatter, inside per-model
daily caps. The section title keeps "unchanged from v3" for the other nine.

---

## 6. Review history (what was wrong with v1, v2, v3 and v4, and what survived)

### 6.1 v1 (first draft) — key shape and why it fell
Phases: sprint-branch mode (task PRs merged by a session into an unprotected `sprint/NN`
branch, one human merge per sprint) → headless-safe skills (declared headless outcome per
AskUserQuestion site, whole-build-order anchor, bot identity) → `bin/run-sprint.sh` → move
off the Windows host.

Findings against it (three of four v1 reviewers converged, per the author; the v3 and v4
reviewers did not open their reports and re-verified the facts instead):
- **Sprint branch re-opens WB-D20 through config, not the cursor.** Task 2 boots from the
  tree task 1 wrote; on devcontainers that tree includes `.ai/project.yml` (`gates.green` is
  arbitrary shell), `.claude/`, the merge-guard hook, `CLAUDE.md`, the gate workflow. The human
  read moved to the end of the batch. *Verified by author and by both reviewers* that
  devcontainers lists those paths in `code_paths` for exactly this reason.
  **v4 note, amended in v5:** § 7.3's per-launch restore of configuration from the *protected*
  branch **partially** answers this objection for a sprint branch, if the restore source is
  `origin/main` rather than the sprint branch. It closes the config-file vector: `.claude/`,
  `CLAUDE.md`, `.ai/project.yml` and the Action's list come from `main`. It does **not** close
  the code-the-config-points-to vector: `gates.green` on devcontainers runs
  `tools/tests/run-gate-tests.sh`, `.github/scripts/build-and-test.sh` and
  `tests/template-proof.sh` from the working tree (§ 2.3), none of which is restored, so task
  2's gate run executes task 1's unreviewed edits to those paths. With both tasks on the same
  credentials the attacker's gain is persistence across the batch rather than new capability,
  which is exactly what v1's own "Known risks" listed (lines 110-113 of
  `analysis/orchestrator-plan-v1.md`: "a bad task 1 shapes tasks 2–4 before the human sees
  any of it"; "prompt-injection persistence inside a batch"). What survives against the sprint
  branch after a `main`-sourced restore: (a) **review granularity** — one fresh-session review
  of a sprint-sized diff instead of 64-line PRs, on a repo whose gate counts per-PR reviews on
  `main`; (b) **task N builds on task N−1's unreviewed code**, including the gate scripts it
  will run; (c) a driver that merges anywhere violates principle 1 by letter. These are costs
  of *review quality and in-batch persistence*, not a WB-D20 breach in the cursor sense. The
  v1 verdict stands on evidence; v3's "killed it" overstated it; v4's "answers this objection"
  overstated the other way.
- **Driver-dispatched coder + reviewer empties the fresh-session gate.** The gate counts the
  owner's ID; a headless reviewer under the owner's login mints it by construction. Per-task
  reviews into an unprotected branch satisfy nothing on main. *Verified by author.*
- **Bot identity breaks the plugin's trust predicates** (OWNER/MEMBER/COLLABORATOR allowlist)
  or becomes a trusted writer — the #122 question. *Verified by author.*
- **"Declared headless outcome per ask site" converts human authorizations into config.**
- **Whole-build-order anchor = batch-wide stall** on any issue comment. *Verified by author.*
- **Stale premises:** subagents can nest; budget flags already exist. *Verified by author.*
- Nothing on crash/resume, concurrency with the one live cursor, kill switch, audit.

Survived into v2: deterministic driver, fresh capped session per task, policy before session,
anchor per task, human-only paths, derived digest, usage governor, eval set, context diet.

### 6.2 v2 — key shape and why it was reshaped again
Steps: ledger written into the open task PR → close-time fixes → event-dispatched fresh review
under a non-counting identity → context diet → headless coder loop after #93/#122 → ops.

Findings (three reviewers; each marked with what the author verified):
1. **Ledger-in-task-PR re-opens the WB-D20 gap wider.** `cursor-sync-pr.sh` is blind to a
   task branch (prefix filter), so resume sees `cursor-sync` drift, "none" for sync PRs, gate
   NONE OPEN → **auto-start of a `next_action` nobody merged**. The human merging on GitHub
   approves the ledger's **Next:**, never the git-ignored `next_action`; WB-D20's only display
   of `next_action` is resume's offer path, which this makes dead. handoff's prose explicitly
   rejects the shape. *All verified by author* (§ 2.2 rows 6–8).
2. **Event-dispatched review cannot satisfy the gate and leaks the token.** A bot's review is
   skipped by `REVIEWER_IDS`; a routine runs as the owner and *would* count, violating
   principle 9. `ready_for_review`/`labeled` are `pull_request` activity types that run the
   PR's own workflow copy **with repository secrets**, so a task PR can edit the workflow and
   print `CLAUDE_CODE_OAUTH_TOKEN`. *Gate allowlist and workflow-copy note verified by
   author; secrets-on-same-repo-PR is GitHub semantics (reported).*
3. **Session config comes from the task branch's working tree**, and hooks reload live and
   fail open. Driver-side "read from origin/pr_base" does not reach the session. *Verified by
   author* (§ 4.2).
4. **Hooks are tripwires.** Deny rules and merge-guard do not see `gh api … /merge`,
   `python -c`, aliases. *Verified by author* (§ 2.3).
5. **Budgets unbounded on subscription.** `--max-budget-usd` is a list-price estimate blind
   to the pool. No pre-dispatch usage read is documented beyond status-line fields. *Verified
   by author.*
6. **Throughput honesty.** Dependent tasks wait on the human's merge to main, so v2 runs one
   task (or one independent wave) per sitting. v1 bought N tasks per sitting at the cost of a
   sprint-sized PR and the config gap above.
7. **Acceptance-test-first and quarantined extraction are theatre for this repo class**
   (median PR edits SKILL.md prose; the anchored trusted-author issue already is the boundary).
8. **Human-only path set incomplete** (misses `tests/`, `.gitattributes`, `.trivyignore.yaml`,
   `scripts/`, `plugins/*/{bin,hooks}`). *Verified against devcontainers' `code_paths`.*
9. Housekeeping: CLI is 2.1.228 (flag needs 2.1.259); stale nesting sentence at
   `workflow.md` L140; merge queue only on the public repos.

Placement analysis under the subscription constraint (security reviewer, author agrees; the
WSL2 row was added in v4 without a security reviewer and amended in v5 from § 4.5):

| placement | model auth | GitHub identity | secret at rest | assessment |
|---|---|---|---|---|
| local Windows host | maintainer's login | maintainer's admin `gh`, cached GPG | none new | worst: owner credentials for two orgs, hooks fail open, MSYS quirks |
| cloud routine | subscription | **the maintainer** | none | acts as the owner, so it can mint the gate; PR/release triggers only |
| GitHub Action | `setup-token` secret | Claude App (short-lived token; Contents RW, Pull requests RW, **Workflows RW**, Statuses R) | one-year OAuth token | only placement with a separate GitHub identity; a leak costs usage for a year, not repos; same-repo PR triggers expose the secret; Workflows RW must be denied by allowlist or a custom App |
| dedicated Linux host / VM running the devcontainers image | `setup-token` in its own `CLAUDE_CONFIG_DIR` | fine-grained PAT, non-owner, one repo, no admin/statuses | token on a host the maintainer controls | best for the coder loop: root-owned managed hooks the branch cannot disable; no GPG; egress limited |
| **hardened container on Docker Desktop (WSL2 backend) on the existing machine** (added in v5 after the maintainer asked; **chosen in § 8.2**; not security-reviewed, derived from Docker Desktop's architecture and `docker info` on the machine) | `setup-token` in a `CLAUDE_CONFIG_DIR` baked read-only into the image or mounted from a driver-owned volume | machine user's PAT in its own `GH_CONFIG_DIR` inside the container | token in a Docker volume inside the `docker-desktop` distro's disk image, **readable from Windows as the maintainer**; also readable by anyone who can reach the Docker socket | by construction no `/mnt/c`, no Windows interop, no Windows `PATH`, no GPG (three of § 4.5's five preconditions met without configuration); non-root `USER`, read-only rootfs and baked-in managed settings make principle 6 physical; egress via `--network none` + proxy sidecar. **Residuals:** the Docker socket is a root door (`docker exec -u root`) for any process running as the maintainer on Windows, equivalent to `wsl --user root`; shared kernel with every other container on the machine, the maintainer's dev containers included; Docker Desktop runs under the maintainer's Windows login, so the dispatch window exists only while the laptop is awake and logged in (locked is fine); the image moves to a VM or box unchanged when those residuals matter |
| **WSL2 distro on the existing machine** (added in v4; amended in v5; **dominated by the container row** — same kernel and laptop, but the isolation has to be configured instead of coming for free) | `setup-token` in its own `CLAUDE_CONFIG_DIR` inside the distro | machine user's PAT in its own `GH_CONFIG_DIR` | token on the maintainer's laptop, inside the distro, **readable from Windows via `\\wsl.localhost\`** | reaches most of the Linux-host row's properties **only with all of**: a **new** distro (the existing one carries the maintainer's `gh` identity, § 3.1), `automount.enabled=false`, `interop.enabled=false`, `appendWindowsPath=false`, a loop user **without sudo**, `[wsl2] firewall=true` plus Hyper-V firewall rules for egress. Without those, the session can read the maintainer's `gh`, GPG and Claude credentials from `/mnt/c`, can run the Windows `gh.exe`, and can `sudo` past root-owned managed settings. Residual even then: shared kernel host, laptop sleep interrupts runs, `wsl --user root` from Windows, same physical machine as the admin credentials |

### 6.3 v3 — what the v3 review corrected (applied in v4)

The v3 reviewer (a second Fable 5.1 session, 2026-10-04) verified against the repo, the
consuming repos over read-only `gh api`, the cited URLs, and re-ran `pr_analysis.py` and
`daily_usage.py`. Every § 2.2 row, § 2.3 fact, § 3 number marked *verified by author*, and
§ 4 claim marked [A] reproduced, except the items below. The reviewer did not open
`analysis/session-export/`.

Wrong in v3, fixed in v4:
1. § 4.2 said `PermissionRequest` hooks "can deny, not allow" under `--permission-prompts
   none`. headless.md says the opposite. Fixed in § 4.2; consequence added to § 7.3.
2. § 7.3 called `.claude CLAUDE.md .mcp.json .ai/project.yml` "the Action's restore list". The
   Action's list also has `.husky/`, `.gitmodules`, `.claude.json`, `.ripgreprc`,
   `CLAUDE.local.md`. Fixed in § 7.3. *(v5: the list correction stands; the reason v4 gave for
   `.husky/` — "git hooks that execute on the loop host's own commit" — does not; see § 6.4
   item 2.)*
3. § 4.2 and step 2 said the stale nesting sentence is also in `critic-gate/SKILL.md`. It is
   only in `workflow.md` L140. Fixed in both places.

Overstated or unsupported in v3, corrected in v4 (all re-verified in v5):
4. "16 cursor PRs … architect review next" → 14 by a stated rule (§ 3.1).
5. "Sprint 7: 11 PRs for 2 issues" → 9 PRs, #200–#208 (§ 3.1).
6. infrastructure-core "10" decision issues → 15 on 2026-10-04 (§ 3.1).
7. "#93/#122 due 2026-10-17" is a ledger promise; the GitHub milestone is due 2026-12-15 (§ 2.3, § 8.1).
8. "No merge/approve capability" for the Action is not in the docs and is false as an identity
   property (§ 4.4).
9. Merge-queue plan availability is unverified from the cited page (§ 4.4).
10. The `--help` grep was not evidence for the `--permission-prompts` version floor (§ 4.1).

Framing the v3 reviewer disputed, reworded in v4 (v5 verdict on each in § 6.4):
11. § 6.1's "killed it" overstated the sprint-branch case once § 7.3's restore existed (note
    added in § 6.1).
12. § 8.3 presented one-wave-per-sitting as a ceiling to "accept"; it is today's cadence
    (§ 3.1 baseline paragraph, § 8.3 rewritten).
13. Step 1's trust surface was "none"; it changes what the merged ledger records, so the WB-D
    now covers step 1 as well as step 4 (§ 7.1).
14. § 8.2 offered only host-or-nothing; a WSL2 row was added to the placement table and § 8.2.
15. § 8.5 re-opened the maintainer's stated hard constraint; moved to § 9 as a note.
16. § 3.2's token figures were not named as a proxy for window consumption; paragraph added.
17. Step 4 assumed "independent tasks" are derivable from plan-sprint's build order; plan-sprint
    emits a numbered sequence with no independence marker (`skills/plan-sprint/SKILL.md`
    L303). Dependency added to step 4 and § 7.3.

Biases the v3 reviewer named that v3 had not declared: API-token cost framing under a
subscription constraint; exit metrics that count touches, not reading time; a security posture
tuned to prompt injection over review-load; "trust surface: none" on the author's own
ceremony fix.

### 6.4 v4 — what the v4 review corrected (applied in v5)

The v4 reviewer (a third Fable 5.1 session, 2026-10-04) wrote a first-pass verdict on v4
before opening v3, then verified against the repo, the consuming repos over read-only
`gh api`, the raw text of hooks.md, settings.md and permissions.md, the other § 4 URLs, and
Microsoft's wsl-config page; re-ran `pr_analysis.py` (devcontainers) and `daily_usage.py 14`
and reproduced § 3 exactly. It did not open `analysis/session-export/`. Every § 6.3 factual
correction (items 1–10) reproduced.

Its first-pass verdict, before opening v3, was: v4 holds as a plan; steps 1–2 cheap and well
evidenced; step 4 correctly gated on § 8; three reviser judgements look wrong or half right
from the text alone (§ 8.3 conflates merge cadence with chain throughput; § 7.3's
`core.hooksPath` line is mechanically confused and the loop user's own settings file is
writable; § 6.1's note treats the restore as a full answer); step 1's WB-D looks right; the
WSL2 row is under-assessed. Verification against primary sources confirmed each of those and
added items 4, 7 and 8 below.

Wrong or overstated in v4, fixed in v5:
1. **§ 6.3 item 2's rationale for `.husky/`.** Husky hooks execute only when `core.hooksPath`
   points at `.husky`, which husky's npm `prepare` script writes into the untracked
   `.git/config`; a fresh clone never has it. No consumer has `.husky/` or `package.json`
   (§ 2.3). Restoring the Action's full list is harmless and kept; the reason is corrected.
2. **§ 7.3's `core.hooksPath` line** said `git -c core.hooksPath=/dev/null` stops ".husky/ or
   a task-branch `.git/hooks` write" executing "on commit". `git -c` binds only the driver's
   own git invocations, not the session's `git commit` in Bash, and a hook firing inside the
   session gains nothing the session's Bash tool does not already have. "A task-branch
   `.git/hooks` write" cannot exist: `.git/hooks` is untracked, and the per-task clone discards
   whatever the session wrote there. The only real exposure is driver-run git inside a clone
   the session has already touched (the post-exit `git diff` runs no hooks; a later
   `git checkout` would). Rewritten in § 7.3 as a driver-side rule with its real scope.
3. **§ 7.3 missed a live widening path.** The loop user's own `settings.json` in
   `CLAUDE_CONFIG_DIR` is writable by the session process (same user), and the settings
   watcher applies edits to `hooks` and `permissions` live (§ 4.2). A session that writes a
   `PermissionRequest` allow-hook into its own user settings widens itself mid-run; the
   post-exit hash only records it afterwards. Fixed in § 7.3 (files read-only to the session
   user; managed deny on writes under the config dir) and principle 6.
4. **§ 7.3's pre-launch hash compare** ran immediately after restoring from the same ref, so it
   checked nothing. Moved to post-exit, where it detects what the session changed.
5. **§ 6.1's v4 note** said the restore "answers this objection". It answers the config-file
   half; `gates.green` executes tree-resident scripts the restore does not touch (§ 2.3).
   Amended to "partially answers", with v1's Known risks cited.
6. **§ 8.3 / item 12: reversed.** "One wave per sitting is today's cadence" conflates the
   interval between merges with the throughput of a dependent chain. Today the human is
   present during the merge window (§ 3.1: 12:22–23:37 UTC on the busiest day), so a chain
   advances every nine minutes. The loop exists to run while they are away (§ 7.4's window),
   so a chain advances once per sitting, which is once a day. That is a real ceiling for
   dependent work. v3's "accept" framing was right; v4 was wrong to remove it. § 8.3 rewritten
   again; v4's reframing of the *real* decision as "re-open the sprint branch or not" is kept,
   because it is the right question.
7. **§ 4.4's App permissions** named only Contents and Pull requests. The installed set also
   includes Workflows RW (the #93 gap for an Action-placed loop) and Statuses R. Added.
8. **§ 4.1 / § 9 missed a platform-churn risk.** headless.md says `--bare` will become the
   default for `-p`. The subscription path depends on plain `-p`; no opt-out is documented
   yet. Added to § 4.1 and § 9.

v5 verdict on v4's judgement calls (§ 6.3 items 11–17):
- 11 (soften "killed it"): **kept, amended** — the restore is partial (item 5 above).
- 12 (§ 8.3 "nothing to accept"): **reversed** (item 6 above).
- 13 (step 1 needs the WB-D): **kept**. WB-D20's own text says a GitHub merge approves the
  ledger alone; step 1 removes that read for one step type. Small, non-zero, and it changes a
  recorded decision's property, which is what a WB-D is for. v5 adds the sharper angle neither
  v3 nor v4 named: the derived step is a fresh-session review that mints the gate under the
  owner's ID, so the PR it targets must be derived from GitHub state the session cannot shape
  (same-repo head, maintainer-authored), never from `state.json`. Written into step 1.
- 14 (WSL2 row): **kept as an option, amended** with § 4.5's preconditions. As written in v4
  it would have placed the loop on a distro that can read every credential it was meant to be
  isolated from.
- 15 (§ 8.5 → § 9 note): **kept**. A stated hard constraint is not an open decision.
- 16 (proxy paragraph): **kept**. The most useful addition in v4.
- 17 (independence marker): **kept, verified**. plan-sprint treats dependency only as a
  placement *reason* (L169, L176); the emitted build order (L303) carries no marker.

Biases the v4 reviewer named that v3 and v4 had not declared:
- Both sessions treat code.claude.com as ground truth for behaviour nobody executed, and as
  stable when it is not (`--bare` default change announced; routines in research preview;
  `--permission-prompts` 31 builds old).
- The v4 reviser showed convenience bias toward the maintainer's existing machine: it added
  and ranked second a placement it had not threat-modelled, on the host the ledger says
  already carries the maintainer's identity.
- The v4 reviser moved every disputed point toward the middle (softened v1, hardened step 1,
  added a middle placement), which reads as judgement but is also what a same-family second
  opinion tends to produce.
- The v4 reviser's § 8.3 argument committed the count-what-is-countable bias it named in the
  author: merge gaps measure the human's presence, not chain latency.

---

## 7. The plan (v5)

### 7.1 Steps

| # | change | trust surface | exit metric |
|---|---|---|---|
| 1 | **No-op handoff rule.** When the only cursor change is "review or merge PR N next", handoff writes `.ai/state.json` and skips the ledger PR; resume derives that step **from GitHub state only** (an open same-repo PR whose head was pushed by the maintainer's login and whose title or body names the anchored task issue), never from `state.json`'s `next_action`. Fix #209 (roadmap entry written before close) and #220 (dirty ledger) so a sprint close is one PR. | **small, and it needs the WB-D**: `main`'s ledger stops being the complete record during a review (WB-D20's display property), and resume gains a GitHub-derived step. Because that step is a fresh-session review that mints the gate under the owner's ID, the derivation must be from GitHub state the session cannot shape. The WB-D must say what a fresh machine with no `state.json` does, and must state the derivation rule. | cursor PRs per work PR < 0.5 on devcontainers within one week; relay PRs = 0; plus **minutes the human spends per work PR**, measured from merge timestamps, so reading load is visible |
| 2 | Fix the stale nesting sentence (`workflow.md` L140 only). Split `resume` into a lean auto-start path plus on-demand appendices (target < 20 k tokens of plugin prose per task session). Update the CLI to ≥ 2.1.259 on the host that will run anything headless. | none | prose loaded per task session measured from transcripts |
| 3 | **Fresh-session review stays human-started**, locally, as today (after step 1 it costs one session and zero PRs). Automating it is **blocked on #122 and #93**. If and when they are decided: `workflow_dispatch` from the driver only, no `pull_request*` trigger, no PR checkout, the OAuth secret in a GitHub Environment with required reviewers, tools limited to read + inline-comment, `--max-turns`, `timeout-minutes`, concurrency group. Posted under an identity **not** in any reviewer allowlist. | blocked | n/a |
| 4 | **Headless coder loop** (`bin/run-sprint.sh`, fixture-tested) running as a **hardened container built from the devcontainers image**, hosted on Docker Desktop on the maintainer's laptop to start (§ 8.2; the image is unchanged if it later moves to a VM or box). Details in 7.2–7.5. Waves of **independent** tasks; task PRs to `pr_base`; the human merges the wave in one sitting (merge queue where available; serial CI re-runs on infrastructure-core). **Prerequisite not in the plugin today:** plan-sprint emits a numbered build order with no independence marker, so either plan-sprint gains a per-issue `depends_on` (human-confirmed at planning, like the build-order slot) or the driver treats the whole order as one chain and dispatches one task per sitting. | **the same WB-D** (which human authorizations become plan-time policy, including the critic allowlist and the critic-selection judgment slot; the loop identity's trust class; the human-only path key; the independence marker — all decided in § 8.4) | a 3–4 task wave completes with no session above the context cap and spend under the ceiling; zero human touches between dispatch and the merge sitting; **and** human minutes per work PR not above the step-1 baseline |
| 5 | **Usage governor and operations** (7.4, 7.5). | none | no "hit your limit" error during the maintainer's declared hours over two weeks |
| 6 | **Eval set**: 20–50 real past tasks (from merged PRs), code-graded first, re-run per driver release; read the transcripts. | none | pass^k stable release over release |

Steps 1–2 are one milestone (five issues, the stale-sentence fix, and the WB-D's step-1 half).
Steps 4–6 are a second milestone that cannot start before the human decisions in § 8.

### 7.2 Step 4 — identities and credentials
- Model auth: `claude setup-token` minted by the maintainer, stored only on the loop host in
  its own `CLAUDE_CONFIG_DIR`. Rotate yearly; record the mint date. The token is still the
  maintainer's subscription: a leak anywhere spends their pool for up to a year, and no
  revocation procedure is documented (§ 4.3).
- GitHub: a **separate machine user** with a fine-grained PAT scoped to the one repo:
  contents + pull-requests write, **no** admin, **no** statuses, **no** workflow-file
  permission. Own `GH_CONFIG_DIR`. Its login is recorded as `orchestration.loop_identity` and
  the plugin's trust predicates treat it as **untrusted by name** (§ 8.1): write access makes
  it a COLLABORATOR, which is exactly the association `review-sandbox.sh` and
  `plan-anchor.sh` would otherwise accept.
- Allowed git/gh surface for the session: `git push origin task/*`, `gh pr create`, read
  calls. Everything else denied by `--allowedTools` + driver-supplied deny rules.
- Commits unsigned or SSH-signed with the machine identity, never the maintainer's GPG key
  (WB-D20: signature is not an authorship signal; a distinguishable committer is).
- Egress on the host limited to Anthropic and GitHub.

### 7.3 Step 4 — session configuration
- Own clone per task (never the maintainer's checkout; WB-D12 single live cursor holds).
- Before each launch, restore from `origin/{pr_base}` **the Action's full list plus this
  plugin's own config**: `.claude/ .mcp.json .claude.json .gitmodules .ripgreprc CLAUDE.md
  CLAUDE.local.md .husky/ .ai/project.yml`; remove any of them the base lacks (as the Action
  does). This closes the config-file vector only; the gate's tree-resident scripts
  (§ 2.3) still run from the task branch, which is acceptable for a task PR to `pr_base`
  (the human reviews that diff) and is the residual cost named in § 6.1 for a sprint branch.
- **Driver-side git rule.** Every git command the driver itself runs inside a clone the
  session has touched (anything after launch: the post-exit diff, any later checkout or
  fetch) runs with `-c core.hooksPath=/dev/null`, and the driver never runs `git checkout`,
  `git merge`, `git rebase` or `git commit` in such a clone. This protects the driver. It does
  not and need not reach the session's own git calls: a hook firing inside the session has
  the session's existing Bash capability and nothing more.
- Launch: `claude -p --model sonnet --max-turns N --max-budget-usd X --autocompact 100k
  --permission-mode dontAsk --permission-prompts none --allowedTools "…" --settings
  <driver-file> --setting-sources user --plugin-dir <pinned copy> --strict-mcp-config
  --output-format json --json-schema <stop-schema> "<task prompt>"`.
  `--setting-sources user` excludes project and local settings and `.mcp.json` (§ 4.1).
  Whether it suppresses project `CLAUDE.md` is **unverified**; if not, the restore step covers
  it. **Watch the `--bare` default change** (§ 4.1): when it lands, this line needs whatever
  opt-out ships with it, or the session will have no OAuth credential.
- **Every settings source the session loads is driver-owned and unwritable by the session**
  (principle 6). The reason is two documented facts together: a `PermissionRequest` hook in
  any loaded source can *allow* what `--permission-prompts none` would otherwise deny
  (§ 4.2), and the settings watcher applies edits to `hooks` and `permissions` live, in user
  and managed settings alike (§ 4.2). Concretely: the user settings in the loop's
  `CLAUDE_CONFIG_DIR` and the `--settings` file are written by the driver **and made
  read-only to the session user (owned by the driver user or root, mode 0644)** before launch;
  the restore step neutralises `.claude/` and `--setting-sources user` excludes it anyway; the
  managed settings carry a deny rule on `Write`, `Edit` and shell writes under the loop's
  `CLAUDE_CONFIG_DIR` and the `--settings` path, so the session cannot create a sibling file
  the watcher would pick up. Deny rules must **enumerate** the dangerous surface (merge,
  status, workflow-file, config-dir, human-only paths) rather than lean on `dontAsk`'s
  default, because a hook can widen only what nothing explicitly denies.
- **Post-exit, not pre-launch:** hash every settings file, hook script and the plugin copy and
  compare with the pre-launch hashes the driver recorded; any difference fails the task and
  stops the wave. (v4 ran the compare before launch, right after restoring from the same ref,
  where it could not fail.)
- Host-level, as a container (§ 8.2): root-owned `/etc/claude-code/managed-settings.json`
  carrying the deny rules and PreToolUse guards is **baked into the image**;
  `allowManagedHooksOnly: true` so no user, project, local or plugin hook runs at all; the
  container runs as a non-root `USER` with a **read-only root filesystem** (tmpfs for the
  work clone and `/tmp`), so the session cannot write any settings file at all; no bind mount
  under `/mnt` or a Windows drive; `--network none` plus an egress proxy sidecar allowing
  only api.anthropic.com and github.com. **The driver's preflight checks all of these from
  outside the container** (`docker inspect`: `User` non-root, `ReadonlyRootfs`, no `/mnt` or
  drive-letter `Mounts`, network mode, sidecar up) and refuses to dispatch when any fails.
  Residuals on the Docker Desktop host are listed in § 6.2's container row.
- Wave composition comes from the plan, not from the driver's guess: a task is dispatched in
  the same wave as another only when the human-confirmed plan marks neither as depending on
  the other (step 4's prerequisite). Absent the marker, one task per sitting.
- Task prompt: the anchored issue number, the spec comment id, acceptance criteria, target
  files, the gate command list from `origin/{pr_base}`'s `.ai/project.yml`. Never raw issue
  text beyond that.

### 7.4 Step 4/5 — the usage governor
Implementable from docs: per-task `--max-turns`, `--max-budget-usd` (proxy), `--autocompact`;
`--model` for the **coder session** taken from the repo's `models.coder`; the two judgment
slots on `models.architect`; **critics** on their own agent frontmatter `model:` (§ 8.4a); every
model's usage counted against that model's per-day cap below; `timeout` around every session;
parse `permission_denials`, `total_cost_usd`, `is_error` from the result JSON; stop on any "hit
your limit" result. Sizing note from § 3.2: today's flow already runs ≈ 34 Opus critic
subagents a day at ≈ 0.2 M cache-read each and ≈ 5 M per median Sonnet coder session, so each
per-model cap should start near today's observed load for that model, not below it.

Driver-side rules (sized from § 3.2):
- per-day session cap and per-day Opus/Fable session cap;
- dispatch only inside a declared window (e.g. 00:00–07:00 local) plus marked away-blocks,
  **and only while the Docker daemon answers and the § 7.3 preflight passes**: on the laptop
  host (§ 8.2) the window is bounded by the laptop being awake and the maintainer logged in,
  so the governor checks Docker, not just the clock, and records every window it could not use;
- reserve ≥ 50 % of the measured weekly envelope for the maintainer's interactive work;
- transcript-metered token ceiling per task and per day (sum `cache_read` + `output`);
- liveness: transcript mtime; a session silent > N minutes is killed and recorded;
- backoff and stop after the first limit error; never auto-continue.

Not implementable from docs: a reliable pre-dispatch read of remaining plan usage.

### 7.5 Step 5 — state, recovery, audit
- Driver state: append-only JSONL **outside any worktree**, owned by the driver user. GitHub
  is the source of truth, reconciled at each step (`git ls-remote` for the branch, `gh pr list
  --head` for the PR, digest marker in the PR body).
- Recovery: pushed-but-no-PR → create the PR without re-running; PR-but-no-digest → write it
  from the log.
- Kill file outside any worktree, checked before each dispatch and polled during a run (kill
  the process group). Lock file in the driver directory; `resume` refuses auto-start while
  present (needs a small plugin change).
- Per-task audit line: issue number + `updated_at` at dispatch, anchor SHA, `origin/{pr_base}`
  SHA, head SHA, PR number, session id, models used, turns, usage, cost estimate, stop reason,
  `permission_denials`, pre- and post-exit hook/settings/plugin hashes, human-only-path check
  result, fixture check result. Mirrored into the PR body by the driver's identity with the
  log line's hash.

### 7.6 Stays human
Sprint scope and spec approval (plan-sprint), every `hitl_gate`, every merge to `pr_base`,
the release tag, the decision backlog, resolving #93/#122, minting and rotating tokens,
deciding `orchestration.*` policy per repo.

---

## 8. Decisions only the maintainer can make

All four were decided by the maintainer on 2026-10-04, one at a time, after the v4 review and
before the next review pass. Each entry keeps the options that were weighed so the next
reviewer can judge the choice, then states the decision.

1. **#93 and #122 on devcontainers.** The ledger promises them by 2026-10-17; the GitHub
   milestone says 2026-12-15. Step 3 and the loop identity's trust class both wait on them.
   Nothing in this plan can decide them; the decision here is only **which date governs**,
   because steps 1–2 can ship on either and steps 4–6 cannot start before them.
   *Decided (2026-10-04):* **the ledger date, 2026-10-17, governs**, and **the loop identity
   is untrusted by name regardless of #122's outcome**: `orchestration.loop_identity` names
   the machine user, and `review-sandbox.sh trust` and `plan-anchor.sh` return untrusted for
   that login whatever its `author_association` says, so nothing the loop writes is ever
   executed locally at review or anchored as a plan without a human in between. This is the
   loop's answer to #122 for its own identity only; #122's general answer is still the
   devcontainers owner's. #93 is mitigated for the loop by PAT scope alone: a fine-grained PAT
   without the Workflows permission cannot push a change under `.github/workflows/`.
2. **Where the loop runs.** The runtime unit is a **container built from the devcontainers
   image** in every option; the decision is what hosts the Docker daemon. Options weighed:
   Docker Desktop on the existing laptop (WSL2 backend), hardened per § 7.3; the same
   container on a VM or small Linux box; a bare WSL2 distro (now dominated, § 6.2); the
   Windows host as-is (ranked last by every reviewer; not offered). Steps 1–2 pay on any host.
   *Decided (2026-10-04):* **a hardened container on Docker Desktop on the laptop, to build and
   prove step 4.** Non-negotiable: the driver's preflight (§ 7.3) runs before every dispatch
   and refuses when the container is not non-root, read-only, bind-mount-free under `/mnt` and
   drive letters, and behind the egress sidecar. Accepted residuals, recorded in § 6.2: the
   Docker socket is a root door for anything running as the maintainer on Windows; the token
   volume is readable from Windows; shared kernel with the maintainer's other containers; the
   dispatch window exists only while the laptop is awake and logged in. The image moves to a
   VM or always-on box unchanged when the `depends_on` measurement (§ 8.3) shows the loop
   earns one. No security reviewer has looked at this placement; § 9 records that.
3. **Wave granularity.** Keeping the human merge as the only approval means a dependent chain
   advances one task per sitting. Today, with the human present, a chain advances every nine
   minutes (§ 3.1); under the loop, which runs while they are away, it advances once a day.
   For *independent* tasks the wave model is strictly better than today. So the decision is:
   **accept one dependent task per sitting**, and let plan-sprint's `depends_on` marker
   (step 4's prerequisite) maximise the independent share of each sprint; or **re-open v1's
   sprint branch** for N dependent tasks per sitting, at the cost § 6.1's amended note
   describes (review granularity, in-batch persistence through the gate's tree-resident
   scripts, a driver that merges somewhere). If the sprint branch is re-opened, the minimum
   protections are § 7.3's config restore from `origin/main` per session, a batch of two,
   per-task digests in the sprint PR, a fresh-session review of the sprint PR as a whole, and
   the gate scripts for task N run from `origin/main`'s copy rather than the sprint branch.
   *Decided (2026-10-04):* **accept the ceiling; add a human-confirmed `depends_on` marker to
   plan-sprint.** Principle 1 stands as written. The driver dispatches waves of tasks the plan
   marks independent and one task per sitting otherwise. Over the first two or three sprints
   the driver records what share of dispatched tasks were independent; the sprint branch is
   re-opened only if that share turns out low, and then with every protection listed above.
4. **Which human authorizations become plan-time policy** and what step 1's no-op handoff rule
   records on `main` and derives from GitHub — the content of the one WB-D.
   *Decided (2026-10-04), in four parts:*
   - **4a. Policy set, model routing and judgment slots.** `orchestration.*` in each consuming
     repo's `.ai/project.yml` carries: `critics` (an **allowlist** of critic agents the loop
     *may* spawn, not a fixed must-spawn list), `round_cap` (critic re-run rounds before a task
     stops as non-converged; 2), `human_only_paths`, `loop_identity`, and plan-sprint's
     `depends_on` marker per issue. **There is no loop-specific model key and no loop
     default.** Model routing is the plugin's existing doctrine, unchanged: the coder session
     runs on `models.coder`, the two judgment slots run on `models.architect`, and each critic
     runs on its own frontmatter `model:` (the thing that already sets what a critic runs as;
     this plugin's three pin `opus`, a consuming repo's custom critic may pin anything). The
     maintainer's instruction, recorded for the next reviewer: **"the most appropriate model
     for the task and purpose"**, not Opus by default and not Sonnet by default; the `models`
     map and the agent frontmatter are where "appropriate" is decided, per repo, by a human,
     and the governor's per-model caps (§ 7.4) bound whatever that routing costs.
     **Critic selection is a named LLM judgment slot:** the loop runs critic-gate's existing
     proposal logic (which critics the diff warrants, from the skill's table) unattended and
     spawns the result, filtered by the allowlist. Principles 3 and 10 are amended to say so.
     The second-opinion round on another model stays human-only and is unavailable to the loop.
     The maintainer's reason, also recorded: "LLM judgement is part of what I am looking for
     here to produce quality code at times where I am not here to babysit."
   - **4b. Step 1 on a fresh machine, or on disagreement.** resume derives the review step
     from GitHub state only (open same-repo PR, head pushed by the maintainer's login, names
     the anchored task issue) and **auto-starts it only when `state.json` exists and names the
     same PR**. With no `state.json`, or when the two disagree, resume shows the derived step
     and waits. Two independent sources must agree before a step that mints the gate under the
     owner's ID runs unattended. Fails closed, like every other auto-start condition.
   - **4c. Shape.** One WB-D number, written in two halves on the step-1 / step-4 boundary;
     the step-1 half lands with milestone 1, the loop half is added when milestone 2 starts.
   - **4d. Where policy lives.** In each consuming repo's `.ai/project.yml` under
     `orchestration.*`, WB-D17 style: every key present and explicit; `schema-complete`
     refuses a loop dispatch when any is absent, so the repo's own record says what the loop
     may do to it.

---

## 9. Known gaps, unverified claims, and places the author may be biased

- **Never executed:** `claude -p` under `--permission-prompts none` with this plugin; a hook
  deny under `dontAsk`; `--setting-sources user` effect on project `CLAUDE.md`;
  `--max-budget-usd` behaviour on subscription auth; what a `-p` run reports at a usage limit
  (reported: error exit); whether `--autocompact 100k` degrades task quality; whether the
  settings watcher honours file ownership (§ 7.3 assumes a read-only file simply cannot be
  edited, which is a filesystem fact, not a Claude Code one); `allowManagedHooksOnly` on the
  chosen host.
- **Not security-reviewed:** the container placement chosen in § 8.2 and its hardening list in
  § 7.3 were written by the v4 reviewer from Docker Desktop's architecture and one `docker
  info`, after the maintainer asked whether a container would do. No security reviewer has
  seen it. The next reviewer should attack it: the egress sidecar design, what `docker exec`
  from Windows can reach, and whether a read-only rootfs really stops every settings write
  the watcher could pick up.
- **Platform churn:** `--bare` is announced as the future default for `-p` (§ 4.1); routines
  are in research preview; `--permission-prompts` landed 31 builds after the installed CLI.
  Every § 4 fact has a date and should be re-fetched before anything is built.
- **Reported, not re-read by author:** Agent SDK auth statement (re-read by both reviewers);
  merge-queue plan availability (page has no statement); auto-mode availability; errors.md
  limit behaviour; prompt-caching.md subagent TTL; the Flatt write-up of an issue-body
  injection exfiltrating a token from a Claude Action run
  (https://flatt.tech/research/posts/poisoning-claude-code-one-github-issue-to-break-the-supply-chain/).
- **Data limits:** transcript scan de-duplicated by `message.id`; one mirrored directory
  excluded; no reconciliation with Anthropic's accounting; "peak context" is input+cache
  tokens on the largest turn, not the API's own measure.
- **Possible over-correction:** the plan forbids any driver merge anywhere. A narrowly-scoped
  merge into a *throwaway integration branch whose config and gate scripts both come from
  `origin/main`* might be defensible; § 6.1's note and § 8.3 now say so, but nobody has
  designed it.
- **Possible under-correction:** the no-op handoff rule (step 1) leaves `main`'s ledger one
  step stale during a review; a fresh machine with no `state.json` resumes from `main`. The
  author believes resume's GitHub-derived step covers it; not proven. v4 moved this into the
  WB-D; v5 added the derivation rule to step 1.
- **Fable preference:** the maintainer routes architect work to Fable (memory note) while the
  repo's `models.architect` says `opus`. The loop takes the map literally (§ 8.4a), so under
  the loop the judgment slots run on Opus unless the map changes; a reviewer may think that is
  too little Fable or too much.
- **Same-family revision, three times.** v4 and v5 were each produced by a Fable 5.1 session
  acting as reviewer and then as editor. The factual corrections in § 6.3 and § 6.4 were
  checked against primary sources; the judgement calls (§ 6.3 items 11–17 and § 6.4's verdicts
  on them) are two same-family opinions, one of which reversed the other on § 8.3. The next
  review must be on another model family, and it should read § 6.4 item 6 with the most
  suspicion: it is the one place v5 overruled v4 on judgement rather than fact.
- **Note, not a decision (moved from v3's § 8.5):** the subscription-only constraint is the
  maintainer's stated requirement and the plan honours it. For the record, the constraint is
  what forces plain `-p` (hooks and plugins load) over `--bare`, and makes `--max-budget-usd` a
  proxy rather than a cap; an API key for the loop host alone would remove both. The plan does
  not ask for that; it records the cost.
- **The author did not read** bounty-infra's or infrastructure-core's threat models in full,
  nor devcontainers' `docs/threat_model.md` beyond grep hits. Neither did the v3 or v4
  reviewer.

---

## 10. Appendix — artefacts and how to regenerate the numbers

Analysis scripts and the v1–v4 drafts are beside this file in `docs/proposals/analysis/`
(originals in the authoring session's scratchpad):
`C:\Users\SR116\AppData\Local\Temp\claude\c--Users-SR116-projects-glunk-works-claude-workbench\d2bb1d4a-393d-4799-95ed-47e30db7c48c\scratchpad\`
- `pr_analysis.py <repo>-prs.json …` — PR classification, open→merge timing, cadence.
  Input: `gh pr list -R <repo> --state all --limit 200 --json number,title,createdAt,mergedAt,state,additions,deletions,changedFiles,files`.
- `usage_analysis.py <since>` — per-project/model/session usage from `~/.claude/projects`.
- `peak_ctx.py <since>` — per-session peak context; subagent totals.
- `daily_usage.py <days>` — daily envelope, de-duplicated; per-session medians by kind/model.
- `orchestrator-plan-v1.md` … `orchestrator-plan-v4.md` — the earlier drafts as reviewed.
  v3 is the document § 6.3 was run against; v4 is the document § 6.4 was run against.

The v3 reviewer re-ran `pr_analysis.py` (devcontainers, claude-workbench) and
`daily_usage.py 14` on 2026-10-04 and reproduced § 3 within one PR. The v4 reviewer re-ran
`pr_analysis.py` (devcontainers) and `daily_usage.py 14` on 2026-10-04 and reproduced § 3
exactly (Fable cache reads 11 M/day where v4 printed 10). The relay-PR count in both used
`'review next' in title.lower()` over the same 200-PR pull.

Memory note written by the authoring session: `token-spend-data-lives-in-transcript-usage-fields.md`
(where usage data lives; the mirrored directory).

The eight subagent reports and the authoring session's transcript are exported under
`docs/proposals/analysis/session-export/` (git-ignored). Its README says **do not read unless
required**: it is context for the maintainer, not review input. § 6 condenses the reports.
Neither the v3 nor the v4 review session's transcript is exported; their reasoning exists only
as § 6.3 and § 6.4. The v4 reviewer's first-pass verdict, written before it opened v3, is
summarised at the top of § 6.4.
