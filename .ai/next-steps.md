# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, working from milestone 26, *Identity M5b: dev containers on the shared template*. No lane is running.

**Just done (2026-11-01 to 2026-11-02, driver session, opus):**
- **Four milestone 26 tasks merged**, each through a spec session, a Claude lane and `wow-review`: #1224 (PR #1228, `f320abd`), #1164 (PR #1232, `90c07ef`; the lane fixed a `tests-1` failure where the no-jq fixture's `cp` followed a symlink to the runner's `/usr/bin/gh`), #1225 (PR #1238, `3d56343`) and #715 (PR #1242, `e21b96e`). Each review passed with only non-blocking findings, which the review host filed as issues.
- **#1164's spec was redrafted once**: the body gained "the check runs once per session", so the reach hook remembers a reached result per session instead of probing on every prompt (measured about 750 ms per prompt).
- **#715's lane got three additions** from its spec's round-4 critic notes (the `-SpecSweep` tests flipped to refusals, `wow-lane.ps1`'s sweep help line, the `GH_CONFIG_DIR` header wording), listed in PR #1242's body.
- **#1241** (`38f8cd6`): `bash scripts/test-all.sh` is now a `gates.green` entry, since #715's lane prompt runs only those entries.
- **#1229** filed (bound every job in `pr-title.yml` and `ci.yml` with `timeout-minutes`) after a `pr-title` job stuck in progress on PR #1228.
- **PR #1246** opened, auto-merge armed: retires the `lanes` area in `CLAUDE.md` and fixes the `.ai/project.yml` comment (part of #1243). The five open `area/lanes` issues now carry `area/way-of-working`.
- Milestone 26's description kept current through each merge; its build order is now #1226, #1165, #1161.

**Next:** Host session (maintainer): cut the way-of-working release carrying #1164, #1224 and #715, bump this repo's plugin pin with no other container session open, reinstall the host tools from main, and run one start of day with no lane running; then, on opus, run `/way-of-working:plan-sprint` to triage the unmilestoned backlog (#1229 to #1237, #1243 and older) into milestones.

**HITL Gate: OPEN** — the release, the pin bump, the host-tools reinstall and the start of day are the maintainer's host steps; no lane can be prepped until the release carrying bin/lane.sh is installed

**Critic pass:** none in this session; every code change came through a lane, each with its own critic gate.

**Maintainer actions:**
- Approve PR #1246, then delete the `area/lanes` label on GitHub. The release PR lists `/way-of-working:lanes` in the `plugin.json` and `marketplace.json` descriptions, the rest of #1243.
- At the start of day after the reinstall: #1225 takes effect (one token mount at `/run/wow`). Check that `gh` works, that `/run/glunk-identity/dev` is gone and that `docker inspect` shows five mounts. The same start of day writes the four-field driver record #1164 needs.
- Exit the leftover #1164 spec session in `/tmp/lanes/spec-lwlgdu`.
- Still open from earlier: file `WB-D42` route step 4 in 603-Identity/devcontainers (the draft is in the 2026-11-01 comment on #1226); #1226 and #1165 wait on it.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
