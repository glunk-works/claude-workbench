# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, working from milestone 26, *Identity M5b: dev containers on the shared template*, anchored on task #1161. No lane is running.

**Just done (2026-11-02, driver session, opus):**
- The maintainer finished the v0.29.0 host steps: #1248 reviewed and approved, the release dispatched (`v0.29.0` on `fa78ed7`), the pin bump #1253 installed, the host tools reinstalled, and a start of day run. In the container, `/run/wow` is mounted and `/run/glunk-identity/dev` is gone (#1225 live). The `area/lanes` label is deleted.
- `/way-of-working:plan-sprint` placed 15 of 21 unmilestoned issues into milestones 26 to 29, each with a triage comment and a live build-order edit (`milestone-desc.sh`, all `live ok` in auto mode); recorded in PR #1254 (`4b52c5f`). #223, #334, #409, #792, #1020 and #1167 stay unmilestoned.
- Route step 4 was already filed as 603-Identity/devcontainers#418 (2026-11-01); nothing has started on it. Milestone 26's description now names it, and its **Lanes:** line says #1161, #1239 and #1240 can run now.
- Anchored task #1161 on milestone 26.

**Next:** task #1161 — get a spec-task: comment drafted for #1161 in its own -Spec session and reacted to by the maintainer, then prep a lane for it with `/way-of-working:lanes` and build it on sonnet; #1239 and #1240 can follow as parallel lanes. The driver stays on opus.

**HITL Gate: NONE OPEN** — next gate: the maintainer reaction on the spec comment for task 1161, then the merge of its PR

**Critic pass:** none in this session; it wrote no code.

**Maintainer actions:**
- Exit the leftover #1164 spec session and remove `/tmp/lanes/spec-lwlgdu` (the directory is still there).
- Start devcontainers#418 in that repo's own sessions: consider splitting it (flavour, tofu variant, template and lint, record), and clear its open dependency-bump PRs first, since the flavour builds on that base. #1226 and #1165 wait on it.
- Milestone 27 is due 2026-11-06 with 17 items; move the date if it no longer fits.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
