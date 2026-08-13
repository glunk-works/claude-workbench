# Changelog

Consuming repos **pin a tag**, so nothing here reaches a repo until it bumps its pin in
`.claude/settings.json`. This file exists so that decision can be made with the contents in
view — `/way-of-working:archive-sprint` step 6 prompts for a pin bump at every sprint close,
and a prompt that cannot say *"this one needs a migration"* is a trap.

**Read the `⚠️ Migration` line, if a release has one, before bumping.**

**Bumping the pin is three steps, and skipping either of the last two fails silently.**
Editing `.claude/settings.json` changes what is *pinned*; it does not change what is *loaded*.

```bash
# 1. edit the ref in .claude/settings.json, then:
claude plugin update <plugin>@<marketplace>   # 2. fetch the newly pinned tag
# 3. restart the session — `update` reports "restart required to apply", and a
#    running session keeps executing the copy it started with
claude plugin list                            # verify: does it report the new version?
```

**Verify with `claude plugin list`, never by looking for a new cache directory.** The cache
keeps one directory per version and does **not** remove the old one, so "a new directory
appeared" is true even while the session still runs the old code. Observed three times now —
twice in `WB-D6`, and again during the `v0.5.0` release, where a session was served skills
from a `0.1.0` cache directory while `claude plugin list` correctly reported `0.5.0`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases before
`v0.5.0` are summarized from their tags; the full record is `docs/decisions.md` (`WB-D*`) and
the GitHub release notes.

## [Unreleased]

**No migration required.**

### Fixed

- **`coupling-check.sh` guarded only 4 of the org's 8 repos.** `TIER2` itself listed 3
  (`bounty-infra`, `global-bootstrap`, `scope-core`); the 4th (`loop-orchestrator`) was
  covered only via `TIER1`, and the check's other four org repos had no coverage anywhere.
  Added the missing four (`claude-workbench`, `bedrock-serverless-rag`, `pm-agent-loop`,
  `appsec-triage-agent`), plus the `loop-engine` worked-example emitter name and
  `loop-orchestrator` itself, to `TIER2`, and restated its comment as a membership rule
  instead of an ad-hoc list. `claude-workbench` is the repo a contributor is most likely to
  be sitting in while editing the plugin, and was the highest-risk gap. Two pre-existing,
  legitimate self-references to `claude-workbench` in `archive-sprint`/`retro`'s own prose
  (describing the plugin's distribution source, not a leaked local-repo literal) were
  reworded to name the concept instead of the repo. See #43.

- **The pin-bump procedure was wrong for a second time, and this release changes where it
  lives rather than only what it says.** `claude plugin update` resolves against the ref
  registered in `~/.claude/plugins/known_marketplaces.json`, not the ref just edited into
  `.claude/settings.json`, so it reported *"already at the latest version"* and loaded the
  old tag — a silent no-op reporting success. Corrected in
  `reference/conventions.md` § *Bumping a pinned plugin*, which also covers the two
  adjacent traps: `update` defaulting to `--scope user` on a project-scoped install, and a
  first registration made **without** a `ref` shadowing a project pin permanently. See #37.
- **The corrected steps now ship in the generated release notes** (`release.yml`), because
  `CHANGELOG.md` is the wrong channel for this by construction: a consuming repo reads the
  pin-bump instructions from the version it *already has*, so a fix here is only readable
  after the bump it describes. Release notes are read at bump time and stay editable after
  the tag is cut. `WB-D6`'s lesson, applied to the delivery mechanism instead of the prose.
- **Verification is now by commit, not by version string.** `claude plugin list` reports the
  `version` field from the installed `plugin.json`, which is self-consistent at the wrong
  commit and therefore proves nothing; the check compares `gitCommitSha` in
  `installed_plugins.json` against the tag. Found live: a consuming repo reporting `0.5.1`
  while running a `main` commit two merges past that tag.
- **The machine-namespace rule shipped with an example that contradicted it — and a second
  doc that contradicted the rule outright.** Global Conventions § *Issue + label taxonomy*
  stated the namespace as *the emitting system*, then illustrated it with the **repo** name,
  which is only coincidentally the same thing: in the repo the example was drawn from the
  emitter is `loop-engine`, so the label reads `loop-engine/needs-human`, and the one
  instance a reader had to generalize from taught the wrong rule. `project-schema.md` then
  stated that wrong rule flatly, in three places, as a plain property of the `repo` key.
  Fixed together — the conventions bullet now names the emitter and gives both cases (the
  one where the namespace matches the repo and the one where it does not), while
  `project-schema.md` and `/way-of-working:ship` step 6 still derive a skill's namespace
  from `{repo}` but now say **why** that is correct: a skill's emitter *is* the repo's own
  automation, so it is the general rule applied, not an exception to it. **No emitted label
  changes and no key moved** — every namespace any skill produced was already right; what
  was wrong was the reason given for it, which is what a reader generalizes from. Closes
  #28's decision 1.

## [0.6.0] — 2026-08-13

**No migration required.** No `.ai/project.yml` key changed and no skill contract moved.
Two things behave differently after the bump, though, and neither is visible in a diff of
your own repo: `/way-of-working:ship` step 1 now runs a preflight that can **stop** a ship
before anything is committed, and the plugin ships its first executable — `bin/` is on the
Bash tool's `PATH` while the plugin is enabled, so a name collision with a script of your
own on `PATH` is possible in principle. Only `cursor-drift.sh` is claimed today.

### Added

- **`/way-of-working:ship` step 1 gains a push-reach preflight** (`gh api repos/{repo}
  --jq .permissions.push`), so a wrong-identity push is caught before anything is
  committed rather than at `git push`. It only verifies `gh`'s identity, not `git`'s — see
  the new Global Conventions section below for the case it can't catch.
- **Global Conventions documents the `git`-vs-`gh` push-identity split**
  (`reference/conventions.md` § *Push identity*): `git push` and `gh` can resolve
  different GitHub accounts on the same machine, so a healthy `gh` preflight does not
  guarantee the next `git push` succeeds. Includes the diagnosis, a per-push workaround,
  and the durable fix.
- **`/way-of-working:handoff`'s own push (step 5) gets a pointer to the same section** —
  it has the identical exposure but, per #23's own preferred shape, no preflight of its
  own; only `ship` does. Closes #23.
- **`plugins/way-of-working/bin/cursor-drift.sh`**, a tested extraction of
  `/way-of-working:resume` step 2's cursor-freshness classifier (`clean | cursor-sync |
  drift | unreadable`), proven by `tests/cursor-drift.test.sh` against real throwaway git repos —
  including the squash-merge case `WB-D7` names. `bin/` is on the Bash tool's `PATH` while
  the plugin is enabled, so the skill calls it by bare name; `${CLAUDE_PLUGIN_ROOT}` was
  confirmed **not** set in that context first (issue #21 step 1), which is what made `bin/`
  the right delivery mechanism rather than the interpolated path the issue proposed. A new
  `tests` CI job runs the fixtures on every PR (not yet a required check). See `WB-D10`.
- **`coupling-check.sh` and `invariants-check.sh` now also cover `plugins/*/bin/`** — the
  no-repo-specific-literal rule and the drift-classifier regression guard both apply to the
  script the same way they already applied to skill/agent prose.

## [0.5.1] — 2026-08-10

**No migration required.** Docs-only. Worth taking before a fan-out, though: it corrects the
pin-bump instructions themselves, which a repo reads from the version it already has.

### Fixed

- **The pin-bump instructions named no command.** Every mention of the plugin cache said
  "clear it" and "confirm the version rotated" without saying how, and the directory-rotation
  test was wrong — the cache keeps the old version's directory alongside the new one. Now
  states the three steps (edit the ref, `claude plugin update`, **restart**) and verification
  via `claude plugin list`. `WB-D6` updated: the mechanism it left open is now understood.

### Changed

- `WB-D8` records that the reporting repos confirmed their hubs can expose findings as
  issues, so the breaking file-based cross-repo backlog is **not scheduled** rather than
  deferred. See #5.

## [0.5.0] — 2026-08-10

**No migration required.** Every existing `.ai/project.yml` stays valid untouched;
`backlog.repo` is optional and defaults to the current behavior. Bump the pin, clear the
plugin cache, confirm the version rotated.

Closes five issues raised upstream by `/way-of-working:retro` in consuming repos: #5
(partially), #6, #7, #12, #13.

### Added

- **`backlog.repo`** — a `kind: github_issues` backlog may name the repo that holds it, for
  the hub-and-spoke shape where one repo carries the record for a family of sibling repos.
  Reads *and* writes work cross-repo (`gh issue list/create --repo …`). Not supported with
  `kind: file`; see `WB-D8` for why that asymmetry is the design. (#5, partial)
- **Blocking preconditions get a convention and two checks.** `reference/conventions.md`
  defines the `BLOCKING:` marker and extends the Definition of Done to enumerate
  preconditions, not only deliverables; `/way-of-working:ship` records a precondition's
  satisfaction in the PR that relies on it; `/way-of-working:archive-sprint` gains
  precondition 5, which checks it at close. (`WB-D9`, #7)
- **`invariants` CI job** (`scripts/invariants-check.sh`) — asserts that three
  already-shipped defects have not returned: cursor freshness compared by commit range,
  `gh auth status` being parsed, and the reach check ordered after the ruleset call.
- **This changelog.**

### Changed

- **`/way-of-working:resume` compares cursor freshness by content, not ancestry.** The
  `v0.4.0` carve-out used a commit *range* (`<last_commit>..HEAD`), which is meaningless
  unless `last_commit` is an ancestor of `HEAD` — and under squash-merge it frequently never
  becomes one, so auto-start could not fire whenever a handoff ran with a code PR still open.
  Now a two-argument `git diff <last_commit> HEAD`. (`WB-D7`, #6)
- **`/way-of-working:critic-gate` has a bounded stopping rule.** *"Iterate until the critics
  are clean"* is replaced by a severity-based convergence test, an unconditional re-run on
  the fixed tree, cross-round finding tracking, and a hard cap of 2 fix-and-re-run rounds
  before the decision returns to the human. (#12)
- **`/way-of-working:resume` establishes repo reach before the ruleset preflight.** An
  identity that cannot see a ruleset gets `404`, not `403`, so the old behavior reported a
  reachability failure as *"the ruleset does not exist"*. (#13)

### Fixed

- `/way-of-working:handoff`'s cursor-PR note described the superseded range-based rule.
- `/way-of-working:critic-gate`'s closing rationale claimed the spawn decision stays with the
  human, which stopped being true of re-spawns when the round cap replaced per-round
  confirmation.
- The README described `project-schema.md` as `v0.2.0`; the schema carries no version of its
  own and had changed since.

## [0.4.0]

`WB-D6` dispositions from the pilot's real-work exercise: tier-3 coupling patterns for
path-shaped literals, a `/way-of-working:critic-gate` proposal row for newly-added docs, and
a `/way-of-working:handoff` step-5 clarification for stacked handoffs. The first (later
superseded) fix for the cursor-drift check. A release workflow that derives its tag from
`plugin.json`, and the published `/way-of-working:<skill>` command names.

## [0.3.0]

Interim tag; see the release notes.

## [0.2.0]

`.ai/project.yml` and `reference/project-schema.md` — the parameterization contract
(`WB-D2`). Full generalization of the 7 skills and the 4 agents against it (`WB-D5`), and the
grep-based `coupling` CI job that enforces it mechanically.

## [0.1.0]

The plugin skeleton: marketplace and plugin manifests, 7 skills, 4 agents, the `SessionStart`
cursor-banner hook, and the Global Conventions (`WB-D1`, `WB-D3`, `WB-D4`). Skills were
copied across still coupled to their source repo **on purpose** — generalizing them was
`v0.2.0`'s job.
