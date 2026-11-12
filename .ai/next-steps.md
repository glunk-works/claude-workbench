
# Cursor — claude-workbench

**Now:** **Sprint 19** (cursor id `sprint-19`), status **implementing**, on milestone 30, *Second consumer: fixes from resume-orchestrator's cutover*. Milestone 30 has no open issue and no lane is live. v0.33.0 is released; the pin bump to it (PR #1476) awaits the maintainer's approval. Milestone 31 (*Cutover read-back*) is next, to get resume-orchestrator going again; milestone 33 waits until it closes.

**Just done (2026-11-12, driver session, opus):**
- Milestone 30 lanes merged and cleaned up: #1425 with #1428 folded in (PR #1463, `6e9a903`) and #1405 (PR #1467, `4165698`).
- Milestone 33 lanes merged and cleaned up: #1454 with #1456 (PR #1462, `2705cd6`), #1465 (PR #1469, `03540bf`), #1466 (PR #1471, `42ddbdd`) and #1470 (PR #1474, `874e954`). #1466's first lane stopped on a stale spec (#1467 had changed `resume/SKILL.md`); a spec-task refresh carried the approved text forward unchanged.
- Filed #1461, #1465, #1466 and #1470 (the skill loader replaces a bare `$<digit>` with the invocation argument; probe run here under Claude Code 2.1.316: `$(0)` and `${1}` untouched, `$N` is the Nth argument from 0, replaced only when it exists). Closed #1472 as superseded by #1473.
- Released v0.33.0 (PR #1475, tag at `2e32980`); opened the pin bump to v0.33.0 (PR #1476), auto-merge armed.
- Removed the orphaned spec worktrees, their records and three stale local branches.

**Next:** after #1476 merges and the container restarts, check every `way-of-working@claude-workbench` entry in `installed_plugins.json` is at `gitCommitSha` `2e32980` (uninstall a project-scope entry only if stale); then, once the maintainer passes the sprint-19 gate, open the docs PR adding the sprint-19 entry to `docs/decisions.md` (closing at the #1476 merge), and after it merges run `/way-of-working:archive-sprint`, then `/way-of-working:plan-sprint` onto milestone 31. Model: opus (architect).

**HITL Gate: OPEN** — the maintainer approves PR #1476 (pin to v0.33.0), reinstalls the host tools and restarts the container, then passes the sprint-19 gate before the roadmap entry and archive-sprint

**Critic pass:** none in this driver session; each lane ran its own critic gate, recorded in its PR body. The release PRs (#1475, #1476) had none: a version string, a CHANGELOG heading and a pin, as for #1448 and #1449.

**Maintainer actions:**
- Approve PR #1476, reinstall the host tools (#1381, #1425, #1405 and #1465 change the identity scripts), restart the container.
- After the reinstall, do one start of day with `-Clone` and `-Reference` so the driver record gains the Reference path; then the `-Repo` forms (and `-EndDay`) work. Check once that a new lane tab and a new spec tab lead with the role and issue number (#1465).
- Rewrite `reference/conventions.md` § *Bumping a pinned plugin*: after the restart, check the user and /workspace entries are at the tag sha and uninstall the project-scope entry only if it is stale.
- The rest of #1427's Migration line: remove each old `tokens/<repo>` directory on both homes, only after `wow-admin <owner/name> --revoke` says no admin token is on file for it (an owner-equals-name directory keeps its owner directory; remove only the leftover token files in it).
- The next time the container is recreated after a `FROM` bump, run the extended live-run check under *Opening it* in `docs/identity/DEV-CONTAINER.md`.
- Carried: resume-orchestrator: merge its PR #186, then the home-volume cleanup and restart through `wow-driver.ps1`.

**Follow-ups outside this repo (not sprint-19 work):**
- The remaining items of #419's private record (the Infisical identity list and the Cloudflare token audit). global-bootstrap #71 and #68 can be closed; #67 and #69 stay open. bounty-infra #196, #197 (docs) and #194 (Gemini key). loop-orchestrator #216. Delete the leftover serverless-bedrock-rag folder in Infisical.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 30](https://github.com/glunk-works/claude-workbench/milestone/30) · [milestone 31](https://github.com/glunk-works/claude-workbench/milestone/31) · [milestone 33](https://github.com/glunk-works/claude-workbench/milestone/33) · [.ai/parked/](parked/)
