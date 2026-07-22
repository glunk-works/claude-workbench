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

## Status

All four of `WB-D1..D4` are implemented by this repo's existence and structure as of
`v0.1.0`. `WB-D2`'s schema (`reference/project-schema.md`), the full skill and agent
generalization against it, `WB-D5`, and the grep-based `coupling` CI job that enforces
`WB-D2` mechanically all land in `v0.2.0`.
