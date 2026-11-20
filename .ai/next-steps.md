# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): no lane building; lanes 1598 and 1156 merged and await cleanup; #1659 is next.

**Just done (2026-11-19/20, driver session, opus):**
- Merged after the driver's assessment against each spec: #1685 (#1675, Claude Code 2.1.316 in both images, `c8c164f`), #1689 (#1230, `0226275`), #1690 (#1261, workflow file published by the admin App, `a018efd`), #1692 (#1598, tokens-root paths without GNU-only sed; Windows junction checks witnessed in the `tests-windows` log, `8f6e361`), #1693 (#1156, test-all suite annotation, `ea2dfe6`). Lanes 1675, 1679, 1230 and 1261 cleaned up.
- #1156's 2026-10-26 triage decision moved into its body, then re-reacted and re-specced.
- Plan-sprint findings pass: #1673 folded into #1681, #1688 into #1676; filed #1694 (area/ci), #1695 (area/identity), #1696 (area/way-of-working); closed #1672, #1673, #1682, #1683, #1686, #1688 with mapping comments.
- Plan-sprint placement pass: #1694, #1676, #1677 (`depends_on: #1676`), #1681 onto milestone 29; #1695, #1696 onto milestone 33; #223, #334, #409, #1167, #1548 left unmilestoned. Both build orders written via `milestone-desc.sh` and hash-checked; triage comments posted on all eleven.

**Next:** task #1659 — driver work: when the maintainer says the lane 1598 and 1156 sessions exited, run `lane.sh done 1598` and `lane.sh done 1156`; then propose the milestone 29 edit (Done gains #1598 via PR #1692 and #1156 via PR #1693, both leave the Build order, Lanes line) and write it via `milestone-desc.sh` on the OK. #1659: the maintainer runs `wowl glunk-works/claude-workbench -Spec 1659` for the light refresh of spec 7024197941 and reacts; the driver checks it reads fresh, then preps its lane (its `ci.yml` edit needs the host admin-App publish); #1691 follows it. Model: opus (architect).

**HITL Gate: OPEN** — lane 1598 and 1156 cleanup waits on the maintainer saying their sessions exited; the milestone 29 edit waits on the maintainer OK; #1659 needs its spec refreshed and reacted; #1691 #1676 #1681 #1694 #1695 #1696 need the maintainer reaction before their specs; the driver continues from the ledger and nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- Review findings from PR #1692 (filed by the host): `Resolve-RealPath` does not expand 8.3 short names, so the default-home guard could fail open (pre-existing; the maintainer decides whether it belongs in the private security-audits repo); `tests-windows` does not fail on the junction SKIP line; a root-path home refuses with the wrong cause. From PR #1693: bash 4.2 quoted-replacement escaping and GNU `\|` in tests.
- After #1675: reinstall the host tools so `wow-review` builds the 2.1.316 review image; run the loop's `LOOP_ATTACK=1` pass when the loop is next used.
- #1679's channel takes effect only after a plugin release, this repo's pin bump and a host-tools reinstall in both homes.
- devcontainers' `docs/host-steps.md` still describes the old Procedure B; that repo's driver is amending it.
- Offered, no answer yet: note on #1366 that `secret-scan.yml` has no job timeout.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1624 needs the maintainer's reaction before its spec.
- 603-Identity/devcontainers: devcontainers#556's spec still needs the maintainer's reaction; #627 uses the admin-App publish.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule.
- #1591: each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** no code diff by the driver this session; lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
