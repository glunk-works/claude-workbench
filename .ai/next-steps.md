# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): one lane live, #1661 (PR #1758, in review).

**Just done (2026-11-22 to 2026-11-23, driver session, opus):**
- Merged after the driver's assessment of each review and diff against its spec: #1744 (#1727, `0153dab`), #1746 (#1362, `5efe5b1`), #1750 (#1677, `3313ef9`; the workflow file published by the admin App), #1748 (#1367, `2fecacb`; its merge of main published by the admin App, review rerun on the host), #1752 (#1681, `e473b6a`; merge of main published by the admin App), #1756 (#1658, `fe43cef`; spec refreshed onto `2fecacb` with no critic round). Each merged lane cleaned up.
- #1603: the #1575 and #1571 refusals run live on the Windows host and pass (the #1571 run under a scratch `HOME`, so the real default home took no `tokens-root` file); recorded on the issue and closed.
- Filed #1753: the printed `wow-admin` revoke and mint hints name no identity home, so they fail in a shell whose `WOW_HOME` names another home.
- Milestone 29 description (Build order markers, Done, Lanes) kept current through `milestone-desc.sh`.

**Next:** Driver work: run `/way-of-working:plan-sprint findings` to place the reviewer App findings issues filed from the milestone 29 lane PRs and #1753; then, when PR #1758 (#1661) has a review on its current head, run `/way-of-working:pr-checks 1758` and give the merge assessment before the maintainer approves; after it merges run `lane.sh done 1661`, propose the milestone 29 Done and Lanes edit, and hand over the spec command for #1398, the next milestone 29 item. Model: opus (architect).

**HITL Gate: OPEN** — the review image managed-settings probe re-run on Claude Code 2.1.316 (REVIEW-LIVE-RUN.md) is the maintainer host run; every spec waits on the maintainer reaction and every lane PR on the maintainer approval; nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- Every `-Spec` hand-over carries `-Driver NAME`, the name taken from `ListAgents` at that moment; it changes when the container is recreated.
- A `.github/workflows` change, or a lane's merge of main that brings one in, is refused to the dev App: the admin App publishes it from a host pwsh block, run with `WOW_HOME` naming the glunk home (#1753 is the hint fix).
- The installed host tools in both homes predate `2fecacb`, so `wow-publish` (#1681) is not installed yet; the next `install-host-tools.ps1` run installs it.
- Reviewer App findings issues filed from PRs #1729, #1733, #1734, #1739, #1740, #1744, #1746, #1748, #1750, #1752, #1756 and #1758, plus #1753, await the next `/way-of-working:plan-sprint` findings pass. #1740's two fit #1398 on milestone 29.
- The loop image (`scripts/loop/Dockerfile`, `ARG BASE_IMAGE`) is still on `devcontainer-base` 1.6: Dependabot does not track it by design. Offered: an issue for a hand bump.
- #1366 is the maintainer's admin decision. #1624 needs the maintainer's reaction before its spec.
- #1694's only unwitnessed Done-when item: check one `tests-1`/`tests-2` job summary for the run-time line.
- devcontainers' `docs/host-steps.md` still describes the old Procedure B; that repo's driver is amending it. devcontainers#556's spec still needs the maintainer's reaction.
- #1591: each other glunk-works repo switches at its milestone 34 item. Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34).
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** this driver session wrote no code diff; each lane PR carries its own critic record in its body.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
