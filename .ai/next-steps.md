# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): lane #1675 live (PR #1685 open); #1230 waits on #1675; #1261's spec is approved but stale.

**Just done (2026-11-19, driver session, opus):**
- Merged after the driver's assessment against each spec: #1669 (#1229, `d8a30cd`), #1671 (#1667, `f19b0a7`), #1674 (#1028, exempt; the driver's own three mutation runs each failed only their case, `419d2cb`), #1678 (#1029, `af150e6`), #1680 (#1492, `af908b0`), #1684 (#1679, driver-to-lane message channel, `545cb71`). Lanes 1229, 1667, 1028, 1029 and 1492 cleaned up.
- Lane 1230 stopped before any change: the dev container's managed settings allow only Claude Code 2.1.316 and the review image pins 2.1.289. Lane dropped; #1675 (bump both images to 2.1.316) filed, specced and laned; #1230's spec needs no change.
- Filed: #1675, #1676 (one Claude Code version across the three Dockerfiles), #1677 (weekly version check), #1679 (message channel, now merged), #1681 (one host command for the admin-App publish; body amended with the devcontainers run's lessons: request bodies over stdin, every call checked).
- Milestone 29 description written via `milestone-desc.sh` five times, each read back equal (Done lines, #1675 placed before #1230, #1679 placed, Lanes lines).

**Next:** task #1675 — driver work only, lane #1675 builds: start `lane.sh wait 1675` in the background; when PR #1685's review lands run `/way-of-working:pr-checks 1685` and give the merge assessment against spec comment 7015223527 (both Dockerfiles must carry `CLAUDE_SHA256` `fd13c70000fec3f2116dfbcbb6121210b4a29328bf0e46210a59dd594a67d824` for 2.1.316); after the merge and the maintainer's host-tools reinstall, prep a fresh #1230 lane. Clean up lane 1679 (PR #1684 merged) once the maintainer says its session exited. Model: opus (architect).

**HITL Gate: OPEN** — lane #1675 is building in its own session; lane 1679 cleanup waits on the maintainer saying its session exited; #1261 needs its spec refreshed and reacted; the milestone 29 description edit waits on the maintainer OK; the driver continues from the ledger and nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- Milestone 29 edit, composed and not written: Done gains #1029 (PR #1678), #1492 (PR #1680) and #1679 (PR #1684); those three leave the Build order; the Lanes line names #1675 live. Recompose from a fresh read before writing, on the maintainer's OK.
- #1261: its redrafted spec (7014748297, the maintainer's `choice=apply` answer applied) has the maintainer's reaction but reads `stale 1`, because #1684 edited `tests/identity-launchers.test.sh` outside `sec_yqver`. The maintainer runs `wowl glunk-works/claude-workbench -Spec 1261` for the light refresh, then reacts on the refreshed comment; then the driver checks it reads fresh and preps the lane.
- After #1675 merges (maintainer, on the host): reinstall the host tools so the next `wow-review` builds the 2.1.316 review image; run the loop's `LOOP_ATTACK=1` pass when the loop is next used.
- #1679's channel takes effect only after a plugin release, this repo's pin bump and a host-tools reinstall in both homes; until then lanes paste as before.
- Unplaced and awaiting the maintainer's reaction: #1676, #1677, #1681.
- Review findings filed by the launcher on PRs 1669, 1671, 1678, 1680 and 1684 (one-line help wrap, missing no-warning assertions, an unguarded empty array in check 9, `sed \x27`, two `-Driver` doc nits): triage when convenient.
- The admin-App publish blueprint given to devcontainers was corrected after its first run (body over stdin, `& { }` wrapper, checked exits); devcontainers' `docs/host-steps.md` still describes Procedure B with a container stop and the admin App opening the PR, which that repo's driver is amending.
- Offered, no answer yet: note on #1366 that `secret-scan.yml` has no job timeout, which matters once `secrets / scan` becomes required.
- Next candidates on milestone 29 (App-filed, reacted 2026-11-19): #1156 (after #1492's `test-all.sh` change), #1237 (`ci.yml`), #1274 and #1434 and #1598 (`install-host-tools.ps1`), #1659 (after #1261), #1030, #1603 (live host run, not a lane), #1658.
- Host tools must be reinstalled for the merged host-side changes since the last install (#1604, #1594, #1590, #1599, #1623, #1667, #1029, #1492) to apply on the host.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1624 needs the maintainer's reaction before its spec.
- 603-Identity/devcontainers: devcontainers#556's spec still needs the maintainer's reaction; #627 (Trivy scan workflow) uses the admin-App publish.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule.
- #1591: each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** no code diff by the driver this session; lane PRs carry their own critic records.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
