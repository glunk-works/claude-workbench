# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), milestone 11 *v0.16.0 follow-ups: merge-flow
hardening*. Status: **implementing**.

**Just done (2026-10-06):**
- Built #243 (invariants-check check 11: a skill or agent that pipes `gh` output straight into
  a `plugins/*/bin` predicate fails the gate; two matcher passes, either one fails it; fixtures
  in `tests/invariants-gh-pipe.test.sh`, registered in CI and the CLAUDE.md gate list); merged
  as PR #264 (`ffc7ebd`).
- Critic pass on that diff: architect and security-critic, initial pass plus 4 fix-and-re-run
  rounds, **cap reached**, default models, no second-opinion round (declined). Rounds 1–4 each
  found real gaps in the matcher; round 5's last fix (awk/grep status handling, large-file
  SIGPIPE report) was verified by running, not re-reviewed, so the pass is not converged. No
  review CI gate exists, so that pass was the only critic look the diff had.
- Left open on purpose: the check is a regression guard — its header lists the shapes it cannot
  match; the new suite takes ~6 min on this Windows host (not measured on Linux CI); two local
  branches the prune skipped (`docs/sync-cursor-sprint-08-orchestrator-plan`,
  `fix/hook-exec-bit-214`) may hold stranded work.

**Next:** task #246 — `ai-cursor-banner`: cap the length of the state fields it injects. Read
the issue first. Then the green gate, critic-gate (architect + security-critic) and ship.
#247 is a *Decide* item — open a HITL Gate for it, don't build it. On **sonnet** (`coder`).

**HITL Gate: NONE OPEN** — the milestone 11 description verified `match` against the prior
anchor this session; the next gate is the human's merge of each PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[.ai/parked/](parked/)
