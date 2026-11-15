# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*. Milestones 32 and 36 are complete and shipped as way-of-working v0.36.0.

**Just done (2026-11-15, driver session, opus):**
- Milestone 32's last lane: #1547 with #1525 folded in, merged in #1552.
- Milestone 36: #1515 merged in #1554; #1516 merged in #1556 (its spec was posted by the maintainer after three spec-task escalations, and its lane restarted from the first lane's saved draft after a lane escalation; a fix round named `--repo {backlog.repo}` on every findings-mode write).
- Released way-of-working v0.36.0 (#1559, tag at `6921024`); the host tools were reinstalled first, per its Migration line. This repo's pin bump is PR #1560.
- #1557 closed as fixed in the fix round of #1556. Milestone 32 and 36 descriptions are current, written through `milestone-desc.sh`.

**Next:** drive sprint-21:
- Once PR #1560 merges and the session restarts, confirm the user-scope and `/workspace` plugin install entries are at the `v0.36.0` tag commit.
- Then run `/way-of-working:plan-sprint findings` on the open review-finding issues #1553, #1555 and #1558, and apply only the placements the maintainer confirms. This is the mode's first real run.
- #411 is milestone 21's last item, the devcontainers cutover, and it's the maintainer's.

Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer approves PR 1560 and confirms the findings-mode placements

**Maintainer actions:**
- Approve PR #1560 (auto-merge is armed), then restart the session.
- Bump each consuming repo's pin to `v0.36.0`; the host tools are already reinstalled.
- Carried from 2026-11-14, unconfirmed: the host files the review findings from #1521, #1522 and #1526.
- #411, the devcontainers cutover. Close sprint-21 once #411 is done, with the `docs/decisions.md` sprint entry PR.
- Milestones 32, 35 and 36 have no open issues; close them through the archive path when convenient.
- #223: the refresh pass (tick what is done, move any live weakness to the private record, then decide whether it stays open).
- Carried: on the first real spec `### Trailers` squash, confirm GitHub joins its Co-authored-by lines into the trailer block (the #1518 decline rests on it).
- Carried: resume-orchestrator, merge its PR #186, then do the home-volume cleanup and restart through `wow-driver.ps1`.
- Carried: the next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Critic pass:** the v0.36.0 release diff (#1559) ran architect, security-critic and docs-consistency by the diff rule: 1 round, converged, no defects. Its unapplied tightenings are in #1559's body. The pin bump (#1560) touches no `code_paths`.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [.ai/parked/](parked/)
