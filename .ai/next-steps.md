# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **implementing** —
build-order step 1 (#126) shipped; step 2 (#113) is fully implemented and uncommitted, one
more critic-gate round requested before shipping.

**Just done (2026-09-24, Sonnet):**
- Task #113, option 1 (A+C+D, human-approved): new `plugins/way-of-working/bin/review-sandbox.sh`
  replaces the shared-`.git` `git worktree add` step with an isolated PR-execution sandbox
  (`trust`/`make`/`run`/`destroy`), `tests/review-sandbox.test.sh` fixtures it, and
  `skills/architect-review/SKILL.md`'s *Pin the target* / *Review by execution* / *Compose
  and post* / *Verify the post took* steps were rewritten around it — an untrusted PR now
  gets no local execution, only a required-check witness. `agents/architect.md` and its two
  siblings' `git worktree add` exemption updated; `reference/workflow.md`,
  `docs/decisions.md` (new `WB-D13`), `CLAUDE.md`, `README.md` updated to match.
- Filed [#158](https://github.com/glunk-works/claude-workbench/issues/158) (the container
  option, B) into Sprint 5's build order — WB-D13's "filed and scheduled" claim now points
  at a real issue.
- `/way-of-working:critic-gate` — `architect` + `security-critic` + `docs-consistency`, 3
  rounds, **cap reached** (2 fix-and-re-run rounds after the initial pass), not cleanly
  converged: round 3 found one more real bug, since fixed — `run`'s `timeout` did not
  actually bound wall-clock time when the wrapped command backgrounded a detached child (it
  inherited the output pipe, so `head -c` never saw EOF and `run` blocked for the child's
  whole life, defeating the sandbox's own time bound and making the leftover-process fixture
  pass "ok" for the wrong reason). Also fixed: two of this session's own "fixes" were
  themselves vacuous tests (confirmed by mutation), and several header/SKILL.md/decisions.md
  claims overclaimed what the isolation actually closes (now corrected, including that
  `GH_TOKEN` is readable from an ancestor process's `/proc/<pid>/environ` — a property of
  `env -i`, not closeable without the container). No `models.second_opinion` round attempted
  (not set in `.ai/project.yml`). Full residual list in `bin/review-sandbox.sh`'s own header
  and `docs/decisions.md`'s `WB-D13`.
- **Working tree is dirty with the full #113 implementation — nothing committed yet.**

**Next:** task #113 — on **sonnet** (`coder`), fresh session: run **one more**
`/way-of-working:critic-gate` round (architect + security-critic + docs-consistency) to
verify round 3's fixes actually hold and nothing regressed — human asked for this in a
lower-context session rather than continuing in the session that just hit the cap. If it
converges (tightenings only), commit and `/way-of-working:ship`. If it finds something real,
fix it first. **Do not discard the working tree.**

**HITL Gate: OPEN** — one more critic-gate round requested before shipping #113, not yet run
in this cursor's session.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[issue #113](https://github.com/glunk-works/claude-workbench/issues/113) ·
[issue #158](https://github.com/glunk-works/claude-workbench/issues/158)
