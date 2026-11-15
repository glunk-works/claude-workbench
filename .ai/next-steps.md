# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*. Milestone 32's lanes are being driven alongside it; lanes #1294 and #1335 are running.

**Just done (2026-11-15, driver session, opus):**
- Milestone 32 merges: #1501 (#1530), #1369 (#1531), #1319 with #1320 folded in (#1535), #1532 with #1534 folded in (#1537), #1316 (#1538), #1334 (#1540), and #1520 with #1533 folded in (#1542, `537f7d7`).
- #1327 closed as already covered: the `backlog.repo: null` and `glunk-works/backlog` cases in `tests/lane.test.sh` already reach both halves of the path it asked to test.
- Folded #1541 and #1543 into #1539. Specs for #1294, #1335 and #1539 are reviewed and approved.
- Lanes #1294 (`test/lane-groups-done-contract`) and #1335 (`perf/lane-groups-skip-live-wait`) prepped and running in parallel; milestone 32's description is current.

**Next:** drive sprint-21:
- #411 is milestone 21's last item, the devcontainers cutover, and it's the maintainer's.
- Milestone 32: restart `lane.sh wait 1294` and `lane.sh wait 1335` in the background (the waits do not survive a session change). When each prints `reviewed`, run pr-checks and give the merge assessment before the maintainer approves. Run `lane.sh done N` once each merges and the maintainer says its session exited.
- Once both have merged, hand over `-Spec 1539` for a light refresh (it will read stale on the two test files), review it, and prep its lane when the maintainer says.

Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer approves the #1294 and #1335 lane PRs after the driver merge assessment

**Maintainer actions:**
- #411, the devcontainers cutover. Further cutovers follow it. Close sprint-21 once #411 is done, with the `docs/decisions.md` sprint entry PR.
- Once milestone 32 is done: release way-of-working (main is past v0.35.0 with #1531 onward; until then spec sessions post without the `### Not applied (tightenings)` section) and bump the pin.
- #1536 stays unmilestoned on purpose.
- Carried from 2026-11-14, unconfirmed this session: bump each consuming repo's pin to `v0.35.0`; place #1515 and #1516; the host files the review findings from #1521, #1522 and #1526, and declines the #1522 "30-minute background cap" finding (background waits ran 34 and 39 minutes on 2026-11-14).
- On the first real spec `### Trailers` squash, confirm GitHub joins its Co-authored-by lines into the trailer block (the #1518 decline rests on it).
- Carried: resume-orchestrator, merge its PR #186, then do the home-volume cleanup and restart through `wow-driver.ps1`.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Critic pass:** none this session; it was a driver session and wrote no code.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [milestone 32](https://github.com/glunk-works/claude-workbench/milestone/32) · [.ai/parked/](parked/)
