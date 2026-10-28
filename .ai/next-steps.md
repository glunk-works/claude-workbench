# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #410 (scope-core) is cut over, with its done-when met; #419 is next.

**Just done (2026-10-28, driver session in the container, opus):**
- **#410 scope-core cutover, done-when met.** The driver walked `reference/cutover.md` at v0.28.0 step by step with a host scope-core session (Seuss27, every write approved) and read back live state after each step. The full record is on #410, in the cutover record comment. #410 closes on the maintainer's call.
  - scope-core had no `.ai/project.yml`, so the schema fold was its first one, plus a `docs/decisions.md` stub serving as roadmap, decision log (`SC-D`) and threat model (scope-core #6). CODEOWNERS was #7.
  - The single ruleset was split: `main-required-checks` (26051193, strict) was created first, then `protected-integration-branches` (19521159) was rewritten as the approval ruleset, squash only. Strict and squash only were the maintainer's decisions. Neither ruleset has bypass actors.
  - PR 1 was #8 (identities map, `review.ci_gate`, both `rulesets` entries, the gate workflow byte-identical to v0.28.0, a new `.claude/settings.json` pin). The pinned check was added right after it. The first real gated PR through `wow-review` was #9, which closed scope-core#4 (a non-required zizmor job). Its review finding is scope-core#10.
  - The dev App stays off scope-core, by the maintainer's decision.
- Milestone 20's description now marks #410 done and names #419 next.
- **Lessons for the next cutover:**
  - `gh`'s login token cannot list `/user/installations` (403). Read `orgs/<org>/installations` plus the repo's GitHub Apps settings page instead.
  - The first REST read after a repo-settings PATCH can be stale. Re-read, or confirm through GraphQL, before calling it wrong.

**Next:** Walk the maintainer through #419 by its own checklist, one step at a time with a live read-back after each (opus). #419: every AWS role a workflow can assume trusts only Environment or main subjects, and the Infisical identities are retired. Every admin write and merge is the maintainer's.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts #419, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
