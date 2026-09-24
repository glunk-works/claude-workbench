# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **awaiting_review**. Build order and model per phase
are in the milestone description.

**Just done (2026-09-23, sonnet coder session):**
- Built **#86** (build order step 3): added the `planning:` schema key (kind
  `github_milestones`) — `bin/plan-anchor.sh` (new deterministic anchor predicate, mirroring
  `cursor-drift.sh`'s contract) + its fixture suite, `project-schema.md` § `planning`, and
  wired `resume`, `handoff`, `coder`, `ship`, `architect-review`, `park-sprint`,
  `unpark-sprint`, `archive-sprint`, `conventions.md`, and `workflow.md` to branch on
  `{planning.kind}`. `files`/absent behavior unchanged.
- Ran the local green gate (`lint.sh`, `coupling-check.sh`, `invariants-check.sh`, all
  `tests/*.test.sh`) — all passed.
- Ran `/way-of-working:critic-gate` (architect + security-critic + docs-consistency, all
  three confirmed by the human before spawning): **3 rounds, converged** — round 1 found
  ~30 issues (a false-`match` bug in the anchor parser, an invalid `gh api -R` flag,
  `park-sprint` silently changing `files`-kind behavior, an unprojected `gh` call that would
  have leaked milestoned-issue text into an auto-starting session's context before any trust
  check, the spec comment's author never being checked); round 2 found 6 smaller residuals;
  round 3 came back clean plus 3 trivial wording nits, fixed. All fixed and re-verified
  green.
- Shipped as [PR #135](https://github.com/glunk-works/claude-workbench/pull/135), at
  `ef35b64` (not yet merged).

**Next:** on **sonnet** (`coder`), once PR #135 merges: build **#128** (build order step 4 —
`archive-sprint` closes the sprint's milestone when `planning.kind` is `github_milestones`;
rides on #86's key, no new schema). Check whether #128 needs its own approved spec comment
first, the way #86 did, or is ready to build directly — ask the human if unclear. Then the
green gate, `/way-of-working:critic-gate`, and ship.
**Do not start #104 unattended** (release-tag security surface; staged commands go to the
human).

**HITL Gate: OPEN.** The human must merge [PR #135](https://github.com/glunk-works/claude-workbench/pull/135)
(#86) before #128 can start — #128 rides on #86's schema key landing on `main`. Also confirm
whether #128 needs a spec-approval pass first.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
