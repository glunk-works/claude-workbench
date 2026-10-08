# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-08):**
- Task #296 shipped as PR #364 (`541578a`): `driver-core.sh` takes a required
  `--protected-paths-file` (`scripts/loop/protected-paths.txt`) and refuses changes to the eight
  trust predicates and their fixtures as rule `protected`, both sides of a rename seen. It also
  refuses any `.gitattributes` and its NTFS short names, at any depth.
- Critic pass: `security-critic` and `architect` on their default models, 3 rounds, converged
  (round 3 only tightenings). No second-opinion round (declined). This repo has no review CI gate,
  so that was the only critic look before the merge.
- Real findings fixed on the way: a `.gitattributes` bypass and its `GITATT~1` alias, a driver
  hang on a directory passed as the list, and fixtures that passed for the wrong reason.
- Filed #363: whether to protect the `SKILL.md` call sites of the predicates (maintainer's call;
  decision 6 scoped #296 to the predicates and fixtures).
- Left as tightenings, not filed: ASCII-only case-folding, exotic short-name forms Git for Windows
  refuses to check out. Several driver-core fixtures skip on this host; run
  `sh tests/driver-core.test.sh` under WSL or Linux to exercise them.

**Next:** task #321 — driver critic staging bundle, critic launch and the system/init load check,
per the issue body; ship it as one PR. On **sonnet** (coder). Next in the build order whose
dependency (#319) is done; #322 and #323 follow. The driver caller must pass
`scripts/loop/protected-paths.txt` from its own checkout, never from the session tree.

**HITL Gate: NONE OPEN** — milestone 13's anchor re-verified against the prior baseline. Next gate:
the human's merge of the #321 PR. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
