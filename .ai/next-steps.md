# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **planning**, on milestone 21, *Identity M6: devcontainers cut over*.

**Just done (2026-11-13, driver session, opus):**
- Sprint 20 (milestone 31) archived: status entry `75b986d` (PR #1500), last change `2c386f7` (PR #1498, the pin bump to `v0.34.0`).
- Filed #1499 (the live admin-token runs of `wow-readback` and `ruleset-drift.sh`), placed on milestone 21.
- Retro: filed #1501 (spec critic rounds escalating over a slip the last fix introduced), placed on milestone 32. #1497 placed on milestone 33, whose wait on milestone 31 is dropped. Build orders of milestones 21, 32 and 33 updated.

**Milestone close:** closed — milestone 31, *Cutover read-back: ruleset fields and the admin-token read-back* (`verify --plan` match, read back `closed` with 0 open issues).

**Next:** plan sprint-21 on milestone 21: both its items are the maintainer's (#411 the devcontainers cutover, #1499 the live admin-token runs); confirm the milestone, then pick which milestone's lanes (33, 32 or 35) run alongside it. Model: opus (architect).

**HITL Gate: OPEN** — first anchor for milestone 21: confirm sprint-21 works from milestone 21 (Identity M6: devcontainers cut over)

**Maintainer actions:**
- #1423 (milestone 35) needs your policy decision before its spec.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [.ai/parked/](parked/)
