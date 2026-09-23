# Cursor — claude-workbench

**Now:** **Sprint 1** — [milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1),
*stabilize v0.8.0 and close the live-observed gaps*. Status: **implementing** — the next
build is [#98](https://github.com/glunk-works/claude-workbench/issues/98); no gate is open.
The plan of record is the milestone, not a file: build order, per-phase models, and the
release that closes the sprint are in its description.

**Just done (2026-09-23):**
- **#84** (`f79e6b1`): the prune snippet's `base=$(yq …)` now fails loudly instead of
  unguarding `{pr_base}` on an empty/`null` read, in both copies. Critic gate: `architect` +
  `docs-consistency`, 1 round, converged.
- **#62** (`d59658c`): `invariants-check.sh` now mechanically checks the two prune-block
  copies stay byte-identical. Critic gate: `architect`, 1 round — caught and fixed an
  off-by-one that silently dropped the block's last line from the comparison.
- **#85** (`f7440a0`): critic agent definitions now say read-only covers git state, not just
  files (a critic once moved HEAD in the shared workspace live). Critic gate: `architect` +
  `docs-consistency` + `security-critic`, **4 rounds** (human-authorized past the normal
  2-round cap) — converged.
- **#97** (`da5d842`, [PR #110](https://github.com/glunk-works/claude-workbench/pull/110),
  open): `architect-review` read `.ai/project.yml` from two copies and never synced the
  first, so a stale local `{pr_base}` could produce a confusing false NOT READY on a PR
  that's actually green. Now syncs onto `{pr_base}` unconditionally (fetch + switch + merge
  --ff-only + a byte-equality check against `origin/{pr_base}`) before the first read, and
  step 7 reads that single synced copy instead of a separate remote fetch. Critic gate:
  `architect` + `docs-consistency`, **3 rounds** (at the 2-round cap) — round 1 found the
  original fix used a bare `git pull` (against this plugin's own `archive-sprint`
  precedent) and no equality check; round 2 (both critics independently) found the fixed
  sync only ran when *not already* on `{pr_base}`, missing #97's own reproduction; round 3
  converged clean on both.

**Next:** Build **#98** on **sonnet** (`coder`): `architect-review`'s step-3 "on `{pr_base}`"
check is self-consistency (checked in the same checkout it verifies), not an independent
anchor — a checkout on a branch whose own `.ai/project.yml` lies about `pr_base` satisfies
it. Design settled in the issue comment: compare `{pr_base}` against
`gh api repos/{repo} --jq .default_branch` (admin-only, unlike `origin/HEAD`); on mismatch
(the schema's long-migration case) don't fail — confirm `{ruleset.name}` protects
`{pr_base}` via the same ruleset call `/way-of-working:resume` step 4 already makes, proceed
if it does, stop naming both values if not. **Budget note from the issue comment:** the new
clause is meant to replace step 3's "since the author controls that base" justification,
which #99 item 4 removes anyway — land after #99, or trim that sentence yourself when #98
lands. Then #100 (one word, `absent`), #99 (four low tightenings), then `chore(release)` →
`v0.9.0`. Critic gate: `architect` + `docs-consistency` + `security-critic` for #98 (trust
chain); `architect` + `docs-consistency` for #100/#99.
**Do not start #61** until every Sprint 1 PR has merged. **Do not start #104** unattended.

**HITL Gate: NONE OPEN.** Next gate: the human's merge of [PR #110](https://github.com/glunk-works/claude-workbench/pull/110)
(#97). Sprint 1 ships as `v0.9.0` after item 7 (`chore(release)`).

**Note:** this cursor sync supersedes the still-open
[PR #109](https://github.com/glunk-works/claude-workbench/pull/109) — cut before this
session's work, from the same stale base. #109 can be closed unmerged once this PR lands;
this one carries everything #109 had plus #97.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D12`) ·
[milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1) ·
[open issues by milestone](https://github.com/glunk-works/claude-workbench/milestones)
