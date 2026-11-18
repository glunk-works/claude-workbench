# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): #124, #1595, #1172, #1233 and #1625 merged; lanes #1604 (PR #1643), #1234 (PR #1642), #1593 and #1594 running.

**Just done (2026-11-18, driver session, opus):**
- Merged after the driver's assessment against each spec: #1632 (#124), #1636 (#1595), #1638 (#1172), #1640 (#1233, exempt gate), #1641 (#1625). For each, the driver ran the suites the review could not witness at the PR head. Lanes 124, 1595, 1172, 1233 and 1625 are cleaned up (`lane.sh done`).
- #1172's spec went stale when #1632 merged: refreshed as 6989811480 (carried forward, no critic round), and its unstarted lane was dropped and prepped again.
- Specs reviewed and approved, and lanes prepped: #1604 (6990561469), #1234 (6993918414), #1593 (6993983033), #1594 (6994089403). Paste-in notes handed over for #1593 (StrictMode `.Value` on an absent property throws; checked in pwsh) and #1594 (the order check's grep form, the broker suite's missing helpers).
- Milestone 29 description: Lanes line written via `milestone-desc.sh` (`live: #1604, #1234, #1593, #1594`, with the merged ones under Done).

**Next:** task #1604 — driver work only, the lanes build it and #1234, #1593, #1594: restart the background review waits (`lane.sh wait 1604`, `1234`, `1593`, `1594`); PR #1642 (#1234, exempt gate) has every required check green and awaits the maintainer's approval; when a lane PR's review lands run `/way-of-working:pr-checks` and give the merge assessment against its spec; run `lane.sh done` only after the maintainer says a merged lane's session has exited. Model: opus (architect).

**HITL Gate: OPEN** — lanes #1604, #1234, #1593 and #1594 are building in their own sessions and their PRs need the maintainer's approval; the driver continues from the ledger and nothing auto-starts a build of #1604 here.

**Also waiting on the driver or the maintainer:**
- #1594 and #1604 both edit `docs/identity/DEV-CONTAINER.md` (different sections); the second to merge may need `origin/main` merged in.
- Next parallel candidates on milestone 29 need the maintainer's reaction before `-Spec`: #1457 waits for #1604 (`wow-lane.ps1`); #1589 and #1274 touch `DEV-CONTAINER.md`; #1033's chain and #1599 share the broker test file with #1594.
- A possible follow-up: the same unguarded first-action `Arguments` read #1593 fixes is in `register-broker-task.ps1` (the `-Unregister` path) and `install-host-tools.ps1` (the stop path).
- The reviewer App's non-blocking findings on #1632, #1636 and #1638 were to be filed by the host; triage them in the next `/way-of-working:plan-sprint findings` pass.
- #1633 (findings from #1631): proposed for milestone 33 (Tidy-ups); awaiting the maintainer's call.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1623 and #1624 need the maintainer's reaction on the issue before their specs.
- 603-Identity/devcontainers: devcontainers#556's spec still needs the maintainer's reaction; PR #601's review was launched at 18:38Z.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule.
- #1591: each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`. bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** none this session on code: the driver wrote no code diff. Lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
