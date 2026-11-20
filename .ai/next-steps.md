# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): no lane building; way-of-working v0.40.0 is released and pinned here.

**Just done (2026-11-20, driver session, opus):**
- Merged after the driver's assessment against each spec: #1710 (#1563, `c8342fc`), #1712 (#1434, `228a380`), #1709 (#1691, `77bbde5`; `ci.yml` published by the admin App), #1715 (#1705, `58e283c`), #1717 (#1694, `30a2298`; `ci.yml` published by the admin App), #1718 (#1711, `c709ce7`). Lanes cleaned up; milestone 29's Build order and Lanes line kept current via `milestone-desc.sh`; #1705 and #1711 placed on milestone 29.
- Released way-of-working v0.40.0 (#1721, `371730f`: plan-sprint runs findings before placement; lanes resolve a changelog-only merge conflict through `merge-union.sh`) and bumped this repo's pin to it (#1722, `9320e76`).
- Filed #1711 (now built); appended the devcontainers Procedure B design reference to #1681's body. Reviewer App findings issues filed: #1713 (from #1710), #1714 (from #1712), #1716 (from #1715); the host filed one more each from #1717 and #1718.

**Next:** Driver work: after the container restart and the host-tools reinstall in both homes, confirm the installed plugin is at the v0.40.0 tag commit (`371730f`) for the user and `/workspace` entries; then run `/way-of-working:plan-sprint` (the default pass, which now runs the findings phase first) on the reviewer App findings issues and place what it produces on milestone 29; then pick the next milestone 29 lanes with `lane.sh groups 29`. Model: opus (architect).

**HITL Gate: OPEN** — the container restart and the host-tools reinstall in both homes wait on the maintainer; the plan-sprint pass is a dialogue with the maintainer; nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- Driver habit: at each lane cleanup, note the merged PR's findings issue; the default `/way-of-working:plan-sprint` pass now unpacks findings first (#1705, v0.40.0), so one pass handles them.
- `check-host.ps1` (#1434): run it once from the install clone after the reinstall, to cover its untested real-ScheduledTask path. Check one `tests-1`/`tests-2` job summary for the new run-time line (#1694's only unwitnessed Done-when item).
- #1681 (one host publish command): its body now carries the devcontainers Procedure B design reference (`603-Identity/devcontainers` `docs/host-steps.md`); it needs the maintainer's reaction before its spec.
- Review findings now filed by the host: from PR #1700, the update rule's "header line" should name the `yq minimum` row of the test file's coverage header; from PR #1701, the broker suite's guard read under `set -eu` stops with no `FAIL -` line when pwsh fails (`|| guard_read=`). Earlier: PR #1692's 8.3 short-name residual (the maintainer decides whether it belongs in the private security-audits repo) and PR #1693's bash 4.2 escaping notes.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1624 needs the maintainer's reaction before its spec.
- devcontainers' `docs/host-steps.md` still describes the old Procedure B; that repo's driver is amending it. devcontainers#556's spec still needs the maintainer's reaction.
- Offered, no answer yet: note on #1366 that `secret-scan.yml` has no job timeout.
- #1591: each other glunk-works repo switches at its milestone 34 item. Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** the v0.40.0 release diff (#1721): architect, security-critic and docs-consistency, selected by the diff rule; 2 rounds, converged, plus one verify-only round on a post-convergence edit, clean; one defect fixed (the Migration line said a host-tools reinstall delivers `check-host.ps1`, which runs from the install clone); the second-opinion round was offered and declined; two tightenings applied on the maintainer's pick (the push condition and the opt-out). The pin bump (#1722): the rule selected no critic. Lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
