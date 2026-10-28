# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #419 is the milestone's last open issue; its audit is done and its fixes are in progress, tracked privately.

**Just done (2026-10-28, driver session in the container, opus):**
- **#419 audit done.** The driver walked the maintainer through #419's checklist on the host, one live read-back at a time. The public summary is on #419 (comment 6477938022): 13 roles reviewed, 2 deleted. Findings, decisions and the per-repo fix list are kept privately, because they describe gaps that are still open.
- **Rule for public text from here on:** no role names, open gaps, row numbers or private links in a public issue, PR, commit, code comment or decision log. Fix PRs are titled by the change, not the gap.
- **Cost rule recorded:** a paid feature beyond what is already paid for needs a real benefit at the current team size; prefer the free equivalent.
- **IaC rule recorded:** everything non-secret goes in IaC; anything hand-managed is a named residual with a reason and a follow-up, and an IaC migration never blocks a security fix.

**Next:** Walk the maintainer through #419's privately tracked fix issues one at a time, in their filing order (opus). The maintainer pastes each issue into the session, since this session cannot read the private record; the driver explains it, then hands over host commands one step at a time with a live read-back after each. Every admin write and merge is the maintainer's. After the last fix, re-check #419's done-when live and, if it is met, close #419 and run `/way-of-working:archive-sprint` for sprint-18.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts each 419 fix, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
