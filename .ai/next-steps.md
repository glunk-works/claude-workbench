# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*. Milestone 32's last lane, #1547, is running; milestone 36's specs, #1515 and #1516, are drafting.

**Just done (2026-11-15, driver session, opus):**
- Milestone 32 merges: #1335 (#1545), #1294 (#1546), #1539 with #1541 and #1543 folded in (#1549), and #1527 with #1536 folded in (#1550, `7379e4f`). Each lane was cleaned up with `lane.sh done`.
- Triage pass (plan-sprint): new milestone 36, *Review findings flow* (#1515, #1516); #1523 and #1350 (uv, with `uv_build` as the default backend) placed on milestone 33; #1525 folded into #1547; #1524 closed as already fixed; #211, #212 and #213 closed in favour of #1548, which retires review-sandbox `make`/`run` and stays unmilestoned until no repo is under `identities: null`; #1379 declined; #223 left for the maintainer's refresh pass.
- Filed #1547 (`lane.sh wait` ends `exempt` on a gate-exempt PR); its refreshed spec is approved and its lane `feat/lane-wait-exempt` is running.
- Milestones 32, 33 and 36 descriptions are current, written through `milestone-desc.sh`.

**Next:** drive sprint-21:
- #411 is milestone 21's last item, the devcontainers cutover, and it's the maintainer's.
- Milestone 32: restart `lane.sh wait 1547` in the background with the Bash tool's maximum background timeout (the wait does not survive a session change). When it ends, run pr-checks and give the merge assessment before the maintainer approves; a `timeout` is possible, since the installed plugin predates the `exempt` ending. Run `lane.sh done 1547` once it merges and the maintainer says its session exited.
- Milestone 36: review the #1515 and #1516 spec comments as each posts, before the maintainer reacts; prep their lanes only when the maintainer says.

Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer reacts to the #1515 and #1516 specs and approves the #1547 lane PR after the driver merge assessment

**Maintainer actions:**
- #411, the devcontainers cutover. Further cutovers follow it. Close sprint-21 once #411 is done, with the `docs/decisions.md` sprint entry PR.
- Release way-of-working once both milestone 36 items merge, batched with milestone 32's work (decided 2026-11-15), and bump the pin.
- Milestone 35 has no open issues; close it through the archive path when convenient.
- #223: the refresh pass (tick what is done, move any live weakness to the private record, then decide whether it stays open).
- #1547 now carries #1525's finding on the background-wait timeout, which the 2026-11-14 ledger meant to decline; its spec only names the maximum timeout in the lanes skill and keeps the caps, so it does no harm, but say so if it should come out.
- Carried from 2026-11-14, unconfirmed this session: bump each consuming repo's pin to `v0.35.0`; the host files the review findings from #1521, #1522 and #1526.
- On the first real spec `### Trailers` squash, confirm GitHub joins its Co-authored-by lines into the trailer block (the #1518 decline rests on it).
- Carried: resume-orchestrator, merge its PR #186, then do the home-volume cleanup and restart through `wow-driver.ps1`.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Critic pass:** none this session; it was a driver session and wrote no code.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [milestone 32](https://github.com/glunk-works/claude-workbench/milestone/32) · [milestone 36](https://github.com/glunk-works/claude-workbench/milestone/36) · [.ai/parked/](parked/)
