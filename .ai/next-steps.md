# Cursor — claude-workbench

**Now:** **Sprint 8** (cursor id `sprint-08`), anchored on
[milestone 8](https://github.com/glunk-works/claude-workbench/milestone/8), *Security review
phase 1: plugin release*. Status: **implementing**. (Milestone 9 is titled "Sprint 8:
orchestrator milestone 1"; it is the next sprint, not this one.)

**Just done (2026-10-05):**
- PR #221 (plan v9) merged. Milestone-1 issues created from v9 § 7.1 steps 1–2 and § 8.13:
  #229–#236, plus 603-Identity/devcontainers#262.
- `/way-of-working:plan-sprint` triaged the 20 unmilestoned issues into new milestones 8, 9
  and 10, with a `[plan-sprint]` comment on each; #223 and #227 left unmilestoned. #229 moved
  from milestone 9 into 8 so both PR-workflow blockers under the restrict-updates ruleset
  ship first.
- PR #228 (`docs/decisions.md`: pm-agent-loop archived) open for the human's admin merge.
- **Daily-flow consequence, still true:** every merge to `main` is a bypass; merge in the web
  UI or with `gh pr merge --admin` outside a Claude session until #229 ships.
- No code diff this session (planning only), so no critic pass applied.

**Next:** task #229 — make resume's cursor-sync merge carry `--admin` and update the prose
that forbids it; then the green gate, `/way-of-working:critic-gate` (`architect` +
`security-critic`) and `/way-of-working:ship`. On **sonnet** (`coder`). The rest of the
build order is in the milestone description.

**HITL Gate: OPEN** — first anchor for milestone 8, description sha
`31bc11c6464d9e0d77c7a7d19e3434da1dc4f7b9cfd33c6ba3dce36da4bc653d`. Merging this cursor-sync
PR confirms milestone 8 as the live sprint and #229 as its first task; then say go. Next
gate after that: the human merges each task PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 8](https://github.com/glunk-works/claude-workbench/milestone/8) ·
[plan v9](../docs/proposals/sprint-orchestrator-plan-v9.md) · [.ai/parked/](parked/)
