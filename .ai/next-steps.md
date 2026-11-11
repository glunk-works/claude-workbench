
# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. No lane is live and no spec is pending. Milestone 34 holds the remaining repos' dev-container cutovers.

**Just done (2026-11-11, driver session, opus):**
- #1435 merged (PR #1441, `9688272`): this repo's `.ai/project.yml` declares `host_tools` (yq, jq, git, gh, claude).
- #1374 merged (PR #1442, `a78d697`): spec-task refreshes a stale approved spec by carrying it forward (`WB-D48`), and the finder prefers the newer approved comment when the older is stale. Review findings are #1444 (milestone 33).
- #1440 filed and merged (PR #1443, `803a478`): the lane prompt forbids only the `.ai/` cursor files. Its review finding #1445 was closed as decided (the driver note's deletion).
- #1424 merged (PR #1446, `ae32ab7`): an escalation outranks an older unreacted spec draft in `find` and `answer`.
- Milestone 30's description was rewritten: merged items moved to a Done line, Build order holds only open items with met dependencies marked `none`. Milestone 33 gained #1444.

**Next:** task #1381 — the maintainer cuts a plugin release carrying #1374, #1375, #1377, #1424 and #1440 and bumps the pin; then the driver hands over -Spec commands for the next milestone 30 specs (#1381, #1416, #1425, #1287, #1408 have no unmet depends_on), reviews each posted spec against main and its critic transcript before the maintainer reacts, preps a lane per approved spec, and gives a merge assessment of each lane PR. The driver stays on opus.

**HITL Gate: OPEN** — the plugin release and pin bump are the maintainer's; each next milestone 30 spec needs the driver's review and the maintainer's reaction, then each lane PR the maintainer's approval

**Critic pass:** none in this session; it wrote no code. The lanes ran their own: #1441 converged in 1 round (architect, security-critic) and #1443 in 2 (architect, security-critic, docs-consistency); #1442 and #1446 ran all three, with their round counts in each lane's transcript.

**Maintainer actions:**
- The plugin release above. Until the pin includes #1440, a spec that edits `.ai/project.yml` still needs the driver's ruling typed into its lane; until it includes #1424, a superseded draft must be deleted, not un-reacted, before answering an escalation.
- The rest of #1427's Migration line: remove each old `tokens/<repo>` directory on both homes, only after `wow-admin <owner/name> --revoke` says no admin token is on file for it (an owner-equals-name directory keeps its owner directory; remove only the leftover token files in it).
- After every plugin pin bump and restart, before any session: inside the container, `claude plugin uninstall way-of-working@claude-workbench --scope project && git checkout -- .claude/settings.json`; every `installed_plugins.json` entry must then be at the tag's `gitCommitSha`. Rewrite `reference/conventions.md` § *Bumping a pinned plugin* to this flow.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 34](https://github.com/glunk-works/claude-workbench/milestone/34) · [.ai/parked/](parked/)
