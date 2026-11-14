# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*, with milestone 35's lanes alongside.

**Just done (2026-11-14, driver session, opus):**
- Milestone 35 lanes merged: #1458 (#1504), #1505 (#1506), #1421 (#1509), #1422 (#1511), #1402 with #1510 folded in (#1513), #1512 (#1514). Only #1423 is left; the maintainer decided its policy (option A, the readers' rule, in its body).
- Review findings regrouped: the open grouped review issues on milestones 33 and 29 now carry area titles, emptied ones are closed as duplicates with a mapping comment, and both milestones' Build orders match. #1508, #1518 and #1497 declined.
- Filed #1507 (background PR-review wait, milestone 32, folds #1517), #1515 (wow-review titles, paths, repeat links) and #1516 (a plan-sprint findings mode); #1515 and #1516 are unmilestoned.

**Next:** drive sprint-21: milestone 21 items #411 and #1499 are the maintainer's; the #1423 (milestone 35) and #1507 (milestone 32, folds #1517) spec sessions are running: when the maintainer says a spec is posted, review it per the lanes skill's Review the posted spec step, and once a maintainer has reacted, prep its lane with `/way-of-working:lanes` and start the background review wait for its PR. Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer reacts to the #1423 and #1507 specs before their lanes are prepped

**Maintainer actions:**
- #411 and #1499 (milestone 21).
- React to the #1423 and #1507 specs once reviewed; #1507's PR must close #1517 too.
- Place #1515 and #1516.
- After #1423 merges: the milestone 35 release, then each consuming repo's pin bump.
- On the first real spec `### Trailers` squash, confirm GitHub joins its Co-authored-by lines into the trailer block (the #1518 decline rests on it).
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [milestone 35](https://github.com/glunk-works/claude-workbench/milestone/35) · [milestone 32](https://github.com/glunk-works/claude-workbench/milestone/32) · [.ai/parked/](parked/)
