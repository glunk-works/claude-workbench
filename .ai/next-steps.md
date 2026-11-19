# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): lane #1599 running; every earlier lane merged and cleaned up.

**Just done (2026-11-18/19, driver session, opus):**
- Merged after the driver's assessment against each spec: #1642 (#1234, exempt, `39712c8`), #1643 (#1604, `30e7175`), #1646 (#1594, `a089136`), #1647 (#1593, `bf8447a`), #1650 (#1033, exempt, `0f188b3`), #1651 (#1589, exempt, `3cd51cf`), #1652 (#1590, `2cf0d74`). Where the review could not witness the new cases (pwsh guard cases, the stale-tag cases, the no-confirm fixture), the driver ran the suite on the head merged with main; #1646 merged at its reviewed head without catching up (the base rule is not strict, and the trial merge was clean).
- Lanes 1033, 1234, 1589, 1590, 1593, 1594 and 1604 cleaned up (`lane.sh done`); the first #1589 lane was dropped with its work discarded after its spec escalated.
- Escalations answered by the maintainer: #1599 (amend, then apply), #1590 (apply), #1589 (amend: the lane check runs as `/way-of-working:lanes` status in the driver session, `-SpecSweep`/`-EndDay` on the host). #1599's approved spec went stale on #1033's merge and was refreshed as 7008102611 (carried forward); lane #1599 prepped.
- Milestone 29 description: Lanes line written via `milestone-desc.sh` (`live: #1599`, the merged ones under Done).

**Next:** task #1599 — driver work only, lane #1599 builds it: restart the background review wait (`lane.sh wait 1599`); when its review lands run `/way-of-working:pr-checks` and give the merge assessment against spec comment 7008102611, including that case (d) asserts no other `WARNING:` line; run `lane.sh done 1599` only after the maintainer says its session has exited; then offer the next milestone 29 candidates (#1032, which follows the merged #1033) and the docs follow-up for #1589's *Images and build cache* paragraph that #1590 made stale. Model: opus (architect).

**HITL Gate: OPEN** — lane #1599 is building in its own session and its PR needs the maintainer approval; the driver continues from the ledger and nothing auto-starts a build of #1599 here.

**Also waiting on the driver or the maintainer:**
- A docs follow-up to file for milestone 29 (after #1589 and #1590): `DEV-CONTAINER.md`'s *Images and build cache* paragraph still tells the operator to remove old `wow-review:` tags by hand, which `wow-review` now does itself (the build order's #1590 line expected that shrink).
- Next candidates on milestone 29 need the maintainer's reaction on the issue before `-Spec` (every unblocked one is App-filed): #1032 (after #1033), #1274 (shares `DEV-CONTAINER.md` with #1599), #1156, #1229 (workflow files: host-side publish), #1230, #1237, #1434, #1492, #1598, #1603 (live host run, not a lane).
- Follow-up candidates from reviews: the unguarded first-action `Arguments` read in `register-broker-task.ps1` (`-Unregister`) and `install-host-tools.ps1` (stop path); `tests/review-poll.test.sh` and the broker guard section can skip their pwsh cases while CI stays green; a scheduler read failure passes the broker guard; a `MANIFEST` special file can stall `wow-review`'s stale-tag read under the lock. The host files the reviewer App's findings; triage them in the next `/way-of-working:plan-sprint findings` pass, with those from #1632, #1636 and #1638.
- `wow-lane.ps1` (#1604) and `register-broker-task.ps1` (#1594) and `wow-review` (#1590) apply on the host only after the host tools are reinstalled.
- #1633 (findings from #1631): proposed for milestone 33 (Tidy-ups); awaiting the maintainer's call.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1623 (after #1595 and #1599) and #1624 need the maintainer's reaction on the issue before their specs.
- 603-Identity/devcontainers: devcontainers#556's spec still needs the maintainer's reaction; PR #601's review was launched 2026-11-18 18:38Z.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule.
- #1591: each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** none this session on code: the driver wrote no code diff. Lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
