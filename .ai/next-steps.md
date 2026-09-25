# Cursor — claude-workbench

**Now:** **Sprint 4** — [milestone 3](https://github.com/glunk-works/claude-workbench/milestone/3),
*record the deferred decisions*. Status: **implementing**, no release planned.

**Just done (2026-09-25, Sonnet, coder):**
- Task #48 shipped and merged: [PR #174](https://github.com/glunk-works/claude-workbench/pull/174)
  (`eb733c9`) — `WB-D14` recorded in `docs/decisions.md` (TIER2 stays hand-maintained), and
  `scripts/coupling-check.sh`'s comment retargeted from "see #48" to `WB-D14`. No pattern
  change to the gate.
- `/way-of-working:critic-gate` ran (`architect` + `docs-consistency`): 1 fix-and-re-run round,
  **converged**. Round 1 found two optional wording nits (missing `#48` citation; "fails
  open" wording implying a private repo exists today); both fixed, re-check came back
  tightenings-only. No second-opinion round (human declined; `{review.ci_gate}` is `null`,
  so this was the only critic look the diff got before merge).

**Next:** task #45 — implement the approved spec
(https://github.com/glunk-works/claude-workbench/issues/45#issuecomment-5831964523): add a
`zizmor` job to `.github/workflows/ci.yml` (pinned by a verified commit SHA,
`security-events: write` scoped to that job only), make it green (fix or justify-and-suppress
every finding, listed in the PR body), add `WB-D15` to `docs/decisions.md` (decision + survey
+ waiting list), and file one issue on `glunk-works/bedrock-serverless-rag` asking a human to
enable CodeQL default setup — the toggle itself is the human's, this harness cannot write org
settings. Then the green gate, `/way-of-working:critic-gate` (`architect` + `security-critic`
+ `docs-consistency`), and `/way-of-working:ship` with `Closes #45`, linking the
bedrock-serverless-rag issue. On **sonnet** (`coder`).

**HITL Gate: OPEN** — re-anchored for task #45 within the same sprint/milestone (description
sha unchanged: `3daabee1...`). This session's own `/way-of-working:resume` never ran
`plan-anchor.sh verify` (the prior gate was already open, so it took the wait branch), so per
the baseline-validity rule the anchor is treated as unverified rather than carried forward
silently. A human "go" at resume confirms the #45 spec before the build starts.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 3](https://github.com/glunk-works/claude-workbench/milestone/3)
