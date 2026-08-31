# Cursor — claude-workbench

**Now:** No sprint in flight (issue-driven, single-task PRs). Status: **implementing** —
[#57](https://github.com/glunk-works/claude-workbench/issues/57) is **closed**; all three
parts shipped. Next up is its one deliberate carve-out.

**Just done (2026-08-31):**
- **[#67](https://github.com/glunk-works/claude-workbench/pull/67) merged** (`e0cb6bf`) —
  **#57 part B, the writer**: `archive-sprint`'s compaction step 2 (steps renumbered 3–7),
  `ship`'s ledger-conflict rule, `retro`'s archived-item path, plus the `workflow.md` /
  `CHANGELOG.md` / `decisions.md` consequences.
- **The `{roadmap}` archive destination changed mid-build, and this is the part worth
  remembering.** Part B was drafted with a per-sprint `execution_record.md`; both critics
  independently found it contradicted "an archive sits *beside* the live record" — and worse,
  that a repo with **no sprint cadence could never compact its roadmap**. It now applies the
  *same* `_archive` derivation A defined for a file-kind backlog. `project-schema.md` states
  that rule once, for both. No schema key, no migration.
- **`ship`'s per-entry matcher was deliberately cut** — the one place B's scope was reduced
  rather than met. See **Next**.
- **#57 closed** with the three-part record and both deviations written up.

**Critic gate (part B): 3 rounds, `architect` + `docs-consistency`, cap reached, NOT
converged — the human called it.** Findings **22 → 14 → 8**, falling in count *and*
severity, every round-3 finding in one line of one file. **Rounds 1 and 2 each minted a
defect in their own fix**: round 1's merge-base test was false under squash-merge (`WB-D7`'s
premise in a different command, reproduced), and round 2's replacement escalated *every*
ordinary conflict to a human. The critics **split** on the final verdict; the deciding
evidence was reproduced directly — a wrapped citation beginning with an id falsely anchors,
which in an archive drops a live item.

**Next:** Build **[#66](https://github.com/glunk-works/claude-workbench/issues/66)** on a
branch cut fresh from `main` — the tested anchor-matcher `ship` needs, as a
`plugins/way-of-working/bin/` script plus a `tests/` fixture suite, per `WB-D10` and the
`cursor-drift.sh` precedent. Match the id as a **literal**, tolerate **arbitrary** leading
markup (enumerating markers is what failed three times), and decide explicitly what a wrapped
continuation line does. Then rewrite `ship` step 1 to resolve per entry and shrink the prose
to a pointer. Then green gate → `/way-of-working:critic-gate` → `/way-of-working:ship`.
Model: **opus** — it carries a matching-design decision, not just a script.

**HITL Gate: NONE OPEN.** #66 is fully specified by its issue body; the next gate is the
human's merge of its PR. Two non-blocking decisions sit with the human:
[#61](https://github.com/glunk-works/claude-workbench/issues/61) (now with fresh evidence —
renumbering `archive-sprint` invalidated two external step citations, both caught only by a
mechanical sweep) and [#62](https://github.com/glunk-works/claude-workbench/issues/62). To
know, not decide: B's correction-annotation exception stays **self-certified** — fenced by
prose and a mandatory enumeration in the commit/PR body, but not mechanically checked.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (roadmap + decision log; no sprint
plan — `sprints_dir` empty by design) ·
[#66](https://github.com/glunk-works/claude-workbench/issues/66) (next) ·
[#57](https://github.com/glunk-works/claude-workbench/issues/57) (closed, full record in its
closing comment)
