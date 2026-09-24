# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **implementing**. 0 open issues remain in the
milestone, but build order step 7 (the release itself) isn't fully closed out yet.

**Just done (2026-09-24, sonnet coder session):**
- Built **#104** (build order step 6): `release.yml`'s `release` job now runs under a
  `release` environment (main-only, required reviewer) and mints its write token from a
  dedicated GitHub App instead of `github.token`, narrowed to `contents: read` at the job
  level. Shipped as [PR #143](https://github.com/glunk-works/claude-workbench/pull/143).
  Critic gate: `architect` + `security-critic` + `docs-consistency`, 2 rounds, converged —
  round 1 found and fixed real issues in all three lanes (a false claim about what a dry
  run proves, ruleset-verify commands querying the wrong endpoint, a probe that could read
  "rejected" for an unrelated auth-scope reason, a token-scope overclaim, plus a deferred
  `create-github-app-token` deprecation); round 2 converged clean, tightenings only.
- Shipped the version bump as [PR #144](https://github.com/glunk-works/claude-workbench/pull/144)
  (`chore(release): bump the plugin to 0.10.0`) — critic gate not run, changelog/version
  mechanics alone, per #119's own precedent.
- Fixed the deferred `create-github-app-token` deprecation *before* the real release rather
  than after, as [PR #145](https://github.com/glunk-works/claude-workbench/pull/145) — critic
  gate not run, one-line swap both critics from #104's round already suggested.
- Ran the full remaining order live: dry run (approved) → admin created the
  `release-tag-creation` ruleset (verified: `creation` only, App as sole bypass actor,
  `protected-release-tags` confirmed untouched) → real release, **`v0.10.0` published** →
  both probes rejected (`GH013` on the hand push, `422` on the branch-workflow attempt,
  reproduced under a non-bypassable admin identity to rule out an auth-scope false pass) →
  no stray tags or branches left behind.
- Closed **#104** with the full verification writeup.

**Next:** on **sonnet** (`coder`): finish build order step 7 — bump *this repo's own*
plugin pin (`.claude/settings.json` → `extraKnownMarketplaces.claude-workbench.source.ref`)
from `v0.9.0` to `v0.10.0`, following `CHANGELOG.md`'s bump procedure (edit ref → re-register
the marketplace → uninstall/reinstall → restart → verify by commit SHA, not version string).
Ship it as its own `chore(release)` PR, mirroring PR #121's precedent. Then flag to the human
that build order step 7 also says "tell bounty-infra" — #86 recorded them as waiting on this
tag — which is a human communication call, not something to act on unattended.

**HITL Gate: NONE OPEN** for the pin-bump itself. The bounty-infra notification is the
human's call (see above) — next `/way-of-working:resume` should surface it, not skip it.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
