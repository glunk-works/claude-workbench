---
name: critic-gate
description: >-
  Run the QA-critic pass on a coding diff — after the local green gate, before /handoff.
  PROPOSES which read-only critic subagents apply by what the diff touches, and waits for
  the human to confirm or trim before spawning any — it never auto-fans-out. Aggregates
  findings for the coder to fix, iterates to clean. Defense-in-depth that runs EARLIER — it
  is explicitly NOT the repo's review CI gate and never satisfies it.
---

# /critic-gate — the QA-critic pass (coder-side, before the review)

Goal: catch the cheap, mechanical, boundary-shaped defects on the implementation side, so
the expensive fresh-session review spends its attention on judgment — and so nothing ships
green with no critic having looked. This runs in the **implementation session** after the
green gate and before `/handoff`.

**Read `.ai/project.yml` first** for `{gates.green}`, `{code_paths}`, `{agents.enabled}`,
`{load_bearing_docs}`, and `{review.ci_gate}`.

> **This pass is defense-in-depth that runs EARLIER.** Where `{review.ci_gate}` is set, it
> is **not** that gate and must never be presented as satisfying it — that gate wants a
> *fresh-session*, human-triggered review with an attestation, and it still happens after
> `/handoff`, unchanged.
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
   `{load_bearing_docs}`, tests, other docs.

2. **Propose the applicable critics — spawn NOTHING yet.** This gate does not auto-fan-out.
   Work out which critics *apply* and **present that list to the human with a one-line
   reason each**, then wait. Each critic is real spend, so the human confirms or trims the
   list before any spawn.

   Propose only from `{agents.enabled}` — never offer an agent this repo has not enabled:

   | Diff touches… | propose |
   |---|---|
   | anything in `{code_paths}` | **`security-critic`** (taint / trust-boundary) and/or **`architect`** (correctness pre-review) |
   | anything in `{load_bearing_docs}` | **`docs-consistency`** (prose-vs-code drift) |

   A repo may also enable agents defined locally in its own `.claude/agents/` — a
   guard-surface auditor, a test-validity triager, a live-verification runner. Those are
   repo-local by definition: if one is in `{agents.enabled}` and its angle fits the diff,
   propose it the same way, reading its own definition for when it applies.

   If the caller named critics explicitly (`/critic-gate security-critic architect`), skip
   the proposal and run exactly those. If the diff touches nothing a critic covers, say so
   and stop — don't manufacture a reason to spawn one. Note the `architect`/`security-critic`
   overlap so the human can pick one rather than both when a light look is enough.

3. **On confirmation, spawn only the approved critics.** Each as a **separate read-only
   subagent** via the Agent tool (fresh context — never `/model`-switch and self-review).
   Give each the commit range or PR and its angle; run independent spawns in parallel.

4. **Aggregate the findings.** Collect each critic's ranked findings into one list, deduped,
   most-severe/most-reachable first. Tag each with its source critic and confidence. Drop
   nothing silently; a low-confidence finding is reported as low-confidence.

5. **Fix and re-gate (find/fix separation).** The critics are read-only — **the coder
   applies the fixes** (directly or via the `coder` subagent), then re-runs `{gates.green}`.
   If a fix touched a critic's area, re-spawn that critic (again on confirmation) on the new
   diff. Iterate until the critics are clean or the only remainders are consciously-accepted,
   documented judgment calls.

6. **Report and stop.** Summarize: which critics ran, what they found, what was fixed, what
   was accepted-with-reason.
   - If `{review.ci_gate}` is set, the next step is `/handoff` → fresh session → `/resume` →
     review the diff → post it. `/critic-gate` never posts that review.
   - If `{review.ci_gate}` is `null`, say explicitly that this pass is the only critic look
     the diff has had and that the human's merge is the sole remaining gate.

   Either way: never `--approve`, never merge.

## Why propose instead of auto-spawning
Every critic is real cost and noise, and `architect`/`security-critic` overlap. Auto-fanning
out two or three of them on every sprint spends and distracts without the human choosing to.
Proposing keeps the routing's smarts — *which* critics a diff warrants — while leaving the
spawn decision (and the spend) with the human. A light change may only want one critic; a
trust-boundary change may want the full set. The gate advises; the human picks.
