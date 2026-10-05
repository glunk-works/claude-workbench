# Sprint orchestrator for `way-of-working` — plan v6, with its review history

**Status:** proposal, nothing built, nothing filed. Untracked file; not part of any release.
**Written:** 2026-10-04, by a Claude Code session running Fable 5.1, for the maintainer of
`glunk-works/claude-workbench` and for a *separate* Claude session that will review this
document for context and bias.
**Revised:** 2026-10-04 (v4), by a second Fable 5.1 session that reviewed v3 and applied the
corrections in § 6.3. **Revised again:** 2026-10-04 (v5), by a third Fable 5.1 session that
reviewed v4 against primary sources and applied the corrections in § 6.4. **Revised a third
time:** 2026-10-04 (v6), by an **Opus 5.5** session — the first reviewer from outside the
author's model family — that reviewed v5 against primary sources and applied the corrections in
§ 6.5. The maintainer also corrected one fact during that review: the host is an **always-on
desktop, not a laptop** (§ 4.5, § 6.2, § 8.2).
**Supersedes:** plan v1–v5 (all summarised in § 6; none was filed).
**Decisions:** § 8.1–8.4 were **decided by the maintainer on 2026-10-04** after the v4
review, each marked *Decided* with the reasoning and the alternatives weighed. The v6 review
did **not** change any decision; where it found a decision inconsistent with the rest of the
plan it added a *v6 review note* under that decision, and it raised **two new open decisions**
(§ 8.5 merge restriction on GitHub, § 8.6 devcontainers' Docker-dependent gate) that the
maintainer has not yet answered.

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
- **v6 is the first cross-family revision** (Opus 5.5). It wrote a first-pass verdict on v5
  before opening v4 or v3, then verified against the raw hooks.md, settings.md, permissions.md,
  headless.md and the mods admin page, the three consumers' live rulesets, devcontainers'
  `.ai/project.yml`, and re-ran `pr_analysis.py` (devcontainers). Its claims are marked **[O]**
  in § 4. It did not open `analysis/session-export/`. Its own likely biases: it reads the
  plan as a security reviewer first (most of its findings are in § 7.3 and § 8.2), it is the
  same family as the plan's three Opus critics, and it found what it predicted in its first
  pass, which is either confirmation or confirmation bias. It did **not** execute anything
  either: no container was built, no ruleset was changed, no `claude -p` was run.

Suggested checks for the reviewer:
1. Re-derive the § 3 PR counts from GitHub (`gh pr list --state all --limit 200 --json …`)
   for one repo other than devcontainers. Three reviewers have reproduced devcontainers.
2. Re-read the live rulesets (§ 2.2 last row, § 2.3) and decide whether § 6.5 item 1 — the
   loop identity **can** merge today on a 0-approval ruleset — is right. It is the finding
   v6 ranks highest; if it is wrong, § 8.5 should be withdrawn.
3. Check § 6.5 item 2 against devcontainers' `.ai/project.yml` `gates.green`: does the
   hardened container really need a Docker socket to run that gate, and is § 8.6's framing
   of the choice complete?
4. Read the settings, permissions and mods pages raw and check § 7.3's v6 rewrite: is
   `allowManagedHooksOnly` + `allowManagedPermissionRulesOnly` + Claude Code's sandbox the
   right control set, and what does `allowManagedPermissionRulesOnly` do to `--allowedTools`
   and `--settings` allow rules (v6 did not find out)?
5. Attack the § 7.3 egress and credential design as rewritten in v6 (internal network plus a
   dual-homed proxy; token exfiltration over the allowed GitHub egress).
6. Judge § 6.5's adjudication of § 8.3: v6 sides with v5 on direction but says the ceiling's
   cause is § 7.4's away-only dispatch window, not principle 1. Is that right, and is
   merge-triggered dispatch during a sitting (§ 7.4) a real option or a way around the human?
7. § 8's decisions are the maintainer's. Check whether v6's review notes under them are fair
   or whether v6 smuggled a re-decision in as a "note" — especially the deterministic critic
   floor under § 8.4a, which the maintainer has not confirmed.
8. Read § 7.3 as an attacker again. v4 found the watcher, v6 found the config-dir unlink, the
   `permissions.allow` merge, and git config execution on driver-run fetch. Look for the next.

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
| **All three repos the loop would touch first require 0 approving reviews** (`required_approving_review_count: 0`, no bypass actors) on `main`: claude-workbench (above), devcontainers (id 24183176), bounty-infra (`rules/branches/main`). Each also has `require_extra_approval_for_unattributed_changes: true`, whose semantics v6 did not look up. Consequence: any identity with Contents write can merge a PR whose required checks are green. Principle 2 depends on this (§ 6.5 item 1, § 8.5). *[O], read live 2026-10-04.* | `gh api …/rulesets/…`, `gh api repos/glunk-works/bounty-infra/rules/branches/main` |

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
  `bash tests/template-proof.sh`. This matters for § 6.1 and § 8.3. *Verified by v4 reviewer.*
  **Five of the eight need a Docker daemon** (v6): hadolint, Trivy and zizmor via
  `docker run`, `build-and-test.sh local` (builds all three images and smoke-tests them) and
  `template-proof.sh` (brings up the template with the devcontainer CLI). The file's own
  comment says "Needs Docker, git, jq, Go 1.26.3, node with npm". The remaining three are
  shellcheck, `go test` and `run-gate-tests.sh`. This matters for § 8.2 and § 8.6: the
  session cannot run devcontainers' gate inside a container without Docker access. *[O]*
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

**v6:** the ceiling comes from § 7.4's *away-only* dispatch window, not from principle 1.
The loop adds to the daytime flow rather than replacing it: the human can still work a chain
interactively at today's pace. What the loop cannot do under the current window is advance a
chain past its first link. A dispatch triggered by the human's merge *during* a sitting would
let a chain advance at review cadence without the human dispatching each item (the original
complaint, § 1), at the cost of loop sessions drawing on the usage window while the human
works. § 7.4 lists it as an option. **Nothing in § 3 measures how much of past sprint work
was dependent**; the § 8.3 measurement is the first time anyone will know.

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
where noted, not a summary); **[O]** verified by the v6 (Opus) reviewer from the raw page on
2026-10-04.

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
  honoured for this event; the decision goes through the `decision` object. A hook's allow
  does not override a deny rule: hooks.md's PermissionRequest decision table says "Deny and ask
  rules are still evaluated, so a hook returning `"allow"` doesn't override a matching deny
  rule" [O]. (v5 cited the `PermissionDenied` section for this; that event fires "when auto
  mode denies a tool call" and is not the evidence. Corrected in v6.) A hook's `allow` may also
  carry `updatedPermissions` entries (`addRules`, `removeRules`, `replaceRules`, `setMode`)
  with a `destination` of `session`, `localSettings`, `projectSettings` or `userSettings`, so
  a hook can **persist** an allow rule, or remove a deny rule, in any non-managed source [O].
  Only managed deny rules are out of its reach. **Consequence for § 7.3:** a hook in any loaded
  settings source can widen the session from "denied because nobody can answer" to "allowed",
  for every call the driver did not explicitly deny. So the driver must (a) own every settings
  source the session loads, (b) keep them unwritable by the session for the session's
  lifetime, because the watcher applies edits live, and (c) enumerate the dangerous surface in
  deny rules rather than lean on `dontAsk`'s default. v3 had this inverted ("can deny, not
  allow"); v4 fixed the direction; v5 adds the bound and the watcher. [R][V] v6 sharpens (a)
  and (b): the dependable way to own them is to make non-managed sources *irrelevant*
  (`allowManagedHooksOnly`, `allowManagedPermissionRulesOnly`, deny rules in managed settings
  only), because (b) cannot be met by file permissions in a directory the session must write
  (next bullets). [O]
- Deny rules win over allow rules and over `bypassPermissions`. [S] permissions.md; the same
  rule is stated in devcontainers' `merge-guard.sh` header. [V] permissions.md (raw): "Rules
  are evaluated in order: deny, then ask, then allow"; "a managed settings deny can't be
  overridden by `--allowedTools`". [O]
- **Allow rules merge across scopes.** settings.md: Claude Code "merges `permissions.allow`
  across scopes, unless your organization sets `allowManagedPermissionRulesOnly`." So a
  writable user `settings.json` widens the session through `permissions.allow` alone, with no
  hook involved, and `allowManagedHooksOnly` does not stop that. [O] What
  `allowManagedPermissionRulesOnly` does to `--allowedTools` and `--settings` allow rules was
  **not** checked.
- **The watcher also loads new files.** settings.md: "Claude Code also loads a settings file
  you create mid-session if its folder existed when the session started." [O]
- **`CLAUDE_CONFIG_DIR` holds writable state.** settings.md: with it set, "Claude Code then
  stores your settings, session history, and plugins there", and `.claude.json` (sign-in
  session, per-project state) is a file Claude Code "writes for itself". So the config dir
  cannot be read-only to the session user, and a root-owned file in a directory the session
  user can write can be unlinked and recreated (POSIX directory semantics). [O]
- **Bash deny rules are not a boundary.** permissions.md: a Bash rule "covers the invocation
  Claude usually produces and isn't a security boundary around the program"; "For filesystem
  and network enforcement that doesn't depend on the command text, use sandboxing." Claude
  Code's sandbox applies OS-level filesystem and network limits to Bash, PowerShell and
  Monitor commands and their children. [O] permissions.md § How permissions interact with
  sandboxing; whether its Linux backend runs inside an unprivileged container was not checked.
- **Mods** (plugins that run code inside Claude Code; on by default from v2.1.287) are a
  second widening path parallel to hooks: with no managed policy, a mod "that Claude writes
  during a session" loads, and a mod can approve a call an `ask` rule would prompt for.
  Where managed settings exist, deny rules hold over mods; `allowManagedHooksOnly` stops
  user-installed mods from loading. [O] https://code.claude.com/docs/en/plugins/mods/admin.md

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
- **v6 additions** (from Docker Desktop's documented behaviour, not re-fetched, and not
  executed on this machine):
  - Docker Desktop shares Windows drives with the engine for bind mounts. Any process that
    can reach the Docker socket can `docker run -v C:\Users\<user>:/x …` and read the
    maintainer's gh, GPG and Claude credentials. "No `/mnt/c` by construction" holds only for
    a container that has **no** socket access. A container given the socket (for example to
    run devcontainers' gate, § 2.3) has every credential § 4.5 lists, as root.
  - `host.docker.internal` and the bridge gateway reach services listening on the Windows
    host. An egress allowlist must cover them, not only the public internet.
  - **The host is an always-on desktop, not a laptop** (maintainer, 2026-10-04). Sleep is
    not a constraint. Docker Desktop still runs under the maintainer's Windows login, so after
    a reboot (for example a Windows Update restart) nothing dispatches until someone logs in,
    unless Docker Desktop is configured to start without one.

---

## 5. Design principles (unchanged from v3)

1. **The orchestrator never merges to `pr_base`.** Every approval that lands on main is a
   human merge of a task-sized PR. No sprint branch, no driver merges anywhere.
2. **The human's merge is the only approval, as a property of credentials and repository
   rules, not prose.** The loop's GitHub identity cannot merge, cannot post commit statuses,
   cannot push to `main`, has no admin. Hooks and deny rules are defence in depth, never the
   control. **v6:** a PAT with Contents write can merge a green PR on a ruleset that requires
   0 approvals (§ 2.2), which all three first-wave repos do today. So "cannot merge" is not a
   credential property on its own; it needs a **ruleset change** (§ 8.5) before step 4 runs.
   Until then the principle is false and the plan must say so.
3. **Deterministic driver** (fixture-tested `bin/` scripts, WB-D10). LLM judgment only in
   **two named slots**, each with `--json-schema` output: (a) **critic selection** — which
   critics the diff warrants, using critic-gate's own table, filtered by the
   `orchestration.critics` allowlist (§ 8.4a); (b) **stop classification**. Nothing else.
   (v3–v4 named only slot b; the maintainer added slot a in § 8.4a.) **v6 recommendation,
   not yet confirmed by the maintainer (§ 8.4a note):** the driver computes a deterministic
   **floor** from critic-gate's path-keyed rows (`code_paths` → architect and security-critic;
   `load_bearing_docs` → docs-consistency; newly added doc → docs-consistency), and slot (a)
   may only **add** critics to it, never remove them. Slot (a) reads a diff written by a
   session that read issue text, so as written it can be steered to select no critics.
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
   paths restored from `origin/{pr_base}` before every launch; every control that must hold
   lives in **managed settings** on a read-only path (`allowManagedHooksOnly`,
   `allowManagedPermissionRulesOnly`, the deny rules), so whatever the session writes into
   its own writable config dir cannot widen it (v6; v5 relied on read-only files in a
   writable directory, § 6.5 item 3); hashes recorded after exit.
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
    default** (§ 8.4a), transcript-metered token ceiling, stop on any limit error. A per-model
    cap that trips mid-task (for example the Opus cap after the coder finished but before its
    critics ran) **stops the task without opening a PR**; it never ships with fewer critics
    than the floor (v6).
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

v6 amended principle 2 (repository rules, not credentials alone, § 8.5) and annotated
principle 3 with a recommended deterministic floor that the maintainer has not confirmed.
Principle 6's "unwritable by the session" is now met by making non-managed settings sources
**irrelevant** rather than unwritable (§ 7.3), because the config directory must stay
writable (§ 4.2).

---

## 6. Review history (what was wrong with v1–v5, and what survived)

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
  **v6 note:** for a *task PR to `pr_base`* the tree-script residual is nil. The session
  already has Bash, CI runs the PR's own copy of those scripts anyway, and the human reviews
  the diff. For a *sprint branch* it is persistence across the batch. On devcontainers it
  would also be persistence **with Docker access**, because `build-and-test.sh` and
  `template-proof.sh` drive the Docker daemon (§ 2.3), which is root-equivalent on the host
  (§ 4.5). That strengthens the case against re-opening the sprint branch on devcontainers.
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
| **hardened container on Docker Desktop (WSL2 backend) on the existing always-on desktop** (added in v5 after the maintainer asked; **chosen in § 8.2**; reviewed for the first time in v6, from documentation and config only — nothing was built) | the `setup-token` credential in the container (env or `.credentials.json`) | machine user's PAT in its own `GH_CONFIG_DIR` inside the container | token in a Docker volume inside the `docker-desktop` distro's disk image, **readable from Windows as the maintainer**; also readable by anyone who can reach the Docker socket; **and readable by the session itself** (same user), which can send it out over the allowed GitHub egress, for example into a PR body on a public repo | **only while the container has no Docker socket:** no `/mnt/c`, no Windows interop, no Windows `PATH`, no GPG. Managed settings baked into a read-only `/etc` make the controls physical; the session's writable config dir does not (§ 7.3, v6). Egress through an `--internal` network and a dual-homed proxy (v5's `--network none` + sidecar cannot work as written, § 6.5 item 4). **Residuals:** the Docker socket is a root door (`docker exec -u root`, `docker cp`, `docker run -v C:\…`) for any process running as the maintainer on Windows, **including the maintainer's own interactive Claude Code sessions**; shared kernel with every other container on the machine; **devcontainers' gate needs Docker (§ 2.3), and giving the container the socket removes every property in this cell (§ 8.6)**; OAuth token exfiltration over the allowed egress (one-year token, no documented revocation, § 4.3); Docker Desktop runs under the maintainer's Windows login, so a reboot pauses dispatch until login. v5 listed "laptop sleep"; the host is an always-on desktop, so that residual is withdrawn. Moving the image to a VM or separate box is justified by the **security** residuals (socket, shared kernel, admin credentials on the same machine), not by availability |
| **WSL2 distro on the existing machine** (added in v4; amended in v5; **dominated by the container row** — same kernel and machine, but the isolation has to be configured instead of coming for free) | `setup-token` in its own `CLAUDE_CONFIG_DIR` inside the distro | machine user's PAT in its own `GH_CONFIG_DIR` | token on the maintainer's laptop, inside the distro, **readable from Windows via `\\wsl.localhost\`** | reaches most of the Linux-host row's properties **only with all of**: a **new** distro (the existing one carries the maintainer's `gh` identity, § 3.1), `automount.enabled=false`, `interop.enabled=false`, `appendWindowsPath=false`, a loop user **without sudo**, `[wsl2] firewall=true` plus Hyper-V firewall rules for egress. Without those, the session can read the maintainer's `gh`, GPG and Claude credentials from `/mnt/c`, can run the Windows `gh.exe`, and can `sudo` past root-owned managed settings. Residual even then: shared kernel host, a reboot pauses runs until login, `wsl --user root` from Windows, same physical machine as the admin credentials |

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

### 6.5 v5 — what the v6 (Opus 5.5, cross-family) review corrected (applied in v6)

The v6 reviewer wrote a first-pass verdict on v5 before opening v4 or v3. It then verified
against: the raw hooks.md, settings.md, permissions.md and headless.md; the mods admin page;
the live rulesets of claude-workbench, devcontainers and bounty-infra; devcontainers'
`.ai/project.yml`; and the plugin files cited in § 2. It re-ran `pr_analysis.py`
(devcontainers) and reproduced § 3.1 exactly (one more cursor PR had merged since: 69 where
v5 printed 68). It did not open `analysis/session-export/`.

Its first-pass verdict, before opening v4 or v3: v5 holds as a sequencing plan. Steps 1–2
are cheap and well evidenced, step 3 is correctly blocked, and § 8.4b is the best addition.
Step 4's security story is weaker than it reads: principle 2 contradicts § 7.2's PAT scope;
the container hardening contradicts itself (`--network none` plus a sidecar; a read-only
rootfs while the config dir has to be writable; `allowManagedHooksOnly` doesn't stop
`permissions.allow`); devcontainers' gate needs Docker; the driver git rule misses
config-driven execution; the OAuth token can leave over the allowed egress. On § 8.3, v5's
logic is sound, but the ceiling limits what the loop adds rather than being a regression,
and nothing measures how much work is dependent. Verification confirmed all of these except
the git point, which it narrowed (item 6).

Wrong or overstated in v5, fixed in v6:
1. **Principle 2 is false on all three first-wave repos today.** § 4.4 already said Contents
   + Pull requests write "is enough to merge through the API", and § 7.2 grants the loop
   exactly that. Every ruleset requires 0 approvals (§ 2.2). On claude-workbench and
   bounty-infra the loop can merge its own green PR. On devcontainers it can merge in the
   window between the owner's review minting `architect-review` and the human's merge. Only
   deny rules stop it, and § 6.2 item 4 calls those tripwires. Principle 2 amended; new open
   decision § 8.5.
2. **The chosen placement cannot run devcontainers' gate.** Five of eight `gates.green`
   steps need Docker (§ 2.3). Inside the § 7.3 container the session either skips the gate
   or is given the socket. The socket is root on the `docker-desktop` VM, and through Docker
   Desktop's drive sharing it reaches every Windows credential (§ 4.5, v6 additions). No
   earlier pass checked the motivating repo's gate against the placement. New open decision
   § 8.6.
3. **§ 6.4 item 3's fix (read-only settings files plus a managed Bash deny on the config
   dir) was half overbuilt and half underbuilt.**
   - Overbuilt: `allowManagedHooksOnly` alone closes the hook path, including mods the session
     writes.
   - Underbuilt: (a) `permissions.allow` from user settings still merges in, and only
     `allowManagedPermissionRulesOnly` stops that. (b) `CLAUDE_CONFIG_DIR` must be writable
     (session history, `.claude.json`), so a root-owned 0644 file in it can be unlinked and
     recreated. (c) A Bash deny "isn't a security boundary" per permissions.md.
   - § 7.3 rewritten so non-managed sources are irrelevant rather than unwritable.
4. **The egress design could not work as written.** With `--network none` the container has
   only loopback and cannot reach a sidecar. Sharing the sidecar's network namespace gives the
   session the proxy's unrestricted egress. Replaced with an `--internal` network and a
   dual-homed proxy, and the preflight check changed to match. Separately, github.com is
   allowed and three of the repos are public, so the session can exfiltrate the one-year
   OAuth token it can read; the Action scrubs env for this reason. Added as a residual with
   mitigations in § 7.2 and § 7.3.
5. **§ 4.2 cited the wrong evidence for the bound.** `PermissionDenied` is an auto-mode
   event. The bound itself holds, on hooks.md's PermissionRequest decision table. Also added:
   a hook's `updatedPermissions` can persist or remove rules in any non-managed source.
6. **§ 7.3's driver-side git rule was still too narrow.** v5 was right against v4: `git -c`
   in the driver does not bind the session, and husky needs `core.hooksPath` from npm's
   `prepare`. But `core.hooksPath=/dev/null` does not neutralise a `.git/config` the session
   wrote: `core.fsmonitor`, `credential.helper`, `core.sshCommand` and `url.<x>.insteadOf` run
   or redirect on the "later … fetch" v5 still allowed. If the driver runs outside the
   container, that is a way out of the container. Rewritten: the driver takes the post-exit
   diff from the GitHub compare API and never runs git in a clone the session touched.
7. **Smaller inconsistencies.**
   - The launch line hard-coded `--model sonnet` against § 8.4a's "no loop default". It now
     reads `models.coder`.
   - § 8.1 said #93 is mitigated "by PAT scope alone". A PAT without the Workflows permission
     still edits `.github/scripts/*`, which the PR's own CI runs; the mitigation is that plus
     `human_only_paths` covering `.github/`. Note added.
   - § 8.1 said steps 4–6 wait on #93/#122, while its decision makes the loop independent of
     #122. Note added.
   - § 8.4a's unattended critic selection changes critic-gate's own contract ("spawn NOTHING
     yet… the human confirms or trims the list", `skills/critic-gate/SKILL.md` L47–51), not
     only principle 3. The WB-D must amend the skill. Note added.
8. **The host is an always-on desktop**, not a laptop (maintainer correction). The "laptop
   awake" residual is withdrawn, and § 8.2's condition for moving the image is restated in
   terms of security rather than availability.

v6 verdict on § 6.3 items 11–17 and § 6.4's verdicts on them:
- 11: **v5 right** (the restore is partial). For a task PR the residual is nil; for a sprint
  branch it is persistence, and on devcontainers persistence with Docker access (§ 6.1 v6
  note).
- 12 / § 6.4 item 6: **v5 right on direction, wrong on cause.** v4's "nothing to accept"
  fails, because the loop adds nothing to a chain past its first link. But v5 compared the
  loop with a human who is present, as if the loop replaced daytime work. The ceiling comes
  from § 7.4's away-only window, not from principle 1, and merge-triggered dispatch during a
  sitting (§ 7.4) was offered by neither reviser. § 3.1 does not measure dependency share.
- 13: v5 right; § 8.4b is the right strengthening.
- 14: v5 right against v4, but v5 then repeated v4's error with the container row (item 2).
- 15, 16, 17: both right; 17 re-verified (`skills/plan-sprint/SKILL.md` L303).

Biases the v6 reviewer named that none of the earlier passes declared:
- **Tool-centric framing.** All three Fable passes tried to make principle 2 true inside
  Claude Code configuration. None read the GitHub rulesets, which is where principle 2
  actually lives.
- **Accretion.** Each revision added mitigations. None asked whether devcontainers, the repo
  whose 1.53 cursor ratio motivates the work, can host the loop at all.
- **Convenience bias, repeated.** v5 named it in v4's WSL2 row, then wrote "principle 6
  physical" for the container row from one `docker info`.

---

## 7. The plan (v6)

### 7.1 Steps

| # | change | trust surface | exit metric |
|---|---|---|---|
| 1 | **No-op handoff rule.** When the only cursor change is "review or merge PR N next", handoff writes `.ai/state.json` and skips the ledger PR; resume derives that step **from GitHub state only** (an open same-repo PR whose head was pushed by the maintainer's login and whose title or body names the anchored task issue), never from `state.json`'s `next_action`. Fix #209 (roadmap entry written before close) and #220 (dirty ledger) so a sprint close is one PR. | **small, and it needs the WB-D**: `main`'s ledger stops being the complete record during a review (WB-D20's display property), and resume gains a GitHub-derived step. Because that step is a fresh-session review that mints the gate under the owner's ID, the derivation must be from GitHub state the session cannot shape. The WB-D must say what a fresh machine with no `state.json` does, and must state the derivation rule. | cursor PRs per work PR < 0.5 on devcontainers within one week; relay PRs = 0; plus **minutes the human spends per work PR**, measured from merge timestamps, so reading load is visible |
| 2 | Fix the stale nesting sentence (`workflow.md` L140 only). Split `resume` into a lean auto-start path plus on-demand appendices (target < 20 k tokens of plugin prose per task session). Update the CLI to ≥ 2.1.259 on the host that will run anything headless. | none | prose loaded per task session measured from transcripts |
| 3 | **Fresh-session review stays human-started**, locally, as today (after step 1 it costs one session and zero PRs). Automating it is **blocked on #122 and #93**. If and when they are decided: `workflow_dispatch` from the driver only, no `pull_request*` trigger, no PR checkout, the OAuth secret in a GitHub Environment with required reviewers, tools limited to read + inline-comment, `--max-turns`, `timeout-minutes`, concurrency group. Posted under an identity **not** in any reviewer allowlist. | blocked | n/a |
| 4 | **Headless coder loop** (`bin/run-sprint.sh`, fixture-tested) running as a **hardened container built from the devcontainers image**, hosted on Docker Desktop on the maintainer's always-on desktop to start (§ 8.2; the image is unchanged if it later moves to a VM or box). Details in 7.2–7.5. **Two further prerequisites (v6), both open decisions:** a ruleset change so the loop identity cannot merge (§ 8.5), and an answer to how devcontainers' Docker-dependent gate runs (§ 8.6). Waves of **independent** tasks; task PRs to `pr_base`; the human merges the wave in one sitting (merge queue where available; serial CI re-runs on infrastructure-core). **Prerequisite not in the plugin today:** plan-sprint emits a numbered build order with no independence marker, so either plan-sprint gains a per-issue `depends_on` (human-confirmed at planning, like the build-order slot) or the driver treats the whole order as one chain and dispatches one task per sitting. | **the same WB-D** (which human authorizations become plan-time policy, including the critic allowlist and the critic-selection judgment slot; the loop identity's trust class; the human-only path key; the independence marker — all decided in § 8.4) | a 3–4 task wave completes with no session above the context cap and spend under the ceiling; zero human touches between dispatch and the merge sitting; **and** human minutes per work PR not above the step-1 baseline |
| 5 | **Usage governor and operations** (7.4, 7.5). | none | no "hit your limit" error during the maintainer's declared hours over two weeks |
| 6 | **Eval set**: 20–50 real past tasks (from merged PRs), code-graded first, re-run per driver release; read the transcripts. | none | pass^k stable release over release |

Steps 1–2 are one milestone (five issues, the stale-sentence fix, and the WB-D's step-1 half).
Steps 4–6 are a second milestone that cannot start before the human decisions in § 8.

### 7.2 Step 4 — identities and credentials
- Model auth: `claude setup-token` minted by the maintainer, stored only on the loop host in
  its own `CLAUDE_CONFIG_DIR`. Rotate yearly; record the mint date. The token is still the
  maintainer's subscription: a leak anywhere spends their pool for up to a year, and no
  revocation procedure is documented (§ 4.3). **v6:** the session runs as the same user that
  holds the credential, so it can read it. Mitigations: pass it only to the `claude`
  process, never exported into the session's Bash environment (as the Action scrubs
  subprocess env); deny `Read` on the credential path in managed settings; and, if Claude
  Code's sandbox runs in the container, put the credential outside the sandbox's readable
  set. None of these is proven; the residual is recorded in § 6.2.
- GitHub: a **separate machine user** with a fine-grained PAT scoped to the one repo:
  contents + pull-requests write, **no** admin, **no** statuses, **no** workflow-file
  permission. Own `GH_CONFIG_DIR`. Its login is recorded as `orchestration.loop_identity` and
  the plugin's trust predicates treat it as **untrusted by name** (§ 8.1): write access makes
  it a COLLABORATOR, which is exactly the association `review-sandbox.sh` and
  `plan-anchor.sh` would otherwise accept.
- **The PAT's scope does not stop a merge** (v6). Contents write is required to push a branch
  and is also sufficient to merge a green PR on a 0-approval ruleset (§ 2.2). The control
  that makes "cannot merge" true is on the repository side (§ 8.5); the PAT scope and the
  deny rules are defence in depth.
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
- **Driver-side git rule (rewritten in v6).** The driver runs **no git command at all** in a
  clone the session has touched. The session can write that clone's `.git/config`, and
  `core.hooksPath=/dev/null` does not neutralise `core.fsmonitor`, `credential.helper`,
  `core.sshCommand` or `url.<x>.insteadOf`, which run or redirect on status, checkout and
  fetch. The post-exit human-only-path and fixture checks read the diff from GitHub instead
  (`gh api repos/{repo}/compare/{base}...{head}` on the pushed head), or from a fresh clone
  the driver makes after exit. The session's own git calls are out of scope: anything a
  hook or config entry runs inside the session has the session's existing Bash capability
  and nothing more. (v5 was right that v4's `git -c` line could not bind the session.)
- Launch: `claude -p --model <models.coder> --max-turns N --max-budget-usd X --autocompact 100k
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
  and managed settings alike (§ 4.2).
  **v6 mechanism.** v5 made the user `settings.json` read-only and added a managed Bash deny
  on writes under the config dir. That does not hold: the config dir must be writable
  (session history, `.claude.json`), so a root-owned file in it can be unlinked and
  recreated; Bash deny rules are not a boundary; and `permissions.allow` widens without any
  hook (§ 4.2). The control is instead to make every non-managed source **irrelevant**:
  - `allowManagedHooksOnly: true` in managed settings: no user, project, local or plugin
    hook runs, and no user-installed or session-written mod loads.
  - `allowManagedPermissionRulesOnly: true` in managed settings: allow rules from user,
    project or local settings do not merge in. **Unverified:** whether this also discards
    `--allowedTools` and `--settings` allow rules. If it does, the session's allowlist moves
    into managed settings, and the `--settings` file carries only non-permission keys.
  - Every deny rule lives in managed settings, so neither a hook's `updatedPermissions` nor a
    rewritten user file can remove it (§ 4.2). Deny rules still **enumerate** the dangerous
    surface (merge, status, workflow-file, human-only paths, `Read` on the credential path)
    rather than lean on `dontAsk`'s default.
  - If Claude Code's sandbox runs inside the container (unverified, § 9), enable it with a
    filesystem write allowlist of the work clone and `/tmp` and a network allowlist matching
    the proxy. It is the documented OS-level control for Bash.
  - The restore step still neutralises `.claude/`, and `--setting-sources user` still
    excludes it.
  The session may then write whatever it likes into its own config dir; nothing it writes
  is consulted for hooks or permissions.
- **Post-exit, not pre-launch:** hash every settings file, hook script and the plugin copy and
  compare with the pre-launch hashes the driver recorded; any difference fails the task and
  stops the wave. (v4 ran the compare before launch, right after restoring from the same ref,
  where it could not fail.)
- Host-level, as a container (§ 8.2):
  - Root-owned `/etc/claude-code/managed-settings.json` carrying the keys above, the deny
    rules and the PreToolUse guards is **baked into the image**.
  - The container runs as a non-root `USER` with a **read-only root filesystem**, so
    `/etc` and the managed settings cannot change.
  - Writable state lives only on a tmpfs or volume holding the work clone, `/tmp` and
    `CLAUDE_CONFIG_DIR`. v5 said the read-only rootfs meant "the session cannot write any
    settings file at all"; that was wrong, because the config dir is writable. The managed
    keys above are what make that safe.
  - **No Docker socket** mounted or reachable, and no bind mount under `/mnt` or a Windows
    drive.
  - **Egress** through a user-defined `--internal` Docker network whose only other member is
    a proxy container, which is also attached to an external network. The proxy allows only
    the hosts Claude Code and `gh`/`git` need (api.anthropic.com and the auth and telemetry
    hosts Claude Code uses; github.com, api.github.com and the git/object hosts). It denies
    `host.docker.internal` and the host gateway. The gate's own fetches widen the list per
    repo (bounty-infra's `hatch` and `tofu init` need PyPI and the OpenTofu registry, § 8.6).
    That list is repo-specific, so it belongs in `orchestration.*`, not in the plugin
    (WB-D2), and every host on it is another exfiltration channel. v5's `--network none` plus
    a sidecar could
    not work: `none` leaves only loopback, and sharing the sidecar's namespace gives the
    session the proxy's own unrestricted egress.
  - **The driver's preflight checks all of these from outside the container** (`docker
    inspect`: `User` non-root, `ReadonlyRootfs`, no `/mnt` or drive-letter `Mounts`, no
    `docker.sock` mount, `NetworkMode` is the internal network, proxy up; plus one in-container
    probe that a non-allowlisted host is unreachable) and refuses to dispatch when any fails.
  - Residuals on the Docker Desktop host are listed in § 6.2's container row.
  - **devcontainers is not dispatchable on this placement until § 8.6 is decided**, because
    five of its eight gate steps need the Docker daemon.
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
  **and only while the Docker daemon answers and the § 7.3 preflight passes**. The host is an
  always-on desktop (§ 4.5), but Docker Desktop runs under the maintainer's login, so after
  a reboot the daemon is down until login. The governor checks Docker, not just the clock,
  and records every window it could not use;
- **option, not decided (v6): merge-triggered dispatch during a sitting.** When the human
  merges task N of a dependent chain, the driver dispatches N+1 at once rather than waiting
  for the night window, so a chain advances at review cadence while the human is present
  without them dispatching each item. It keeps principle 1 intact; the cost is loop sessions
  drawing on the usage window during the human's working hours (the 50 % reserve below still
  applies). This is the option § 8.3's "ceiling" leaves out;
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

Items 1–4 were decided by the maintainer on 2026-10-04, one at a time, after the v4 review
and before the v5 review. Each entry keeps the options that were weighed so the next reviewer
can judge the choice, then states the decision. The v6 review added *review notes* under
items 1–4 without changing any decision, and raised items 5 and 6, which are **open**.

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
   *v6 review note (not a change to the decision):*
   - "By PAT scope alone" overstates it. A PAT without Workflows still pushes edits to
     `.github/scripts/*` and anything else a workflow runs from the PR's tree, and
     `pull_request` runs use the PR's copy with the repository's secrets. The loop's
     mitigation for #93 is the PAT scope **plus** `human_only_paths` covering `.github/`
     (principle 8: in-session deny plus the post-exit diff check).
   - This decision makes the loop independent of #122, so the opening sentence's "steps 4–6
     cannot start before them" now holds for step 3 and for #93's general fix, not for the
     loop's own trust class. The maintainer may want to say whether step 4 still waits on
     2026-10-17.
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
   *v6 review note (not a change to the decision):*
   - The host is an **always-on desktop**, not a laptop (maintainer, 2026-10-04). The "awake
     and logged in" residual reduces to "logged in after a reboot". The machine is already
     always on, so the condition for moving the image should be the **security** residuals
     (socket, shared kernel, admin credentials on the same machine), not the `depends_on`
     measurement.
   - As written, the decision cannot serve devcontainers. Five of eight gate steps need
     Docker (§ 2.3), and giving the container the socket removes every property the
     decision's non-negotiables rely on (§ 4.5). That is now open decision § 8.6.
   - The non-negotiable "behind the egress sidecar" is replaced by "on an internal network
     behind a proxy" (§ 7.3), because the sidecar design could not work.
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
   *v6 review note (not a change to the decision):* the decision is consistent with
   principle 1.
   - The ceiling it accepts comes from § 7.4's away-only dispatch window, not from
     principle 1. Merge-triggered dispatch during a sitting (§ 7.4 option) would advance
     chains at review cadence with principle 1 untouched, and should be weighed **before**
     the sprint branch is re-opened.
   - On devcontainers, re-opening the sprint branch would also carry task N−1's edits to
     Docker-driving gate scripts into task N's gate run (§ 6.1 v6 note).
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
     *v6 review note — recommendation awaiting the maintainer, not a change to the decision:*
     - critic-gate's table is keyed on paths for its first two rows (`code_paths`,
       `load_bearing_docs`) and on a mechanical `--diff-filter=A` for the third
       (`skills/critic-gate/SKILL.md` L69–73). The driver can compute those rows without a
       model.
     - The judgment slot's input is a diff written by a session that read issue text. As
       recorded, it can be steered to select **no** critics, and nothing catches that.
     - Recommended: the path-keyed rows form a deterministic **floor**, and the LLM slot may
       only **add** critics within the allowlist (the table's "and/or" choices, repo-local
       critics, the security-critic call on a new doc). That keeps LLM judgment where the
       maintainer wants it and keeps principle 3's driver deterministic where an injection
       could otherwise reduce review.
     - Running critic-gate's proposal unattended also changes that skill's contract ("spawn
       NOTHING yet… the human confirms or trims the list", L47–51), so the WB-D's loop half
       must amend the skill as well as principles 3 and 10.
     - Cost: every task now carries at least one Opus judgment session plus up to three Opus
       critics × `round_cap` 2. § 5 principle 10 now says what happens when the Opus cap
       trips mid-task: stop, no PR.
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
5. **Open (raised by the v6 review, not yet answered): how the loop identity is stopped from
   merging.** Every first-wave ruleset requires 0 approvals (§ 2.2), so a Contents-write PAT
   can merge a green PR. Principle 2 is false until one of these lands. Options:
   - **(a) Restrict updates to `main` to bypass actors**, with the owner as the only bypass
     actor. The loop cannot merge at all. The human merges as today, but now via bypass.
     Check what that does to required checks and to resume's cursor-sync merge before
     choosing.
   - **(b) Require one approving review.** The loop cannot approve its own PR, but the human
     now approves *and* merges (one extra click per PR). It also changes how the human's
     merge counts as approval in the plugin's doctrine (`workflow.md` § Integration gate),
     which a WB-D would have to record.
   - **(c) A required check that fails when the PR's author is `orchestration.loop_identity`
     and the merger is not the owner.** GitHub does not expose the merger to a check before
     the merge, so this is likely not implementable. Listed for completeness.
   - **(d) Accept deny rules as the control** and amend principle 2 to say so. That
     contradicts § 6.2 item 4.
   *v6 recommendation:* (a) or (b), decided per repo, recorded in `orchestration.*` and checked
   by the driver's preflight via `gh api` before any dispatch. Note:
   `require_extra_approval_for_unattributed_changes: true` is already set on all three
   rulesets, and v6 did not establish what it does. Read GitHub's documentation for it before
   choosing; it may already require an approval for the loop's unsigned commits.
6. **Open (raised by the v6 review, not yet answered): devcontainers' Docker-dependent gate.**
   Five of eight `gates.green` steps need the Docker daemon (§ 2.3). Options:
   - **(a)** The session runs only the non-Docker gate steps (shellcheck, `go test`,
     `run-gate-tests.sh`), and CI's required checks (which already run the Docker steps on
     every PR) are the gate of record. The digest states which local steps ran. This changes
     "same quality bar" for devcontainers to "same bar, enforced in CI".
   - **(b)** Rootless Docker-in-Docker or a separate builder VM reachable only from the
     container. More isolation work; untested here.
   - **(c)** Mount the host socket. **Not recommended:** it is root on the `docker-desktop`
     VM and reaches every Windows credential (§ 4.5), which voids § 8.2's non-negotiables.
   - **(d)** Exclude devcontainers from the loop and start with claude-workbench and
     bounty-infra, whose gates need no Docker daemon in the session. bounty-infra's gate is
     `hatch run lint:check`, `hatch run test:run`, `tofu fmt` and
     `tofu init -backend=false && tofu validate` (read 2026-10-04). It needs PyPI and the
     OpenTofu provider registry through the proxy (§ 7.3). The repo whose cursor
     ratio motivated the plan would then be the last to benefit.
   *v6 recommendation:* (a), with `gates.green` gaining a schema-level marker for which steps
   need Docker, so the driver selects the steps without naming a repo-specific value
   (WB-D2). Run (d) as the first proving ground either way.

---

## 9. Known gaps, unverified claims, and places the author may be biased

- **Never executed:** `claude -p` under `--permission-prompts none` with this plugin; a hook
  deny under `dontAsk`; `--setting-sources user` effect on project `CLAUDE.md`;
  `--max-budget-usd` behaviour on subscription auth; what a `-p` run reports at a usage limit
  (reported: error exit); whether `--autocompact 100k` degrades task quality; whether the
  settings watcher honours file ownership (§ 7.3 assumes a read-only file simply cannot be
  edited, which is a filesystem fact, not a Claude Code one; v6 replaced that reliance, § 7.3);
  `allowManagedHooksOnly` on the chosen host.
- **Never executed or looked up (added in v6):**
  - what `allowManagedPermissionRulesOnly` does to `--allowedTools` and `--settings` allow
    rules;
  - whether Claude Code's sandbox runs inside an unprivileged, read-only container;
  - what the rulesets' `require_extra_approval_for_unattributed_changes` does;
  - whether option (a) in § 8.5 interacts badly with resume's cursor-sync merge;
  - which hosts Claude Code itself needs beyond api.anthropic.com (auth, telemetry, update
    checks) for the proxy allowlist;
  - Docker Desktop's drive sharing, taken from its documented behaviour and not tested on
    this machine.
- **Security-reviewed once, on paper:** the container placement chosen in § 8.2 and its
  hardening list in § 7.3 were written by the v4 reviewer from Docker Desktop's architecture
  and one `docker info`. The v6 (Opus) reviewer attacked them from documentation and config
  and found the problems in § 6.5 items 2–4. Nobody has built the container or tried to break
  out of it. Treat § 7.3's host bullet as a design to test, not a tested design.
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
- **Same-family revision, three times; one cross-family pass.** v4 and v5 were each produced
  by a Fable 5.1 session acting as reviewer and then as editor. v6 is the first revision from
  another family (Opus 5.5), and it also edited the plan, so it is a reviewer-turned-editor
  too. A second Opus pass is cross-family to the author but same-family to v6. It should read
  § 6.5 with the suspicion earlier reviewers applied to § 6.4, especially:
  - § 6.5 item 1 (the merge capability), which v6 ranks highest;
  - the § 8.4a deterministic-floor recommendation, which runs partly against the
    maintainer's stated wish for LLM judgment;
  - the § 8.3 "cause is the dispatch window" reading, the one place v6 overruled v5 on
    judgement rather than fact.
- **Host:** the maintainer corrected v5's "laptop" to an always-on desktop during the v6
  review. Any remaining availability argument in this plan should be read with that in mind.
- **Note, not a decision (moved from v3's § 8.5):** the subscription-only constraint is the
  maintainer's stated requirement and the plan honours it. For the record, the constraint is
  what forces plain `-p` (hooks and plugins load) over `--bare`, and makes `--max-budget-usd` a
  proxy rather than a cap; an API key for the loop host alone would remove both. The plan does
  not ask for that; it records the cost.
- **The author did not read** bounty-infra's or infrastructure-core's threat models in full,
  nor devcontainers' `docs/threat_model.md` beyond grep hits. Neither did the v3, v4 or v6
  reviewer.

---

## 10. Appendix — artefacts and how to regenerate the numbers

Analysis scripts and the v1–v5 drafts are beside this file in `docs/proposals/analysis/`
(originals in the authoring session's scratchpad):
`C:\Users\SR116\AppData\Local\Temp\claude\c--Users-SR116-projects-glunk-works-claude-workbench\d2bb1d4a-393d-4799-95ed-47e30db7c48c\scratchpad\`
- `pr_analysis.py <repo>-prs.json …` — PR classification, open→merge timing, cadence.
  Input: `gh pr list -R <repo> --state all --limit 200 --json number,title,createdAt,mergedAt,state,additions,deletions,changedFiles,files`.
- `usage_analysis.py <since>` — per-project/model/session usage from `~/.claude/projects`.
- `peak_ctx.py <since>` — per-session peak context; subagent totals.
- `daily_usage.py <days>` — daily envelope, de-duplicated; per-session medians by kind/model.
- `orchestrator-plan-v1.md` … `orchestrator-plan-v5.md` — the earlier drafts as reviewed.
  v3 is the document § 6.3 was run against; v4 is the document § 6.4 was run against; v5 is
  the document § 6.5 was run against.

The v3 reviewer re-ran `pr_analysis.py` (devcontainers, claude-workbench) and
`daily_usage.py 14` on 2026-10-04 and reproduced § 3 within one PR. The v4 reviewer re-ran
`pr_analysis.py` (devcontainers) and `daily_usage.py 14` on 2026-10-04 and reproduced § 3
exactly (Fable cache reads 11 M/day where v4 printed 10). The relay-PR count in both used
`'review next' in title.lower()` over the same 200-PR pull. The v6 reviewer re-ran
`pr_analysis.py` (devcontainers) on 2026-10-04 and reproduced § 3.1 (cursor PRs merged 69
where v5 printed 68, one later merge); it did not re-run `daily_usage.py`.

Memory note written by the authoring session: `token-spend-data-lives-in-transcript-usage-fields.md`
(where usage data lives; the mirrored directory).

The eight subagent reports and the authoring session's transcript are exported under
`docs/proposals/analysis/session-export/` (git-ignored). Its README says **do not read unless
required**: it is context for the maintainer, not review input. § 6 condenses the reports.
No review session's transcript (v3, v4 or v6) is exported; their reasoning exists only as
§ 6.3, § 6.4 and § 6.5. Each reviewer's first-pass verdict, written before it opened the
previous draft, is summarised at the top of its section.
