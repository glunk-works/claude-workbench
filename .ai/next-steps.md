# Cursor — claude-workbench

**Now:** **Sprint 22** (cursor id `sprint-22`), status **implementing**, on milestone 36, *Review findings flow*. Build order: #1564, then #1566.

**Just done (2026-11-17, driver session, opus):**
- Plan-sprint triage of the 7 unmilestoned issues, recommendation accepted whole: #1566 placed on milestone 36 after #1564 (`milestone-desc.sh` write `live ok`); #223, #334, #409, #1167, #1548 and #1579 left unmilestoned with triage comments (#1579 is for `/way-of-working:plan-sprint findings`). Recorded in PR #1606 (`b0d6c25`).
- The maintainer chose milestone 36 for sprint 22; this handoff anchors it on #1564. Milestones 32 and 35 have no open items; 32 ships batched with 36.

**Next:** task #1564 — confirm the maintainer reacted to spec comment 6901042032 after its last edit (`spec-find.sh find 1564` must print `found`), then prep lane #1564 when the maintainer says it comes up. #1566 needs a maintainer reaction on the issue before its spec (`-Spec 1566`). Model: opus (architect).

**HITL Gate: OPEN** — first anchor for milestone 36: confirm sprint-22 works from milestone 36 (Review findings flow); #1564 spec comment 6901042032 needs the maintainer reaction

**Also waiting on the driver or the maintainer:**
- devcontainers#556: spec comment 6949745206 reviewed and recommended; it needs the maintainer's reaction, then a lane in that repo.
- #1595 needs the maintainer's reaction on the issue before its spec.
- #1591's next steps: the next workflow-file change (#1566 is one) runs the admin-App route end to end; each other glunk-works repo switches at its milestone 34 item. No one pushes to a lane branch as Seuss27.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`; bounty-infra's `broker.json` entry (bedrock-serverless-rag, global-bootstrap and scope-core also have a review poller and no broker entry); #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202 and its next steps; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** no code diff in this repo this session (planning only).

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 36](https://github.com/glunk-works/claude-workbench/milestone/36) · [.ai/parked/](parked/)
