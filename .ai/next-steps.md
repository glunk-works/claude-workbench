# Cursor — claude-workbench

**Now:** **Sprint 2**: [milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2),
*plan in GitHub, not in files*. Status: **implementing**. Build order and model per phase
are in the milestone description.

**Just done (2026-09-23, sonnet coder session):**
- Built **#128** (build order step 4): `archive-sprint` now closes a sprint's GitHub
  milestone under `planning.kind: github_milestones` — gated on 0 open true issues (PRs
  excluded) and a `plan-anchor.sh verify --plan` match on a known-usable anchor; stages the
  close for the human (`hitl_gate` open) on drift/unreadable/no-baseline, a harness refusal,
  or an unconfirmed read-back, and reports an already-closed milestone or blocked issue
  distinctly rather than silently.
- Ran the local green gate (`lint.sh`, `coupling-check.sh`, `invariants-check.sh`, all
  `tests/*.test.sh`) — all passed.
- Ran `/way-of-working:critic-gate` (architect + security-critic + docs-consistency, all
  three confirmed by the human): **3 rounds, converged** — round 1 found ~15 issues (a
  step-jump that bypassed the new step entirely, an unresolvable script path, a
  Guardrails/body contradiction, an unprojected description re-fetch); round 2 found a
  pending-close persistence gap on the unpark-handoff path (fixed with a follow-up commit
  onto unpark's own PR) and surfaced a spec-vs-safety judgment call — whether an
  unpark-restored `plan_anchor` should ever auto-trust `verify --plan`'s answer — put to the
  human rather than decided unilaterally; **human chose to follow the spec literally**; round
  3 converged clean except one small fix (mirror the pending note into `state.json`'s
  `hitl_gate`, not just the tracked ledger), applied directly at the round cap.
- Shipped as [PR #137](https://github.com/glunk-works/claude-workbench/pull/137), merged at
  `e540cbd`.

**Next:** on **sonnet** (`coder`): build **#72** (build order step 5 — `models.second_opinion`,
a late critic-gate round on a different model, provenance-verified via a new
`bin/spawn-model.sh` reading harness-written subagent transcripts). Its
[rev-4 spec comment](https://github.com/glunk-works/claude-workbench/issues/72#issuecomment-5802159298)
is the same shape #86's approved spec was — already through 3 critic rounds at planning
time. Read it in full (this session only sampled part of it) and confirm it's ready to build
directly — ask the human if unclear. Then the green gate, `/way-of-working:critic-gate`, and
ship.
**Do not start #104 unattended** (release-tag security surface; staged commands go to the
human).

**HITL Gate: OPEN.** Confirm #72's rev-4 spec is read in full and ready to build directly
before starting.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 2](https://github.com/glunk-works/claude-workbench/milestone/2) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
