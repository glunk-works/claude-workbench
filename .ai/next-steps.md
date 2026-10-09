# Cursor — claude-workbench

**Now:** **Sprint 13** (cursor id `sprint-13`) on [milestone 16, *Identity M1: Apps, token minting and scratch proof*](https://github.com/glunk-works/claude-workbench/milestone/16) ([WB-D24](../docs/decisions.md)). Status: **implementing**, every issue in the milestone closed, the roadmap entry still to write.

**Just done (2026-10-09):**
- Task #377 closed (PR #445, `40fd3f8`): session 5 in `docs/proposals/IDENTITY-SCRATCH-RESULTS.md`, the org approval ruleset on a 603-Identity scratch repo. Cases a, b and c pass; auto-merge fired late both times (timings on #432). Case e was skipped by choice, replaced by a maintainer-authored-PR test and a test that a repo-scoped admin token cannot edit the org ruleset (it cannot).
- WB-D24 amended for 603-Identity in the same PR: one code owner, no second seat, break glass is a browser ruleset suspension.
- Task #443 closed (PR #444, `53d620d`): the host `apps.json` is keyed by role (`dev`, `review`, `admin`), verified on both hosts; the 603 config lives in its own `WOW_HOME`.
- Critic pass on #444 (architect and security-critic): 2 rounds. Round 1 found no defect, only tightenings. Round 2 found the new test passing vacuously, fixed and checked by a deliberate-regression run instead of a third spawn. Converged; no second-opinion round.

**Next:** write sprint 13's done entry in the Status section of `docs/decisions.md` as its own PR (`docs: mark sprint-13 done in docs/decisions.md`), on **sonnet** (coder). After the human merges it, run `/way-of-working:archive-sprint`.

**HITL Gate: NONE OPEN.** The next gate is the human's merge of that PR; `/way-of-working:archive-sprint` needs the entry on `origin/main`. No task issue is anchored, so `/way-of-working:resume` waits for a human "go".

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 16](https://github.com/glunk-works/claude-workbench/milestone/16) · [.ai/parked/](parked/)
