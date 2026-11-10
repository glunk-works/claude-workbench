# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. Waves 1 and 2 merged; task #1371 next. Milestone 26 continues alongside; no lane is running.

**Just done (2026-11-10, driver session, opus):**
- Plugin v0.31.0 released (#1407), this repo's pin bumped (#1409), devcontainers v1.7 with the `plugin-install.sh` postStart line (#1410); the maintainer restarted. A stale project-scope 0.30.0 install still won after the restart and was uninstalled by hand (reported on 603-Identity/devcontainers#526, two comments).
- #1352 merged out of order (PR #1412, `2abb26c`): `.betterleaksignore` from the pinned README's full-history scan, 13 fixture values plus one reviewed docs false positive (`#497`) the maintainer accepted. The spec was redrafted once after the body's triage decision was corrected. This sync PR's `secrets / scan` is the first post-merge check.
- resume-orchestrator moved to v0.31.0 and devcontainers v1.7: its PR #184 (opened as Seuss27, unapprovable under its `RO-D21`) was closed and republished as `glunk-admin[bot]` in its PR #186, reviewed pass.
- Filed #1413 (ruleset-drift.sh fields it does not read) and #1414 (after-admin-token read-back) for resume-orchestrator's driver; commented its demand on #1379.
- Milestone 26's Build order and Lanes line kept current (#1165 and #1352 done).

**Next:** task #1371 — the maintainer reacts on #1371 (after its last body edit) and runs one -Spec 1371 session; the driver reviews the posted spec against main and its critic transcript before the reaction on it; then the #1371 lane. Then #1375, #1377 and #1374 in milestone 30 Build order. Milestone 26: #1340 re-spec (its spec is stale; the maintainer reacts on #1340 first), then #1361. The driver stays on opus.

**HITL Gate: OPEN** — the maintainer reacts on #1371 and runs its -Spec session; then each spec reaction and PR merge

**Critic pass:** none in this session; it wrote no code. The #1352 lane ran its own (architect, security-critic, docs-consistency; converged).

**Maintainer actions:**
- After every plugin pin bump and restart, before any session: inside the container, `claude plugin uninstall way-of-working@claude-workbench --scope project && git checkout -- .claude/settings.json`; every `installed_plugins.json` entry must then be at the tag's `gitCommitSha`. Claude Code re-creates a project-scope entry per folder at session start and never refreshes it on a bump. Rewrite `reference/conventions.md` § *Bumping a pinned plugin* to this flow.
- resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- Triage #1395, #1398, #1402–#1405, #1413 and #1414.
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
