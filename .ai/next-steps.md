# Cursor — claude-workbench

**Now:** **Sprint 1** — [milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1),
*stabilize v0.8.0 and close the live-observed gaps*. Status: **implementing** — the next
build is [#84](https://github.com/glunk-works/claude-workbench/issues/84); no gate is open.
The plan of record is the milestone, not a file: build order, per-phase models, and the
release that closes the sprint are in its description.

**Just done (2026-09-23):**
- **Planned three sprints as GitHub milestones** (Fable, the human's standing routing for
  planning). Sprint 1 = seven small fixes ordered by urgency, then `v0.9.0`
  ([milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1)). Sprint 2 =
  the three approved schema/convention changes plus the release-tag rule, then `v0.10.0`
  ([milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2)). Sprint 3 =
  the two deferred decisions
  ([milestone 3](https://github.com/glunk-works/claude-workbench/milestone/3)).
- The owner answered #61 (refer by name, no exceptions) and #72 (option 1) the same day;
  both lost `status/needs-human`. #104 gained it — its one blocker is the bypass mechanism.
- #74 closed 2026-09-02; the previous cursor still named it as the next build.

**Next:** Build **#84** on **sonnet** (`coder`): the prune snippet's `base=$(yq …)` must
fail loudly on an empty or `null` read, in **both** copies identically; #62 then locks the
parity in `invariants-check.sh`. Critic gate: `architect` + `docs-consistency`.
**Do not start #61** until every Sprint 1 PR has merged. **Do not start #104** unattended.

**HITL Gate: NONE OPEN.** Next gate: the human's merge of the #84 PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D12`) ·
[milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1) ·
[open issues by milestone](https://github.com/glunk-works/claude-workbench/milestones)
