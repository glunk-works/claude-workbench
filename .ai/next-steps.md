# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): every lane item merged; #1366 (the maintainer's admin decision) is the one open issue. No lanes live.

**Just done (2026-11-25, driver session, opus, `/way-of-working:plan-sprint`):**
- Findings phase: 8 findings from 6 reviewer App issues. #1793 (two) and #1799 (two) combined into the new #1809 (area/ci, review image checks and tests); #1790's one finding declined as cosmetic; those three sources mapped and closed. #1792, #1796 and #1806 kept as tasks.
- Placement: #1809, #1796 and #1797 placed in milestone 29 as build-order steps 26 to 28 (#1809 and #1796 independent, #1797 unconfirmed); #1792 placed in milestone 33 as step 30 (unconfirmed). #1806 left unmilestoned as covered by #1366 (milestone 29 step 5 already makes `verify / verify` required). #1774, #223, #334, #409, #1167 and #1548 stay unmilestoned on their 2026-11-24 reasons (no re-post). Triage comments posted on the five decided issues.
- Milestone 29 and 33 descriptions written live through `milestone-desc.sh` (both `live ok`, hash-confirmed), build-order appends only; then, on the maintainer's OK, a third live write (`live ok`, hash-confirmed) gave milestone 29 Done `#1783 (PR #1798)` and Lanes `live: none` with the next lanes named.
- Since the last cursor: #1786, #1787, #1788, #1791 and #1798 merged (#1762, #1764, #1763, #1766, #1783), and way-of-working v0.41.0 released with this repo's pin bumped (#1802, #1803), which closes the "release and pin bump is due" item below.

**Earlier (2026-11-24, driver session, opus, `/way-of-working:plan-sprint`):**
- Findings phase: 11 findings from 7 reviewer App issues (#1761, #1772, #1773, #1775, #1777, #1780, #1781): four folded (two into #1765, one each into #1766 and #1763), six into two new combined issues (#1783 ci, #1784 identity), one declined as covered by #1765; all seven sources mapped and closed. The folds edited #1763, #1765 and #1766, so a maintainer reaction on them must postdate 2026-11-24.
- Placement: #1762, #1763, #1764, #1765, #1766, #1783, #1784 and #1753 placed in milestone 29 as build-order steps 18 to 25 (#1784 after #1766; #1753 after #1766 and #1784; the rest independent); #223, #334, #409, #1167, #1548 and #1774 left unmilestoned with reasons. Triage comments posted on all fourteen.
- Milestone 29 description written live twice through `milestone-desc.sh` (both `live ok`, hash-confirmed): the build-order append, then Done gaining #1660, #1726 and #1725 with Lanes `live: none`. That closes the "final description edit" item below.

**Earlier (2026-11-23, driver session, opus):**
- Findings pass (`/way-of-working:plan-sprint findings`): 25 findings from 14 reviewer App issues went to combined issues #1762 (way-of-working), #1763 (ci), #1764 (devcontainer), #1765 and #1766 (identity), one declined as covered by #1398; the 14 sources were mapped and closed.
- Merged, each after the driver's assessment of its review and diff against its spec: #1758 (#1661, `b9206fa`), #1768 (#1656, `dc59067`), #1769 (#1457, `7f95da1`), #1771 (#1312, `c3e7ce0`), #1767 (#1724, `0b63275`), #1770 (#1398, `5cacb65`), #1776 (#1660, `57e3557`), #1778 (#1726, `a936383`), #1779 (#1725, `8ac6c8d`). Every lane cleaned up.
- `wow-publish` used live for the first time: workflow files for #1724, #1398 and #1725 published by the admin App from a driver-written manifest in the dev clone's `.git/wow-handoff/`.
- #1398's spec escalated and was redrafted on the maintainer's `choice=apply` answer; #1725's spec was refreshed onto `57e3557` with no critic round after #1660 staled it.
- Milestone 29 description kept current (Build order markers, Done, Lanes) through `milestone-desc.sh`.

**Next:** Driver work: milestone 29's open items are #1765, #1784, #1753 (steps 21, 24, 25), the new #1809, #1796 and #1797 (steps 26 to 28), and #1366 (the maintainer's admin decision); the maintainer reacts on the issues to spec, then `lane.sh groups 29` chooses the parallel lanes, a `-Spec` session per issue drafts its spec, and `/way-of-working:handoff` anchors the first task once its spec is approved; the lanes run through `/way-of-working:lanes`. Model: opus (architect).

**HITL Gate: OPEN** — the review image managed-settings probe re-run on Claude Code 2.1.316 (REVIEW-LIVE-RUN.md) is the maintainer host run; plan-sprint placements and the next milestone pick are the maintainer decisions; every spec waits on the maintainer reaction and every lane PR on the maintainer approval; nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- Milestone 29's final description edit (Done gains #1660, #1726 and #1725; Lanes `live: none`) was composed at handoff and waits on the maintainer's OK; recompose it from the live description if it was not written.
- A plugin release and pin bump is due: #1771 lowered the findings body cap to 3500 bytes, and until this repo's pin moves past v0.40.0 a reinstalled host refuses a review's 3501 to 4000 byte findings set.
- Every `-Spec` and lane hand-over carries `-Driver NAME` from `ListAgents` at that moment; a lane prepped by an earlier driver messages that driver, so its outcome is pasted by hand and `lane.sh wait N` is restarted.
- A `.github/workflows` change is refused to the dev App: `wow-publish` publishes it from the host (route and manifest shape in the driver's memory); the lane's draft is restored with `git checkout --` before `lane.sh done`.
- The loop image (`scripts/loop/Dockerfile`, `ARG BASE_IMAGE`) is still on `devcontainer-base` 1.6: Dependabot does not track it by design. Offered: an issue for a hand bump.
- #1366 is the maintainer's admin decision. #1624 needs the maintainer's reaction before its spec. #1753 (the `wow-admin` hints name no identity home) is unmilestoned.
- #1694's only unwitnessed Done-when item: check one `tests-1`/`tests-2` job summary for the run-time line.
- devcontainers' `docs/host-steps.md` still describes the old Procedure B; that repo's driver is amending it. devcontainers#556's spec still needs the maintainer's reaction.
- #1591: each other glunk-works repo switches at its milestone 34 item. Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34).
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** this driver session wrote no code diff; each lane PR carries its own critic record in its body.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
