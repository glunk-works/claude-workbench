# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*), first task #1180.

**Just done (2026-11-18, driver session, opus):**
- Sprint 23 archived with no release, as the maintainer chose: the pin stays at `v0.38.0`, and #1614's Unreleased changelog lines ship with the next plugin release. Status entry `27058bf` (PR #1629); milestone 38 closed; snapshot `.ai/archive/sprint-23-next-steps.md`.
- Milestone 29's description brought current through `milestone-desc.sh` (read back `ok`): #1608, done in PR #1611, left the build order; #1362, milestoned 2026-11-07 but unlisted, appended last with no `depends_on` marker yet (it reads as after every earlier item until one is confirmed); a `**Lanes:**` line added.
- The maintainer picked #1180 (unpark-sprint resolves `parked_from_commit` with `cursor-drift.sh oid`) as sprint 24's first task. `lane.sh groups 29` printed `group none`: no milestone 29 task has a spec yet, so it has no paths to group by.

**Next:** task #1180 — hand the maintainer the -Spec launcher command for #1180 (spec drafted just in time, after the maintainer has reacted to the issue), review the posted spec, then after the maintainer reacts to it prep the lane with `/way-of-working:lanes start`. Model: opus (architect).

**HITL Gate: OPEN** — first anchor for milestone 29: the maintainer confirms sprint 24 works from milestone 29 with #1180 first.

**Also waiting on the driver or the maintainer:**
- #1623, #1624 and #1625 need the maintainer's reaction on the issue before their specs.
- 603-Identity/devcontainers: two driver prompts handed over on 2026-11-18. One updates `docs/host-steps.md` Procedure B and the threat model for #1608's token path. The other sets `agents.diff_rule: []`. devcontainers#556's spec still needs the maintainer's reaction.
- #1595 needs the maintainer's reaction on the issue before its spec.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule (a glob entry reads as unreadable and falls back to the pick-list); one of the spec's unapplied tightenings.
- #1591: the admin-App route ran end to end for #1566 (PR #1615). Each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`. bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** none this session on code: the driver wrote no code diff. PR #1629 (docs) had a docs-consistency pass: 1 round, no contradictions, two optional wording tightenings applied.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
