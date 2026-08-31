# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
Status: **awaiting_review** — #53 is on a green PR awaiting the human's merge; #57 is
implemented on a pushed branch but its critic pass has **not** converged.

**Just done (2026-08-31):**
- **#53 → [PR #58](https://github.com/glunk-works/claude-workbench/pull/58)** (`dc5513c` is
  #57's tip; #58's tip is on `fix/53-coupling-check-denylist`). `coupling-check.sh`'s loop
  inverted from an allowlist to a denylist. Three critic rounds found **six further
  fail-open paths**, all closed: plugin-root files unscanned, a repo-wide zero-scanned
  counter that let a whole plugin pass green, `$(basename)` stripping a trailing newline
  past the exclusion, `grep` exit 2 read as "no match", exclusions matching by name and not
  type, and `dotglob` pinned by no assertion. New `tests/coupling-check.test.sh` — 13
  assertions, wired into both workflows, **mutation-checked 8/8**. All four required checks
  green on the PR, and every fixture (including the platform-dependent newline one) runs
  rather than self-skips on the Linux runner.
- **#57 on pushed branch `feat/prose-economy`** (`dc5513c`), **no PR yet**. The
  prose-economy patch from the `603-Identity` side, applied and then hardened across
  **four critic rounds**.

**Critic pass — the outcome, not just its existence:**
- **#53: 3 rounds, CONVERGED** on code (round 3 confirmed clean and independently
  reproduced the 8/8 mutation result); its remaining findings were prose and were fixed.
- **#57: 4 rounds, NOT CONVERGED — the cap fired and then some.** Every round found real
  defects, and *twice the fix was worse than the bug*: round 2's "commit the compaction
  itself" was destroyed silently by `git branch -D` on a squash-merged branch; round 3's
  "ship it as a PR" aborted on `git checkout` and then cut the branch off the wrong base.
  Both fixed, plus a genuine pre-existing bug — the branch-prune guard in `resume` and
  `archive-sprint` argued safety per *branch* while the risk is per *commit*.
  **Round 4's own fixes have not been critiqued.**
- Note: the critics were spawned directly, not via `/way-of-working:critic-gate`. The
  skill's propose-and-confirm step was never exercised.

**Next:** Run a **fresh `/way-of-working:critic-gate` on `feat/prose-economy`** — check out
the branch, diff against `origin/main`, and put the round-4 commit (`dc5513c`) under the
gate; the human confirms which critics run. Model: **opus** (architect/review work).
Carry in one standing question: the prose-economy *rules* converged early, but the git
choreography of `archive-sprint`'s compaction step has minted defects four rounds running —
worth deciding whether that step should split into its own PR rather than shipping here.

**HITL Gate:** NONE OPEN for that critic gate. Two decisions sit with the human and neither
blocks it: merge PR #58 (green, ready), and the split question above.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (roadmap + decision log; no sprint
plan — `sprints_dir` is empty by design). Branches: `fix/53-coupling-check-denylist` (PR
#58), `feat/prose-economy` (no PR).
