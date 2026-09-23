# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **implementing**. Build order and model per phase
are in the milestone description.

**Just done (2026-09-23, sonnet coder session):**
- Built **#127** (build order step 2): qualified `project-schema.md`'s absent-is-unreadable
  rule with a clause for keys whose reference marks them Optional and states what absent
  means (`backlog.repo`, `review.ci_gate.triggers_on`, `migration_base`) — one clause, the
  fix given verbatim in the issue, no spec needed.
- Ran the local green gate (`lint.sh`, `coupling-check.sh`, `invariants-check.sh`) — all
  passed. Handed off without a `/way-of-working:critic-gate` pass: the diff is a single
  reference-doc clause matching the issue's own fix text, and the cursor's own next_action
  had already called this step docs-only, needs-no-spec.
- Shipped as [PR #133](https://github.com/glunk-works/claude-workbench/pull/133), at
  `bdec34e` (not yet merged).

**Next:** on **sonnet** (`coder`): build **#86** (build order step 3 — add the `planning:`
key, kind `github_milestones`, from the approved Fable spec; makes resume/handoff read the
active milestone instead of `sprint_plan.md`). Then `/way-of-working:critic-gate`
(`architect` + `docs-consistency`) before shipping. Then #128/#72 build from there.
**Do not start #104 unattended** (release-tag security surface; staged commands go to the
human).

**HITL Gate: NONE OPEN.** Specs approved at rev. 4. Next gate: the human merges PR #133,
then each subsequent build PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
