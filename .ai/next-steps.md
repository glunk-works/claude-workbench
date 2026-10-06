# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), milestone 11 *v0.16.0 follow-ups: merge-flow
hardening*. Status: **implementing**.

**Just done (2026-10-05/06):**
- Built #248 (`blocked-state.sh` takes rule parameters as `key=value` words and exits 2,
  naming the rules, when a green `BLOCKED` PR sits under one it cannot evaluate; pr-checks
  reports COULD NOT TELL naming them); merged as PR #260 (`2be93fc`).
- Critic pass on that diff: architect, security-critic and docs-consistency, 2 rounds,
  converged; second-opinion round offered and declined. No review CI gate exists, so that
  pass was the only critic look the diff had.
- Left open on purpose: unknown rule types (`workflows`, commit-message patterns) are still
  ignored, and the jq `// 0` / `// false` defaults could mask a rule whose `parameters` are
  absent. #245's deferred item (`cursor-sync-pr.sh` reading the live `required_status_checks`
  contexts) was not taken up by #248, which touched pr-checks only.

**Next:** task #244 — fixture: run `pr-checks`' blocked-state block against a stub `gh`.
Read the issue first, since #248 changed what that block feeds the predicate. Then the green
gate, critic-gate (architect + security-critic) and ship; #243, #246 and #247 follow in the
milestone's build order. On **sonnet** (`coder`).

**HITL Gate: NONE OPEN** — the milestone 11 description verified `match` against the prior
anchor this session; the next gate is the human's merge of each PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[.ai/parked/](parked/)
