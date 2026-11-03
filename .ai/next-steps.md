# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, back on milestone 26, *Identity M5b: dev containers on the shared template*, anchored on task #1226. Milestones 27 and 28 are complete and closed. No lane is running.

**Just done (2026-11-03, driver session, opus):**
- Closed milestones 27 and 28 (every issue on both was done; last merges through v0.30.0, pin bump `9a186f4`).
- Confirmed 603-Identity/devcontainers#418 (route step 4) closed completed on 2026-11-03.
- Unblocked #1226: removed `status/blocked` and appended a dated triage note to its body.
- Rewrote the milestone 26 description through `milestone-desc.sh` (`ok`): step 4 landed, both issues ready to spec.
- Pruned three squash-merged local branches; anchored task #1226 on milestone 26.

**Next:** task #1226 — run one -Spec session per milestone 26 issue: #1165 now (reacted 2026-11-02), #1226 once the maintainer reacts after its 2026-11-03 body edit; review each posted spec before the maintainer reacts; prep a lane only when the maintainer says. The driver stays on opus.

**HITL Gate: OPEN** — first anchor for milestone 26: the maintainer confirms sprint 19 continues on milestone 26 now that 603-Identity/devcontainers#418 has landed; then each spec comment reaction and each PR merge

**Critic pass:** none in this session; it wrote no code.

**Maintainer actions:**
- Confirm milestone 26 as the anchor (the gate above).
- React on #1226 (after its 2026-11-03 body edit), then start its -Spec session; #1165's can start now.
- Exit any finished spec sessions, then remove their `/tmp/lanes/spec-*` and `/tmp/lanes/record-spec-*` directories (`ls /tmp/lanes`).
- `lane.sh done` printed `next unreadable` for every lane on 2026-11-02; if the next cleanup prints it again, look at why.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
