# Decisions log — `glunk-works/claude-workbench`

This repo's own decision log, in the `WB-D*` namespace. It restates the four decisions
that created this repo — locked in `glunk-works/bounty-infra`'s SW sprint planning pass
(2026-07-22) as **BI-D10..D13** — as this repo's own record, since this repo is where they
take effect. Full reasoning and the task breakdown that implements them:
`bounty-infra`'s `sprints/SW_way_of_working/sprint_plan.md` and
`docs/hardening_roadmap.md` § *Locked decisions (SW planning pass, 2026-07-22)*.

- **WB-D1 (= BI-D10) — the shared way of working ships as a Claude Code plugin, tag-pinned.**
  Each consuming repo commits a `.claude/settings.json` naming this repo as a marketplace
  and enabling the `way-of-working` plugin; skills, agents, hooks, and the Global
  Conventions arrive with it as a **native** mechanism — no sync script, no submodule, no
  vendored copies. A repo-local skill of the same name shadows the plugin's, which is the
  extension seam. **Tag-pinned, never a branch** — a mutable ref on something that shapes
  agent behavior is a handoff to whoever moves it. (Rejected: a git submodule — Claude Code
  does not discover skills nested in a submodule path without symlinks or a sync step, and
  submodules are friction on Windows. A Copier template — duplicates files per repo, DRY at
  the template level rather than runtime. A `raw.githubusercontent` URL — uncacheable,
  unpinnable, silent when upstream moves.)
- **WB-D2 (= BI-D11) — `.ai/project.yml` is the parameterization seam.** A shared skill may
  **never name a repo-specific value**; it reads the contract instead. Every literal removed
  from a skill becomes a schema key (`reference/project-schema.md`), enforced by a
  grep-based CI job in this repo, not by convention. If a value cannot be expressed in the
  schema, the skill is not portable and belongs in the consuming repo, local. A repo-local
  override of a shared skill is a **bug report against the schema, not a fork** — the
  override shadows the whole skill and silently stops receiving upstream fixes. The frozen
  review header/attestation strings live in the schema **as data**, precisely so they are
  pasted rather than retyped. (Rejected: prose in a `CLAUDE.md` — unstructured, unverifiable
  by a skill. `project.yml` as truth with `CLAUDE.md` rendering it — adds a sync obligation
  between two files, exactly the failure mode being eliminated.)
- **WB-D3 (= BI-D12) — the plugin holds only what works in any repo.** 7 skills
  (`resume`, `handoff`, `critic-gate`, `ship`, `pr-checks`, `archive-sprint`, `retro`) + the
  4 general agents (`architect`, `coder`, `security-critic`, `docs-consistency`). Anything
  that encodes one product's internals rather than a way of working stays local to that
  product's own repo. (Rejected: shipping everything gated by `project.yml` — ships
  definitions referencing tools most repos do not have. Skills-only with agents kept local —
  agents are the layer most worth sharing; per-repo re-authoring of them is the problem this
  repo exists to remove.)
- **WB-D4 (= BI-D13) — `bounty-infra` pilots; the source repo migrates after.** The pilot
  needs to be a genuinely different shape from this plugin's source material — different
  language stack, different CI check taxonomy, no fresh-session review-gate CI check — so
  that the parameterization is forced to be general rather than flavored by the repo it was
  extracted from. In particular, `review.ci_gate: null` must be a clean path through every
  skill for a repo that has not wired up a review gate. The source repo keeps its own working
  local copies of these skills/agents until a real sprint has run cleanly through the plugin
  at the pilot, closing the duplication window deliberately rather than immediately.
  (Rejected: migrating the source repo first — touches the repo everything else depends on
  before the schema has been proven anywhere.)

- **WB-D5 — a shared agent ships the taxonomy, never the instances.** Found while
  generalizing the 4 agents (`v0.2.0`), and it is a different problem from the skills. The
  skills' coupling was **values** — check names, commands, paths — each of which became a
  schema key cleanly. The agents' coupling is **knowledge**: the source repo's module
  boundaries, its named subprocess surfaces, its specific trust boundaries, its specific
  high-value doc claims. None of that is expressible as a schema key, and paraphrasing it
  into generic advice would have shipped an agent that reviews every repo against one repo's
  invariants. So each agent now carries the *shapes* that reliably hold invariants (import
  layering, I/O ownership, subprocess surfaces, credential holders, taint source and sink
  classes, the claim shapes that drift in prose) and **builds the instance list at spawn
  time** by reading `.ai/project.yml`, the consuming repo's `CLAUDE.md`, `{threat_model}`,
  and the guarding tests. An agent that cannot read the contract reviews only what needs no
  contract value and says so — it never substitutes a threat model it remembers.
  Consequence, accepted: the agents are **thinner** than the originals and start colder, and
  that is the correct trade — a warm start against the wrong repo's map is worse than a cold
  start against the right one. The source repo's specific invariants are not lost; they live
  in that repo's own `CLAUDE.md` and threat model, which is where the agent now reads them.
  (Rejected: schema keys enumerating a repo's invariants — that is the repo's `CLAUDE.md`
  restated in YAML, a second copy of exactly the kind WB-D2 exists to eliminate. Rejected:
  keeping the rich source-repo agents in the plugin and letting other repos ignore the
  irrelevant parts — an agent asserting a boundary the repo does not have produces confident
  false findings, the most trust-destroying output a critic can emit.)

- **WB-D6 — the pilot's Task-5 real-work exercise, dispositioned.** The bounty-infra pilot
  ran a genuine piece of work end-to-end through the plugin loop (SW Task 5, sessions 6–7)
  and logged six findings. Their disposition, per the *Overriding is a bug report* rule
  (two outcomes only — a schema seam, or not-portable — never a local override):

  - **F1–F4 were already fixed and did not reproduce against the pinned tag.** The four
    "hardcoded loop-orchestrator value" findings (a stale required-check list, a
    `docs/migration_roadmap.md` path, three `.ai/context/*.md` references) all describe the
    **`v0.1.0` skeleton**, whose skills were copied *as-is, still coupled on purpose* (WB-D3
    /Task 2). The generalization that fixes every one of them landed in `v0.2.0`
    (`{roadmap}`, `{ruleset.required_checks}`, `{models}`, `reference/workflow.md`).
    Session 6 reproduced them only because the harness served a **stale `v0.1.0` local
    checkout** despite the consuming repo pinning `v0.2.0` — a plugin-cache staleness
    problem, not a portability defect. **Disposition: already-fixed-upstream via existing
    schema keys; no skill change.** The two real actions are (a) the consuming repo bumps
    its pin and clears the stale checkout to force a re-fetch, and (b) a regression guard so
    the same *class* of leak is caught mechanically next time (below). This is the plan's own
    "tag-pinning ⇒ updates are opt-in ⇒ never" risk in a sharper form: even an explicit pin
    bump was not honored by the local cache, so a pin change must be paired with a cache
    clear until the mechanism is understood.

    **Resolved during the `v0.5.0` release — the mechanism is now understood, and the
    guidance above was imprecise.** A pin bump is **three** steps: edit the ref, run
    `claude plugin update <plugin>@<marketplace>`, and **restart the session** — `update`
    itself reports *"restart required to apply"*, and a running session keeps executing the
    copy it started with. Verification is `claude plugin list`, **not** an inspection of the
    cache directory: the cache keeps one directory per version and does not remove the old
    one, so a `0.1.0` directory sitting beside a `0.5.0` directory is normal and proves
    nothing. Confirmed live — a session mid-release was served skills from the `0.1.0`
    directory (recognisable by pre-`v0.4.0` bare command names) while `claude plugin list`
    correctly reported `0.5.0`. This is why the failure reads as "the fix did not work"
    rather than "the plugin did not reload."

  - **The coupling gate was blind to path-shaped literals, now less so.** F1–F4's shared
    root cause: the `coupling` grep matched repo/org **names** and a curated string list, so
    a hardcoded *path* that is not a repo name ("zero hits") proved only that no name leaked.
    `scripts/coupling-check.sh` gains a **Tier 3** of structural literal *shapes* —
    `docs/<...>roadmap.md` (always `{roadmap}`) and `.ai/context/<file>.md` (either moved
    into this plugin's `reference/` or the consuming repo's local truth, referenced as the
    bare directory, never a named file). A bare `.ai/context/` with no filename stays
    legitimate and unmatched. Check **names** are deliberately *not* added: they appear in
    illustrative example output (`/way-of-working:pr-checks`' report shape), so grepping them false-positives;
    check-name coupling is caught instead by `/way-of-working:resume` and `/way-of-working:pr-checks` reading
    `{ruleset.required_checks}` and reporting *inconclusive* on a mismatch. A grep cannot
    prove portability — it catches how portability actually rots — and Tier 3 narrows the
    blind spot without pretending to close it.

  - **F5 — `/way-of-working:critic-gate` gained a third proposal row: a newly-added doc.** A brand-new
    load-bearing doc cannot already be in `{load_bearing_docs}`, so keying the docs critic
    only off that set silently skipped a doc on the commit where it is most worth a look —
    its first version. **Disposition: a portable behavior fix, no new schema key** — the
    added/edited split is derivable from git (`--diff-filter=A`), so it derives from existing
    keys rather than growing the schema (the "a schema that grows a key per repo has failed"
    corollary). The row proposes `docs-consistency` (plus `security-critic` for a
    security/credential/operational procedure) and flags adding the file to
    `{load_bearing_docs}`; it remains a proposal the human confirms or trims.

  - **F6 — `/way-of-working:handoff` step 5's branch rule clarified, not exempted.** The finding argued that
    a "stacked" handoff (a second session syncing the cursor while the first session's PR is
    still open) needs to commit the sync onto the code branch, because `{pr_base}` lacks that
    PR's content. **Disposition: the finding's rationale is wrong and the rule is right** —
    `.ai/next-steps.md` is *regenerated wholesale* (step 4), not patched, so it carries no
    code context and a fresh `{pr_base}`-cut branch always applies. Step 5 now says so
    explicitly, closing the ambiguity that led the pilot's own history to deviate (`cb6d698`)
    toward the default (separate docs-only PR), rather than adding a permissive exception that
    would license bundling cursor churn into code-PR reviews.

- **WB-D7 — cursor freshness is a content question, never an ancestry one.** `/resume`'s
  drift check decides whether the tree still matches what the cursor describes, and it must
  answer that under **squash-merge**, which is this project's default merge method. Squash
  replays a branch as a brand-new commit object, so the branch tip a cursor recorded never
  becomes an ancestor of `{pr_base}` — not when the PR merges, not ever. Any check keyed on
  SHA equality or on commit *ancestry* is therefore structurally wrong here, and both of the
  first two attempts were: `v0.3.0` compared `last_commit` to HEAD by SHA, and `v0.4.0`
  replaced that with a commit-*range* carve-out (`git rev-list --count <last_commit>..HEAD`
  is 1, `git diff --name-only <last_commit>..HEAD` is the cursor file). The range form works
  only while `last_commit` is an ancestor of HEAD, which it is not whenever a
  `/way-of-working:handoff` runs with a code PR still open — an ordinary occurrence in a
  one-task-per-PR flow, not an edge case, and it was reproduced live within one tag of the
  fix landing. The check is now a **two-argument `git diff <last_commit> HEAD`**: it compares
  trees, is indifferent to ancestry, and reports exactly the cursor file once the work has
  squash-merged. The allowlist stays at `.ai/next-steps.md` alone. (Rejected: widening it to
  "docs-shaped paths," which would survive squash equally well but is a genuine loosening —
  a roadmap or sprint-plan edit between sessions can invalidate the very `next_action` that
  auto-start is about to run unattended, which is the one thing the drift check exists to
  catch. Rejected: having `/way-of-working:handoff` record `last_commit` *after* its own
  commit — the same squash property mints a different SHA on `{pr_base}`, so the mismatch
  returns, and `last_commit` would stop meaning "the commit whose work this cursor
  describes.") Consequence, accepted: while a code PR is still unmerged, its files appear in
  the path list and `/resume` waits. That is a true report — the cursor describes work
  `{pr_base}` does not have — not a false alarm.

- **WB-D8 — a backlog may name its owning repo; a backlog *file* may not.** Three adopting
  repos hit the same seam at once: the record-pointing keys are all repo-relative, so a
  satellite repo whose findings are tracked in a **hub** repo — one repo carrying the roadmap
  and backlog for a family of sibling module repos — cannot say so. The three available moves
  were all bad: a relative path escaping the repo (works on one checkout, breaks in CI), a
  `kind` that is factually wrong (findings route into a channel nobody reads), or `null`
  (honest, but the skills then have nowhere to route a finding in a repo that demonstrably
  has somewhere). Per the *Adding a key* corollary this is a **shape**, not a per-repo key —
  one seam three repos hit, not a bespoke value for one of them — so it earns a key.

  **The key is `backlog.repo`, and it is supported only with `kind: github_issues`.** That
  asymmetry is the whole design, not a limitation to fix later. With issues, cross-repo is
  free in **both** directions — `gh issue list --repo X` and `gh issue create --repo X`, no
  clone, no branch, no PR, no second review surface, no cross-repo push identity. With a
  backlog *file*, reads need an API and **writes need a PR opened against a repo whose owner
  did not ask for it**, which is a genuinely expensive and differently-governed act. The
  cheap half is therefore shipped whole rather than shipping both halves crippled: a
  `github_issues` backlog works completely, and a `file` backlog stays repo-local.
  (Rejected: cross-repo file reads with writes reporting-and-stopping — the write case is the
  one the reporting repos were actually blocked on, and a read-only file pointer leaves it
  exactly as broken as the `null` workaround while charging a schema change for it. Rejected:
  declining the seam entirely — hub-and-spoke is an ordinary shape for an org with a
  monorepo-ish hub and satellite module repos, and this project is arguably that shape too.)

  **Every cross-repo call establishes reach before believing its answer**, per `WB-D7`'s
  sibling lesson: GitHub answers an unreachable resource with `404`, not `403`, so an
  unreachable backlog is indistinguishable from an *empty* one — and "nothing is tracked"
  is exactly the wrong conclusion to hand a retro whose first step is reading what has
  already been decided. `gh api repos/{backlog.repo} --jq .permissions` disambiguates it in
  one call. Deliberately not extended to `roadmap`, `threat_model`, or `decisions.log`: those
  are strings today, mappings only in a breaking change, and nothing has yet demonstrated it
  needs them.

  **Confirmed by the reporting repos (2026-08-10): the hubs can expose findings as issues**,
  so the `github_issues` path is a complete answer for the half they were blocked on, and the
  breaking file-based half is **not scheduled** — not merely deferred. What that leaves open
  is narrower than the original report: a satellite still cannot *read* a hub's `roadmap`,
  `threat_model`, or `decisions.log`, because a document is not a finding and cannot be
  routed to an issue. No repo has yet reported that gap costing anything, and until one does,
  the honest position is that a required `schema_version` and two converted keys are a real
  cost paid against a hypothetical benefit. Reopen this if a consuming repo hits the read
  half; the evidence to design against will arrive with it.

- **WB-D9 — a blocking precondition is marked, and records its satisfaction where the work
  that relies on it lands.** `/way-of-working:archive-sprint`'s verification ledger was the
  only place in the plugin asking *"is this claim backed by evidence?"*, and it is scoped to
  one shape: a **deliverable** marked complete that was only hermetically verified. Nothing
  covered the other shape — a **precondition** gating a specific irreversible act, whose
  satisfaction is recorded nowhere. Such a criterion can be fully satisfied and remain
  **indistinguishable from one that was skipped**, which is the same thing as not having it.

  The fix lands in three places because the gap has three moments, and only the first two
  were ever proposed as sufficient on their own:

  - **`reference/conventions.md` defines the marker** (`BLOCKING:` + the step it gates) and
    extends the Definition of Done to enumerate preconditions, not only deliverables. This is
    **load-bearing, not framing**: the plugin owns no sprint-plan *format* — `sprints_dir` and
    `pointers.sprint_plan` are locations — so without a marker convention a skill has nothing
    to key on and degrades to "read the plan and use judgment," which is exactly what failed.
    `conventions.md` is the right home because it is the plugin's own shipped convention set,
    already dictating commit grammar, branch names, and the label taxonomy.
  - **`/way-of-working:ship` records satisfaction in the PR that relies on it** — the moment
    of truth, and the only one that catches the gap *in time*. It reads `pointers.sprint_plan`
    from the cursor rather than prompting from memory: a prompt answered from recall is a
    weaker instance of the defect it is meant to close.
  - **`/way-of-working:archive-sprint` precondition 5 catches what got through** — mechanical,
    at close, keyed on the marker. Late is where it is most expensive to discover, but
    late-and-mechanical beats a human happening to ask.

  (Rejected: the `architect` agent checking it in `/way-of-working:critic-gate` — this is a
  documentation-of-evidence question, not a diff question, and a diff reviewer has no way to
  see it. Rejected: guidance alone, on the reasoning that plans should not use unverifiable
  blocking criteria — true and now stated, but nothing would enforce it, and the observed case
  had a criterion that *was* satisfied and still left no trace. Rejected: giving
  `/way-of-working:ship` the whole sprint plan to reason about — it reads one cursor field for
  one marker, which is a bounded read, not a scope increase.)

- **WB-D10 — a deterministic predicate moves to a tested script; `bin/` is how a plugin ships
  one.** Filed as issue #21 after `v0.5.0`: three of five findings that `/way-of-working:retro`
  raised upstream were mechanical procedures whose *English* was subtly wrong (`WB-D7`'s own
  drift check shipped wrong twice). The narrower claim, not "prose is bad": where a skill
  describes a computation with one correct answer given its inputs, prose buys nothing and
  costs the ability to test it — that passage should be a script the skill *invokes*, keeping
  only the policy (what to do with each answer) in prose.

  The proposal's own step 1 was to verify its precondition before extracting anything:
  `${CLAUDE_PLUGIN_ROOT}` is set for a `hooks.json`-invoked hook (the harness spawns it
  directly) but **confirmed empty** in the shell a skill's own Bash tool calls run in — a
  skill cannot reliably build `"${CLAUDE_PLUGIN_ROOT}"/scripts/foo.sh` paths. That would have
  stopped the effort at step 1, except a second mechanism is already documented and stable: a
  plugin's `bin/` directory is added to the Bash tool's `PATH` while the plugin is enabled, so
  a script placed there is callable by **bare name** — no path-building, no missing-variable
  failure mode, and arguably better ergonomics than the interpolated form the issue proposed.

  Landed this pass: `plugins/way-of-working/bin/cursor-drift.sh`, the `WB-D7` classifier,
  called from `/way-of-working:resume` step 2 as `cursor-drift.sh <last_commit>` and proven by
  `tests/cursor-drift.test.sh` — real throwaway git repos exercising the squash-merge case
  `WB-D7` names, not a mock of git's behavior. A fixture catches a **wrong answer**; the
  `invariants` regex only ever caught one **wrong shape** of answer (the range form
  literally reappearing), so both stay: the fixture is authoritative, the regex is a cheap
  independent check that now also scans `bin/` scripts, not just prose. `coupling-check.sh`'s
  scope widened to include `bin/` alongside `skills/` and `agents/` — it is shared, executed
  plugin code under the same no-repo-specific-literal rule. A new `tests` CI job runs the
  fixtures on every PR but was deliberately **not** added to `{ruleset.required_checks}` in
  this pass — that is a live branch-protection change, made against a running repo rather
  than reviewed in a diff, and `WB-D8`'s own precedent is to defer exactly that kind of
  change until there is a concrete reason to make it, not as a side effect of an unrelated
  pass.

  Deliberately **not** done in this pass, per the issue's own staging: the
  `/way-of-working:resume` step 3 / `/way-of-working:archive-sprint` step 5 branch-prune block, byte-identical
  in both skills today, is a stronger duplication case but the issue's own order asks for one
  extraction to run through a real `/way-of-working:resume` session before a second one
  starts — this repo consuming its own plugin (`WB-D1`) makes that the very next tag-pinned
  session, not a hypothetical one. (Rejected: reaching for `${CLAUDE_PLUGIN_ROOT}` with a
  documented workaround, e.g. having the *hook* export it somewhere a skill could read it —
  no such channel exists between a hook process and the agent's own Bash tool shell; they are
  different processes. Rejected: shipping the script under `scripts/` like the repo's own
  gates — those run in CI and this repo's own shell, never inside a consuming repo's session,
  so they cannot be what a plugin skill invokes portably.)

## Status

All four of `WB-D1..D4` are implemented by this repo's existence and structure as of
`v0.1.0`. `WB-D2`'s schema (`reference/project-schema.md`), the full skill and agent
generalization against it, `WB-D5`, and the grep-based `coupling` CI job that enforces
`WB-D2` mechanically all land in `v0.2.0`. `WB-D6`'s dispositions — the Tier-3 coupling
patterns, the `/way-of-working:critic-gate` new-doc row, and the `/way-of-working:handoff` step-5 clarification — land in
`v0.4.0`; F1–F4 needed no plugin change (already fixed in `v0.2.0`).

`v0.5.0` lands `WB-D7` (superseding the `v0.4.0` range-based drift carve-out), `WB-D8`, and
`WB-D9`, plus the `invariants` CI job and `CHANGELOG.md`. It is **non-breaking** — every
existing `.ai/project.yml` stays valid untouched.

That last part was not the plan. `WB-D8` was scoped as a breaking change — `roadmap` and
`threat_model` converted to mappings behind a new required `schema_version` — until a review
pass observed that `backlog` was *already* a mapping, so the half that adopting repos were
actually blocked on needed no break at all. The breaking half is deferred until a consuming
repo demonstrates it needs one, which is also what supplies the evidence to design it
against. Worth recording because the cheaper answer was available from the start and was
found by asking "what does this actually cost the people adopting it," not by a new
requirement arriving.

`WB-D10` lands unreleased, alongside #23's push-identity fix (`CHANGELOG.md`'s
`[Unreleased]` section) — it does not yet have a tag.
