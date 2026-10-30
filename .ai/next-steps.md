# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #419 is the milestone's last open issue; its fixes are in progress, tracked privately. Fixes 1 to 4 are done.

**Just done (2026-10-29 to 2026-10-30, driver session in the container, opus):**
- **#419 fix 4 done:** changes in a 603-Identity repo, merged and applied by the maintainer, and proven by live read-backs. A closing comment for the private record is drafted; the maintainer posts it and closes fix 4.
- **Process notes from fix 4:** split host work into a plan paste and an apply paste and check the plan in between, because a pasted script keeps running after `throw` and feeds `Read-Host`. In PowerShell, `@($null)` counts as one item, so filter with `Where-Object { $_ }` before counting. Quote `'-out=x.tfplan'`. The admin SSO session can expire mid-session; `aws sso login --profile admin-sso` restores it.
- **Follow-ups for the maintainer:** listed in fix 4's drafted closing comment, in the private record.

**Next:** Continue walking the maintainer through #419's privately tracked fix issues one at a time, from fix 5 in filing order (opus). The maintainer pastes each issue into the session, since this session cannot read the private record; the driver explains it, then hands over host commands one step at a time with a live read-back after each. Every admin write and merge is the maintainer's. After the last fix, re-check #419's done-when live and, if it is met, close #419 and run `/way-of-working:archive-sprint` for sprint-18.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts each 419 fix, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
