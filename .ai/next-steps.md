# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #407 (global-bootstrap) is cut over, with its done-when met; the bedrock-serverless-rag cutover (#408) is next.

**Just done (2026-10-28, driver session in the container, opus):**
- **#407 global-bootstrap cutover, done-when met.** The driver walked `reference/cutover.md` at v0.28.0 step by step with a host global-bootstrap session (Seuss27, every command approved) and read back live state after each step. The full record is on #407, in the cutover record comment and the done-when comment. #407 closes on the maintainer's call.
  - The root module moved into `infra/` (global-bootstrap #35) so that `code_paths` could be a plain prefix. The host plan read No changes.
  - Schema completion was #36 and CODEOWNERS #37.
  - The rulesets were split into `main-required-checks` (26037875, `validate` and `architect-review` @15368) and the approval ruleset 24741847. Both have no bypass actors.
  - PR 1 was #38. The first real gated PR through `wow-review` was #39.
  - The dev App stays off global-bootstrap, by the maintainer's decision, until a container needs it (#1165).
- **Lesson for the next cutovers:** `gh`'s OAuth token gets a 403 on `user/installations/<id>/repositories`, which a script can read as "not installed". Read the repo's own `settings/installations` page instead.

**Next:** Walk the maintainer through the #408 bedrock-serverless-rag cutover by `reference/cutover.md` at v0.28.0, one step at a time, with a live read-back after each step (opus). Apply the lessons recorded on #406 and #407:
- read installations on the repo's settings page;
- check that `code_paths` can be written as a plain prefix before `review.ci_gate` is set;
- create the checks ruleset before rewriting the approval ruleset;
- use two code owners;
- the maintainer pushes PR 1.

The remaining cutovers are #410, then #419.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts the #408 bedrock-serverless-rag cutover, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
