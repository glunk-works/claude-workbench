# Cursor — claude-workbench

**Now:** **Sprint 21** (cursor id `sprint-21`), status **implementing**, on milestone 21, *Identity M6: devcontainers cut over*, with milestone 35's lanes alongside.

**Just done (2026-11-13, driver session, opus):**
- Sprint-21 plan confirmed by the maintainer: it works from milestone 21 (#411 the devcontainers cutover, #1499 the live admin-token runs, both the maintainer's), and milestone 35 (*Lanes ready for other repos*) supplies the lanes that run alongside it. The first anchor gate for milestone 21 is answered.
- No lane prepped yet.

**Next:** drive sprint-21: milestone 21 items #411 and #1499 are the maintainer's; when the maintainer says the first milestone 35 lane comes up (#1458 or #1422), run its -Spec session, and prep the lane with `/way-of-working:lanes` once a maintainer has reacted to its spec. Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: the maintainer says when the first milestone 35 lane starts

**Maintainer actions:**
- #411 and #1499 (milestone 21).
- #1423 (milestone 35) needs your policy decision before its spec.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 21](https://github.com/glunk-works/claude-workbench/milestone/21) · [milestone 35](https://github.com/glunk-works/claude-workbench/milestone/35) · [.ai/parked/](parked/)
