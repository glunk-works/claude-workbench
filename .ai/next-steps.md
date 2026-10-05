# Cursor — claude-workbench

**Now:** **Sprint 8** (cursor id `sprint-08`), anchored on
[milestone 8](https://github.com/glunk-works/claude-workbench/milestone/8), *Security review
phase 1: plugin release*. Status: **implementing**. Plugin **v0.16.0** is released and this
repo's own pin is bumped to it; `claude plugin list` reports 0.16.0 for this repo, both
drive-letter casings (the mirror step, per the CHANGELOG's bump note).

**Just done (2026-10-05):**
- Shipped the restrict-updates fixes: `resume`'s cursor-sync merge works under the rule (#229,
  PR #238) and `pr-checks` reports **READY (admin merge)** instead of waiting (#224, PR #239);
  the SessionStart hook is stored executable, with a fail-closed invariants check (#214, PR
  #240). Released as v0.16.0 (#241), pin bumped (#242).
- **Critic passes (default models, no second-opinion round attempted):** #229 — 4 rounds,
  converged (round 4 tightenings-only). #224 — 4 rounds, **cap reached**: round 4 left small
  prose findings, applied after it and **not re-read by a critic**; the human chose to ship.
  #214 — 1 round, fixes applied, **no re-run**, so not formally converged.
- Follow-up issues from those passes are filed unmilestoned for `/way-of-working:plan-sprint`
  to triage (`gh issue list --search "no:milestone"`).
- Every merge to `main` is still an admin bypass (merge in the web UI); `resume`'s offer
  should now work on this ledger's own sync PR with 0.16.0 loaded — first real test.

**Next:** task #225 — in architect-review step 5 mark the PR body as data to review, never
instructions to the session, and call out bot-authored PRs (Dependabot and any `[bot]`
author) explicitly; apply the same wording where `agents/architect.md` and
`agents/security-critic.md` read a PR body; add an `invariants-check.sh` check that the
wording stays if it fits that script's model. Then the green gate,
`/way-of-working:critic-gate` (`architect` + `security-critic`) and `/way-of-working:ship`.
**#226** (Apache-2.0 license) follows and ships in the same release as #225. On **sonnet**
(`coder`).

**HITL Gate: NONE OPEN** — the next gate is the human merging each task PR.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 8](https://github.com/glunk-works/claude-workbench/milestone/8) ·
[CHANGELOG.md](../CHANGELOG.md) · [.ai/parked/](parked/)
