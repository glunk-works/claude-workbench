# Cursor — claude-workbench

**Now:** **Sprint 1** — [milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1),
*stabilize v0.8.0 and close the live-observed gaps*. Status: **implementing** — the next
build is [#97](https://github.com/glunk-works/claude-workbench/issues/97); no gate is open.
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
  2-round cap) — converged. Round 1 found the fix didn't cover #85's own scenario
  (uncommitted work); round 2 found and closed a push-to-real-remote hole the round-1 fix
  itself had opened; rounds 3–4 were prose-accuracy corrections (a historical claim wrong
  twice, then a self-contradiction), each caught by a critic reading the repo's own other
  docs rather than just re-reading the new prose.

**Next:** Build **#97** on **sonnet** (`coder`): `/way-of-working:architect-review` reads
`.ai/project.yml` from two copies (local working tree, then `origin/{pr_base}`) and never
syncs the first, so a stale local checkout can produce a confusing false NOT READY on a PR
that's actually green. Fix per the issue: one clause (`git switch {pr_base} && git pull
--ff-only` before the first read) or collapse to the single `origin/{pr_base}` read step 7
already uses. The skill is at 1198/1200 words — trim elsewhere to stay in budget. Then #98
(`pr_base` anchor, design settled in the issue comment), #100 (one word, `absent`), #99
(four low tightenings), then `chore(release)` → `v0.9.0`. Critic gate: propose per diff —
#97/#100/#99 are architect + docs-consistency; #98 add security-critic (trust chain).
**Do not start #61** until every Sprint 1 PR has merged. **Do not start #104** unattended.

**HITL Gate: NONE OPEN.** Next gate: the human's merge of the #97 PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D12`) ·
[milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1) ·
[open issues by milestone](https://github.com/glunk-works/claude-workbench/milestones)
