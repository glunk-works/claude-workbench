# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): lane #1623 running; every earlier lane merged and cleaned up.

**Just done (2026-11-19, driver session, opus):**
- Merged after the driver's assessment against each spec: #1655 (#1599, reviewed pass, `4b7ad31`), #1657 (#1032, exempt, `054bb74`). Lanes 1599 and 1032 cleaned up (`lane.sh done`).
- Specs reviewed and reacted: #1032 (7009205521), #1623 (7009381361). Lane #1623 prepped (`fix/wow-admin-revoke-failures`; architect, security-critic, docs-consistency).
- `/way-of-working:plan-sprint findings`: eight reviewer-App findings issues unpacked into #1658 (identity: install profile and task-action reads), #1659 (ci: broker cases on the runners), #1660 (identity: launchers), #1661 (identity: review tools), all on milestone 29, and #1662 (way-of-working: unpark wording) on milestone 33; sources #1633, #1635, #1637, #1639, #1645, #1648, #1649, #1653 mapped and closed. #1656 (findings from #1655) placed on milestone 29.
- `/way-of-working:plan-sprint`: #223, #334, #409, #1167 and #1548 left unmilestoned, unchanged from the 2026-11-17 triage. Milestone 29 and 33 build orders written via `milestone-desc.sh` (merged items moved to a Done line; read back equal).

**Next:** task #1623 — driver work only, lane #1623 builds it: restart the background review wait (`lane.sh wait 1623`); when its review lands run `/way-of-working:pr-checks` and give the merge assessment against spec comment 7009381361; run `lane.sh done 1623` only after the maintainer says its session has exited; then propose the milestone 29 Lanes and Done update (#1032 done via PR #1657) and offer the next candidates: #1035 (unblocked by #1032), #1229, and the docs fix for the stale *Images and build cache* paragraph in `docs/identity/DEV-CONTAINER.md`. Model: opus (architect).

**HITL Gate: OPEN** — lane #1623 is building in its own session and its PR needs the maintainer approval; the driver continues from the ledger and nothing auto-starts a build of #1623 here.

**Also waiting on the driver or the maintainer:**
- Milestone 29's Lanes line still lists #1032 as live; the Done line lacks it. Propose and write on the maintainer's OK.
- A docs follow-up, no issue yet: `DEV-CONTAINER.md`'s *Images and build cache* paragraph still tells the operator to remove old `wow-review:` tags by hand, which `wow-review` now does itself since #1590. The driver offered to ship it as a docs PR (docs-consistency critic).
- Next candidates on milestone 29 need the maintainer's reaction on the issue before `-Spec` (App-filed): #1035 (after #1032), #1229 (workflow files: host-side publish), #1274, #1156, #1230, #1237, #1434, #1492, #1598, #1603 (live host run, not a lane). #1658 follows #1623 (shares `install-host-tools.ps1`).
- Milestone 29 markers on #1032, #1623 and #1656 name closed issues, so they read all-earlier; harmless, left as found.
- `wow-lane.ps1` (#1604), `register-broker-task.ps1` (#1594), `wow-review` (#1590) and `install-host-tools.ps1` (#1599) apply on the host only after the host tools are reinstalled.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1624 needs the maintainer's reaction on the issue before its spec.
- 603-Identity/devcontainers: devcontainers#556's spec still needs the maintainer's reaction; PR #601's review was launched 2026-11-18 18:38Z.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule.
- #1591: each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** none this session on code: the driver wrote no code diff. Lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
