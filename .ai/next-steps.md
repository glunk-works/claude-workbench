# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **planning**. The build order and the model for
each phase are in the milestone description.

**Just done (2026-09-23):**
- Sprint 1 archived (cursor snapshot in `.ai/archive/`, git-ignored; nothing to compact).
  Its [milestone 1](https://github.com/glunk-works/claude-workbench/milestone/1) was then
  **closed by hand**. That gap in `archive-sprint` is now
  [#128](https://github.com/glunk-works/claude-workbench/issues/128).
- Triaged the unmilestoned backlog:
  - #127 and #128 went into Sprint 2. #127 comes before #86; #128 comes right after it.
  - A new [Sprint 3: harden architect-review's trust chain](https://github.com/glunk-works/claude-workbench/milestone/4)
    holds #126, #113 and #125, and ships as v0.11.0.
  - The old "record the deferred decisions" sprint was renamed **Sprint 4**
    (milestone 3).
  - #124 stays unmilestoned, as its own text asks. The reason is commented on the issue.
- [PR #123](https://github.com/glunk-works/claude-workbench/pull/123) (#112, trust only the
  default branch's `migration_base`) merged as `e43a1ff`.

**Next:** on **fable** (`architect`), by the human's routing of design to Fable in milestone 2:
write the design specs as comments on **#86** and **#72**. The #86 spec must say how a
sprint maps to a milestone, because #128 builds on it. Output is issue comments only.
#61 and #127 need no spec and can go straight to a Sonnet `coder`.
**Do not start #104 unattended**, since it changes the release-tag ruleset's security surface.

**HITL Gate: NONE OPEN.** The next gate: the human approves the #86 and #72 specs before
build starts.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
