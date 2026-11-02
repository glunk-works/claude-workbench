# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, moving from milestone 26 (*Identity M5b*, which now waits only on devcontainers#418) to milestone 27, *v0.28.0 follow-ups: runbook and reference docs*, anchored on task #1197. No lane is running.

**Just done (2026-11-02, driver session, opus):**
- Five lanes built and merged: #1262 (PR #1268, `9b7c714`), #792 (PR #1269, `a17e8b4`, the status line flags `handoff` at 60% context), #1266 (PR #1270, `bc9ae12`, with the review's as-written fix folded in), #1265 (PR #1271, `8699e26`) and #1263 (PR #1273, `3283181`, the yq minimum's reason, cited upstream as mikefarah/yq#2871). All five lanes are cleaned up.
- Closed #1272 (fixed by #1270) and #1250 (already done in v0.29.0); placed the review finding #1274 on milestone 29.
- Folded milestone 27's same-file chains through the issue bodies: #1197 takes #1198, #1188 and #1231; #1192 takes #1194 and #1195; #1186 takes #1187; #1249 takes #1252. Removed `status/needs-human` from #1160 and `status/blocked` from #791 (both decided 2026-10-26).
- Rewrote the milestone 26, 27, 28 and 29 descriptions through `milestone-desc.sh` (all `ok`).
- Anchored task #1197 on milestone 27.

**Next:** task #1197 — run one -Spec session per milestone 27 chain head (#1197, #1192, #1186, #1249, #1184, #1143, #1160, #1251; all reacted 2026-11-02), review each posted spec before the maintainer reacts, then prep a lane for each with `/way-of-working:lanes` as its spec is approved; #791 waits for #1160 to merge. The driver stays on opus.

**HITL Gate: OPEN** — first anchor for milestone 27: the maintainer confirms sprint 19 continues on milestone 27 while milestone 26 waits on devcontainers#418; then each spec comment's reaction and each PR merge

**Critic pass:** none in this session; it wrote no code. Each lane ran its own critic gate before its PR.

**Maintainer actions:**
- Confirm milestone 27 as the anchor (the gate above), then start the eight -Spec sessions.
- Exit the finished spec sessions, then remove their `/tmp/lanes/spec-*` and `/tmp/lanes/record-spec-*` directories (`ls /tmp/lanes`); the #1164 pair `spec-lwlgdu` is still among them.
- `lane.sh done` printed `next unreadable` for every lane on 2026-11-02, before the milestone 26 description dropped its closed items; if the next cleanup prints it again, look at why.
- Start devcontainers#418 in that repo's own sessions; #1226 and #1165 wait on it.
- Milestone 27 is due 2026-11-06; move the date if eight lanes will not fit.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 27](https://github.com/glunk-works/claude-workbench/milestone/27) · [.ai/parked/](parked/)
