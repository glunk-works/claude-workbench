# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*. Its one item, #411, is now an actor-split checklist; the driver drives it with the maintainer and a host admin session.

**Just done (2026-11-15, driver session, opus):**
- Confirmed this repo's pin bump (#1560) and both plugin install entries at the `v0.36.0` tag commit.
- First real run of `/way-of-working:plan-sprint findings`: #1553, #1555 and #1558 unpacked into #1562 (milestone 33) and #1563 (milestone 29), mapping comments posted, sources closed; milestone 29 and 33 build orders written through `milestone-desc.sh` (auto mode, not denied).
- Filed #1564 (findings mode labels combined issues; milestone 36, whose description is current) and #1566 (labels synced by workflow, suggested by PR; unmilestoned).
- Rewrote #411's body: who does each step (the maintainer only where no session can), repo rulesets for now, devcontainers gets its own `-dev` container on the template with a pinned image tag, the host admin session runs from the plain clone; two critic rounds (docs-consistency, security-critic), last edits not re-run.
- Recorded the interim repo-rulesets decision under WB-D24's 603-Identity amendment: merged in #1565 (`7ea9833`).

**Next:** drive #411 with the maintainer and a host admin session: step 1 (the maintainer creates the 603-Identity Apps) and step 3 (a devcontainers session bumps its pin) can start in parallel; check each finished step against 603-Identity/devcontainers' public state. Alongside, once the maintainer has answered the #1564 escalation and rerun its spec, check that transcript early for `ANSWER=` and `ANSWERCHECK=ok`. Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer answers the 1564 escalation and starts step 1 of 411

**Maintainer actions:**
- On #1564, post `spec-task-answer: escalated=6900755949 choice=apply` as Seuss27, then rerun `-Spec 1564`.
- Record in the private security-audits repo the item from #411's security-critic round (given in the driver chat, 2026-11-15).
- Before #411 step 2: confirm what the existing 603-Identity identity home on the host covers; `DEV-CONTAINER.md` does not describe a second org's home.
- #1562 and #1563: spec at lane time, not now (each is last in its milestone's build order).
- Carried: bump each consuming repo's pin to `v0.36.0`; milestone 34 starts with #1429 (bounty-infra).
- Carried: the host files the review findings from #1521, #1522 and #1526; #223's refresh pass; the first spec `### Trailers` squash check (#1518); resume-orchestrator PR #186 and its home-volume cleanup; the extended live-run check after the next `FROM` bump (`docs/identity/DEV-CONTAINER.md`, *Opening it*).
- Milestones 32 and 35 have no open issues; close them through the archive path when convenient.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Critic pass:** no code diff this session. The #411 body ran docs-consistency and security-critic, 2 rounds plus fixes, cap called by the driver; its final wording was not re-run.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [.ai/parked/](parked/)
