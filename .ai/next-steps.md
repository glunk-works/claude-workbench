# Cursor — claude-workbench

**Now:** **Sprint 23** (cursor id `sprint-23`), status **implementing**, milestone 38 (*Rule-based critic selection by default*).

**Just done (2026-11-18, driver session, opus):**
- Checked the `v0.38.0` plugin install: the user entry and the `/workspace` entry are both at `f37258d`.
- `/way-of-working:plan-sprint findings`, its first live run (#1620, closed with the record): findings issues #1579, #1610, #1612, #1613, #1617 and #1619 were unpacked into combined issues #1623 (`area/identity`), #1624 (`area/way-of-working`) and #1625 (`area/ci`), with two findings declined as already fixed, and the six source issues were closed after their mapping comments.
- `/way-of-working:plan-sprint`: created milestone 38 for #1614; placed #1623 and #1625 in milestone 29 and #1624 in milestone 33, with both build orders edited live through `milestone-desc.sh` (auto mode, not denied: a `WB-D28` data point). #223, #334, #409, #1167 and #1548 stay unmilestoned for the reasons recorded on 2026-11-17.
- The maintainer picked milestone 38 as Sprint 23; first anchor for milestone 38.

**Next:** task #1614 — get #1614 specced: the maintainer reacts on #1614 after its last edit, then the driver hands over `wowl glunk-works/claude-workbench -Spec 1614`; once the maintainer reacts on the posted spec, the driver preps its lane when the maintainer says. Model: opus (architect).

**HITL Gate: OPEN** — first anchor for milestone 38: the maintainer confirms Sprint 23 works from milestone 38 (Rule-based critic selection by default), then reacts on #1614 before its spec.

**Also waiting on the driver or the maintainer:**
- Milestones 32 and 35 have no open issue and say "none left", but are still open on GitHub.
- #1614, #1623, #1624 and #1625 need the maintainer's reaction on the issue before their specs.
- 603-Identity/devcontainers: two driver prompts handed over on 2026-11-18. One updates `docs/host-steps.md` Procedure B and the threat model for #1608's token path. The other sets `agents.diff_rule: []`. devcontainers#556's spec still needs the maintainer's reaction.
- #1595 needs the maintainer's reaction on the issue before its spec.
- #1591: the admin-App route ran end to end for #1566 (PR #1615). Each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`. bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** none this session: a planning session with no diff.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 38](https://github.com/glunk-works/claude-workbench/milestone/38) · [.ai/parked/](parked/)
