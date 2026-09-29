# Cursor — claude-workbench

**Now:** **Sprint 7** — [milestone 7](https://github.com/glunk-works/claude-workbench/milestone/7),
*the local green gate checks what it claims, in reasonable time*. Status: **implementing**.

**Just done (2026-09-29):**
- #162 merged as #202 (`71b63f4`): invariants check 3 now matches the real
  `gh api --paginate repos/...` ruleset call, reports a missing call loudly, and has a
  fixture suite (`tests/invariants-reach-order.test.sh`) that goes red against the old script.
- Critic pass on #162: `architect`, 2 rounds, converged; no second-opinion round. No review
  CI gate here, so that pass and the human's merge were the only review.

**Next:** task #189 — make `tests/schema-complete.test.sh` not read as hung on Git Bash
(about 2m15s, past the default 120s timeout). First put the choice to the human — batch the
`yq` calls, or keep them and document the runtime — then implement it, run the local green
gate, then `/way-of-working:critic-gate` (`architect`; `docs-consistency` if it settles on
documenting) and `/way-of-working:ship`. On **sonnet** (`coder`). After it: the
`chore(release)` step (0.14.0) from the milestone's build order.

**HITL Gate: OPEN.** #189 needs the batch-vs-document decision from the human before any
code. Then the human merges #189's PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 7](https://github.com/glunk-works/claude-workbench/milestone/7) ·
[.ai/parked/](parked/)
