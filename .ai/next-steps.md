# Cursor — claude-workbench

**Now:** **Sprint 1** — [milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1),
*stabilize v0.8.0 and close the live-observed gaps*. Status: **implementing** — the
milestone's `chore(release)` → `v0.9.0` PR is open; HITL Gate is open on its merge + tag.

**Just done (2026-09-23):**
- **Milestone item 7** (`594bc93`, [PR #119](https://github.com/glunk-works/claude-workbench/pull/119),
  open): `CHANGELOG.md` gains a `## [0.9.0]` entry summarizing #97 (PR #110), #98
  (PR #115), #100 (PR #116), #99 (PR #117); `plugin.json` bumped to `0.9.0`. No
  `.ai/project.yml` key changed — `architect-review` newly reading `{ruleset.rule_types}`
  reads as "no migration required," the same shape `0.8.0`'s `.ai/parked/` addition was.
  Critic gate: not run — changelog/version mechanics alone, following #101's own
  precedent, since each summarized diff already had its own pass (noted in the PR body).

**Next:** Wait for the human to merge [PR #119](https://github.com/glunk-works/claude-workbench/pull/119),
then for the human's own explicit dispatch of `release.yml` (`dry_run` first, then for
real) to cut the `v0.9.0` tag — never do that part unattended. Once tagged, on **sonnet**
(`coder`): open this repo's own pin-bump PR (bump the plugin pin in
`.claude/settings.json` to `v0.9.0`) per [PR #102](https://github.com/glunk-works/claude-workbench/pull/102)'s
precedent — that PR closes Sprint 1.
**Do not start #61** until every Sprint 1 PR has merged — verify against the milestone
first. **Do not start #104** unattended.

**HITL Gate: OPEN.** The human must merge PR #119, then explicitly dispatch `release.yml`
(`dry_run` first) to cut `v0.9.0`. Do not proceed to the pin-bump PR until both land.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D12`) ·
[milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1) ·
[open issues by milestone](https://github.com/glunk-works/claude-workbench/milestones)
