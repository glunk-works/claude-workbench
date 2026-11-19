# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): lanes #1229 and #1667 running; the #1028 spec session is running.

**Just done (2026-11-19, driver session, opus):**
- Merged after the driver's assessment against each spec: #1664 (#1623, reviewed pass, `576213e`; the failed-removal fixture confirmed run in CI, not skipped), #1668 (#1035, exempt; the driver's own mutation check showed the new case fails when `Test-FileArgMatch` drops the quoted form, `1caa077`). Lanes 1623 and 1035 cleaned up.
- Docs fix shipped by the driver: #1666 (`DEV-CONTAINER.md` *Images and build cache* now says `wow-review` removes stale tags itself; docs-consistency: no defects, one tightening applied; `6258800`).
- `/way-of-working:plan-sprint findings`: #1665 (four findings from the review of PR 1664) unpacked into #1667 on milestone 29 and closed with a mapping comment.
- Specs reviewed and reacted: #1035 (7010789111), #1229 (7010848845), #1667 (7011315883). Lanes 1035, 1229 and 1667 prepped.
- #1229 is workflow-only: the lane's local commit `0b6a288` was published byte-identical by the admin App from the host (two verified `glunk-admin[bot]` commits on `ci/job-timeouts`); the dev App opened PR #1669 (closes #1229, milestone 29, auto-merge armed).
- Milestone 29 description written via `milestone-desc.sh` three times (merged items to Done, #1667 appended, Lanes line); each read back equal.

**Next:** task #1229 — driver work only, lanes #1229 and #1667 build: restart the background waits (`lane.sh wait 1229` for PR #1669, `lane.sh wait 1667`); when PR #1669's review lands run `/way-of-working:pr-checks 1669` and give the merge assessment against spec comment 7010848845; do the same for #1667's PR against 7011315883; review the #1028 spec when its session posts it, before the maintainer reacts, and prep its lane only on the maintainer's word; after each merge run `lane.sh done N` once the maintainer says the lane session exited (lane 1229 holds the local commit `0b6a288`, which never merges, so `done` may stop: hand the maintainer the `!` cleanup line), then update the milestone 29 Lanes and Done lines. Model: opus (architect).

**HITL Gate: OPEN** — lanes #1229 and #1667 are building in their own sessions and the #1028 spec session is running; each lane PR needs the maintainer approval; the driver continues from the ledger and nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- Offered, no answer yet: note on #1366 that `secret-scan.yml` has no job timeout (out of scope for #1229), which matters once `secrets / scan` becomes required.
- Next candidates on milestone 29 need the maintainer's reaction on the issue before `-Spec` (App-filed): #1229's follow-ups #1261 and #1659 (same workflow file, after #1229), #1274, #1156, #1230, #1237, #1434, #1492, #1598, #1603 (live host run, not a lane), #1658 (unblocked by #1623).
- Milestone 29 markers on #1028, #1658 and #1656 name closed issues, so they read all-earlier; harmless, left as found.
- Host tools must be reinstalled for `wow-lane.ps1` (#1604), `register-broker-task.ps1` (#1594), `wow-review` (#1590), `install-host-tools.ps1` (#1599, #1623) and `wow-admin` (#1623) to apply on the host.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1624 needs the maintainer's reaction on the issue before its spec.
- 603-Identity/devcontainers: devcontainers#556's spec still needs the maintainer's reaction; PR #601's review was launched 2026-11-18 18:38Z.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule.
- #1591: each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** #1666 (driver-shipped docs): docs-consistency, 1 round, converged (one tightening applied). No other code diff by the driver; lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
