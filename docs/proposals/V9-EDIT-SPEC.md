# Edit spec: sprint orchestrator plan v8 → v9

**For:** a fresh Claude Code session that applies this spec to
`docs/proposals/sprint-orchestrator-plan-v8.md` and saves the result as
`docs/proposals/sprint-orchestrator-plan-v9.md` (copy v8 to `analysis/orchestrator-plan-v8.md`
first, as every earlier pass did with its predecessor).
**Written:** 2026-10-04 by the session that reviewed v8 (Opus 5.5) and recommended the five
decisions below. That session did **not** edit the plan; the maintainer chose (decision 5)
that a different session would, so the recorder is not the reviewer.

## Rules for the editing session

- **Apply, do not re-review.** Every decision below is the maintainer's, taken one at a time on
  2026-10-04. Do not reopen them. If an instruction here is impossible to apply as written
  (a line moved, a sentence no longer exists), apply its intent and list the deviation in your
  hand-back message, not in the plan.
- **Do not re-verify evidence** unless an edit cannot be made without it. Every citation below
  was read from the primary source on 2026-10-04 by the reviewing session; mark those facts
  **[O3]** in the plan (add `[O3]` to the § 4 legend: "verified by the v9 (third Opus)
  reviewer from the raw page or live API on 2026-10-04").
- **The tests ran before you** (maintainer's amendment to D5). The three tests (§ 8.5 checks
  1–3, § 8.7 `isolated` probe, § 8.8 `--restricted` launch) were run by an earlier session and
  recorded in `docs/proposals/V9-TEST-RESULTS.md`, together with any decision the maintainer
  took because of a result. Read it after this spec. Where a result or a post-test decision
  contradicts an item here, **the results file wins**; apply it and say so in your hand-back.
  Record each result in v9 as **[T]** (add to the § 4 legend: "tested on this machine on
  <date>"), add a "Tested (<date>)" note under § 8.5, § 8.7 and § 8.8, and move each
  answered item out of § 9's "never executed" lists. No full review round follows v9; the
  only review is a diff check against this spec and the results file. Say so in § 0 and § 9.
- Read-only on GitHub. No commits unless the maintainer asks.

## Naming

- This review's section is **§ 6.8 "v8 — what the v9 (third Opus 5.5) review corrected
  (applied in v9)"**, after § 6.7.
- Decisions taken now are marked *Decided (2026-10-04, after the v9 review)*.
- Header: add a "Revised a sixth time" sentence. The v9 **review** was an Opus 5.5 session
  (same family as v6 and v7, cross-family to v8 and the author); the v9 **edit** was a
  separate session (name your own model). The reviewer recommended and the maintainer took
  five decisions; for the first time since v5, the reviewer did not write the draft.

## Decisions (write each under its § 8 item, and carry it into § 5, § 7, § 9)

### D1. The driver spawns the critics (§ 8.4a, principle 3, § 7.3, § 7.4, § 8.8)

*Decided (2026-10-04, after the v9 review):* each critic (the floor ones and those slot (a)
adds) runs as **its own capped session started by the driver**:
`claude -p --restricted --agent <critic> --plugin-dir <pinned copy> --model <frontmatter model>
--max-turns N --max-budget-usd X --json-schema <findings-schema> …` against the pushed diff.
The coder session gets **no `Agent` tool and no `--plugin-dir`**.

Why: the plan never said which process spawns critics (§ 8.4a L1899–1901 says only "the loop
… spawns the result"), and the v8 launch line put `Agent` in `--tools` (L1553), i.e. the coder
session would spawn its own reviewers. The deterministic floor exists because that session
read issue text and can be steered; if it spawns the critics, it decides whether the floor
runs. Driver-spawned critics make the floor mechanical, put each critic under its own model,
turn cap and budget (what § 7.4's per-model caps assume), and give critics a fresh view of the
diff. Costs, to record: more sessions per task with no shared cache (some extra Opus spend,
bounded by the existing caps); the `round_cap` fix loop needs the driver to hand findings to a
new or resumed coder session; more driver code. Options weighed: (B) coder spawns in-session,
driver audits the transcript afterwards — after the fact, on evidence the session wrote; (C)
leave unspecified — § 8.8's test would be built around the wrong question.

Consequences to write:
- Principle 3: the driver computes the floor **and spawns it**; slot (a)'s additions are
  spawned by the driver too.
- § 7.3 launch line (coder): `claude -p --restricted --tools "Bash,Read,Edit,Write,Glob,Grep"
  --model <models.coder> …` — drop `Agent` and `--plugin-dir`. Add a second line for a critic
  launch as above.
- § 8.8 and § 9: the two `--restricted` unknowns become (1) `--tools Bash` restores Bash and
  it runs under the sandbox; (2) **plugin agents load** under `--restricted --agent
  --plugin-dir`, observable from the result JSON's `plugins` and `plugin_errors` fields
  (headless.md:244). Delete "whether `--plugin-dir` skills load": the v8 line had no `Skill`
  tool (`--tools` gives only "the ones you list", cli-reference.md:136, tools-reference.md
  Glob section; `Skill` is a separate tool, tools-reference.md:52), and under D1 the coder
  loads no plugin.

### D2. § 8.5's scratch test: checks 1–3 now (§ 8.5, § 7.1 step 4, § 4.4, § 9)

*Decided (2026-10-04, after the v9 review):* the proving round runs **checks 1–3**. Check 3
reads **both** `mergeStateStatus` and `viewerCanMergeAsAdmin` (GraphQL `PullRequest`: "Indicates
whether the viewer can bypass branch protections and merge the pull request immediately";
read by schema introspection 2026-10-04) as the admin **and** as the machine user. The
driver's preflight re-reads `viewerCanMergeAsAdmin` and `mergeStateStatus` as the machine
user on each loop PR, a live per-PR check of principle 2. Check 4 (merge queue) becomes a
**precondition for ever enabling a merge queue**; check 5 (auto-merge) a **precondition for
devcontainers' #139**, run when devcontainers joins under § 8.6 (e).

Why: no live ruleset on the four repos has a merge-queue rule; no workflow in devcontainers,
bounty-infra or claude-workbench has a `merge_group` trigger, and GitHub says required checks
do not run in the queue without one (docs.github.com, managing a merge queue, L32). All four
`main` rulesets have `strict_required_status_checks_policy: false`, so a wave merges serially
with no re-run between merges. Auto-merge is #139 only, and devcontainers is excluded from the
first round. Options weighed: (B) keep five and build queue/auto-merge scaffolding on the
scratch repo — answers questions about features no repo uses; (C) drop 4–5 entirely — loses
the record of why they are needed.

Consequences to write:
- § 7.1 step 4: delete "merge queue where available **and where the § 8.5 test shows it merges
  under the restrict-updates rule**; serial CI re-runs on infrastructure-core". The human
  merges the wave serially; strict status checks are off on every repo, so no re-runs.
- § 4.4 `--admin` paragraph: add that `--admin` is **not only** client-side when a merge queue
  is enabled: gh then merges directly instead of enqueueing (`merge.go` L549–551
  `shouldAddToMergeQueue` returns false under `UseAdmin`; L298–304). Moot while no queue
  exists; it matters for the check-4 precondition.
- § 8.5 contingency ("(e) plus fork-safe required checks"): add its cost honestly. Making
  bounty-infra's `tofu-plan` fork-safe cuts against `plan-infra.yml` L11–18, which scopes its
  read-only credentials to the `pull_request` OIDC subject on purpose; it is a CI trust-model
  redesign, not a toggle.
- § 9: replace the merge-queue and auto-merge unknowns with the two preconditions.

### D3. § 8.2's trigger: host config, private repos allowed (§ 8.2, § 7.3, § 7.4, § 6.2 row)

*Decided (2026-10-04, after the v9 review):* **"public repos only on this host" is dropped.**
Private repos (infrastructure-core) may run on the Docker Desktop host under two conditions:
(1) **one machine-user PAT per repo**, never one token covering both a private and a public
repo; (2) the private repo's clone holds **no live secrets** (to be checked before
infrastructure-core's first dispatch). `orchestration.placement` moves out of the repos'
`.ai/project.yml` into the **driver's own config on the loop host** (beside the kill file and
lock, § 7.5), one value per host. An **away-block** is a one-shot record with an end time and
a maximum length, consumed by the driver when the block ends, and written to the audit log.
The move to a VM or box is still required before any **standing window**, for every repo.

Why — record the maintainer's question verbatim, because it changed the decision: **"what is
the major risk with the private repo on docker desktop? I am already working within docker
with the private repos on this desktop."** The reviewer's answer, which the maintainer
accepted:
- The admin credentials are reachable from the loop container only by escaping it (shared
  kernel → Docker VM → Windows files). That risk is identical for a public or a private repo;
  public-only did not reduce it.
- The private repo's integrity is protected by the same controls as any repo: the loop cannot
  merge (§ 8.5), the human reviews every PR.
- What is private-specific is **confidentiality** of its source via a prompt-injected session.
  Its channels are narrow: egress is Anthropic (which already receives the code from
  interactive sessions), GitHub and the gate's registries; on GitHub the session can write only
  where its token can, so a PAT scoped to the private repo alone has nowhere public to push.
  Injection is also less likely there: only org members can file issues on a private repo.
- What really differs from the maintainer's current work is that the loop runs
  **unattended**, holds the one-year OAuth token, and reads issue text with no one watching.
  That applies to every repo and is what the standing-window move trigger is about.
- infrastructure-core's `block-secret-bearing-files` push ruleset (blocks `*.tfvars`,
  `*.tfstate`, `*.pem`, `*.key`, …) suggests secrets are already kept out; its history was not
  checked.

Also record why placement leaves the repos: it is a host fact; four repos could hold four
different claims about one machine, and the governor would trust whichever repo it was
dispatching. Record the honest limit of away-blocks: the governor cannot prove a block was
written by the human; a nightly scheduled block would be a standing window it cannot tell
apart. One-shot consumption makes automating it a deliberate act, and the audit log makes a
nightly pattern visible. Options weighed: (A) keep public-only and enforce it in the preflight
(visibility read live) — enforces a rule that protects little; (B) visibility check only,
placement stays per repo, block mechanism left to driver design; (C) as written — public-only
unenforced, prose only.

Consequences to write:
- § 8.2: add the decision under the post-v8 one; strike "for public repos only" from the
  post-v7 decision's effect with a pointer, and amend "moves … before it runs against
  infrastructure-core (private) or runs unattended nights as a matter of routine" to the
  standing-window trigger alone.
- § 7.3: delete the bullet "**Public repos only on this host** … infrastructure-core waits for
  the move" and replace it with the two conditions; the preflight checks that the PAT's
  repository access is exactly the dispatched repo.
- § 7.4 and § 7.1 step 4: `orchestration.placement` → the driver's host config; describe the
  one-shot block.
- § 8.4d / § 4 (schema): `placement` is the one orchestration value that is **not** in
  `.ai/project.yml`; say why.
- § 6.2 container row: the private repo is no longer excluded; the residuals are unchanged.

### D4. § 8.9 demoted to host hygiene (§ 8.9, § 4.5, § 9)

*Decided (2026-10-04, after the v9 review):* not a blocker. § 4.5 records:
- the Windows file is **documented**, not inferred: "On Windows, credentials are stored in
  `%USERPROFILE%\.claude\.credentials.json`" (authentication.md:206);
- the Ubuntu distro's gh falls back to plain text when no credential store exists (gh's own
  help: "If a credential store is not found … gh will fallback to writing the token to a plain
  text file"), so a plain token there is likely;
- the socket residual **does not apply to the loop container**, which is never given the
  socket; anything that holds the socket already runs as the maintainer on Windows and can
  read both files without Docker (`\\wsl.localhost\Ubuntu\…`, § 4.5's own bullet). Whether
  § 4.5 says "write-then-execute" or "direct read" changes no control in § 7.

Logging the WSL gh out (its ledger entry already says it cannot push) is optional hygiene.
Options weighed: (B) keep the maintainer's check — costs the maintainer's time for an answer
that changes no control; (C) drop the paragraph — loses a true, cheap hygiene point. § 9
drops the item from the open list.

### D5. Who writes v9

*Decided (2026-10-04, after the v9 review):* a fresh session applies this spec, with only a
diff check of v9 afterwards. *Amended by the maintainer the same day:* **the three tests run
first**, in their own session, so that their results inform v9 rather than being bolted on
after it; any decision a result forces is taken before v9 is written. Options weighed: (B) the reviewing
session writes v9 — the reviewer-then-editor pattern a fifth time, and it recommended all five
decisions and revised one in conversation; (C) an addendum only — § 7 and § 8 would contradict
it. Record under § 8.10's successor (a new § 8.11 is fine) and in § 0.

## Editorial bundle (no decision changes; apply all)

1. **`--settings` must be unwritable — a v8 regression.** v7 said the driver file sits
   "outside every writable path" (v7 L1274); v8's launch paragraph dropped it. Under
   `--restricted` it is the only non-managed source left: `env` from `--settings` is
   re-applied live (settings-reference.md, "When Claude Code applies `env` values"), and
   `apiKeyHelper` is read **only** from `--settings` (permissions.md:726), with helpers running
   outside the sandbox (sandboxing.md:43). Fix: pass `--settings` as **inline JSON**, or as a
   root-owned file on the read-only root filesystem; say so in the launch paragraph,
   principle 6 and the § 7.3 host bullet. Record in § 6.8 that a v8 edit outside § 8 changed a
   decision's effect without saying so.
2. **Sandbox protected paths.** § 4.2 (v8 L534–544) and § 7.3 (L1621–1626) say the sandbox
   denies Bash writes to the `--plugin-dir` copy. It does not: that entry is in the
   **permission system's** protected list (permission-modes.md:646); sandboxing.md's Protected
   paths section says "The permission system has its own protected paths … the sandbox's list
   applies to a command that is already running", and its four groups contain no plugin dir.
   Correct both places. Restate the sandbox's remaining reasons: the network allowlist, the
   credential `denyRead`, and Bash writes to the clone's `.claude/` and the config dir.
   (Under D1 the coder has no plugin dir anyway.)
3. **§ 9 L2221–2222** ("moot under `--restricted`" for user CLAUDE.md, agents, skills):
   unsupported — cli-reference.md:123 speaks only of settings. What makes them moot is the
   **fresh `CLAUDE_CONFIG_DIR` per task**. Reword.
4. **§ 8.6 CI-wait rule and § 9's image-scope item.** The verdict is readable from outside: the
   jobs API (`GET /repos/{repo}/actions/runs/{run}/jobs`) gives each step's `conclusion`. On the
   last six devcontainers PR runs, "Build and test all images" and "Prove the template" read
   `skipped`, guarded by `if: steps.scope.outputs.build == '1'` (`build.yml` L64, L71). Replace
   "step outputs or summary" (v8 L2111–2112) with this, and close the § 9 item. (v8's § 2.3
   claim that image-scope's path list covers image-shaping files holds: build context is
   `images/<flavor>`, so `COPY tools/…` is `images/base/tools/`.)
5. **§ 2.2 layering precedent.** infrastructure-core 24418824 is `target: push`
   (`file_extension_restriction`, `file_path_restriction`, `conditions: null`), not a branch
   ruleset, so it is not precedent for § 8.5 (a). The real precedent, which v8 missed:
   devcontainers `release-tags` (24335229), a separate ruleset with an `update` rule and
   bypass actor `RepositoryRole` 5 (admin), `bypass_mode: always`, on tags `v*` and
   `devc-automerge-*`. Also list the other live rulesets v8 omitted: claude-workbench
   `protected-release-tags` (20554576) and `release-tag-creation` (23936220, Integration
   bypass); infrastructure-core's disabled Copilot review ruleset (19359056).
6. **§ 7.3 egress.** The proxy is dual-homed; its external network still reaches its own
   gateway, so the proxy's allowlist refuses IP literals and `host.docker.internal`. And
   Docker Desktop's networking page puts the bridge inside the VM, so on this host the
   `--internal` gateway reaches the VM's services rather than Windows'; the in-container probe
   stays the proof. Delete "The option landed in Engine 28" (§ 4.5, v8 L797–798): not on the cited page.
   `--internal` containers "may communicate between each other" (network create.md L197)
   supports the proxy-reachability claim; cite it.
7. **§ 6.6 item 9 and § 6.7 item 7.** Revert v8's note under § 6.6 item 9: v5 was not
   inconsistent. The paragraph v8 cites (v5 L861) names the away-window two lines later:
   "under the loop, which runs while they are away, it advances once a day" (v5 L863). v6
   read one sentence; v7's substance was right ("strawman" is strong wording, not wrong
   substance). Under § 6.6 item 7, keep v8's point that v6's principle 3 (L511–512) and
   § 8.4a note (L1193–1195) differ, but delete the rebuttal of "smuggled": v7 never used the
   word (no match in v7); it is v6's own check 7 (v6 L82). Note that the reviewer is the same
   family as v7, so this verdict should be weighed by the quoted lines.
8. **§ 3.1 bounty-infra row.** `pr_analysis.py` on 2026-10-04 (Seuss27): 86 PRs, 2026-06-26 →
   10-02; 69 work (66 merged), 2 cursor, 2 record, 13 dependabot; **0.03** cursor per work PR;
   median open→merge 4 min; median work size 89 lines; busiest day 2026-07-23, 15 merges over
   21.5 h, median gap 31 min. **The title classifier misses bounty-infra's grammar**
   (`docs(SE): sync cursor …`). By files (a PR touching only `.ai/next-steps.md`) or a "sync
   cursor" title: 22 cursor PRs (21 merged), 33 merged work PRs, **≈ 0.67** per work PR, median
   work size 69 lines, median open→merge 3 min. Add the row with both figures and the rule;
   note in § 10 that the classifier is tuned to the other repos' titles.
9. **§ 4.4** keep v8's OIDC correction; add that the "read-only token cannot carry
   `id-token: write`" step is an inference from events L587 plus OIDC reference L494, not a
   quote.

## § 6.8 content (write from this; condense)

- First-pass verdict, written before opening v7: v8 holds as a sequencing plan; its best
  change is procedural (tests before the driver). Ten predictions; verification confirmed
  six (Skill missing from `--tools`; "moot under `--restricted`" unsupported; sandbox vs
  permission protected-path conflation; `viewerCanMergeAsAdmin` and no merge queue anywhere;
  jobs-API step conclusions; 24418824 is a push ruleset), partly confirmed three (`isolated`
  silent on Desktop; placement self-declared and public-only unenforced; § 7.3 differently
  complicated rather than simpler) and **refuted one** (it predicted v8's item 9 verdict was
  fair).
- Verdicts on § 6.7 items 1–8: 1 right; 2 right on the flag, wrong in effects (bundle 1–3);
  3 mostly right (D2's `--admin`/queue note, `viewerCanMergeAsAdmin`); 4 right (bundle 9);
  5 partly right (D3); 6 sound on gh (D4); 7 half right on item 7, wrong on item 9 (bundle 7);
  8 right except the CI-wait route and the § 2.2 precedent (bundle 4, 5).
- Verdicts on § 6.7's verdicts on § 6.6 items 1–10: agree on 1–6, 8, 10; agree on 7 that v7
  overreached on the § 8.4a note; disagree on 9.
- Verified as v8 states: `--restricted` quote (cli-reference.md:123); the `isolated` quote
  (port-publishing, Gateway modes); `merge.go` L255–275 / L779–800 and `http.go` L48–80 (no
  admin field); WB-D20 at L1003; critic-gate L67–95; resume L350; ci.yml zizmor L118–122;
  `plan-infra.yml` L20–25; `ci.yml` L178; all four repos' rulesets with both accounts;
  image-scope's path list.
- Biases. v6/v7 same family: v7 kept v6's security-first structure; v8's "search by
  inheritance" claim holds. v8: over-trust of its own finds shows in bundle 1–3 and in its
  claim that § 7.3 got simpler. v8's item 9 verdict splits the difference against the text —
  the "compensating adjudication" it named in v7. v9 reviewer: its item 9 verdict sides with
  its own family; weigh it by the quoted line. Undeclared by every pass: eight passes refined
  the Docker-socket residual although the loop container never gets the socket; "merge queue
  where available" was carried from v3 without anyone checking it was configured; nobody
  counted the document's own size (2,338 lines) as a review cost; and every pass after v7
  treated "public repos only" as protecting the admin credentials, which it does not (D3).
- Not opened: `analysis/session-export/`, v4, v3. v6 and v5 opened only at the lines § 6.7
  cites. Executed nothing; changed no GitHub setting.

## § 0 and § 9 updates

- § 0: add the v9 bullet (reviewer properties above; the editing session's own properties).
  Replace the suggested-checks list with: **diff-check v9 against `V9-EDIT-SPEC.md` and
  `V9-TEST-RESULTS.md`**; the next work after that is whatever the test results left open,
  then the driver. Keep the v8 list as "superseded, kept for the record".
- § 9: the "Three Fable revisions, two Opus revisions, then a Fable revision" bullet gains the
  v9 sentence (Opus review, separate editor). Under "Never executed or looked up", add a
  "(added in v9)" list: plugin agents loading under `--restricted --agent --plugin-dir`; the
  scratch test's `viewerCanMergeAsAdmin` reads; infrastructure-core's history for live
  secrets (D3 condition 2).
- § 10: list `orchestrator-plan-v8.md` and this spec.
