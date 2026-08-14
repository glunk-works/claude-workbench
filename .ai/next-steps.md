# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Status: **implementing** — [#43](https://github.com/glunk-works/claude-workbench/issues/43)
is closed, its fix merged as [PR #47](https://github.com/glunk-works/claude-workbench/pull/47)
(`360ed74`). Picking the next backlog item is what's left.

**Just done (2026-08-13):**
- **#43 closed** via PR #47 — `scripts/coupling-check.sh`'s TIER2 covered 4 of 8 org repos;
  now covers all 8 plus the `loop-engine` worked-example emitter name. Verified by deliberate
  regression (planted each new literal, confirmed the gate caught and named it, reverted).
- **Two pre-existing, legitimate `claude-workbench` self-references** in
  `archive-sprint/SKILL.md` and `retro/SKILL.md` (describing the plugin's own distribution
  source, not a leaked local-repo literal) were reworded to name the concept instead of the
  repo — adding the bare name to TIER2 would otherwise have broken the gate on them.
- **`/way-of-working:critic-gate` ran** (`architect`, human picked it over `security-critic` for this
  diff). **Two spawned rounds, converged; a third round of two trivial text corrections
  (a doc miscitation, a changelog arithmetic slip) was applied without a third spawn** given
  their severity — noting the deviation from the strict re-run-every-round rule rather than
  silently calling it a clean 2-round pass.
  - Round 1 (7 findings): 2 medium fixed (TIER2's "every repo in the org" comment silently
    depended on TIER1 covering `loop-orchestrator` — folded it into TIER2 directly; the
    comment pointed at #43 for a question this PR closes — refiled as **#48**), 1 pre-existing
    gap filed as **#49** (`plugins/*/hooks/` isn't scanned by this gate at all, and already
    has a live hit), 1 low-priority message improvement applied, PR title/body corrected.
  - Round 2: 2 low findings (message misquoted `project-schema.md`'s fix count; CHANGELOG
    conflated TIER1/TIER2 coverage) — both fixed directly.
- **PR #47 merged** (`360ed74`): lint, coupling, invariants, tests all passed.
- **Filed #48** (TIER2 derive-vs-hand-maintain — opus call) and **#49** (`hooks/` scanning
  gap, with a confirmed live hit in `ai-cursor-banner.sh`) as follow-ups, deliberately not
  folded into #43's PR.

**Next:** Pick the next backlog item — **#44** (secret-scanning validity checks; cheap, but
the human must run the `PATCH` calls, since the harness classifier declines `gh api` writes
to org repos), **#45** (which repos CodeQL can actually analyse — a decision, not a task),
**#48** (TIER2 derive-vs-hand-maintain — opus), or **#49** (add `hooks/` to the scanned set
and fix its one live hit — mechanical, coder-doable, the only one of the four that's a pure
pick-up-and-go). **Architect/opus** is assigned next because the live choice among these is
itself the kind of call #43's own scope note said belongs to opus, not because #49
specifically needs opus.

**HITL Gate: OPEN.** Which of #44/#45/#48/#49 comes next is not yet ratified — #49 is the
only purely mechanical pick if a quick coder pass is wanted instead.

**Pointers:** [`docs/decisions.md`](../docs/decisions.md) (roadmap/decisions of record) ·
[PR #47](https://github.com/glunk-works/claude-workbench/pull/47) (merged, closed #43) ·
[#44](https://github.com/glunk-works/claude-workbench/issues/44) ·
[#45](https://github.com/glunk-works/claude-workbench/issues/45) ·
[#48](https://github.com/glunk-works/claude-workbench/issues/48) ·
[#49](https://github.com/glunk-works/claude-workbench/issues/49)
