# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): no lane building; the dev container and review image bases are at 4.812 on `main`, and the host tools are reinstalled at `4587f1c`.

**Just done (2026-11-20 to 2026-11-22, driver session, opus):**
- Plan-sprint pass on the reviewer App findings: combined issues #1724, #1725, #1726 and #1727 filed and placed on milestone 29, #1704 placed on milestone 33, the source findings issues closed with mapping comments.
- Merged after the driver's assessment of each review and diff against its spec: #1728 (#1030, `5bd188b`), #1730 (#1235, `8b92560`), #1729 (#1237, `5924ff3`; `ci.yml` published by the admin App), #1732 (#1303, `82f2b7f`), #1734 (#1283, `88407b5`), #1733 (#1676, `6840c93`; the maintainer's host build passed and failed as the spec requires), #1737 (#1297, `d81fd1c`; its spec refreshed onto `5924ff3`). All seven lanes cleaned up.
- Dependabot bumps merged: #1739 (dev container `devcontainer-devapp` 4.812, `9f1698f`; host build passed, so its `claude` is still 2.1.316) and #1740 (review image `devcontainer-base` 4.812, `4587f1c`; attestation verified and the base's tools checked on the host). Host tools reinstalled from `4587f1c`; `check-host.ps1` all ok.
- Milestone 29 and 33 descriptions (Build order, Done, Lanes) kept current through `milestone-desc.sh`, each write read back by hash.

**Next:** Driver work: after the maintainer recreates the dev container on the 4.812 base and runs the live-run check, run `/way-of-working:resume`; then hand over the spec command for #1677 (the next milestone 29 item, now unblocked by #1676) and pick further milestone 29 lanes with `lane.sh groups 29`. Model: opus (architect).

**HITL Gate: OPEN** — the dev container recreate on the 4.812 base and its live-run check wait on the maintainer; the review image managed-settings probe re-run on Claude Code 2.1.316 (REVIEW-LIVE-RUN.md) is the maintainer's host run; every spec waits on the maintainer's reaction; nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- Every `-Spec` hand-over carries `-Driver NAME`, the name taken from `ListAgents` at that moment; it changes when the container is recreated.
- Reviewer App findings issues filed from PRs #1729, #1733, #1734, #1739 and #1740 await the next `/way-of-working:plan-sprint` findings pass. #1740's two (no CI check of the review image's base attestation, no CI build of that image) fit #1398 on milestone 29.
- The loop image (`scripts/loop/Dockerfile`, `ARG BASE_IMAGE`) is still on `devcontainer-base` 1.6: Dependabot does not track it by design. Offered: an issue for a hand bump.
- #1681 needs a fresh reaction (its body was edited after the last one). #1727 has no reaction yet. #1366 is the maintainer's admin decision; #1603 is the maintainer's host run.
- #1694's only unwitnessed Done-when item: check one `tests-1`/`tests-2` job summary for the run-time line.
- #1362 on milestone 29 needs a confirmed `depends_on` marker. #1624 needs the maintainer's reaction before its spec.
- devcontainers' `docs/host-steps.md` still describes the old Procedure B; that repo's driver is amending it. devcontainers#556's spec still needs the maintainer's reaction.
- #1591: each other glunk-works repo switches at its milestone 34 item. Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34).
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** this driver session wrote no code diff; each lane PR carries its own critic record in its body.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
