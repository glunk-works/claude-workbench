
# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. Waves 1 and 2 and #1371 merged; task #1375 next. Milestone 26 continues alongside; no lane is running.

**Just done (2026-11-10, driver session, opus):**
- #1371 merged (PR #1417, `87645ae`), closing #1259 too: `ruleset-drift.sh` keeps reading types and checks when bypass actors are not visible, resume's plain installation-token ruleset line, the installation probe before `gh api user` in resume, handoff, ship and conventions, the no-cursor commits-ahead line. wow-review passed at its head; its four non-blocking findings are in #1418.
- The #1371 spec took three spec sessions: two skipped spec-task's *Answer branch* step and redrafted from scratch; the third, relaunched with a typed note naming the step, applied the answer and converged in 2 rounds. Filed #1416 (make the answer check unskippable).
- The approved design departs from the #1371 triage decision: no `mode` word read from `GH_TOKEN` (the dev container never exports it); the probe runs first instead.
- Milestone 30's Build order and Lanes line kept current (#1371 merged); the #1371 lane cleaned up.

**Next:** task #1375 — the maintainer reacts on #1375 and runs one -Spec 1375 session; the driver reviews the posted spec against main and its critic transcript before the reaction on it; then the #1375 lane. Then #1377 and #1374 in milestone 30 Build order. Milestone 26: #1340 re-spec (its spec is stale; the maintainer reacts on #1340 first), then #1361. The driver stays on opus.

**HITL Gate: OPEN** — the maintainer reacts on #1375 and runs its -Spec session; then each spec reaction and PR merge

**Critic pass:** none in this session; it wrote no code. The #1371 lane ran its own (architect, security-critic, docs-consistency; 2 rounds, converged).

**Maintainer actions:**
- After every plugin pin bump and restart, before any session: inside the container, `claude plugin uninstall way-of-working@claude-workbench --scope project && git checkout -- .claude/settings.json`; every `installed_plugins.json` entry must then be at the tag's `gitCommitSha`. Claude Code re-creates a project-scope entry per folder at session start and never refreshes it on a bump. Rewrite `reference/conventions.md` § *Bumping a pinned plugin* to this flow.
- resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- Triage #1395, #1398, #1402–#1405, #1413, #1414, #1416 and #1418.
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
