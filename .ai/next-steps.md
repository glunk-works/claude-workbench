# Cursor — claude-workbench

**Now:** **Sprint 5** — [milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5),
*every config key is an explicit decision*. Status: **planning**.

**Just done (2026-09-28, resync only, no diff this session):**
- Confirmed via `/way-of-working:resume` that the cursor had drifted behind reality: task
  #152's [PR #187](https://github.com/glunk-works/claude-workbench/pull/187) and its
  cursor-sync [PR #188](https://github.com/glunk-works/claude-workbench/pull/188) were
  already merged, the plugin had shipped as
  [v0.13.0](https://github.com/glunk-works/claude-workbench/pull/190), and this repo's own
  plugin pin was bumped to v0.13.0
  ([PR #191](https://github.com/glunk-works/claude-workbench/pull/191)) — all of it landed
  without the ledger being resynced in between.
- Ruleset check: healthy (`protected-integration-branches`: 4 rule types, 3 required
  checks). No migration under way.
- Pruned 2 squash-merged local branches (`chore/pin-v0.13.0`, `chore/release-0.13.0`).
- Milestone 5 has exactly one open issue left: **#158**.

**Next:** run a pre-build architect design pass on #158 (container the PR-execution
sandbox to close the keyring/persistent-write residual) — it needs a new
`review.sandbox.image` schema key and a decision between the sandbox's existing `env -i`
isolation and a Docker/Podman container (option B, per #113's approved design revision 2)
before any code is written, the same way #152 went through adversarial architect reviews
first. On **opus** (`architect`).

**HITL Gate: NONE OPEN** — next human checkpoint is approving the #158 design once the
pre-build architect pass produces one.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 5](https://github.com/glunk-works/claude-workbench/milestone/5) ·
[issue #158](https://github.com/glunk-works/claude-workbench/issues/158)
