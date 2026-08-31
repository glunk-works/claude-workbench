---
name: critic-gate
description: >-
  Run the QA-critic pass on a coding diff — after the local green gate, before /way-of-working:handoff.
  PROPOSES which read-only critic subagents apply by what the diff touches, and waits for
  the human to confirm or trim before spawning any — it never auto-fans-out. Aggregates
  findings for the coder to fix, then re-runs the critics on the fixed tree and iterates to
  convergence under a bounded stopping rule. Defense-in-depth that runs EARLIER — it is
  explicitly NOT the repo's review CI gate and never satisfies it.
---

# /way-of-working:critic-gate — the QA-critic pass (coder-side, before the review)

Goal: catch the cheap, mechanical, boundary-shaped defects on the implementation side, so
the expensive fresh-session review spends its attention on judgment — and so nothing ships
green with no critic having looked. This runs in the **implementation session** after the
green gate and before `/way-of-working:handoff`.

**Read `.ai/project.yml` first** for `{pr_base}`, `{gates.green}`, `{code_paths}`,
`{agents.enabled}`, `{load_bearing_docs}`, `{review.ci_gate}`, and
`{ruleset.required_checks}`.

> **This pass is defense-in-depth that runs EARLIER.** Where `{review.ci_gate}` is set, it
> is **not** that gate and must never be presented as satisfying it — that gate wants a
> *fresh-session*, human-triggered review with an attestation, and it still happens after
> `/way-of-working:handoff`, unchanged.
>
> Where `{review.ci_gate}` is `null`, this repo has no review CI gate, so **this pass is the
> only standing critic look the diff gets before the human's merge.** That is not a reason
> to skip it or to widen it into an approval — it is a reason to say so plainly in the
> report, so the human knows exactly how much review the diff has had.

## Preconditions
- **The green gate passes.** Run every entry in `{gates.green}` in order, each from its
  `cwd`, and stop at the first non-zero exit. A red gate is fixed first — don't spend
  critics on a diff that doesn't build.
- There is a diff to review: `git diff {pr_base}...HEAD` (branch) or the staged/working tree.

## Steps

1. **Scope the diff.** `git diff --stat {pr_base}...HEAD` (and the full diff for content).
   Note which trees it touches — anything in `{code_paths}`, anything in
   `{load_bearing_docs}`, tests, other docs — and which files are **newly added** versus
   edited (`git diff --diff-filter=A --stat {pr_base}...HEAD`). A brand-new doc cannot
   already be in `{load_bearing_docs}`, so the added/edited split matters for the last row
   of the table below.

2. **Propose the applicable critics — spawn NOTHING yet.** This gate does not auto-fan-out.
   Work out which critics *apply* and **present that list to the human with a one-line
   reason each**, then wait. Each critic is real spend, so the human confirms or trims the
   list before any spawn.

   Propose only from `{agents.enabled}` — never offer an agent this repo has not enabled:

   | Diff touches… | propose |
   |---|---|
   | anything in `{code_paths}` | **`security-critic`** (taint / trust-boundary) and/or **`architect`** (correctness pre-review) |
   | anything in `{load_bearing_docs}` | **`docs-consistency`** (prose-vs-code drift) |
   | a **newly-added** doc that is not under `{code_paths}` and not already in `{load_bearing_docs}` | **`docs-consistency`** (does the new prose match the code/system it describes?), **plus `security-critic`** if it documents a security, credential, or operational procedure — and flag that the file should be added to `{load_bearing_docs}` so its later *edits* are covered by the row above |

   **Why the third row exists.** `{load_bearing_docs}` is a fixed drift-audit set, and a
   brand-new file cannot already be in it — so keying the docs critic *only* off that set
   silently skips a doc on the one commit where it is most worth a look: its first version,
   before any reviewer or drift audit has ever seen it. A new operational or security-relevant
   doc (an upload runbook, a credential-handling procedure) that lands with no critic pass is
   exactly the gap this row closes. It stays a **proposal**, like every other row — the human
   confirms whether the new doc is load-bearing enough to warrant `security-critic`, or trims
   it to `docs-consistency` alone, or skips it for a trivial addition (a changelog stub, a
   README typo). Detection is mechanical (`--diff-filter=A` from step 1), the judgment stays
   with the human, and adding the file to `{load_bearing_docs}` is the durable fix that moves
   it into the second row for next time.

   A repo may also enable agents defined locally in its own `.claude/agents/` — a
   guard-surface auditor, a test-validity triager, a live-verification runner. Those are
   repo-local by definition: if one is in `{agents.enabled}` and its angle fits the diff,
   propose it the same way, reading its own definition for when it applies.

   If the caller named critics explicitly (`/way-of-working:critic-gate security-critic architect`), skip
   the proposal and run exactly those. If the diff touches nothing a critic covers, say so
   and stop — don't manufacture a reason to spawn one. Note the `architect`/`security-critic`
   overlap so the human can pick one rather than both when a light look is enough.

3. **On confirmation, spawn only the approved critics.** Each as a **separate read-only
   subagent** via the Agent tool (fresh context — never `/model`-switch and self-review).
   Give each the commit range or PR and its angle; run independent spawns in parallel.

4. **Aggregate the findings.** Collect each critic's ranked findings into one list, deduped,
   most-severe/most-reachable first. Tag each with its source critic and confidence. Drop
   nothing silently; a low-confidence finding is reported as low-confidence.

   **Verify before acting — trust but verify.** A finding that can be checked by running
   something (a command, a gate entry, a file read) is checked by running it before it is
   acted on; a finding that rests on unexecuted reasoning is tagged as such. This is
   *Convergence*'s retraction rule — verify a critic's claim against the source before
   acting on it — applied to every finding, not only the ones a later round takes back.

5. **Fix and re-gate (find/fix separation).** The critics are read-only — **the coder
   applies the fixes** (directly or via the `coder` subagent), then re-runs `{gates.green}`.

   **For prose findings, prefer deletion and derivation over correction**
   (`reference/conventions.md` § *Prose economy*). When the finding is a stale restatement
   of derivable state — a count, a status, a live setting — the fix is to delete the claim
   or replace it with its deriving command, never to hand-correct the value; a claim now
   corrected for the second time is a claim to remove. And when the same prose defect
   class recurs across rounds, the converging fix is a check that fails the same way the
   finding reads — a `{gates.green}` check, verified by a deliberate regression, and, if
   the class should block a merge rather than only a local run, promoted to CI. **That
   promotion has a required order** (`{ruleset.required_checks}` is mirrored last, because
   it records GitHub's state rather than requesting it); the order and the reason are in
   the same *Prose economy* section — follow it there rather than from memory.

   **Then re-spawn the critics on the FIXED tree. This is not optional.** The old rule here
   was "if a fix touched a critic's area" — too weak, because it let whoever just made the
   fixes decide, after the fact, that none of them warranted a second look, and the fix round
   is itself the highest-risk moment (see *Convergence* below). **Every critic whose findings
   were acted on gets re-run**, along with any whose area the fixes touched. Scope each to
   **what changed since its last report**, not the whole diff again — a re-run costs a
   fraction of the first pass when it is told what to grade.

   Iterate under the stopping rule below — **not** "until the critics are clean," which on a
   dense diff may never happen and is what turns this gate into an unbounded spend.

6. **Report and stop.** Summarize: which critics ran, what they found, what was fixed, what
   was accepted-with-reason. **State the round count and which stopping condition fired**
   (converged / cap reached / human called it) — a reader deciding how much to trust the diff
   needs to know whether the loop ended because it was done or because it ran out of rope.
   - If `{review.ci_gate}` is set, the next step is `/way-of-working:handoff` → fresh session → `/way-of-working:resume` →
     review the diff → post it. `/way-of-working:critic-gate` never posts that review.
   - If `{review.ci_gate}` is `null`, say explicitly that this pass is the only critic look
     the diff has had and that the human's merge is the sole remaining gate.

   Either way: never `--approve`, never merge.

## Convergence — when to stop iterating

**Count is not the signal. Severity and provenance are.** A round that returns twelve wording
tightenings is converged; a round that returns two false statements is not.

**Stop when a full round returns nothing that would change what a reader or operator does.**
Concretely, no finding that is:
- a **false statement** — a claim the source contradicts;
- a **contradiction** with another part of the diff or the repo;
- **operationally wrong** — a command, flag, order of steps, or expected value that would
  mislead someone executing it;
- a **newly-introduced** defect the previous round's fixes created.

Wording, emphasis, phrasing-could-be-tighter, and "consider also mentioning" are **tightenings**.
A round of only tightenings means converged — land it. Chasing prose to a fixed point is not
what this gate is for.

**Never stop on the round that applied fixes.** At minimum one re-run must come back
tightenings-only. Skipping it is the single most expensive shortcut available here, because the
correction sweep is where defects are born, not where they die.

**Hard cap: 2 fix-and-re-run rounds after the initial pass. Then stop and hand the decision to
the human** — with what is still open, what it would cost, and your recommendation. Do not
silently continue; every round is real spend, and the human authorized a *pass*, not a loop.
Going past the cap is a decision they make with the numbers in front of them, and it is often
the right one — the cap exists to make it **their** call, not to end the review.

**Non-convergence is its own finding.** If round N+1's severity is not lower than round N's, the
loop is not converging and another round will not fix it. That is a signal about the **diff** —
too large, too entangled, or built on a wrong assumption — not a reason to spawn again. Say so
and stop.

**Track findings across rounds, not round-by-round.** Carry a list. Watch for two things a
per-round view misses:
- **Regressions** — a finding that was fixed and came back.
- **Retractions** — a critic refuting *its own* earlier finding. This happens, and if the
  earlier finding was already written into the work, the retraction arriving a round late means
  a defect is sitting in the tree with a critic's endorsement on it. **Verify a critic's claim
  against the source before acting on it**, exactly as you would your own.

### Why a stopping rule at all
Without one, "iterate until clean" is unbounded, and the round count gets decided ad hoc,
mid-session, by whoever is tired first. Observed on a single docs-only diff (two critics, four
rounds): roughly **21 → 12 → 13 → 2** findings. **Round 3 returned more than round 2 and was the
more converged of the two** — its findings were overwhelmingly tightenings, while round 2's were
false statements the round-1 fixes had just introduced. A count-based rule misreads that in both
directions: it would have stopped at round 2 and continued past round 3. The severity rule above
reads it correctly.

The cap matters just as much. That session ran **four** rounds; the human had approved **one**,
and the escalation to rounds 3 and 4 was made unilaterally, mid-session, on the reviewer's own
judgment. Round 4 was worth running — it caught an inverted instruction for a destructive command
against a live account — but that is an argument for *asking*, not for proceeding. Under this
rule the cap fires after round 3 and round 4 happens with explicit sign-off, which is the same
review at a fraction of the surprise.

## Why propose instead of auto-spawning
Every critic is real cost and noise, and `architect`/`security-critic` overlap. Auto-fanning
out two or three of them on every sprint spends and distracts without the human choosing to.
Proposing keeps the routing's smarts — *which* critics a diff warrants — while leaving the
spawn decision (and the spend) with the human. A light change may only want one critic; a
trust-boundary change may want the full set. The gate advises; the human picks.

**What the human is approving is a bounded pass, not each individual spawn.** Step 2's
confirmation covers the initial spawns *and* the re-runs the stopping rule allows — up to the
cap. That is deliberate: asking again after every fix round would put the confirmation where
it carries least information (mid-loop, on a diff whose density is now known) rather than
where it carries most. The **cap** is what keeps the spend bounded, and crossing it returns
the decision to the human with the numbers in front of them. So: the human picks the critics
and the ceiling; the gate spends up to it and then stops.
