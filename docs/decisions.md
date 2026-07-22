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

  - **The coupling gate was blind to path-shaped literals, now less so.** F1–F4's shared
    root cause: the `coupling` grep matched repo/org **names** and a curated string list, so
    a hardcoded *path* that is not a repo name ("zero hits") proved only that no name leaked.
    `scripts/coupling-check.sh` gains a **Tier 3** of structural literal *shapes* —
    `docs/<...>roadmap.md` (always `{roadmap}`) and `.ai/context/<file>.md` (either moved
    into this plugin's `reference/` or the consuming repo's local truth, referenced as the
    bare directory, never a named file). A bare `.ai/context/` with no filename stays
    legitimate and unmatched. Check **names** are deliberately *not* added: they appear in
    illustrative example output (`/pr-checks`' report shape), so grepping them false-positives;
    check-name coupling is caught instead by `/resume` and `/pr-checks` reading
    `{ruleset.required_checks}` and reporting *inconclusive* on a mismatch. A grep cannot
    prove portability — it catches how portability actually rots — and Tier 3 narrows the
    blind spot without pretending to close it.

  - **F5 — `/critic-gate` gained a third proposal row: a newly-added doc.** A brand-new
    load-bearing doc cannot already be in `{load_bearing_docs}`, so keying the docs critic
    only off that set silently skipped a doc on the commit where it is most worth a look —
    its first version. **Disposition: a portable behavior fix, no new schema key** — the
    added/edited split is derivable from git (`--diff-filter=A`), so it derives from existing
    keys rather than growing the schema (the "a schema that grows a key per repo has failed"
    corollary). The row proposes `docs-consistency` (plus `security-critic` for a
    security/credential/operational procedure) and flags adding the file to
    `{load_bearing_docs}`; it remains a proposal the human confirms or trims.

  - **F6 — `/handoff` step 5's branch rule clarified, not exempted.** The finding argued that
    a "stacked" handoff (a second session syncing the cursor while the first session's PR is
    still open) needs to commit the sync onto the code branch, because `{pr_base}` lacks that
    PR's content. **Disposition: the finding's rationale is wrong and the rule is right** —
    `.ai/next-steps.md` is *regenerated wholesale* (step 4), not patched, so it carries no
    code context and a fresh `{pr_base}`-cut branch always applies. Step 5 now says so
    explicitly, closing the ambiguity that led the pilot's own history to deviate (`cb6d698`)
    toward the default (separate docs-only PR), rather than adding a permissive exception that
    would license bundling cursor churn into code-PR reviews.

## Status

All four of `WB-D1..D4` are implemented by this repo's existence and structure as of
`v0.1.0`. `WB-D2`'s schema (`reference/project-schema.md`), the full skill and agent
generalization against it, `WB-D5`, and the grep-based `coupling` CI job that enforces
`WB-D2` mechanically all land in `v0.2.0`. `WB-D6`'s dispositions — the Tier-3 coupling
patterns, the `/critic-gate` new-doc row, and the `/handoff` step-5 clarification — land in
the next tag; F1–F4 needed no plugin change (already fixed in `v0.2.0`).
