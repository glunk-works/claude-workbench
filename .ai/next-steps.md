# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*. #411 and #1568 are done. Build order: #1575 (done in #1592), #1571, #1581.

**Just done (2026-11-16 to 17, driver session, opus):**
- #1575 merged in #1592 (`f1fb797`): register-review-poll-task refuses to replace another home's poller task. Its review findings are #1593, and the broker-task guard is #1594 (both on milestone 29).
- #1571 refreshed onto `f1fb797` (spec comment 6947900681) and built in a lane. The lane hung for 40 minutes on an endless `sed` loop it had written (`wow-common.sh`); the maintainer stopped the test, the lane got the fix as a note, and its PR is #1596.
- #1591 (glunk-works runs one code owner, `* @Seuss27`) filed on milestone 34 and placed first there. Its lane escalated two false statements in the spec (comment 6949289312): the PR counts came from a truncated list, and loop-orchestrator has no CODEOWNERS file. The maintainer answered `choice=apply` (6949671772), and the redraft `-Spec 1591` is running. The old lane was dropped with discard.
- Filed: #1590 (wow-review removes stale image tags, milestone 29), #1595 (install-host-tools writes the wowd/wowl/wowend profile block, milestone 29, maintainer decision in its body). 603-Identity/devcontainers#556 (the base image moves to a pinned Python 3.15) was filed from that repo, and its spec has posted.
- bounty-infra (#1429 step 1): admin App added to the repo; `wow-preflight` reads both rulesets back as #406 left them; `production` admin bypass turned off; the reviewer App was already working there. Milestone 34 and #1429 now name the admin-App installation check.
- Milestone descriptions 21, 29 and 34 written through `milestone-desc.sh`; #412 to #418 carry the one-code-owner note for 603-Identity.

**Next:** task #1571 — when PR #1596 has its review, run `/way-of-working:pr-checks 1596` and give the merge assessment against spec comment 6947900681. After it merges: `lane.sh done 1571`, hand the maintainer the host-tools reinstall for both homes (`git pull --ff-only` in the install clone, HEAD equal to origin/main, `register-broker-task.ps1` per home with its own `-TaskName`, then each home's `bin\MANIFEST`), then `-Spec 1581` for its refresh. Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer approves PR 1596 after the driver merge assessment

**Also waiting on the driver:**
- Review the #1591 redraft when it posts: it must differ from 6948602717 only in the two corrections and the critic line. Then a fresh lane (milestone 34, critics architect, security-critic, docs-consistency); it shares no file with #1571 or #1581. After it merges, the maintainer removes JaredGroves-603's write access, and no one pushes to a lane branch as Seuss27 again.
- Review devcontainers#556's spec (the 3.15 build source, how `python3` resolves, apt's own Python).
- #1595 needs the maintainer's reaction on the issue before its spec; it waits for #1571 (`install-host-tools.ps1`) and #1581 (`DEV-CONTAINER.md`).

**Maintainer actions:**
- bounty-infra: #193 is approved and clean to merge; #202 needs only an approval; leave #201 open until the 3.15 pilot (held until bounty-infra runs as the dev App). Its next steps: #1591, then #1429's template PR, the `broker.json` entry (it can ride the #1571 reinstall), the dev and loop Apps, pin `v0.37.0`, `lanes.dir`.
- #412 (infrastructure-core cutover) can start; keep "Prevent self-review" off on its Environments.
- After the reinstall: `docker rmi` the `wow-review:60985f814e95` image (#1590 automates it later); old project volumes are checked for clones before removal (#1589).
- Carried: react to #1564's spec comment 6901042032 (milestone 36) when you want its build; devcontainers follow-ups #529, #531, #533, #534, #536; milestones 32 and 35 have no open issues; the host files the review findings from #1521, #1522 and #1526; #223's refresh pass; #1518's first `### Trailers` squash check; resume-orchestrator PR #186 and its home-volume cleanup.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record. global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 and #194. loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Critic pass:** no code diff in this repo this session; each lane runs its own critic gate, and #1592 had its fresh-session review.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [.ai/parked/](parked/)
