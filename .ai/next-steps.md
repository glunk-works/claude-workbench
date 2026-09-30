# Cursor — claude-workbench

**Now:** **Sprint 7** — [milestone 7](https://github.com/glunk-works/claude-workbench/milestone/7),
*the local green gate checks what it claims, in reasonable time*. Status: **implementing**;
both issues are merged, only the release step remains.

**Just done (2026-09-30):**
- #189 merged as #204 (`ab6eb2a`): `schema-complete.sh` reads each key table in one `yq`
  call; the fixture suite went from about 2m15s to about 15s on Git Bash. Batching was the
  human's choice over documenting the runtime.
- Critic pass on #189: `architect` + `security-critic`, 3 rounds, converged; no second-opinion
  round (declined). Round 1 found two real exploits in the batching (a percent-encoded YAML
  tag could forge a row; a multi-document file read `complete`), both fixed with fixtures.
  No review CI gate here, so that pass and the human's merge were the only review.
- Left open, pre-existing and out of scope, candidates for issues: yq-vs-other-parser
  differences (duplicate keys, empty leading documents); shapeless `value` keys accept a
  map/seq behind a custom tag; routing keys may start with `-`.

**Next:** the release step, item 3 of the milestone's build order — `chore(release)`: bump
`way-of-working` to 0.14.0 (covers #197/#198, #162 and #189, which touched `bin/`), tag it,
then bump this repo's own pin. Follow the earlier `chore(release)` PRs for the exact files.
Then `/way-of-working:critic-gate` (`architect`) and `/way-of-working:ship`. On **sonnet**
(`coder`). This is not one issue's build, so `/way-of-working:resume` waits for a "go".

**HITL Gate: NONE OPEN.** The human merges the release PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 7](https://github.com/glunk-works/claude-workbench/milestone/7) ·
[.ai/parked/](parked/)
