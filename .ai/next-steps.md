# Cursor — claude-workbench

**Now:** **Sprint 9** (cursor id `sprint-09`), anchored on
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11), *v0.16.0
follow-ups: merge-flow hardening* (due 2026-10-16, ships with the milestone 9 release).
Status: **implementing**. Plugin **v0.16.0** is released and this repo's own pin is bumped to
it; #225 and #226 are merged but unreleased.

**Just done (2026-10-05, archive-sprint + plan-sprint + handoff, no code diff):**
- Archived Sprint 8 (milestone 8 closed; it closed at `d4f82ac`, recorded in
  `docs/decisions.md`, PR #253).
- Planned the backlog: created milestone 11 and placed #250, #245, #248, #244, #243, #246 and
  #247 in it in that build order. #227 and #223 stay unmilestoned on purpose; milestones 9,
  6 and 10 are unchanged.
- Decided: `restrict-updates-to-main` stays, so every merge to `main` is an admin bypass by
  design. One release at the end of milestone 9, unless something worth pushing out sooner
  is fixed. Next sprint is milestone 11, ahead of milestone 9.
- First anchor for milestone 11, description sha
  `267c67978b0a48a26b8706dd5fba09b5c9dd95c4b3c6841986140840fe8bded5`.

**Next:** task #250 — before `resume` offers the `--admin` cursor-sync merge, check the
active `gh` identity can bypass the restrict-updates ruleset; if not, do not offer it, name
the identity and say to merge in the web UI or switch `gh`; give `pr-checks`' READY (admin
merge) verdict the same identity line; add fixtures for `never` and `pull_requests_only`;
update the CHANGELOG, WB-D20 and the script and skill prose. Then the green gate,
`/way-of-working:critic-gate` (`architect` + `security-critic`) and `/way-of-working:ship`.
#245, #248, #244, #243, #246 and #247 follow in the milestone's build order. On **sonnet**
(`coder`).

**HITL Gate: OPEN** — first anchor for milestone 11: a human confirms the milestone
description is the intended plan, then says go.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 11](https://github.com/glunk-works/claude-workbench/milestone/11) ·
[CHANGELOG.md](../CHANGELOG.md) · [.ai/parked/](parked/)
