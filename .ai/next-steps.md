# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, re-anchored on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*, task #1378. Milestone 26 (#1340, #1352, #1361) continues alongside; no lane is running.

**Just done (2026-11-09, driver session, opus):**
- #1165 merged as #1363 (`ecd0120`); its lane was cleaned up (worktree, branch and prompt removed).
- Triaged the resume-orchestrator cutover findings (#169 there): each issue's body carries its 2026-11-09 triage decision. Filed #1378 (ship head check, closes #1372), #1379 (scheduled ruleset-drift workflow, a credential decision), #1380 and #1382 (launcher text, review-poll pause), #1381 (driver-record clone paths, deferred) and #1383 (cutover preflight as wow-admin).
- Folded #1372 into #1378, #1259 into #1371 (moved off milestone 29), and parts of #1370 into #1371 and #1377; the critic-identity check from #1377 into #1373.
- Created milestone 30 (due 2026-11-27, ahead of milestone 21's cutover) with its Build order and Lanes line; placed 12 issues; #1379 and #1381 left unmilestoned on purpose. Milestone 29's Build order updated.
- First anchor for milestone 30 (switched from milestone 26).

**Next:** task #1378 — the maintainer reacts on #1378 and runs one -Spec 1378 session; the driver reviews the posted spec before the reaction; then the lane. Wave 1 beside it: #1373 and #1368, plus #1380 and #1382 any time, each after its own reaction and -Spec session. #1376 is specced after #1378 merges. The driver stays on opus.

**HITL Gate: OPEN** — first anchor for milestone 30 (switched from milestone 26): the maintainer confirms milestone 30, reacts on #1378 and runs its -Spec session; then each spec reaction and PR merge

**Critic pass:** none in this session; it wrote no code.

**Maintainer actions:**
- React on each wave 1 issue after its last body edit (#1378, #1373, #1368; #1380 and #1382 when wanted) before its -Spec session.
- Carried: remove `status/needs-human` from #1165 if still set; remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Triage queue (driver, with the maintainer):**
- #1349 (tracking, milestone 26), #1352, #1353 (finding 2 kept as #1361), #1340 step 2 re-spec, #1344.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
