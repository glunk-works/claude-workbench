# Cursor — claude-workbench

**Now:** **Sprint 18** (cursor id `sprint-18`), status **implementing**, working from milestone 20, *Identity M5: glunk-works repos cut over*. #419 is the milestone's last open issue; its fixes are in progress, tracked privately. Fixes 1 to 3 are done.

**Just done (2026-10-29, driver session in the container, opus):**
- **#419 fix 3 done:** one PR in a 603-Identity repo (603-Identity/trust-anchors#89), merged by the maintainer, and a deploy credential rolled and written by the maintainer on the host; acceptance proven by live read-backs and a green manual deploy. A closing comment for the private record is drafted; the maintainer posts it and closes fix 3.
- **Process notes from fix 3:** run host acceptance commands in PowerShell, or Git Bash with `MSYS_NO_PATHCONV=1`, since MSYS rewrites `/`-leading arguments. The admin SSO role cannot decrypt CI/CD parameters by design, so a credential is proven only by the run that uses it. Pick a Cloudflare token by its permissions, not its name.
- **Follow-up drafted, not filed:** an infrastructure-core issue for short-lived per-deploy Cloudflare credentials; the maintainer files it through a host session.

**Next:** Continue walking the maintainer through #419's privately tracked fix issues one at a time, from fix 4 in filing order (opus). The maintainer pastes each issue into the session, since this session cannot read the private record; the driver explains it, then hands over host commands one step at a time with a live read-back after each. Every admin write and merge is the maintainer's. If fix 3 was the last, re-check #419's done-when live and, if it is met, close #419 and run `/way-of-working:archive-sprint` for sprint-18.

**HITL Gate: NONE OPEN** — next gate: the maintainer starts each 419 fix, every admin write and merge theirs

**Critic pass:** none; this session wrote no code in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 20](https://github.com/glunk-works/claude-workbench/milestone/20) · [milestone 26](https://github.com/glunk-works/claude-workbench/milestone/26) · [.ai/parked/](parked/)
