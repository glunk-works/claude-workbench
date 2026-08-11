# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Starting **#23** — status: implementing.

**Just done (2026-08-11):**
- Scaffolded `.ai/project.yml`, `.ai/next-steps.md`, `.gitignore`, `CLAUDE.md`, and
  `.claude/settings.json` (self-hosting `way-of-working@claude-workbench` pinned to
  `v0.5.1`) — closed finding 14 of #28. Merged as PR #29 (`e733b42`).
- #28's security-baseline half (decision 8) executed: enabled secret scanning + push
  protection + Dependabot security updates + private vulnerability reporting on
  `claude-workbench`, `scope-core`, and `bedrock-serverless-rag` (the repo that
  previously had Dependabot alerts fully disabled, org-wide). Initial scan on bedrock:
  zero secret-scanning alerts, zero Dependabot alerts — worth a follow-up check since
  GitHub's history backfill can lag.
- Added the missing `required_status_checks` rule (`lint`, `coupling`, `invariants`) to
  the `protected-integration-branches` ruleset — it previously enforced nothing beyond
  PR-required + no-force-push.
- #28's label/template taxonomy half (decisions 1–7) deliberately not started — deferred
  per the issue's own recommendation to split urgent/cheap (security) from
  expensive/judgment-heavy (taxonomy).

**Next:** Implement #23's own preferred fix — **(3) + (1)**:
1. Document the `gh`-vs-`git` push-identity failure signature (the `403 denied to
   <account>` shape, `gh auth status` reporting green while `git push` still fails) in
   `plugins/way-of-working/reference/conventions.md`.
2. Add a cheap `gh`-side push-reach preflight (`gh api repos/{repo} --jq .permissions`)
   to `/way-of-working:ship` step 1, before any commit — catches the common case, not
   the exact `git`-vs-`gh` split observed, and the skill should say so plainly.

This touches `plugins/` (`code_paths`), so it needs the green gate and a `/critic-gate`
pass before its own `/ship`. No HITL gate open — model already matches (`sonnet`/`coder`),
cursor is clean, continuing in-session per explicit instruction rather than a full
session switch.

**Also open:** **#21** (extract deterministic predicates — explicitly "not urgent",
picked up after #23). #28's taxonomy half (decisions 1–7) remains decided-not-started.

**Pointers:** [`docs/decisions.md`](docs/decisions.md) (roadmap/decisions of record) ·
[#23](https://github.com/glunk-works/claude-workbench/issues/23) ·
[#21](https://github.com/glunk-works/claude-workbench/issues/21) ·
[#28](https://github.com/glunk-works/claude-workbench/issues/28)
