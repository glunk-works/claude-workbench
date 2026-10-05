# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), no milestone picked yet. Status: **planning**.
Plugin **v0.16.0** is released and this repo's own pin is bumped to it; #225 and #226 are
merged but unreleased and ship with the milestone 9 release.

**Just done (2026-10-05, archive-sprint, no code diff):**
- Archived Sprint 8, which closed at `d4f82ac` (PR #252) and is recorded in
  `docs/decisions.md` by PR #253. No deep-record compaction was needed.
- Shipped this sprint: #229, #224, #214 (v0.16.0), then #225 (PR #251) and #226 (PR #252).
- Decided: `restrict-updates-to-main` stays — every merge to `main` is an admin bypass by
  design (flow control, not a workaround). Release plan: one release at the end of milestone
  9, unless something worth pushing out sooner is fixed.
- Planned the backlog (plan-sprint): created milestone 11, *v0.16.0 follow-ups: merge-flow
  hardening* (due 2026-10-16, ships with the milestone 9 release), and placed #250, #245, #248,
  #244, #243, #246 and #247 in it in that build order. #227 and #223 stay unmilestoned on
  purpose. Milestones 9 (due 2026-10-23), 6 and 10 are unchanged.

**Milestone close:** closed — milestone 8, *Security review phase 1: plugin release*
(`verify --plan` match, 0 open issues, read-back `closed`).

**Next:** pick which milestone is the next sprint — milestone 11 (due 2026-10-16, ahead of
milestone 9) or milestone 9 — and anchor it via `/way-of-working:handoff`; picking is a human
decision, not plan-sprint's. Milestone 9's plan wants an architect-drafted `WB-D` for #230
before any build, and its step 1 depends on 603-Identity/devcontainers#262. Sprint-06 stays
parked. On **opus** (`architect`).

**HITL Gate: NONE OPEN** — the next gate is the human choosing the next milestone.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[CHANGELOG.md](../CHANGELOG.md) · [.ai/parked/](parked/)
