# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*. v0.35.0 is released, and milestone 32's lanes come next.

**Just done (2026-11-14, driver session, opus):**
- Milestone 35 is complete: #1423 merged in #1521 (`2a96c06`). #1507, with #1517 folded in, merged in #1522 (`9c63751`) after one fix round on its review.
- Released v0.35.0 (#1526, `ef4beba`), and this repo's pin moved to it (#1528, `eca20b6`). It has no Migration line.
- #1499 is closed. `wow-readback` and the admin view of `ruleset-drift.sh` ran live against this repo with no findings, and the record is on the issue.
- Filed #1520 (count an untested new branch as a critic defect, and carry tightenings to the lane as approved notes), placed second on milestone 32 after #1369.

**Next:** drive sprint-21:
- #411 is milestone 21's last item, the devcontainers cutover onto v0.35.0, and it's the maintainer's.
- After the container restart, confirm every installed way-of-working entry is at `ef4beba`.
- When the maintainer says to start milestone 32, hand over `-Spec 1369`, review the posted spec, and prep its lane once a maintainer has reacted. Wait for its review with `lane.sh wait`. #1520 follows #1369.

Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer reacts to the #1369 spec before its lane is prepped

**Maintainer actions:**
- Restart the container so `plugin-install.sh` installs v0.35.0, then bump each consuming repo's pin to `v0.35.0`.
- #411, the devcontainers cutover, onto v0.35.0. Further cutovers follow it.
- Close sprint-21 once #411 is done. Open the `docs/decisions.md` sprint entry PR together with the close.
- Place #1515 and #1516. The host files the review findings from #1521, #1522 and #1526. Decline the #1522 "30-minute background cap" finding: background waits ran 34 and 39 minutes on 2026-11-14.
- On the first real spec `### Trailers` squash, confirm GitHub joins its Co-authored-by lines into the trailer block (the #1518 decline rests on it).
- Carried: resume-orchestrator, merge its PR #186, then do the home-volume cleanup and restart through `wow-driver.ps1`.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Critic pass (this session's own diff, the v0.35.0 release PR #1526):** architect, security-critic and docs-consistency by the project's diff rule; 2 rounds, converged. The second-opinion round on fable was offered and declined.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [milestone 32](https://github.com/glunk-works/claude-workbench/milestone/32) · [.ai/parked/](parked/)
