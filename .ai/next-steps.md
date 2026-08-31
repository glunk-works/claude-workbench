# Cursor — claude-workbench

**Now:** No sprint in flight (issue-driven, single-task PRs). Status: **implementing** —
[#57](https://github.com/glunk-works/claude-workbench/issues/57) ships as three PRs; **C and
A have merged**, B is next.

**Just done (2026-08-31):**
- **[#64](https://github.com/glunk-works/claude-workbench/pull/64) merged** (`f22de76`) —
  **#57 part A**: `conventions.md`'s new **Prose economy** section, plus the matching rules
  in `handoff` (no regenerable aggregates), `critic-gate` (verify before acting; prefer
  deletion over correction) and `workflow.md`.
- **The A/B boundary moved mid-review — the part worth remembering.** A was specified as
  *rules only*; both critics found that a convention whose readers cannot honour it is not
  actionable. The human redrew it to **A = rules + readers, B = the writer**, so A also
  shipped `project-schema.md`'s `_archive` derivation and all **three** readers — `retro`,
  `docs-consistency`, and `archive-sprint`'s two evidence preconditions (the third was
  found only in round 2).
- **Critic gate: 3 rounds, cap reached, NOT converged — the human called it.** Findings ran
  18 → 19 → 22, rising because *scope* did (5 → 8 → 10 files); round 3's severe findings sat
  in what rounds 1–2 had added. Narrowing was the response — `ship/SKILL.md` was pulled into
  A in round 2 and deliberately reverted back out to B. Two of the sharpest findings were
  defects the fix rounds themselves minted.
- **⚠️ Part A's round-3 fixes were verified mechanically but never graded by a critic** —
  the gate stopped at its cap before them, and they are on `main` now.

**Next:** Build **#57 part B — the writer**, on a branch cut fresh from `main`:
`archive-sprint`'s **compaction step** (move-don't-rewrite, verified before commit) and
`ship`'s **ledger-conflict exception** (prove a removal per item from the `_archive` sibling
on the *incoming* revision; "not in the archive" is **not** proof of "your side's addition"
— a deliberate deletion lands there too, so that branch asks the human). Fold in two
consequences: `archive-sprint`'s "archival only moves the `.ai/` cursor snapshot" goes false
when compaction lands, and `retro`'s "confirmed again" path must say whether an archived item
is annotated in place or reopened. **Do not reuse `feat/prose-economy`** — stale, still
carries the prune loop #60 replaced. Then green gate → `/way-of-working:critic-gate` →
`/way-of-working:ship`. Model: **opus** — B writes a destructive move.

**HITL Gate: NONE OPEN.** B's scope is specified and the A/B line is settled; the next gate
is the human's merge of B's PR. Two non-blocking decisions sit with the human:
[#61](https://github.com/glunk-works/claude-workbench/issues/61)'s scope and
[#62](https://github.com/glunk-works/claude-workbench/issues/62).

**Pointers:** [docs/decisions.md](../docs/decisions.md) (roadmap + decision log; no sprint
plan — `sprints_dir` empty by design) ·
[#57](https://github.com/glunk-works/claude-workbench/issues/57) · branch
`feat/prose-economy` — no PR, stale: **source material for B, never a base**.
