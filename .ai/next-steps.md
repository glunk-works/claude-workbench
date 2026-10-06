# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), milestone 11 *v0.16.0 follow-ups: merge-flow
hardening*. Status: **implementing**.

**Just done (2026-10-05/06):**
- Built #244 (`tests/blocked-state-block.test.sh`: extracts pr-checks' block (b), runs it
  against a stub `gh`; failing `gh` never reaches the predicate, unsafe branch names stop the
  chain before any `gh api` call, three mutants must fail open as `lag|0`; registered in CI
  and the CLAUDE.md gate list); merged as PR #262 (`28cea99`).
- Critic pass on that diff: architect and security-critic, 2 rounds. Round 2's one fix (the
  bash switch the file's comment described but never made) was verified by running the test,
  not by a third re-spawn, so the pass is not strictly converged. No review CI gate exists,
  so that pass was the only critic look the diff had; no second-opinion round ran.
- Left open on purpose: the pr-checks block's character check admits `..` (git forbids it in
  real ref names); no backlog issue filed for it yet.

**Next:** task #243 — `invariants-check`: reject piping `gh api` into a predicate script.
Read the issue first. Then the green gate, critic-gate (architect + security-critic) and
ship; #246 follows. #247 is a *Decide* item — open a HITL Gate for it, don't build it. On
**sonnet** (`coder`).

**HITL Gate: NONE OPEN** — the milestone 11 description verified `match` against the prior
anchor this session; the next gate is the human's merge of each PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[.ai/parked/](parked/)
