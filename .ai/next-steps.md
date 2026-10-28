# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #408 (bedrock-serverless-rag) is cut over, with its done-when met; the scope-core cutover (#410) is next.

**Just done (2026-10-28, driver session in the container, opus):**
- **#408 bedrock-serverless-rag cutover, done-when met.** The driver walked `reference/cutover.md` at v0.28.0 step by step with a host bedrock-serverless-rag session (Seuss27, every write approved) and read back live state after each step. The full record is on #408, in the cutover record comment. #408 closes on the maintainer's call.
  - Schema fold was bedrock #181 and CODEOWNERS #182. The old CODEOWNERS had per-directory lines that named one owner and overrode `*`; they were dropped.
  - The single ruleset was split: `main-required-checks` (26042322) was created first, then `protected-integration-branches` (20506099) was rewritten as the approval ruleset, squash only by the maintainer's decision. Neither has bypass actors. `ruleset-drift.yml` hard-coded the old shape and was updated in the same window (#183).
  - PR 1 was #184, the pinned check was added right after it, and the first real gated PR through `wow-review` was #185.
  - The dev App stays off bedrock-serverless-rag, by the maintainer's decision; F2 (bedrock #139) blocks it anyway.
- Milestone 20's description now marks #408 done and names #410, then #419.
- **Lesson for the next cutovers:** the plugin reinstall CLI dropped the uppercase drive-letter install record instead of updating it; re-check both casings afterwards.

**Next:** Walk the maintainer through the #410 scope-core cutover by `reference/cutover.md` at v0.28.0, one step at a time, with a live read-back after each step (opus). Apply the lessons recorded on #406, #407 and #408:
- read installations on the repo's settings page;
- land the schema fold before the pin bump;
- CODEOWNERS with no override lines that name fewer owners;
- create the checks ruleset before rewriting the approval ruleset;
- update any workflow that hard-codes the ruleset shape in the same window;
- re-check both drive-letter install records after the plugin reinstall.

The remaining cutover after #410 is #419.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts the #410 scope-core cutover, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
