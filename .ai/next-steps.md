# Cursor — claude-workbench

**Now:** **Sprint 4** — [milestone 3](https://github.com/glunk-works/claude-workbench/milestone/3),
*record the deferred decisions*. Status: **implementing**, no release planned.

**Just done (2026-09-25, Opus, planning pass):**
- #48 decided: **TIER2 stays hand-maintained.** Rejected deriving at run time (fails open in
  CI) and a generated list (same drift weakness; non-repo names in TIER2). Spec:
  [#48 comment](https://github.com/glunk-works/claude-workbench/issues/48#issuecomment-5831964368).
- #45 decided: **two repos, split.** bounty-infra's analyses turned out to be zizmor, not
  CodeQL. This repo adds a non-required `zizmor` job. bedrock-serverless-rag gets CodeQL
  default setup, which the human toggles, tracked by an issue filed there. The rest wait. Spec:
  [#45 comment](https://github.com/glunk-works/claude-workbench/issues/45#issuecomment-5831964523).
- Milestone 3's description rewritten to record both decisions and the build order (#48, then
  #45). First anchor for milestone 3, description sha
  `3daabee1f6fcc57f6b6d1eb49f5db25653ef7fe9bedba4fb4334cdccf7da3a60`.

**Next:** task #48 — implement the approved spec
(https://github.com/glunk-works/claude-workbench/issues/48#issuecomment-5831964368): `WB-D14`
in docs/decisions.md plus retargeting TIER2's comment pointer in `scripts/coupling-check.sh`.
Then the green gate, `/way-of-working:critic-gate` (`architect` + `docs-consistency`), and
`/way-of-working:ship` with `Closes #48`. On **sonnet** (`coder`).

**HITL Gate: OPEN** — first anchor for milestone 3 (sha above). The human confirms the Sprint 4
plan, approved in the 2026-09-25 planning session, before the #48 build starts. A human "go"
at resume closes it.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 3](https://github.com/glunk-works/claude-workbench/milestone/3)
