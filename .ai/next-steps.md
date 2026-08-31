# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Status: **implementing** — [#57](https://github.com/glunk-works/claude-workbench/issues/57)
is shipping as three PRs; the first has merged and the second is next.

**Just done (2026-08-31):**
- **[#60](https://github.com/glunk-works/claude-workbench/pull/60) merged** (`dade8a4`) —
  two pre-existing data-loss paths, **carved out of #57** so they would not keep waiting on
  a branch that had not converged in four rounds. The branch prune in `resume` /
  `archive-sprint` deleted branches whose local tip had moved past the merged commit, and
  `handoff` step 5's unchained `checkout -b` cut the cursor branch off the wrong base. The
  prune is now gated on **`headRefOid`** — the commit GitHub actually merged, which survives
  the head branch being deleted — never on `origin/<branch>`.
- **Critic gate on #60: 3 rounds, the CAP FIRED — not converged.** Round 3 was still
  returning genuine defects; its two findings were fixed with no re-run and the decision
  handed to the human, who merged. **Three of the defects found were in fixes the gate
  itself wrote**, including a critic's unverified universal that reached two shipped skills
  before anyone checked it. Behavior converged at round 2 and never regressed — everything
  after that was prose *about* the behavior.
- **#57 split three ways** (human decision): **C** = the two bug fixes (**merged, #60**),
  **A** = the prose-economy rules, **B** = `archive-sprint`'s compaction step.
- **Filed [#61](https://github.com/glunk-works/claude-workbench/issues/61)** — reference
  skill steps by name, not number (34 numeric refs across 8 files; the dangerous ones point
  *into* a numbering from files the renumberer never opens) — and
  **[#62](https://github.com/glunk-works/claude-workbench/issues/62)**, mechanize the
  prune-block byte-identity invariant that `docs/decisions.md:276` only asserts in prose.
- **`/way-of-working:retro` ran** — two findings to memory (heredocs eating backslashes into
  a shipped commit; verifying a critic's *quantifier*, not just its mechanism), one
  confirmed-again note to #57.
- **Push identity fixed at the machine level** (`gh auth setup-git`). `git push` now follows
  `gh`'s **active** account; the old per-push `-c credential.helper=…` workaround is
  redundant. Consequence: `603-Identity` work now needs `gh auth switch` for `git` too.

**Next:** Rebuild **#57 part A — the prose-economy *rules* only** — on a branch cut fresh
from `main`. **Do not rebase or reuse `feat/prose-economy`**: it is stale in four files and
still carries the superseded prune loop #60 replaced. Take `conventions.md`'s *Prose
economy* section, `handoff` step 4's no-regenerable-aggregates rule, and the `retro` /
`critic-gate` / `workflow.md` / `docs-consistency.md` touches. Leave for **B**:
`archive-sprint`'s compaction step, `project-schema.md`'s `_archive` derivation, and `ship`'s
ledger-conflict exception. Two bullets — *Corrections replace text* and *The deep record is
not append-only* — name the compaction step, which will not exist until B lands: state them
as conventions **without asserting the mechanism exists**, and let B add the pointer. Then
green gate → `/way-of-working:critic-gate` → `/way-of-working:ship`. Model: **opus** — the
A/B boundary is a judgment call and the critic gate follows immediately.

**HITL Gate: NONE OPEN.** The next gate is the human's merge of A's PR. Two decisions sit
with the human, neither blocking: #61's scope (ban same-file `step N` self-references too?)
and #62's sequencing (it will fail on `feat/prose-economy` until B is rebuilt).

**Pointers:** [docs/decisions.md](../docs/decisions.md) (roadmap + decision log; no sprint
plan — `sprints_dir` is empty by design) ·
[#57](https://github.com/glunk-works/claude-workbench/issues/57) ·
[#61](https://github.com/glunk-works/claude-workbench/issues/61) ·
[#62](https://github.com/glunk-works/claude-workbench/issues/62) · branch
`feat/prose-economy` — no PR, stale: **source material for A and B, never a base**.
