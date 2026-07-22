# claude-workbench

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces.md)
holding `way-of-working`: a portable Claude Code session-handoff protocol
(`/resume` → `/handoff` → `/critic-gate` → `/ship` → `/pr-checks` → `/archive-sprint`,
plus `/retro`), four general-purpose review/implementation agents (`architect`, `coder`,
`security-critic`, `docs-consistency`), a `SessionStart` cursor-banner hook, and the
Global Conventions (Python, OpenTofu/IaC, Conventional Commits, branch names, the
squash-merge policy, label taxonomy, Definition of Done).

## Why

The working method for a Claude-Code-driven repo was being re-authored per repo, with no
single source of truth. This repo is that source of truth, shipped as an installable
plugin rather than a docs URL, so it can be prompt-cached and version-pinned the same way
a GitHub Actions `uses:` is. See [`docs/decisions.md`](docs/decisions.md) (`WB-D1..D4`) for
the full reasoning, and `glunk-works/bounty-infra`'s
`sprints/SW_way_of_working/sprint_plan.md` for the extraction sprint that produced it.

## The parameterization rule

A shared skill or agent in `plugins/way-of-working/` may **never name a repo-specific
value** (a check name, a roadmap path, a review-gate header string, an identity). If it
needs one, it reads the consuming repo's `.ai/project.yml`
(`plugins/way-of-working/reference/project-schema.md`). If a value can't be expressed
there, the skill isn't portable and belongs local to that repo instead. A repo-local
override of a shared skill is a **bug report against the schema, not a fork** — plugin
skills cannot be partially overridden; a same-named local skill shadows the whole thing.

## Using it in a repo

```json
// .claude/settings.json
{
  "extraKnownMarketplaces": {
    "claude-workbench": {
      "source": { "source": "github", "repo": "glunk-works/claude-workbench" }
    }
  },
  "enabledPlugins": {
    "way-of-working@claude-workbench": true
  }
}
```

Pin to a released tag in the marketplace source config (never `main`) and add the repo's
own `.ai/project.yml` per `reference/project-schema.md`.

## Layout

```
.claude-plugin/marketplace.json
plugins/way-of-working/
  .claude-plugin/plugin.json
  skills/     resume/ handoff/ critic-gate/ ship/ pr-checks/ archive-sprint/ retro/
  agents/     architect.md coder.md security-critic.md docs-consistency.md
  hooks/      hooks.json + ai-cursor-banner.sh
  reference/  conventions.md  workflow.md  project-schema.md (v0.2.0)
docs/decisions.md   # the WB-D* log
```
