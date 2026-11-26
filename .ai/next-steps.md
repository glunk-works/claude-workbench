# Cursor — claude-workbench

**Now:** **Sprint 24** (cursor id `sprint-24`), status **implementing**, milestone 29 (*Follow-ups: host and script hardening*): no lanes live; open items are #1753 (needs its spec), #1797 (after the rest) and #1366 (the maintainer's admin decision).

**Just done (2026-11-25 to 11-26, driver session, opus, lanes):**
- Merged after the driver's assessment of each review and diff against its spec: #1811 (#1784, `dea4a06`), #1812 (#1765, `43e7cd4`), #1818 (#1796, `c213794`), #1819 (#1815, `9fce80e`), #1822 (#1814, `6a27fe7`), #1826 (#1809, `df38859`). Every lane cleaned up.
- #1812's red `tests-2` was a real environment dependency (SIGPIPE ignored on entry), fixed in the lane; #1811's red `tests-launchers` was a pwsh native crash that passed on a re-run.
- A subagent measured CI and session history for flaky tests (`tests-launchers` is the flaky job, mostly pwsh native crashes; 12 of 40 red jobs came from tests pushed before their workflow file). Filed and shipped as #1814 (launcher section cap, crash retry, held out of the `test-all` pool) and #1815 (ship's `Expected red:` line, `workflow-gap.sh`).
- #1814's spec escalated (one contradictory sentence) and was redrafted on the maintainer's `choice=apply` answer.
- #1809's three files were published by the admin App onto a fresh branch (hash-checked pwsh contents-API block, `CHANGELOG.md` rebuilt on main's tip, suite run on `6a27fe7` first); the dev App opened PR #1826. Token revoked.
- Filed #1817 (area/identity) from the devcontainers driver's request, adjusted: repo only from an existing driver record, pinned fetch, values file treated as container-written data. Unmilestoned.
- Milestone 29 description kept current through `milestone-desc.sh` (placements of #1814 and #1815 as steps 29 and 30, Done, Lanes `live: none`).

**Next:** Driver work on milestone 29: get the maintainer's reaction and a -Spec session for #1753 (now unblocked by #1784) and review its spec; hold Dependabot #1824 until it is recreated at matching image tags (devapp 4.885 vs base 4.888) and #1825 until `.betterleaksignore` carries reviewed fingerprints for the three v1.8 scanner false positives; then run `/way-of-working:plan-sprint` to unpack today's reviewer App findings issues and place #1817. Model: opus (architect).

**HITL Gate: OPEN** — the review image managed-settings probe re-run on Claude Code 2.1.316 (REVIEW-LIVE-RUN.md) is the maintainer host run; #1824 needs a Dependabot recreate and #1825 needs reviewed .betterleaksignore fingerprints before either is approved; plan-sprint placements are the maintainer decisions; every spec waits on the maintainer reaction and every lane PR on the maintainer approval; nothing auto-starts a build here.

**Also waiting on the driver or the maintainer:**
- #1824: comment `@dependabot recreate`; once both FROM lines share a tag, both images' checks in `.github/dependabot.yml` apply, and the dev image is built on the host before approval.
- #1825: the v1.8 secret scan flags `docs/proposals/orchestrator-m2-decisions.md:134`, `tests/identity-mint.test.sh:184` and `tests/identity-wow.test.sh:172` (a model id and token-fixture text, no credential). Fingerprints are HMAC hashes made with the org tooling; the ignore entries must merge to `main` before #1825's scan is re-run, since the scan reads the base commit's ignore file.
- A plugin release is due: #1815's `Expected red:` line and `workflow-gap.sh` reach lanes only once the installed plugin moves past v0.41.0.
- Every `-Spec` and lane hand-over carries `-Driver NAME` from `ListAgents` at that moment; a lane prepped by an earlier driver messages that driver, so its outcome is pasted by hand and `lane.sh wait` is restarted.
- A `.github/workflows` change is refused to the dev App: `wow-publish` publishes workflow files onto a lane PR; a change that also needs non-`.github/` files and no red CI goes through the admin App's contents-API block (route in the driver's memory). The lane's draft is restored with `git checkout --` before `lane.sh done`.
- The loop image (`scripts/loop/Dockerfile`, `ARG BASE_IMAGE`) is still on `devcontainer-base` 1.6: Dependabot does not track it by design. Offered: an issue for a hand bump.
- #1366 is the maintainer's admin decision. #1624 needs the maintainer's reaction before its spec. #1806 closes when #1366 merges.
- devcontainers#735 names #1817's launcher in that repo's `docs/host-steps.md` after it ships.
- #1591: each other glunk-works repo switches at its milestone 34 item. Maintainer, on the host: bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34).
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** this driver session wrote no code diff; each lane PR carries its own critic record in its body. #1826 carries the #1809 lane's record (architect, security-critic, docs-consistency, 1 round, converged).

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 29](https://github.com/glunk-works/claude-workbench/milestone/29) · [.ai/parked/](parked/)
