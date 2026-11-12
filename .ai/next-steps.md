
# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. v0.32.0 is released and this repo pins it. No lane is live and no spec is pending. Milestone 34 holds the remaining repos' dev-container cutovers.

**Just done (2026-11-12, driver session, opus):**
- #1448 merged (`376636d`): way-of-working v0.32.0, released from `main` as tag `v0.32.0` at `376636d`, carrying #1374, #1375, #1377, #1424, #1440, #1371 and #1427.
- #1449 merged (`2edff6d`): this repo's own pin moves to `v0.32.0`.

**Next:** task #1381 — after the container restart through the launcher, the driver runs, from /workspace in its own session, `claude plugin uninstall way-of-working@claude-workbench --scope project && git checkout -- .claude/settings.json`; the maintainer runs `/reload-plugins`; the driver checks the user entry and any /workspace entry in `installed_plugins.json` are at `376636d` (old /tmp/lanes entries are leftovers). Then the driver hands over -Spec commands for #1381, #1416, #1425, #1287 and #1408 (no unmet depends_on), one per issue after the reaction-timing check, reviews each posted spec before the maintainer reacts, preps a lane per approved spec, and gives a merge assessment of each lane PR. The driver stays on opus.

**HITL Gate: OPEN** — the maintainer runs /reload-plugins after the driver's uninstall; each next milestone 30 spec needs the driver's review and the maintainer's reaction, then each lane PR the maintainer's approval

**Critic pass:** docs-consistency on #1448, 1 round, converged (two optional completeness notes: the #1410 bullet's number was added, #1436 was left out as repo-internal). #1449 ran none: a one-line pin change outside `code_paths`.

**Maintainer actions:**
- The launcher's start of day lands in a session that still loads 0.31.0: the stale project-scope /workspace entry outranks the user-scope install. The driver's uninstall above, then `/reload-plugins`, is the fix; the 27 old `/tmp/lanes/*` project entries matter only to a session started in those folders.
- The rest of #1427's Migration line: remove each old `tokens/<repo>` directory on both homes, only after `wow-admin <owner/name> --revoke` says no admin token is on file for it (an owner-equals-name directory keeps its owner directory; remove only the leftover token files in it).
- Rewrite `reference/conventions.md` § *Bumping a pinned plugin* to the post-restart project-scope uninstall flow.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 34](https://github.com/glunk-works/claude-workbench/milestone/34) · [.ai/parked/](parked/)
