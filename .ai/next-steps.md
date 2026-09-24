# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **implementing**. Build order and model per phase
are in the milestone description.

**Just done (2026-09-23, sonnet coder session):**
- Built **#72** (build order step 5): added the optional `models.second_opinion` schema key
  — a human-authorized, spawn-time override on the Agent tool's `model` parameter for one
  late `/way-of-working:critic-gate` round on a different model, plus the one delta-scoped
  re-run its fixes require. Provenance is verified from harness-written transcript evidence
  (never the subagent's own report text) via a new `bin/spawn-model.sh`, fail-closed to
  `unconfirmed`/`mismatch` on anything it cannot verify. Rewrote `project-schema.md`'s and
  `workflow.md`'s prior absolute "models never touches subagent spawns" claim to state this
  one narrow exception; reworded "(Opus)"/"(Sonnet)" wording across the four agent files to
  "by default".
- Ran the local green gate (`lint.sh`, `coupling-check.sh`, `invariants-check.sh`, all
  `tests/*.test.sh` including the new `tests/spawn-model.test.sh`) — all passed.
- Ran `/way-of-working:critic-gate` (architect + security-critic + docs-consistency, all
  three confirmed by the human): **2 rounds, converged**. Round 1 found real,
  severity-bearing issues in all three lanes — a reproducible bug where a subagent's own
  tool-call input could smuggle a `model` key past a greedy match and forge provenance, a
  fail-open on a transcript's last line missing a trailing newline, an unvalidated
  `CLAUDE_CODE_SESSION_ID` allowing path traversal, a missing executable bit, a
  second-opinion offer that could repeat indefinitely, and several schema/skill
  contradictions (budget rule, a false "never searches directories" claim, a
  falsely-attributed prefix table, an unsupported cost multiplier, a sweep miss in
  `workflow.md`'s agent catalog). All fixed; round 2 converged clean (5 low-confidence
  tightenings total, 2 applied). `{models.second_opinion}` is not set in this repo, so no
  round ran on a different model this pass.
- Shipped as [PR #139](https://github.com/glunk-works/claude-workbench/pull/139).

**Next:** on **sonnet** (`coder`): task #104 — build order step 6, only `release.yml` may
create `v*` tags. The human already decided the bypass mechanism on 2026-09-23 (a GitHub App
`claude-workbench-release`, key held by a main-only `release` environment with a required
reviewer; App and environment already set up) —
[read the full decision record](https://github.com/glunk-works/claude-workbench/issues/104#issuecomment-5801462976)
before starting. Build the `release.yml` workflow gate and stage the
`release-tag-creation` ruleset-creation `gh api` command(s) for the admin to run — the
harness's own classifier blocks `gh api` writes to org-level settings, and this session must
not attempt that write itself. Then the green gate, `/way-of-working:critic-gate`, and ship.

**HITL Gate: OPEN.** Confirm #104's decision-record comment is read in full before starting —
this is a release-tag security surface (a new GitHub App plus a ruleset bypass actor).
Staged commands go to the human; never auto-run a ruleset or environment change.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
