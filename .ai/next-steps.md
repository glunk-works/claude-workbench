# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), milestone 11 *v0.16.0 follow-ups: merge-flow
hardening*. Status: **implementing**.

**Just done (2026-10-05):**
- Built #245 (`cursor-sync-pr.sh` takes `{ruleset.required_checks}` as a third argument and
  offers a `BLOCKED` sync PR only if every listed name is a green entry in the rollup);
  merged as PR #258 (`7476419`).
- Critic pass on that diff: architect, security-critic and docs-consistency, 2 rounds,
  converged; second-opinion round offered and declined. No review CI gate exists, so that
  pass was the only critic look the diff had.
- Left open on purpose: the required list is the working-tree `.ai/project.yml`, not the
  live ruleset's contexts, and matching is by name only. The architect suggested reading the
  contexts from `rules/branches/<base>` instead; deferred to #248, not yet confirmed there.

**Next:** task #248 — `pr-checks` reads the rules the blocked-state predicate cannot see.
Read the issue first, since #245 left the live `required_status_checks` contexts to it. Then
the green gate, critic-gate (architect + security-critic) and ship; #244, #243, #246 and
#247 follow in the milestone's build order. On **sonnet** (`coder`).

**HITL Gate: OPEN** — first anchor for milestone 11 in this handoff (no verified baseline
this session), description sha
`267c67978b0a48a26b8706dd5fba09b5c9dd95c4b3c6841986140840fe8bded5`, unchanged since the
previous anchor: a human confirms the description is still the intended plan, then says go.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[.ai/parked/](parked/)
