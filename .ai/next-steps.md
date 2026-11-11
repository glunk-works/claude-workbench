
# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. #1371, #1375 and #1377 merged; the #1374 and #1435 spec sessions are running. Milestone 26 is closed; the remaining repos' dev-container cutovers are milestone 34.

**Just done (2026-11-11, driver session, opus):**
- #1340 step 2 merged (PR #1427, `6b93749`): the bare `tokens/<repo>` layout is retired and `wow-admin` takes `owner/name`; closes #1340 and #1348. The maintainer reinstalled the host tools on the glunk home (register-broker-task) and the 603id home (install only, no task). #1345 closed against it.
- #1361 merged (PR #1436, `84186e6`): the live-run check witnesses the image-provided controls. Milestone 26 closed with no open issue; its opening now says it covers route steps 1 to 6 plus resume-orchestrator.
- #1377 merged (PR #1437, `45a829a`): the optional `host_tools` key, `bin/host-doctor.sh`, and resume's `Host tools:` and `Plugin:` lines. Its review findings are #1438 (milestone 33).
- Milestone 34 created, *Identity M5c: remaining repos on the dev-container template* (route step 7), with tracking issues #1429 to #1433: bounty-infra, bedrock-serverless-rag, scope-core, global-bootstrap, loop-orchestrator.
- Filed #1434 (host-side launcher check, milestone 29) and #1435 (declare `host_tools` here, milestone 30), both split from #1377's spec. Milestone 26, 29, 30, 33 and 34 descriptions are current.

**Next:** task #1374 — the driver reviews the posted #1374 and #1435 specs against main and their critic transcripts before the maintainer reacts on each; then the #1374 and #1435 lanes, and a merge assessment of each lane PR's wow-review and diff vs spec before the maintainer approves. Then milestone 30 Build order: #1424, #1416; #1381 (fold #1346, #1386, #1391 at spec time), #1425, #1287, #1289, #1405, #1408. The driver stays on opus.

**HITL Gate: OPEN** — the #1374 and #1435 specs need the driver's review and the maintainer's reaction; then each lane PR's wow-review and the maintainer merge

**Critic pass:** none in this session; it wrote no code. The #1340, #1361 and #1377 lanes ran their own: #1427 converged in 3 rounds (architect, security-critic, docs-consistency), #1436 in 2 (docs-consistency), #1437 in 3 (architect, security-critic, docs-consistency).

**Maintainer actions:**
- The rest of #1427's Migration line: remove each old `tokens/<repo>` directory on both homes, only after `wow-admin <owner/name> --revoke` says no admin token is on file for it (an owner-equals-name directory keeps its owner directory; remove only the leftover token files in it).
- A plugin release after this wave: #1375 and #1377 reach sessions only with it and a pin bump.
- After every plugin pin bump and restart, before any session: inside the container, `claude plugin uninstall way-of-working@claude-workbench --scope project && git checkout -- .claude/settings.json`; every `installed_plugins.json` entry must then be at the tag's `gitCommitSha`. Rewrite `reference/conventions.md` § *Bumping a pinned plugin* to this flow.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 34](https://github.com/glunk-works/claude-workbench/milestone/34) · [.ai/parked/](parked/)
