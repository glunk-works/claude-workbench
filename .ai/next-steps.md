# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): no lane building; way-of-working v0.39.0 is released and pinned here; three approved specs wait for a light refresh, then lanes.

**Just done (2026-11-20, driver session, opus):**
- Merged after the driver's assessment against each spec: #1700 (#1274, the yq-minimum update rule names every copy, `dd84ff8`), #1701 (#1659, the broker profile cases run on the Windows runner and its guard cases fail rather than skip; `ci.yml` published by the admin App, Windows cases witnessed in run 44729188691, `6c17572`). Lanes 1598, 1156, 1274 and 1659 cleaned up; the milestone 29 description kept current via `milestone-desc.sh`.
- Released way-of-working v0.39.0 (#1706, `906ac92`; the driver-to-lane message channel) and bumped this repo's pin to it (#1707, `a0eab30`).
- Specs approved by the maintainer, all on base `6c17572`: #1434 (comment 7039566658, redrafted on the `apply` answer to escalation 7038010927), #1691 (7039558153), #1563 (7039588425). The release moved `CHANGELOG.md`, which each lists, so each now reads stale.
- Filed #1704 (map commit types with no type label to `type/chore` in the label conventions) and #1705 (plan-sprint runs the findings phase before placement in one pass, the maintainer's option B, with a `keep as task` destination and a placement guard); both unmilestoned.

**Next:** task #1434 — driver work: after the container restart and the host-tools reinstall in both homes, confirm the installed plugin is at the v0.39.0 tag commit. The maintainer runs `wowl glunk-works/claude-workbench -Spec N` once each for 1434, 1691 and 1563 (light refresh, carried forward with no critic round) and for 1705 (first draft, after a reaction on the issue). Review each posted spec before the maintainer reacts, then prep the three lanes with `driver=` from `ListAgents` (1434 `feat/host-launcher-check`, 1691 `fix/ci-yq-preflight-stdout`, 1563 `fix/wow-review-repeat-check`; critics architect and security-critic, plus docs-consistency for 1434), hand over each `wowl` line and start `lane.sh wait` for each. #1691's `ci.yml` edit needs the host admin-App publish; #1694 follows it on that file. Model: opus (architect).

**HITL Gate: OPEN** — the container restart and the host-tools reinstall in both homes wait on the maintainer; the light refreshes for #1434 #1691 #1563 and the first spec for #1705 need the maintainer to run -Spec and react (#1705 and #1704 also need a reaction on the issue first); #1691 needs the host admin-App publish of its ci.yml edit; the driver continues from the ledger and nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- New driver habit: at each lane cleanup, run `/way-of-working:plan-sprint findings` on the merged PR's new findings issue, if the review filed one.
- Review findings now filed by the host: from PR #1700, the update rule's "header line" should name the `yq minimum` row of the test file's coverage header; from PR #1701, the broker suite's guard read under `set -eu` stops with no `FAIL -` line when pwsh fails (`|| guard_read=`). Earlier: PR #1692's 8.3 short-name residual (the maintainer decides whether it belongs in the private security-audits repo) and PR #1693's bash 4.2 escaping notes.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1624 needs the maintainer's reaction before its spec.
- devcontainers' `docs/host-steps.md` still describes the old Procedure B; that repo's driver is amending it. devcontainers#556's spec still needs the maintainer's reaction.
- Offered, no answer yet: note on #1366 that `secret-scan.yml` has no job timeout.
- #1591: each other glunk-works repo switches at its milestone 34 item. Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** the v0.39.0 release diff (#1706): architect, security-critic and docs-consistency, selected by the diff rule; 2 rounds, converged; one defect fixed (the Migration line said no repo changes behaviour, untrue of lanes prepped with `driver=`); the second-opinion round was offered and declined. The pin bump (#1707): the rule selected no critic. Lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
