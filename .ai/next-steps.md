# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, milestone 26, *Identity M5b: dev containers on the shared template*, anchored on task #1165. #1226 is merged; no lane is running.

**Just done (2026-11-06, driver session, opus):**
- #1226 built and merged as #1351 (`de6e8dd`): `.devcontainer/` is the shared template's dev-App flavour, `FROM devcontainer-devapp:4.607` by digest, with the `pwsh` block as its one extra. Spec 6691155775, redrafted after the image-pin note; the lane's critic gate ran architect, security-critic and docs-consistency.
- The two template workflows went in as the maintainer's host commit; `verify / verify` passed. `secrets / scan` is red on test fixtures only (all fake values), not required; the ignore list is #1352.
- wow-review passed at `ed3ad81`; its non-blocking findings are #1353.
- Appended a 2026-11-06 note to #1165's body: resume-orchestrator is the section's first case.
- Reviewed resume-orchestrator's cutover spec (its #88, comment 6690566962) with its session: it stands as posted (workflow PRs published as glunk-admin, broker entry after its #115).

**Next:** task #1165 — after the #1226 Migration line, the rebuild and its live checks, the maintainer reacts on #1165 and runs one -Spec 1165 session; the driver reviews the spec before the reaction; then the lane. The driver stays on opus.

**HITL Gate: OPEN** — the maintainer does the #1226 Migration line, rebuilds the dev container through start of day and confirms the #1226 live checks; then the reaction on #1165 and each spec and PR merge

**Critic pass:** none in this session; it wrote no code (the #1226 lane ran its own).

**Maintainer actions:**
- #1226 Migration line: `broker.json` entry `glunk-works/claude-workbench`, reinstall the host tools, restart the broker; then start of day, and the spec's live checks in a session acting as the dev App.
- Remove `status/needs-human` from #1165 if its escalation was deleted on purpose; delete the outsider comment on #1165 if it is spam.
- Remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions.

**Triage queue (driver, with the maintainer):**
- Place #1349 (resume-orchestrator's cutover, filed under its old name resume-optimizer) and #1352.
- #1353: keep finding 2 (live checks in DEV-CONTAINER.md's after-rebuild section) as a docs follow-up; decline 3 and 4; finding 1 is #1352.
- #1340 step 2 note (#1348 findings 1 and 3, decline 2) and re-spec; triage #1344.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
