# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #419 is the milestone's last open issue; its fixes are in progress, tracked privately. Fixes 1 and 2 are done and closed in the private record.

**Just done (2026-10-28, driver sessions in the container, opus):**
- **#419 fix 1 done:** one PR in another org repo, reviewed, merged and applied by the maintainer; live read-back passed.
- **#419 fix 2 done:** a reviewed CI job and a narrowed role trust in 603-Identity repos, across four PRs, each reviewed, merged and (where IaC) applied by the maintainer with before/after snapshots; acceptance proven with an approved run (credentials issued) and a rejected run (none issued).
- **Process notes from fix 2:** a review in a 603-Identity repo must post as JaredGroves-603, which is the account that repo's review gate counts. A fresh review session on a public repo must be told the public-text rule, or it may file gap details publicly. Host agents get a written brief and never the private issue text.

**Next:** Continue walking the maintainer through #419's privately tracked fix issues one at a time, from fix 3 in filing order (opus). The maintainer pastes each issue into the session, since this session cannot read the private record; the driver explains it, then hands over host commands one step at a time with a live read-back after each. Every admin write and merge is the maintainer's. After the last fix, re-check #419's done-when live and, if it is met, close #419 and run `/way-of-working:archive-sprint` for sprint-18.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts each 419 fix, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
