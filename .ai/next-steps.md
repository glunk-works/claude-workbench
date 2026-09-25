# Cursor — claude-workbench

**Now:** **Sprint 4** — [milestone 3](https://github.com/glunk-works/claude-workbench/milestone/3),
*record the deferred decisions*. Status: **done**.

**Just done (2026-09-25, Sonnet, coder):**
- Task #45 shipped and merged: [PR #176](https://github.com/glunk-works/claude-workbench/pull/176)
  (`5b73f8b`) — `WB-D15` recorded in `docs/decisions.md`: a `zizmor` job added to
  `ci.yml` (two runs — a real gate plus a SARIF upload; a single default-mode run, as
  first drafted, never actually fails on a finding), the `dependabot-cooldown` finding
  fixed, two `adhoc-packages` findings suppressed with justification, and
  [bedrock-serverless-rag#134](https://github.com/glunk-works/bedrock-serverless-rag/issues/134)
  filed asking a human to enable CodeQL default setup there. `/way-of-working:critic-gate`
  (`architect` + `security-critic` + `docs-consistency`): 3 rounds, converged — caught the
  zizmor-never-fails defect and a leftover stray step from fixing it.
- Unplanned, at the maintainer's direct request (not a milestone-3 item): issue
  [#177](https://github.com/glunk-works/claude-workbench/issues/177) →
  [PR #178](https://github.com/glunk-works/claude-workbench/pull/178) (`4f58026`) —
  `WB-D16`: `/way-of-working:critic-gate`'s hard cap raised from 2 to 4 fix-and-re-run
  rounds, critic selection now goes through a structured pick-list wherever the host can
  present one. Critic gate: `architect`, 3 rounds, converged — caught an invented,
  arithmetically-wrong rationale for the cap raise (removed rather than kept) and a false
  round-count claim in the skill's own worked example.
- Unplanned, at the maintainer's explicit call ("despite what this sprint said"): cut
  release **v0.12.0** — [PR #179](https://github.com/glunk-works/claude-workbench/pull/179)
  (plugin bump + changelog, `bc4237a`) merged, tag/release published targeting that same
  commit, [PR #180](https://github.com/glunk-works/claude-workbench/pull/180) (this repo's
  own pin bump, `85db39d`) merged. Ran the plugin-update procedure locally: marketplace
  re-pointed to `v0.12.0`, `claude plugin update --scope project`, and the known
  drive-letter-casing trap (`c:\` vs `C:\` in `installed_plugins.json`) mirrored so the IDE
  session's casing also reports `0.12.0` — restart still required to load it.

**Next:** Verify the plugin update actually landed — run `claude plugin list` and confirm
`way-of-working@claude-workbench` reports `0.12.0` (never infer this from a new cache
directory appearing; old ones are never removed). Then run
`/way-of-working:archive-sprint` to close out sprint-04 (milestone 3 — 0 open issues) and
plan sprint-05. On **opus** (`architect`) — sprint close feeds directly into planning the
next sprint.

**HITL Gate: NONE OPEN** — next is `/way-of-working:archive-sprint`, a deliberate
sprint-completion action; `sprint_status: done` also blocks unattended auto-start
regardless.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 3](https://github.com/glunk-works/claude-workbench/milestone/3)
