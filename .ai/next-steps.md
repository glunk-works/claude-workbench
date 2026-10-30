# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #419 is the milestone's last open issue; its fixes are in progress, tracked privately. Fixes 1 to 4 are done; fix 5 is done except its last step, which waits on fix 6.

**Just done (2026-10-30, driver session in the container, opus):**
- **#419 fix 5, steps 1 to 6 done:** changes in bedrock-serverless-rag (#202) and global-bootstrap (#51, #54), merged and applied by the maintainer and proven by live read-backs. Its last step waits on fix 6 step 5. A progress comment for the private record is drafted; the maintainer posts it.
- **Cleanup during verification:** an unintended lab apply on bedrock-serverless-rag was removed by hand and its state lock cleared; AWS and state match again. Details and follow-ups are in fix 5's private comment; the approval-time hazard is filed publicly in bedrock-serverless-rag.
- **Process notes from fix 5:** in a repo whose only code owners are the maintainer's two accounts, the account that pushes also opens the PR. global-bootstrap's apply needs all four `TF_VAR_` values, `findings_bucket_name` included. Every bedrock-serverless-rag merge starts a deploy whose apply is rejected while the lab is torn down. In pasted PowerShell, keep `if … else` on one line.

**Next:** Continue walking the maintainer through #419's privately tracked fix issues one at a time, from fix 6 in filing order (opus). The maintainer pastes each issue into the session, since this session cannot read the private record; the driver explains it, then hands over host commands one step at a time with a live read-back after each. Every admin write and merge is the maintainer's. Once fix 6 step 5 lands, return to fix 5's last step, then close fix 5. After the last fix, re-check #419's done-when live and, if it is met, close #419 and run `/way-of-working:archive-sprint` for sprint-18.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts each 419 fix, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
