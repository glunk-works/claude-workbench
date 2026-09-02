# Cursor — claude-workbench

**Now:** No sprint in flight (issue-driven, single-task PRs). Status: **awaiting_review** —
[#69](https://github.com/glunk-works/claude-workbench/pull/69) is finished and green at
`f3302f9`, waiting only on the human's merge.

**Just done (2026-09-02):**
- **The owed mutation sweep ran to completion** (`bbcaf82`) — the first time it has. Earlier
  attempts stranded on a non-terminating mutant against a suite with no timeout; orphaned
  processes from those sessions were still running when this one started. The sweep now
  bounds every run and counts a hang as detected. Numbers and procedure live in `WB-D11`
  and the suite header, re-derived against the shipping tree, never carried forward.
- **Four live guards were found filed as covered, and fixtured** (`bbd8a78`, `f3302f9`) —
  `col = 0` (an awk global reset, not an initialiser), the `~~~` fence-opener alternative,
  and the "nothing else on the line" tail on both halves of the front-matter delimiter.
  Two of the four fail toward a false match, the direction `entry-anchor.sh` calls
  unrecoverable.
- **The sweep's quantifier is now bounded, not universal.** Round 9's own fix had widened
  "the two compound guards" into "every compound condition", and three of the four guards
  above were hiding behind that word. The note now names the measured site list and says
  explicitly that it is not a proof none was missed.
- **[#71](https://github.com/glunk-works/claude-workbench/issues/71) and
  [#72](https://github.com/glunk-works/claude-workbench/issues/72) filed** — the
  fixture-coverage convention, and letting a late critic round switch models.

**Critic gate: 10 rounds, `architect` + `docs-consistency`. Stopping condition: the human
called it** — not convergence. Rounds 1–8 (Opus) converged at round 8; round 9 (Opus) found
one live guard; **round 10 was run on Fable** and both critics independently found three
more plus the false universal. Round 10 applied fixes and those fixes were **not**
re-critiqued, which the gate's own rule says never to do — recorded here rather than
smoothed over. That evidence is what [#72](https://github.com/glunk-works/claude-workbench/issues/72) is about.

**Next:** Wait for the merge decision. Once #69 merges, build **#71** — a `reference/`-only
prose edit, fully specified in its issue body. Do **not** start #72 unattended; it is
`status/needs-human` and asks for a design choice between three shapes.
Model: **opus** — both are judgment about what the shared record may claim.

**HITL Gate: OPEN.** (1) Merge #69? (2) Is closing #66 on it right, given the recorded
scope reduction — per-entry *ranking* shipped where #66 asked for *resolution*, and step-1
prose grew where #66 asked it to shrink? Round 8's critics said close it and file a
follow-up. Check the gate state with `gh pr checks 69` and `gh pr view 69`.
Also open and untouched: #61, #62, #54, #52, #48, #45.

**Pointers:** [docs/decisions.md](../docs/decisions.md) (`WB-D11` is this work's record; no
sprint plan — `sprints_dir` empty by design) ·
[#69](https://github.com/glunk-works/claude-workbench/pull/69) ·
[#66](https://github.com/glunk-works/claude-workbench/issues/66)
