# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Nothing in implementation — status: planning, on **#28**'s split.

**Just done (2026-08-13):**
- **Cursor repair.** This handoff's main job: the cursor had gone five merged PRs stale
  (`last_commit` still pointed at #31's branch tip while `main` was at #36), because #33–#36
  and #38 each landed without a `/way-of-working:handoff`. `/way-of-working:resume` correctly
  reported `drift` and waited. `last_commit` is now `979000a` = `main`.
- **#37 closed** by PR **#38** (`979000a`): the documented pin-bump procedure no longer
  silently no-ops for a project-scoped install, and `conventions.md` now names the channel a
  pin bump actually ships on. All four checks green; merged by the human.
- Landed earlier without a cursor sync, recorded here for the record: **#21 closed**
  (`cursor-drift.sh` extracted from skill prose into a tested script — #33, corrected in
  #34), and **plugin 0.6.0 released** with this repo's own pin bumped to match (#35, #36).
- Pruned 2 squash-merged local branches. Ruleset `protected-integration-branches` healthy:
  4 rule types, 3 required checks.
- No `/way-of-working:critic-gate` pass this session and none needed — this session wrote no
  code (`git diff main...HEAD` empty).

**Next:** Split **#28** and start its **security half only** (decision 8 — private
vulnerability reporting, secret scanning, push protection, Dependabot alerts across the 8
org repos), per the issue's own recommended next action. Apply review items 2 and 6:
snapshot each repo's posture before changing anything, and treat
`bedrock-serverless-rag`'s secret-scanning enablement as an incident-shaped step — it is the
only repo in the org with Dependabot alerts off and may surface live historical credentials.
Leave the taxonomy half (decisions 1–7) alone pending review item 15. Architect/opus.

**HITL Gate: OPEN.** #28's security baseline mutates settings on 8 repos outside this one.
The human approves the rollout scope and order before any setting is flipped — nothing in
#28 runs unattended. No `review.ci_gate` in this repo.

**Pointers:** [`docs/decisions.md`](docs/decisions.md) (roadmap/decisions of record) ·
[#28](https://github.com/glunk-works/claude-workbench/issues/28) (the only open issue) ·
[#38](https://github.com/glunk-works/claude-workbench/pull/38) ·
[#37](https://github.com/glunk-works/claude-workbench/issues/37)
