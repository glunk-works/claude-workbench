# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #419 is the milestone's last open issue; its fixes are tracked privately. Fixes 1 to 6 are done and proven live; the maintainer closes fixes 5 and 6 in the private record.

**Just done (2026-10-30 to 31, driver session in the container, opus):**
- **#419 fix 6:** bounty-infra is off Infisical. Its two keys are SSM SecureStrings declared write-only in global-bootstrap (#66, #70), and the operator IP is a `scan` Environment secret. The apply role trusts only the `production` and `scan` Environments (#72), and both roles use the immutable ID-qualified subject (#76). bounty-infra reads it all (#195). Proven by a deploy run, a zero-traffic scan run and a plan run. A closing comment for the private record is drafted in `.git/wow-handoff/fix6-progress.md`.
- **#419 fix 5:** its last step is done. The bedrock-serverless-rag apply role no longer trusts the main ref (global-bootstrap #75).
- **bounty-infra #187 closed (#199):** `scripts/dependabot-infra.ps1` takes a Dependabot PR through the infra-plan gate, after a security-critic pass whose findings were fixed. The first PR merged this way was #198, by hand.
- **Infisical:** the bounty-infra identity, folder and secrets are deleted. Only loop-orchestrator still uses the project (loop-orchestrator #216).

**Next:** Confirm with the maintainer that fixes 5 and 6 are closed in the private record (opus). Then re-check #419's done-when live and, if it is met, close #419 and run `/way-of-working:archive-sprint` for sprint-18. If a fix is still open, walk through what remains one step at a time with a live read-back. Every admin write and merge is the maintainer's.

**HITL Gate: NONE OPEN** — next gate: the maintainer confirms the private fixes closed, every admin write and merge theirs

**Follow-ups outside this repo (not sprint-18 work):** global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Critic pass:** none in this repo, which this session did not change in code. The bounty-infra script had a security-critic pass: 1 round, with its blocking and lower findings fixed and the attack shapes re-tested.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
