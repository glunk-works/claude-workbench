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

### Fixed

- **The pin-bump instructions named no command.** Every mention of the plugin cache said
  "clear it" and "confirm the version rotated" without saying how, and the directory-rotation
  test was wrong — the cache keeps the old version's directory alongside the new one. Now
  states the three steps (edit the ref, `claude plugin update`, **restart**) and verification
  via `claude plugin list`. `WB-D6` updated: the mechanism it left open is now understood.

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
