
# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. Specs for #1425, #1405 and #1454 are being drafted in their own sessions; no lane is live. Milestone 34 holds the remaining repos' dev-container cutovers.

**Just done (2026-11-12, driver session, opus):**
- Five lanes merged and cleaned up: #1408 (PR #1451, `22f6b42`), #1287 (PR #1452, `75320a5`), #1416 (PR #1453, `b7d65e0`), #1381 with #1346, #1386 and #1391 folded in (PR #1455, `35db2da`), #1289 (PR #1459, `f4d4c23`). None is released yet; v0.32.0 predates them.
- The plugin bump to v0.32.0 needed no project-scope uninstall: after the restart both `installed_plugins.json` entries were already at `376636d` (the memory note now says check, then uninstall only if stale).
- Plan-sprint: #1428 to M30 (after #1425), #1454 and #1456 to M33, #1457 to M29, #1458 (filed this session: architect-review loads no spec on a PR that closes folded issues) to M32; the six older unmilestoned issues stay as triaged. Then folds by body edit: #1428 into #1425, #1456 into #1454 (with a dated note that #1454's finding 1 is already done).
- Milestone 30's description is current (Done; build order #1425, #1428, #1289, #1405, where #1289 has since merged; the two folds noted).

**Next:** task #1425 — the three spec sessions running now post specs for #1425 (folds #1428), #1405 and #1454 (folds #1456, milestone 33); the driver reviews each posted spec and its critic transcript before the maintainer reacts, preps a lane per approved spec, gives a merge assessment of each lane PR, and cleans up merged lanes. The driver stays on opus.

**HITL Gate: OPEN** — each posted spec (#1425, #1405, #1454) needs the driver's review and the maintainer's reaction, then each lane PR the maintainer's approval

**Critic pass:** none in this driver session, which wrote no code; each lane ran its own critic gate, recorded in its PR body.

**Maintainer actions:**
- Reinstall the host tools, then do one start of day with `-Clone` and `-Reference` so the driver record gains the Reference path; after that `wow-driver.ps1 -Repo glunk-works/claude-workbench` and the `wow-lane.ps1 -Repo` forms (and `-EndDay`) work. Until then the driver hands over the long form.
- Release the plugin when the wave is in: #1381's lanes-skill command form, #1416 and #1287 reach consumers only with the next release and a pin bump.
- Rewrite `reference/conventions.md` § *Bumping a pinned plugin*: after the restart, check the user and /workspace entries are at the tag sha and uninstall the project-scope entry only if it is stale.
- The rest of #1427's Migration line: remove each old `tokens/<repo>` directory on both homes, only after `wow-admin <owner/name> --revoke` says no admin token is on file for it (an owner-equals-name directory keeps its owner directory; remove only the leftover token files in it).
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 34](https://github.com/glunk-works/claude-workbench/milestone/34) · [.ai/parked/](parked/)
