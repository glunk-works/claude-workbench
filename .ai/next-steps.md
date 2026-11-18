# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): #1180 merged; lanes #124 (PR #1632) and #1595 running; #1172's spec drafting.

**Just done (2026-11-18, driver session, opus):**
- #1180 merged as `98fe240` (PR #1631; reviewer App pass; driver assessment against spec 6987080917: no blocking issue). Lane 1180 cleaned up (`lane.sh done 1180`, `next none`). Its three non-blocking review findings are #1633 (unmilestoned).
- Specs reviewed and approved: #124 (6987049707) and #1595 (redraft 6988515369, after the maintainer's `apply` answer 6988077644 on escalation 6987272126). Both lanes prepped and started; `lane.sh groups 29` put #1180, #124 and #1595 in one parallel group.
- Milestone 29 description current via `milestone-desc.sh`: #1608 out of the build order, #1362 appended last (no `depends_on` marker yet), Lanes line `live: #1180, #124, #1595`.
- Host: the Store pwsh was replaced by the MSI, which left all four host tasks (both brokers, both review pollers) silently no-oping from ~17:19Z; the maintainer re-registered them from the MSI pwsh, both homes installed at `35396ca`, and the 603id poller launched devcontainers PR #601's review.

**Next:** task #124 — driver work only, the lane builds it: restart the background review waits (`lane.sh wait 124`, `lane.sh wait 1595`); when a lane PR's review lands run `/way-of-working:pr-checks` and give the merge assessment against its spec; review #1172's posted spec, then prep its lane after the maintainer reacts. Model: opus (architect).

**HITL Gate: OPEN** — lanes #124 and #1595 are building in their own sessions and #1172's spec is drafting; the driver continues from the ledger and nothing auto-starts a build of #124 here.

**Also waiting on the driver or the maintainer:**
- Proposed milestone 29 Lanes line, not yet written: `live: #124, #1595. Done: #1608 (PR #1611), #1180 (PR #1631).` (add #1172 once its lane starts).
- #1633 (findings from #1631): proposed for milestone 33 (Tidy-ups), with a build-order line; awaiting the maintainer's call, or the next `/way-of-working:plan-sprint findings` pass.
- #1362 on milestone 29 needs a confirmed `depends_on` marker.
- #1623, #1624 and #1625 need the maintainer's reaction on the issue before their specs.
- 603-Identity/devcontainers: two driver prompts handed over on 2026-11-18 (`docs/host-steps.md` Procedure B and the threat model for #1608's token path; `agents.diff_rule: []`). devcontainers#556's spec still needs the maintainer's reaction. PR #601's review was launched at 18:38Z.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule; one of the spec's unapplied tightenings.
- #1591: each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`. bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** none this session on code: the driver wrote no code diff. Lane PRs carry their own critic records (#1631: architect, security-critic, docs-consistency; 1 round, no defects).

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
