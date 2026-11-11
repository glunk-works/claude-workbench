
# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. #1371 and #1375 merged; task #1377 next. Milestone 26 continues alongside: the #1340 lane is running.

**Just done (2026-11-11, driver session, opus):**
- #1375 merged (PR #1420, `c963d7a`): `declared-ids.sh` prints `no-map` for `identities: null`, `spec-find.sh` prints `legacy`, `spec-post.sh` holds as `held legacy`, resume decides the mode before the finder. wow-review passed at its head; the lane is cleaned up.
- #1340 step 2 re-specced: the first redraft escalated (2 low findings), the maintainer answered `apply`, and the redraft converged (comment 6799326069, reacted). The first answered run was ignored because two older un-reacted drafts outranked the escalation in `spec-find.sh`; they were deleted and the run relaunched. Filed #1424. Lane prepped on `feat/retire-bare-token-dir`; its PR closes #1348.
- #1381 moved into milestone 30 with a triage decision in its body (driver-record paths, short launcher forms, an end-of-day command). #1414's body gained the corrected audit-log result. Filed #1421, #1422, #1423 (from resume-orchestrator#151), #1424 and #1425 (wow-admin's owner check, the #1340 residual).
- plan-sprint triaged 59 unmilestoned issues: new milestones 31 (cutover read-back, due 12-02), 32 (spec and lane flow, 12-16) and 33 (tidy-ups, undated); milestones 29 and 30 extended; 29 moved to 12-11; #1360, #1411, #1403, #1356 and #1358 closed; #1350, #1379 and #1345 left out on purpose. Each issue carries a `[plan-sprint]` triage comment.

**Next:** task #1377 — the maintainer reacts on #1377 and runs one -Spec 1377 session; the driver reviews the posted spec against main and its critic transcript before the reaction on it; then the #1377 lane. Alongside: when the #1340 lane's PR is ready, the driver assesses its wow-review and diff against the spec before the maintainer approves. Then milestone 30 Build order: #1374, #1424, #1416; after #1340 merges, #1381 (fold #1346, #1386, #1391 at spec time), #1425, #1287, #1289, #1405, and #1361 in milestone 26. Check #1377's Files touched against #1340's (`cutover.md`) before its reaction. The driver stays on opus.

**HITL Gate: OPEN** — the maintainer reacts on #1377 and runs its -Spec session; the #1340 lane PR needs wow-review and the maintainer merge; then each spec reaction and PR merge

**Critic pass:** none in this session; it wrote no code. The #1375 lane ran its own (architect, security-critic, docs-consistency). Both spec sessions converged in 3 rounds.

**Maintainer actions:**
- Milestone 30's Lanes line still says the #1375 lane is live; the driver proposes the fix at the next Lanes update.
- After #1340 merges: the Migration line's host steps (rewrite bare `broker.json` entries, reinstall host tools, restart the broker, remove old `tokens/<repo>` directories only after `--revoke` says none is on file); then check #1345 against that PR and close it.
- A plugin release after this wave (#1375 lands before milestone 21's cutover).
- After every plugin pin bump and restart, before any session: inside the container, `claude plugin uninstall way-of-working@claude-workbench --scope project && git checkout -- .claude/settings.json`; every `installed_plugins.json` entry must then be at the tag's `gitCommitSha`. Rewrite `reference/conventions.md` § *Bumping a pinned plugin* to this flow.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
