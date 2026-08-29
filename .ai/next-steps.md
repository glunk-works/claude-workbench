# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Status: **implementing** — two issues closed this session, both merged; the next pick-up is
[#53](https://github.com/glunk-works/claude-workbench/issues/53).

**Just done (2026-08-14):**
- **#44 declined and closed** via [PR #51](https://github.com/glunk-works/claude-workbench/pull/51)
  (`e5afdee`). Secret-scanning validity checks require **GitHub Secret Protection**
  ($19/committer/mo, Team or Enterprise); `glunk-works` is on **free**, so all 8 `PATCH` calls
  returned **200 and changed nothing**. Declined at ~$276/yr against an alert queue #28 recorded
  as empty on all 8 repos. Recorded in
  [`.ai/context/security-posture-2026-08-13.md`](context/security-posture-2026-08-13.md).
  **The operative lesson: a 200 is not a confirmation** — only the re-read caught it.
- **#49 closed** via [PR #55](https://github.com/glunk-works/claude-workbench/pull/55)
  (`9e6c191`). `coupling-check.sh` never scanned `plugins/*/hooks/`, and a stale literal was
  sitting in the blind spot. Widened the scanned set; fixed the hit; corrected both CI workflow
  step names (the `coupling` **job id** deliberately untouched — it is what
  `ruleset.required_checks` matches); widened the rule sentence in the gate's header + banner,
  `CLAUDE.md`, `README.md`, and `reference/project-schema.md`.
- **`/way-of-working:critic-gate` ran** on #49 (`architect` + `docs-consistency`, human-picked;
  `security-critic` proposed and trimmed). **Three rounds, converged** — round 3 returned
  tightenings-only. Round 1's two critics independently found the same top defect (the stale CI
  step names), which is what pulled it into the PR. One architect claim was **checked and
  rejected** (it named the wrong branch); its underlying convention point was right, hence the
  `ci/49-…` → `fix/49-…` rename.
- **Filed #52, #53, #54** as deferred critic findings rather than folding them into #49 —
  the same discipline #43 used when it filed #48 and #49.

**Next:** Implement **#53** — invert `coupling-check.sh`'s component loop from an allowlist to a
denylist so it **fails closed**, and add a header clause saying so. This is the structural cause
of #49: adding `hooks` fixed the instance, not the property, and `commands/` is the obvious next
instance. Mechanical against a written spec, so **coder/sonnet**. Then `/way-of-working:critic-gate`
(it touches `code_paths`) and `/way-of-working:ship`.

**HITL Gate: NONE OPEN.** The next gate is the human's merge of #53's PR. **#45** (which repos
CodeQL can analyse) and **#48** (TIER2 derive-vs-hand-maintain) are both **opus decisions** still
waiting and may preempt #53 — say so at `/way-of-working:resume` rather than treating it as a gate.

**Pointers:** [`docs/decisions.md`](../docs/decisions.md) (roadmap/decisions of record) ·
[#45](https://github.com/glunk-works/claude-workbench/issues/45) ·
[#48](https://github.com/glunk-works/claude-workbench/issues/48) ·
[#52](https://github.com/glunk-works/claude-workbench/issues/52) ·
[#53](https://github.com/glunk-works/claude-workbench/issues/53) ·
[#54](https://github.com/glunk-works/claude-workbench/issues/54)
