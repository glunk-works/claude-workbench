# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #406 (bounty-infra) is cut over and closed; the global-bootstrap cutover (#407) is next.

**Just done (2026-10-27/28, driver session in the container, opus):**
- **#406 bounty-infra cutover, closed as completed.** The driver walked `reference/cutover.md` at v0.28.0 step by step with a host bounty-infra session (Seuss27, every command approved) and read back live state after each step. The full record is on #406: the briefing comment, the step 7 read-back and the install comment.
  - The rulesets were split into `main-required-checks` (9 checks @15368, `architect-review` included) and the approval ruleset (code-owner review, 1 approval, last-push approval, stale dismissal), both with no bypass actors. `restrict-updates-to-main` is deleted.
  - Two code owners (`@Seuss27 @JaredGroves-603`), so no admin App is needed.
  - PR 1 is bounty-infra #188; PR 2, #189, was the first real gated PR through `wow-review`.
  - bounty-infra #179 (CI credentials) closed first. The dev App was installed last, with Administration and Workflows no access and Actions read-only.
- **Filed #1206.** The `slack` App holds Actions and Workflows write on every repo, which widens the integration pin's limit. bounty-infra was removed from it.
- **#791's Slack subscription test** ran on 2026-10-26; the results are on #791.

**Next:** Walk the maintainer through the #407 global-bootstrap cutover by `reference/cutover.md` at v0.28.0, one step at a time, with a live read-back after each step (opus). Apply the bounty-infra lessons from #406:
- read every App installation (org owner), not only the dev App's registration;
- use two code owners;
- create the checks ruleset before rewriting the approval ruleset, so the checks are never unrequired;
- PR 1 is pushed by the maintainer.

The remaining cutovers are #408 and #410, then #419.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts the #407 global-bootstrap cutover, every admin write and merge theirs

**Critic pass:** none; this session wrote no code.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
