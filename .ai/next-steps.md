# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **done** — 0 open issues remain in the milestone and
build order step 7, the last piece, is merged. Not yet archived.

**Just done (2026-09-24, sonnet coder session):**
- Finished build order step 7's own-repo half: bumped this repo's plugin pin
  (`.claude/settings.json` → `extraKnownMarketplaces.claude-workbench.source.ref`) from
  `v0.9.0` to `v0.10.0`, following the corrected procedure in
  `reference/conventions.md` § *Bumping a pinned plugin* / the v0.10.0 release notes —
  **not** the stale generic blurb at the top of `CHANGELOG.md`, which still describes the
  superseded `claude plugin update` approach. Verified by commit SHA
  (`gitCommitSha` in `installed_plugins.json` against `git ls-remote --tags` for
  `v0.10.0`), not version string.
- Along the way, hit and recovered from the known drive-letter-case trap
  (`installed_plugins.json` keys `projectPath` as an exact string): mirroring the entry
  onto both casings via a bad `jq` edit corrupted it, and the follow-up
  `uninstall`/`install` then wiped the tracked entries for four *other* repos sharing this
  file (`infrastructure-core`, `bedrock-serverless-rag`, `jrg-consulting-site`,
  `bounty-infra`). Restored all four from a same-week backup
  (`installed_plugins.json.bak-20260923072031`, confirmed unchanged since) merged
  alongside the correct new `claude-workbench` entries. File is valid JSON, all 8 original
  entries present, nothing lost.
- Shipped the pin bump as [PR #147](https://github.com/glunk-works/claude-workbench/pull/147)
  (`chore(release): bump this repo's own pin to v0.10.0`) — critic gate not required,
  `.claude/settings.json` is not in `code_paths`, mirrors PR #121's precedent.
- Human restarted the session and confirmed the plugin loads correctly at the new pin, and
  separately bumped bounty-infra's own pin to `v0.10.0` — confirmed locally
  (`bounty-infra/.claude/settings.json` → `ref: v0.10.0`). This was the "tell bounty-infra"
  follow-up `#86` recorded them as waiting on; it's done, not just flagged.

**Next:** on **sonnet** (`coder`, mechanical task — any model would do): run
`/way-of-working:archive-sprint` to close out Sprint 2 / milestone 2 and seed the cursor
for whatever comes next.

**HITL Gate: OPEN** — human sign-off that Sprint 2 is actually done and ready to archive.
Evidence: 0 open issues in [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
PR #147 merged, bounty-infra's pin confirmed at `v0.10.0`. Archiving closes the milestone
and rewrites the cursor, so the next `/way-of-working:resume` waits rather than auto-running it.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
