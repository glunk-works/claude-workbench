# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **implementing**. Build order and model per phase
are in the milestone description.

**Just done (2026-09-23, sonnet coder session):**
- Built **#61** (build order step 1): converted every skill-step reference in
  `plugins/way-of-working/` to name-based form (self-references included) and added an
  enforcing check to `scripts/invariants-check.sh`.
- Ran `/way-of-working:critic-gate` (`architect` + `docs-consistency`, 2 rounds):
  round 1 found the step-number guard missing plural/hyphenated forms (one such reference
  was still live) plus a misattributed citation and a grammar slip; round 2 came back
  tightenings-only on both critics — **converged**.
- Shipped as [PR #131](https://github.com/glunk-works/claude-workbench/pull/131), merged
  at `cf90794`.

**Next:** on **sonnet** (`coder`): build **#127** (build order step 2 — qualify
`project-schema.md`'s absent-is-unreadable rule for keys marked Optional; docs-only, fix
is in the issue, no spec needed). Then #86/#128/#72 build from the approved specs.
**Do not start #104 unattended** (release-tag security surface; staged commands go to the
human).

**HITL Gate: NONE OPEN.** Specs approved at rev. 4. Next gate: the human merges each
build PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
