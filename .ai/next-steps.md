# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Status: **planning**, on the go/no-go for **#28**'s taxonomy half.

**Just done (2026-08-13):**
- **#28's security half (decision 8) executed and closed out** — PR **#40** (`e696090`).
  Private vulnerability reporting is now on for all 8 `glunk-works` repos; secret scanning,
  push protection, and Dependabot alerts were already on everywhere. Evidence in
  [`.ai/context/security-posture-2026-08-13.md`](context/security-posture-2026-08-13.md).
- **The snapshot invalidated the plan's premise, which is the point of taking one.** #28's
  survey (2026-08-11) was materially wrong two days later about its own headline repo:
  `bedrock-serverless-rag` had all three controls on, not off, and has **zero
  secret-scanning alerts in any state** — history already scanned clean. Review item 2's
  credential-rotation risk never materialised, and the four-control rollout across 8 repos
  reduced to one setting on four. Cause unestablishable — the org audit-log API 404s on this
  plan.
- **#28 commented and re-scoped** to the taxonomy half only; it remains the sole open issue.
- Pruned 2 squash-merged local branches (#39, #40). Ruleset `protected-integration-branches`
  healthy: 4 rule types, 3 required checks.
- No `/way-of-working:critic-gate` pass and none needed — `git diff main...HEAD` is empty and
  the session's landed diff touched no `code_paths` (one file under `.ai/`).
- Note for the next session: the four `PUT` calls had to be run by the human directly. The
  harness's auto-mode classifier declined `gh api -X PUT` against org repos. Expect the same
  block on any future org-wide setting change.

**Next:** Decide **#28**'s taxonomy half (decisions 1–7) against the issue's own **review
item 15** — does eight decisions of label hygiene remove more friction than it adds? Either
scope it into an executable plan (applying review items 1, 5, 7, 8, 10, 11, 13) or decline it
and close #28. The security half is done, so nothing is waiting on this. Architect/opus.

**Also unfiled, deliberately:** secret-scanning **validity checks** are off on all 8 repos and
7 of 8 have no code scanning. Both are outside decision 8's scope and were recorded rather
than acted on — worth their own issue if the human wants them.

**HITL Gate: OPEN.** The taxonomy half is a go/no-go the human makes, not a task to start —
#28 flags it as unsettled itself, and review items 1 and 10 say parts of the plan as written
are wrong. Nothing in decisions 1–7 runs before that call. No `review.ci_gate` in this repo.

**Pointers:** [`docs/decisions.md`](../docs/decisions.md) (roadmap/decisions of record) ·
[`.ai/context/security-posture-2026-08-13.md`](context/security-posture-2026-08-13.md) ·
[#28](https://github.com/glunk-works/claude-workbench/issues/28) (the only open issue) ·
[#40](https://github.com/glunk-works/claude-workbench/pull/40)
