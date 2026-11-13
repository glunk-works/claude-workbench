# Cursor — claude-workbench

**Now:** **Sprint 20** (cursor id `sprint-20`), status **implementing**, on milestone 31, *Cutover read-back: ruleset fields and the admin-token read-back*. #1488 is its last item; its lane is building in its own window.

**Just done (2026-11-13, driver session, opus):**
- Milestone 31 merged: #1298 (PR #1482), #1418 (PR #1484), #1413 (PR #1486), #1483 with #1485 folded in (PR #1489), #1414 `wow-readback` (PR #1491, `a703f05`). #1414 was split; its second half is #1488. Host tools reinstalled at `a703f05`.
- New milestone 35, *Lanes ready for other repos*: #1458, #1421, #1422, #1402, #1423, split out of milestone 32. Milestone 34 says each repo bumps its pin to that release before its first spec or lane.
- #124 reworked (review only PRs into the default branch) and moved to milestone 29. Milestones 6 and 10 closed; #211, #212 and #213 left open, unmilestoned, with triage notes.
- Review follow-ups placed: #1487 (with #1490 folded) on milestone 33, #1492 on milestone 29.
- The leftover `probe-option-a-tag-creation.yml` workflow was disabled.

**Next:** task #1488 — when lane #1488's PR is up and wow-reviewed, assess it against its approved spec and the review findings. After the merge, run `lane.sh done 1488` and place the reviewer's follow-up issue. Then cut the way-of-working v0.34.0 release for milestone 31 and bump this repo's pin. The release was deferred until #1488 merges, because #1488 adds the `environments` and `repo_settings` schema keys. Model: opus (architect).

**HITL Gate: OPEN** — first anchor for milestone 31: confirm sprint-20 works from milestone 31 (Cutover read-back). Lane #1488 is already building in its own window, so the driver never builds #1488 itself

**Maintainer actions:**
- #1423 (milestone 35) needs your policy decision before its spec.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.

**Follow-ups outside this repo (not sprint work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 31](https://github.com/glunk-works/claude-workbench/milestone/31) · [milestone 35](https://github.com/glunk-works/claude-workbench/milestone/35) · [milestone 34](https://github.com/glunk-works/claude-workbench/milestone/34) · [.ai/parked/](parked/)
