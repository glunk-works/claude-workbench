# Cursor — claude-workbench

**Now:** **Sprint 10** (cursor id `sprint-10`), milestone 12 *Session-start hardening:
banner and branch prune* (due 2026-10-13). Status: **implementing**.

**Just done (2026-10-06):**
- Human confirmed the milestone 12 plan; task #270 built and shipped as PR #275
  (`85f2574`, open, awaiting the human's merge): the banner's `cap` now cuts to 200 then
  replaces control and line-breaking characters, `next_action` runs through `cap` before
  its sentence split; new `ctrl`, `sep` and `huge` fixtures.
- Critic pass (security-critic + architect): 2 rounds, converged. Round 1 caught the
  `gsub`-before-slice perf regression; round 2 tightenings only. Second-opinion round
  offered and declined.
- Plan anchor re-pointed from #270 to #271 (baseline `match`, same description sha).

**Next:** task #271 — in the resume skill's *Prune squash-merged local branches* step, when
a merged branch's local tip differs from `headRefOid`, fetch that oid and `-D` the branch
when `git merge-base --is-ancestor <branch> <oid>` succeeds; keep the skip when the fetch
fails or the tip has commits outside the oid; put the predicate in a fixture-tested `bin/`
script (pattern: `cursor-drift.sh`) with a `tests/*.test.sh` listed in the `CLAUDE.md`
green gate; run the green gate, then `/way-of-working:critic-gate`. On **sonnet**
(`coder`). Merge PR #275 first so #271 branches from a `main` that carries #270.

**HITL Gate: NONE OPEN** — the next gate is the human merging PR #275 and this cursor-sync
PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 12](https://github.com/glunk-works/claude-workbench/milestone/12) ·
[.ai/parked/](parked/)
