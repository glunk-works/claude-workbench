# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. Waves 1 and 2 merged; task #1371 next. Milestone 26 (#1340, #1352, #1361) continues alongside; no lane is running.

**Just done (2026-11-09 to 11-10, driver session, opus):**
- Wave 1 merged: #1368 (#1387), #1380 (#1385), #1382, #1378 (#1392, closes #1372), #1373 (#1394, `WB-D46`).
- Wave 2 merged: #1376 (#1401, `7ef2e35`, `WB-D47`), #1370 (#1400, `025afe6`), #1383 (#1399, `a762698`). Escalations on #1376 and #1370 answered by the maintainer and redrafted; each spec reviewed against `main` and its critic transcript before the reaction. Lanes cleaned up.
- Image bumps merged: dev container and review image to 4.661 (#1396, #1397). devcontainers v1.7 is cut: its secret scan uses `betterleaks stdin --git-diff` (rc.7); `verify` at v1.7 accepts this repo's `devcontainer.json` as is (it equals v1.7's previous template), and requires the `plugin-install.sh` postStart line from v1.8 on.
- Milestone 30's Build order and Lanes line kept current through each prep and merge.

**Next:** task #1371 — after the plugin release and its pin bump, the maintainer reacts on #1371 (after its last body edit) and runs one -Spec 1371 session; the driver reviews the posted spec before the reaction on it; then the #1371 lane. Then #1375, #1377 and #1374 in milestone 30 Build order. Milestone 26: #1352 after the devcontainers v1.7 pin bump and the restart. The driver stays on opus.

**HITL Gate: OPEN** — the maintainer cuts the plugin release for waves 1 and 2, merges its pin bump and the devcontainers v1.7 pin bump with the plugin-install.sh postStart line, and restarts; then reacts on #1371 and runs its -Spec session; then each spec reaction and PR merge

**Critic pass:** none in this session; it wrote no code. Each lane ran its own.

**Maintainer actions:**
- Plugin release, then the dogfood of `plugin-install.sh`: one host-pushed PR moving `secret-scan.yml` and `devcontainer-image.yml` to devcontainers `0517df2c0288c8c5d817cc9c286c37975e6399b1` (v1.7) and appending `; sh /usr/local/share/devc/plugin-install.sh` to `postStartCommand`; merge the plugin pin bump; with every container session exited, `claude plugin uninstall way-of-working@claude-workbench --scope project` (restore `.claude/settings.json` if rewritten); restart; check one user-scope install at the tag's `gitCommitSha`, that the driver and a lane load it, and `betterleaks version` reads `2.0.0-rc.7`. Then rewrite `reference/conventions.md` § *Bumping a pinned plugin*.
- #1352: react and run -Spec 1352 after the restart; fingerprints regenerated with rc.7 and the v1.7 git flags. The ignore-list PR's own scan stays red (the list is read from the base).
- Triage the review-findings issues #1395, #1398, #1402, #1403, #1404 and #1405 (#1405 has a one-line `cutover.md` fix; #1404 notes the push-onto-open-sync-PR path is untested: watch the first live run).
- Carried: remove the old `/tmp/lanes/spec-*` and `record-spec-*` directories of exited spec sessions; Dependabot #1364.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
