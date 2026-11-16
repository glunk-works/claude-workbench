# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*. Build order: #1568, then #411's step 10.

**Just done (2026-11-15 to 16, driver session, opus):**
- #411 steps 1 to 9 on 603-Identity/devcontainers: plugin pin `v0.36.0` (devcontainers#527), CODEOWNERS (#528), approval ruleset `main-approval` created and read back with no bypass, `restrict-updates-to-main` deleted, identities map and plugin gate (#530), old gate removed (#532), its own `.devcontainer/` (#535); `wow-readback` rows all accounted for and both audit-log searches empty.
- #411's body kept current as steps changed: `release-tags` keeps its admin bypass until devcontainers#529; PR 3 carries no verify caller until devcontainers#534; step 10 waits on #1568.
- Filed #1568 (a per-home tokens root, so a second org's home reaches the template's token mount) on milestone 21; milestone 21's build order written through `milestone-desc.sh`.
- #1564's rerun picked up the answer (`ANSWERCHECK=ok apply`) and posted spec comment 6901042032; its build waits on the maintainer's reaction.
- The security-critic item from #411's rewrite is recorded privately.

**Next:** launch the #1568 spec as its own `-Spec` session, check its transcript and the reaction, then run its lane; run the #1564 lane once the maintainer reacts to its spec. #411 step 10 starts only after #1568 is released and the host tools are reinstalled in both homes. Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer reacts to the 1568 spec once it posts

**Maintainer actions:**
- React to #1564's spec comment 6901042032 when you want its build.
- Before #411 step 10: devcontainers' Allow auto-merge back on (step 8), if not already done; delete the temporary `devcontainers-bootstrap` clone.
- devcontainers follow-ups, for its `-dev` container after step 10: #529 (release tags without a bypass), #531 and #533 (threat model and roadmap after the cutover), #534 (verify on its own `.devcontainer/`, plus a Dependabot entry), #536 (lint `.devcontainer/Dockerfile`).
- #1562 and #1563: spec at lane time, not now (each is last in its milestone's build order).
- Carried: bump each consuming repo's pin to `v0.36.0`; milestone 34 starts with #1429 (bounty-infra).
- Carried: the host files the review findings from #1521, #1522 and #1526; #223's refresh pass; the first spec `### Trailers` squash check (#1518); resume-orchestrator PR #186 and its home-volume cleanup; the extended live-run check after the next `FROM` bump (`docs/identity/DEV-CONTAINER.md`, *Opening it*).
- Milestones 32 and 35 have no open issues; close them through the archive path when convenient.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Critic pass:** no code diff in this repo this session; the devcontainers PRs each had a fresh-session architect review there.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [.ai/parked/](parked/)
