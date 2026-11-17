# Cursor — claude-workbench

**Now:** **Sprint 22** (cursor id `sprint-22`), status **planning**. No milestone picked yet.

**Just done (2026-11-17, driver session, opus):**
- Sprint 21 closed: #1571 (PR #1596, `3241b21`) and #1581 (PR #1600, `f5a6dc7`) merged; both identity homes reinstalled at `3241b21`; the sprint-21 record corrected in PR #1601 (`3f3e123`); milestone 21 closed; archived to `.ai/archive/sprint-21-next-steps.md`. No release: nothing under `plugins/` changed after `v0.37.0`.
- #1591's rule landed in PR #1602 (`8332c21`) after two lane escalations and redrafts; JaredGroves-603's write access to claude-workbench is removed. #1591 stays open for its later steps.
- Filed on milestone 29, each in its Build order: #1598 (review findings of PR 1596), #1599 (the default home's shared-owner warning, a cleanup: the runbook already calls it expected), #1603 (live host checks of #1575's and #1571's refusals, which are tests-only so far), #1604 (a finished `-Spec` session's leftover process blocks the next `-Spec`).
- Retro: four memories added or updated (driver-shipped docs PRs get docs-consistency; milestone-desc.sh's file rule in the index; classifier refusals; verify before claim); #1590 confirmed again.
- Plan-sprint triage (7 unmilestoned issues, recommendation accepted whole): #1566 placed on milestone 36 as build-order step 2 after #1564 (`milestone-desc.sh` write `live ok`, order `1564, 1566`); #223, #334, #409, #1167, #1548 and #1579 left unmilestoned (#1579 is for `/way-of-working:plan-sprint findings`). Triage comment on each; nothing staged. The maintainer chose milestone 36 for sprint 22. Milestones 32 and 35 have 0 open items; 32 ships batched with 36.

**Milestone close:** closed — milestone 21, *Identity M6: devcontainers cut over* (0 open issues, `verify --plan` match, read back `closed`).

**Next:** plan sprint 22: anchor milestone 36 (*Review findings flow*, #1564 then #1566) with `/way-of-working:handoff`. #1564 needs the maintainer's spec reaction; #1566 needs a maintainer reaction on the issue before its spec. Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: plan the next unit

**Also waiting on the driver or the maintainer:**
- devcontainers#556: spec comment 6949745206 reviewed and recommended; it needs the maintainer's reaction, then a lane in that repo.
- #1595 needs the maintainer's reaction on the issue before its spec.
- #1591's next steps: the next workflow-file change runs the admin-App route end to end; each other glunk-works repo switches at its milestone 34 item. No one pushes to a lane branch as Seuss27.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`; bounty-infra's `broker.json` entry (bedrock-serverless-rag, global-bootstrap and scope-core also have a review poller and no broker entry); #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202 and its next steps; #412's cutover; #1564's spec reaction; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** no code diff in this repo this session. PR #1601 (docs) had a docs-consistency pass after it opened: 1 round, no defects, two tightenings (one applied). Lanes #1581 and #1591 ran their own critic gates.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: to be picked · [.ai/parked/](parked/)
