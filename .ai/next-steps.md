# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `06656e9`. Status: **implementing**.

**Just done (2026-10-10), planning #464 with the human, one question at a time:**
- **Split with #381:** #381 now owns the whole App-mode review-step path, meaning the predicate plus resume's and handoff's `gh api user` call, which takes the identity from the declared `dev_app` and derives nothing when it is `null`. Recorded as a [scope comment on #381](https://github.com/glunk-works/claude-workbench/issues/381#issuecomment-6097114066), which is the anchored spec.
- **#464 plan** ([comment](https://github.com/glunk-works/claude-workbench/issues/464#issuecomment-6097114231)) starts after #381. PR 1 changes ship's App-mode preflight: `git push --dry-run` before the push, then once the PR is opened its author must equal `identities.dev_app`. On a mismatch ship stops loudly and leaves the PR untouched. A critic round follows. PR 2 is the end-to-end runs: the human launches six interactive sessions under a dev-App token on scratch, with a run sheet per skill, and the results are recorded. #464 is now in milestone 17.
- **#380 closed** on its read side; its remaining "done when" moved to #464. **Filed #467** in milestone 17 for `pr-checks`' BLOCKED diagnosis under an App token, which depends on #381.
- **Milestone 17's build order edited** to add #464 and #467 after #381 and to relabel #380 and #381. Re-anchored on the edited description.
- No code changed, so there was no critic pass.

**Next:** task #381 — build the App-mode review-step path per the [spec comment](https://github.com/glunk-works/claude-workbench/issues/381#issuecomment-6097114066): `review-step.sh` matches the declared `identities.dev_app` under an App token (running login in user mode), and resume's derive chain and handoff's no-op handoff take the identity from `dev_app` instead of `gh api user`, deriving nothing when `dev_app` is `null`. Fixtures for both modes, then the green gate, `/way-of-working:critic-gate` and `/way-of-working:ship` with `Closes #381`. Build on **sonnet** (coder).

**HITL Gate: NONE OPEN — the #464 plan was settled with the human this session; the next gate is the human's merge of the #381 PR.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
