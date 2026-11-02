# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, working from milestone 26, *Identity M5b: dev containers on the shared template*. No lane is running.

**Just done (2026-11-02, driver session, opus — backlog triage):**
- The maintainer finished the v0.29.0 host steps (wow-review and approval of #1248, release dispatch, the pin bump #1253 installed, host tools reinstalled, start of day). The `v0.29.0` tag is on `fa78ed7`.
- `/way-of-working:plan-sprint` placed 15 of 21 unmilestoned issues, each with a `[plan-sprint]` triage comment and a live build-order edit via `milestone-desc.sh` (all four `live ok`, auto mode, no classifier denial): milestone 26 gains #1239 and #1240; milestone 27 gains #1231 (after #1188) and the manifest and changelog items #1249, #1250, #1252, #1251; milestone 28 gains #1244 and #1245; milestone 29 gains #1229, #1230, #1233, #1234, #1235, #1237. #223, #334, #409, #792, #1020 and #1167 stay unmilestoned (each already carries a `left unmilestoned` record). Milestone 27 now has 17 items and is still due 2026-11-06.

**Earlier (2026-11-01 to 2026-11-02, driver session, opus):**
- **Four milestone 26 tasks merged**, each through a spec session, a Claude lane and `wow-review`: #1224 (PR #1228, `f320abd`), #1164 (PR #1232, `90c07ef`; the lane fixed a `tests-1` failure where the no-jq fixture's `cp` followed a symlink to the runner's `/usr/bin/gh`), #1225 (PR #1238, `3d56343`) and #715 (PR #1242, `e21b96e`). Each review passed with only non-blocking findings, which the review host filed as issues.
- **#1164's spec was redrafted once**: the body gained "the check runs once per session", so the reach hook remembers a reached result per session instead of probing on every prompt (measured about 750 ms per prompt).
- **#715's lane got three additions** from its spec's round-4 critic notes (the `-SpecSweep` tests flipped to refusals, `wow-lane.ps1`'s sweep help line, the `GH_CONFIG_DIR` header wording), listed in PR #1242's body.
- **#1241** (`38f8cd6`): `bash scripts/test-all.sh` is now a `gates.green` entry, since #715's lane prompt runs only those entries.
- **#1229** filed (bound every job in `pr-title.yml` and `ci.yml` with `timeout-minutes`) after a `pr-title` job stuck in progress on PR #1228.
- **PR #1246** opened, auto-merge armed: retires the `lanes` area in `CLAUDE.md` and fixes the `.ai/project.yml` comment (part of #1243). The five open `area/lanes` issues now carry `area/way-of-working`.
- **PR #1248** opened, auto-merge armed: the v0.29.0 release PR (`CHANGELOG.md` heading, `plugin.json` version, both plugin descriptions listing `/way-of-working:lanes`, closing #1243 with #1246). Local gate passed, `test-all.sh` included. It touches `code_paths`, so it needs `wow-review`.
- Milestone 26's description kept current through each merge; its build order is now #1226, #1165, #1161.

**Next:** Maintainer: pick the next task to build and anchor it with `/way-of-working:handoff` (milestone 26 is live: #1226 and #1165 still wait on route step 4 in 603-Identity/devcontainers; #1161, #1239 and #1240 do not), then a spec session for it and a lane once the spec has your reaction.

**HITL Gate: OPEN** — the review and approval of #1248, the release dispatch, the pin bump, the host-tools reinstall and the start of day are the maintainer's host steps; no lane can be prepped until the release carrying bin/lane.sh is installed

**Critic pass:** none in this session; every code change came through a lane, each with its own critic gate.

**Maintainer actions:**
- Approve PR #1246, then delete the `area/lanes` label on GitHub.
- At the start of day after the reinstall: #1225 takes effect (one token mount at `/run/wow`). Check that `gh` works, that `/run/glunk-identity/dev` is gone and that `docker inspect` shows five mounts. The same start of day writes the four-field driver record #1164 needs.
- Exit the leftover #1164 spec session in `/tmp/lanes/spec-lwlgdu`.
- Still open from earlier: file `WB-D42` route step 4 in 603-Identity/devcontainers (the draft is in the 2026-11-01 comment on #1226); #1226 and #1165 wait on it.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
