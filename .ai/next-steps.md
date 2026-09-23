# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **implementing**. Build order and model per phase
are in the milestone description.

**Just done (2026-09-23, Fable planning session):**
- Wrote the Sprint 2 design specs as issue comments:
  [#86 spec](https://github.com/glunk-works/claude-workbench/issues/86#issuecomment-5802157545)
  (`planning:` key, kind `github_milestones`, incl. the plan-anchor design) and
  [#72 spec](https://github.com/glunk-works/claude-workbench/issues/72#issuecomment-5802159298)
  (`models.second_opinion`). Build notes for #128 are
  [commented on #128](https://github.com/glunk-works/claude-workbench/issues/128#issuecomment-5802470718).
- The specs went through **three critic rounds** (`architect` + `security-critic` +
  `docs-consistency`, all Opus, fresh-context; round 3 human-authorized past the cap) and
  were revised in place each round — edit history on the comments is the round record.
  **Human approved rev. 4.** No code diff this session, so no critic-gate pass was owed.
- Pruned squash-merged local branch `fix/112-migration-base-anchor`.

**Next:** on **sonnet** (`coder`): build **#61** (build order step 1 — name-based skill-step
references + the `invariants-check.sh` guard; approved 2026-09-23, self-references included;
no spec needed). Then #127 (docs-only, fix in the issue). #86/#128/#72 build from the
approved specs. **Do not start #104 unattended** (release-tag security surface; staged
commands go to the human).

**HITL Gate: NONE OPEN.** Specs approved at rev. 4. Next gate: the human merges each
build PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
