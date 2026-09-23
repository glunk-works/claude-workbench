# Cursor — claude-workbench

**Now:** **Sprint 1** — [milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1),
*stabilize v0.8.0 and close the live-observed gaps*. Status: **implementing** — the last
build before the release is `chore(release)` → `v0.9.0`; no gate is open.

**Just done (2026-09-23):**
- **#97** (`161392e`, [PR #110](https://github.com/glunk-works/claude-workbench/pull/110),
  merged): `architect-review` now syncs onto `{pr_base}` unconditionally before its first
  read. Critic gate: `architect` + `docs-consistency`, 3 rounds, converged.
- **#98** (`06ad89b`, [PR #115](https://github.com/glunk-works/claude-workbench/pull/115),
  merged): `architect-review`'s `{pr_base}` check was self-consistency, not an independent
  anchor — a checkout on a branch whose own `.ai/project.yml` named itself as `pr_base`
  (and named a `repo` it controlled) satisfied every later check. Now anchors both
  `{repo}` and `{pr_base}` to `gh repo view` against the checkout's own git remote, with a
  ruleset-based fallback for the schema's long-migration case. Critic gate: `architect` +
  `docs-consistency` + `security-critic`, **4 rounds** (human-authorized past the 2-round
  cap) — converged. Round 1 found the fix didn't close its own reproduction (`{repo}` was
  still untrusted); round 2 found 2 HIGH bugs in the replacement (`gh api --jq` doesn't
  accept `--arg`; a jq/shell injection path); round 3 found a "two-hop" fix was inert
  ritual and relocated the real check; round 4 converged on wording only. Also fixed a
  real, independent bug in `resume` step 4's ruleset-name lookup along the way. Filed
  #112/#113/#114 for deliberately deferred, deeper gaps.
- **#100** (`eae5e6c`, [PR #116](https://github.com/glunk-works/claude-workbench/pull/116),
  merged): `pr-checks` said `missing` where `review-gate-state.sh` says `absent` for the
  same fact. Now `absent` everywhere. Critic gate: `architect` + `docs-consistency`, 2
  rounds, converged.
- **#99** (`5034273`, [PR #117](https://github.com/glunk-works/claude-workbench/pull/117),
  merged): four low tightenings in `architect-review` (steps 3/4/8). Critic gate:
  `architect` + `docs-consistency`, 3 rounds, converged — round 1 caught a real, live-
  verified HIGH bug in the fix itself: the new step-8 polling loop broke on
  `review-gate-state.sh`'s exit code (always 0 for all four words) rather than its
  printed word, so it never actually polled; fixed to test the captured word instead.

**Next:** Build the milestone's item 7, `chore(release)` → `v0.9.0`, on **sonnet**
(`coder`) — following [PR #101](https://github.com/glunk-works/claude-workbench/pull/101)'s
shape exactly: a `## [0.9.0]` `CHANGELOG.md` entry summarizing #97/#98/#100/#99, a
`plugin.json` version bump, and an explicit migration note (no `.ai/project.yml` key
changed, but `architect-review` now also reads `{ruleset.rule_types}` — confirm that's
still "no migration required," as `.ai/parked/` was for 0.8.0). Critic gate not required
for changelog/version mechanics alone (#101's own precedent) — say so in the PR body.
**Stop at the open PR — do not dispatch `release.yml` unattended;** cutting the tag is
explicitly the human's deliberate act (its `dry_run` default says so). After the human
runs it and it lands, this repo's own pin-bump PR follows next, per
[PR #102](https://github.com/glunk-works/claude-workbench/pull/102)'s precedent — that
pin-bump PR closes Sprint 1.
**Do not start #61** until every Sprint 1 PR has merged — verify against the milestone
first. **Do not start #104** unattended.

**HITL Gate: NONE OPEN.** Next gate: the human's merge of the `chore(release)` PR, then
the human's own dispatch of `release.yml` (`dry_run` first) to actually cut the tag.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D12`) ·
[milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1) ·
[open issues by milestone](https://github.com/glunk-works/claude-workbench/milestones)
