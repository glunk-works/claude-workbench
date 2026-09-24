# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **implementing** —
build-order step 1 (#126) is done; step 2 (#113) waits on a human pick.

**Just done (2026-09-24, Sonnet):**
- Build-order step 1, task #126: extracted `architect-review`'s PR-base preflight chain to
  `bin/review-base-anchor.sh` + `tests/review-base-anchor.test.sh`, `SKILL.md` now calls it
  by bare name. Shipped as [PR #156](https://github.com/glunk-works/claude-workbench/pull/156)
  (merged).
- Critic-gate on #126: architect + security-critic, 3 rounds, converged — the last two
  rounds ran past this pass's own 2-round cap on explicit human authorization, closing a
  real `git switch`-as-option corruption path (reproduced live), a "verified synced" gap, a
  CWD-relative config read, and a human-override scoping gap. No `models.second_opinion`
  round attempted (not set in `.ai/project.yml`). Full findings in `docs/decisions.md`'s
  `WB-D10` entry.
- Cleaned up a stale `docs/sync-cursor-113-spec` branch left over after its own PR (#155)
  had already merged — deleted locally and on `origin`, nothing lost.

**Next:** task #113 — on **sonnet** (`coder`), once picked: implement the worktree-isolation
fix per the 2026-09-24 revision-2 spec comment
([comment](https://github.com/glunk-works/claude-workbench/issues/113#issuecomment-5816327570)) —
option 1 (A+C+D now, B scheduled for Sprint 5) is recommended. Build-order step 2. Then the
green gate, `/way-of-working:critic-gate` (architect + security-critic + docs-consistency —
trust chain plus a skill-prose diff), `/way-of-working:ship`.

**HITL Gate: OPEN** — pick #113's isolation mechanism from the revision-2 spec comment
(option 1, A+C+D now with B scheduled for Sprint 5, recommended; 2, B this sprint; or 3, E).
Needed before build-order step 2 starts.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
