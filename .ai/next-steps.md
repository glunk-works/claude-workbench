# Cursor — claude-workbench

**Now:** **Sprint 8**, no milestone picked yet. Status: **planning**. The sprint's content is
milestone 1 of the sprint orchestrator plan (`docs/proposals/sprint-orchestrator-plan-v9.md`,
on PR #221).

**Just done (2026-10-05):**
- Plan v9 written (Opus 5.5 review, tests run on this machine, Fable 5.1 edit), four
  post-edit decisions taken (v9 § 8.13), Opus-reviewed and applied; on PR #221 (docs-only)
  with its inputs and the v1–v8 drafts.
- Human prerequisites done: three GitHub Apps registered and installed (`glunk-loop`,
  `identity-loop`, `infra-core-loop`; ids in v9 § 8.12), the `restrict-updates-to-main`
  ruleset active on all four repos, test tokens revoked.
- **Daily-flow consequence:** every merge to `main` is now a bypass. resume's cursor-sync
  merge fails until the `--admin` change (item a below) ships; merge cursor-sync PRs in the
  web UI or with `gh pr merge --admin` outside a Claude session until then.
- No code diff this session (docs only), so no critic pass applied.
- Not this session's: `docs/decisions.md` has an uncommitted edit on disk (pm-agent-loop
  archived, 2026-10-05). Left alone for the human.

**Next:** create the milestone-1 issues from v9 § 7.1 steps 1–2 and § 8.13, one each, in
this build order, then run `/way-of-working:plan-sprint` to place them in a sprint-08
milestone. On **opus** (`architect`). This is not one issue's build, so
`/way-of-working:resume` waits for a "go".
- a. resume's cursor-sync merge gains `--admin` (v9 § 8.5). First: it unblocks daily flow.
- b. devcontainers (other repo): `merge-guard.sh` admits that exact shape, still refuses
  `--admin` elsewhere.
- c. Step 1: no-op handoff rule, GitHub-derived review step, the WB-D's step-1 half; folds
  in #209 and #220.
- d. Step 2: fix `workflow.md` L140's nesting sentence; split resume into a lean auto-start
  path (< 20k tokens of prose per task session).
- e. plan-sprint gains a human-confirmed `depends_on` marker per issue.
- f. resume refuses auto-start while the driver's lock file exists.
- g. `orchestration.*` schema keys, `loop_identity` optional, WB-D17 style; `schema-complete`.
- h. § 8.1 name rule in `plan-anchor.sh` (login as argument, `untrusted` verdict, callers)
  and `review-sandbox.sh trust`, fixtures incl. the stale-`loop_identity` case (v9 § 8.13d).
- i. Host: Claude Code ≥ 2.1.259 on the loop host.
Milestone 2 (the driver, v9 § 7.2–7.5) gets no issues until milestone 1 lands.

**HITL Gate: OPEN** — merge PR #221 and confirm the list above before any issue is created.
Next gate after that: plan-sprint's milestone writes.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[plan v9](../docs/proposals/sprint-orchestrator-plan-v9.md) (PR #221) ·
[.ai/parked/](parked/)
