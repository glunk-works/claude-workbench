# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Just adopted its own `.ai/` contract — status: planning next task.

**Just done (2026-08-11):**
- Scaffolded `.ai/project.yml`, this file, `.gitignore`, `CLAUDE.md`, and
  `.claude/settings.json` (self-hosting `way-of-working@claude-workbench` pinned to
  `v0.5.1`) — closing finding 14 of #28 ("claude-workbench does not adopt its own
  plugin's contract").
- #28's security-baseline half (decision 8) executed: enabled secret scanning + push
  protection + Dependabot security updates + private vulnerability reporting on
  `claude-workbench` and `scope-core`. Same baseline enabled on `bedrock-serverless-rag`
  (the repo that previously had Dependabot alerts fully disabled, org-wide); its initial
  secret scan returned zero alerts and zero open Dependabot alerts, but GitHub's history
  backfill can take longer to complete — worth a follow-up check.
- #28's label/template taxonomy half (decisions 1–7) deliberately **not** started this
  session — deferred per the issue's own recommendation to split urgent/cheap
  (security) from expensive/judgment-heavy (taxonomy).

**Next:** Decide between the two remaining open issues — **#23** (ship/handoff discover a
wrong push identity only at push time — small, has evidenced cost: bit this repo's own
v0.5.0 release session six times) and **#21** (extract deterministic predicates from skill
prose into testable scripts — explicitly marked "not urgent" in its own text, staged
work). No HITL gate is open; this is a priority call, not a blocked item. Recommend
starting **#23** next (cheap, evidenced, independent) — Architect/Opus to scope it.

**Also open:** #28's taxonomy half (decisions 1–7: label rename/delete, org `.github`
templates, `labels.yml` + `scripts/sync-labels.sh`) remains decided-not-started, on hold
per this session's split.

**Pointers:** [`docs/decisions.md`](docs/decisions.md) (roadmap/decisions of record) ·
[#23](https://github.com/glunk-works/claude-workbench/issues/23) ·
[#21](https://github.com/glunk-works/claude-workbench/issues/21) ·
[#28](https://github.com/glunk-works/claude-workbench/issues/28)
