# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, working from milestone 26, *Identity M5b: dev containers on the shared template*, anchored on task #1262. No lane is running.

**Just done (2026-11-02, driver session, opus):**
- Four lanes built and merged on milestone 26: #1239 (PR #1257, `9cf2818`), #1240 (PR #1258, `7839b53`), #1256 (PR #1260, `b3d6eda`, host launchers refuse a yq older than v4.54.1) and #1161 (PR #1264, `4077dde`, origin repo in every launch's first message, installer repo-list cross-check, schema interview hand-add line). All four lanes are cleaned up.
- #1256 was found live: the host's Scoop yq v4.53.6 has no `if`, so every `wow-lane.ps1` run stopped at `yq could not read lanes.dir`; fixed on the host with `scoop update yq`.
- `/way-of-working:plan-sprint` placed the day's review follow-ups: #1262, #1263, #1265 and #1266 on milestone 26 (steps 7 to 10, independent), #792 on milestone 28 (60% context mark, decided in its body), #1261 and #1259 on milestone 29. Closed #1020 as not planned. #223, #334, #409 and #1167 stay unmilestoned. Every edit was made live through `milestone-desc.sh` (auto mode, all `live ok`).
- Anchored task #1262 on milestone 26.

**Next:** task #1262 — get a spec-task: comment drafted for #1262 in its own -Spec session (after the maintainer reacts on the issue) and reacted to, then prep a lane for it with `/way-of-working:lanes` and build it on sonnet; #1263, #1265 and #1266 follow the same way as parallel lanes. The driver stays on opus.

**HITL Gate: NONE OPEN** — next gate: the maintainer reaction on issue 1262 and then on its spec comment, then the merge of its PR

**Critic pass:** none in this session; it wrote no code. Each lane ran its own critic gate before its PR.

**Maintainer actions:**
- React on #1262, #1263, #1265 and #1266 (each App-filed, so a reaction must follow its last edit before a -Spec run), and on #792, whose body now holds the 60% decision.
- Exit the leftover #1164 spec session and remove `/tmp/lanes/spec-lwlgdu` and `/tmp/lanes/record-spec-lwlgdu` (both still there).
- Start devcontainers#418 in that repo's own sessions; #1226 and #1165 wait on it.
- Milestone 27 is due 2026-11-06; move the date if it no longer fits.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
