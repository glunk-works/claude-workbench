# Cursor — claude-workbench

**Now:** **Sprint 14** (cursor id `sprint-14`) on [milestone 17, *Identity M2: dual-mode plugin v0.18.0*](https://github.com/glunk-works/claude-workbench/milestone/17), anchored at `19b1f96`. Status: **planning** (task #464 needs a plan before it is built).

**Just done (2026-10-09):**
- Task #380 merged (PR #465, `19b1f96`) as **read-side only**: one procedure in `conventions.md` (*Acting identity and reach*) and resume, ship, handoff, archive-sprint, plan-sprint and retro now point at it. The PR says `Refs #380`, so **#380 is still open**: its "done when" (each skill runs on scratch under both tokens) was not met; the human decides whether to close or narrow it.
- Measured under a dev-App token on the identity scratch repo (`docs/proposals/IDENTITY-SCRATCH-RESULTS.md`, session 6): `gh api user` 403; `.permissions` all `false`; `reached` is read reach only; `git push --dry-run` is a working write probe; an App's `{login, id}` is the `user` of a write response, so `classify` returns `app` only after a first write. The skills' command sequences were run by hand, not as interactive sessions.
- Critic pass on #380: architect, security-critic and docs-consistency, 2 rounds, converged; all on their own default models, no second-opinion round (never offered). Round 1 caught a wrong premise (`.permissions` is all `false`, not `null`) and a weakened ship preflight. No fresh-session `architect-review` ran.
- Filed #464 (unmilestoned) for the follow-up.

**Next:** plan #464 — the end-to-end skill runs under a dev-App token, and how ship's push preflight unblocks in App mode (a `git push --dry-run` check and/or accepting the actor after the first write and stopping if it is not the declared `dev_app`). Settle the split with #381 (review-step in App mode) first, since resume's derivation and handoff's no-op handoff also start with `gh api user`. Also decide whether #464 joins milestone 17 (v0.18.0 depends on #380) and whether `pr-checks`' bare `gh api user` belongs in it. Planning is a dialogue, one question at a time, on **opus** (architect); then the build goes to sonnet. A relaxed preflight needs a critic round.

**HITL Gate: NONE OPEN — the planning dialogue is the work; the human's merge of each task PR is the next gate.**

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 17](https://github.com/glunk-works/claude-workbench/milestone/17) · [.ai/parked/](parked/)
