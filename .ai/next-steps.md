# Cursor — claude-workbench

**Now:** **Sprint 11** (cursor id `sprint-11`), milestone 9 *Sprint 8: orchestrator
milestone 1* (due 2026-10-23). Status: **implementing**.

**Just done (2026-10-06):**
- #233 built and merged as PR #292 (`e8475a9`), closing #233: new `bin/driver-lock.sh`
  (present / absent / unreadable) and resume waits on anything but absent, naming it in the
  pick-up line; the driver directory is host config (`$WOW_DRIVER_DIR`, else the XDG default),
  never a project.yml key; fixtures wired into CI.
- Critic pass (architect, security-critic, docs-consistency): 3 rounds, converged — round 3
  returned a comment fix and tightenings only; no second-opinion round.
- Residuals recorded in the script header: a repo's `.claude/settings.json` `env` can also set
  the driver location; the driver must use the default path or export the variable to login
  sessions; the lock is host-wide and a read, not mutual exclusion. The `chmod`/symlink fixtures
  skip on the Windows author host and run only in Linux CI.
- The sprint's plan anchor was re-taken for #234 (baseline verified `match`).

**Next:** task #234 — build the `orchestration.*` schema keys on **sonnet** (`coder`):
`critics`, `round_cap`, `human_only_paths`, `loop_identity` (optional) and the restrict-updates
choice in `reference/project-schema.md` and `schema-complete.sh`, with fixtures; decide and
document whether `orchestration` as a whole is required for every adopting repo or only one the
loop dispatches into; check resume's interview pick-list rules for each new kind; answer (or
explicitly decline) the keys in this repo's `.ai/project.yml`. Then
`/way-of-working:critic-gate` (architect, security-critic, docs-consistency) and
`/way-of-working:ship` one PR closing #234.

**HITL Gate: NONE OPEN** — next gate: the human merge of #234's build PR (no review CI gate in
this repo).

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 9](https://github.com/glunk-works/claude-workbench/milestone/9) ·
[.ai/parked/](parked/)
