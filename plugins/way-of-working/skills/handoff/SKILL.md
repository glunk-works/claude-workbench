---
name: handoff
description: >-
  Serialize the current dev-session state into .ai/ before switching model or session —
  check the /way-of-working:critic-gate pass ran on any code diff, update .ai/state.json (including
  hitl_gate, always), regenerate .ai/next-steps.md, and commit/push it as its own docs-only
  PR (never merged — the human merges). Run this at the END of a session. Does NOT archive a
  sprint.
---

# /way-of-working:handoff — externalize state before switching model/session

Goal: leave a clean, self-contained cursor so the next (fresh, lean) session can
`/way-of-working:resume` without inheriting this session's bloated context. This is the token-saving
handoff point. It does **not** archive — that is `/way-of-working:archive-sprint`, only on completion.

**Read `.ai/project.yml` first** for `{pr_base}`, `{roadmap}`, `{code_paths}`, `{models}`,
`{ruleset.required_checks}`, and `{review.ci_gate}`.

## Steps

1. **Check the QA-critic pass ran** (skip if this session wrote no code — a planning
   session has no diff to critique). Run `git diff {pr_base}...HEAD --stat`. If it touches
   `{code_paths}` and **no `/way-of-working:critic-gate` pass ran on that diff in this session**, say so
   plainly and offer to run it before handing off. The critic pass belongs to the
   implementation session — once you `/way-of-working:handoff`, the diff moves on with no critic having
   looked, which is the failure mode that justifies a standing critic pass at all.

   If a pass **did** run, carry its outcome into the report (step 6), not just its
   existence: the round count and which stopping condition fired — converged, cap reached,
   or the human called it. *"A critic pass ran"* and *"the critic pass converged"* are
   different claims, and a cursor that records only the first leaves the next session unable
   to tell them apart.

   This is a **prompt, not a block**: the human may decline and hand off anyway (say
   "handing off without a critic pass" in the report so the choice is on the record). It
   exists because nothing else in the pipeline points at `/way-of-working:critic-gate` — the skill said
   "before `/way-of-working:handoff`" while `/way-of-working:handoff` never mentioned it, so the human was the only
   trigger. The gate still **proposes and the human still picks** which critics run; this
   step only stops the pass from being forgotten.

2. **Determine the new cursor** from what this session did:
   - `current_phase`, `current_sprint_id`, and `sprint_status` — one of `planning` |
     `implementing` | `awaiting_review` | `blocked` | `done`. Before writing `done` (or any
     "complete"/"landed" claim into `next_action`), apply the **verification-ledger** check
     (`/way-of-working:archive-sprint` precondition 4): if a surface has a **live** side the hermetic suite
     cannot reach, say "hermetically verified; live smoke deferred → <tracked item>," never
     "done/working end-to-end." Claim only what the evidence covers.
   - `assigned_model` / `assigned_persona` for the **next** session, per `{models}` (see
     `reference/workflow.md`).
   - `last_commit` = current `git rev-parse --short HEAD`.
   - `next_action` = the single most important next step, phrased as an imperative.
   - `hitl_gate` — **always write this field**, even when nothing is open (`"NONE OPEN"` +
     what the next gate will be). It is load-bearing: `/way-of-working:resume` reads it to decide whether
     it may start the next action unattended, and treats a missing or unparseable value as
     an open gate. Dropping it doesn't fail loudly — it silently costs the next session its
     auto-start.
   - `pointers` = `{ "roadmap": "{roadmap}", "sprint_plan": "<active sprint_plan.md>" }`.

3. **Write `.ai/state.json`** (this file is git-ignored — it's a local convenience mirror). Keep `schema_version: 1`. Overwrite it wholesale with the new cursor — "wholesale" means every field above, `hitl_gate` included; an overwrite that drops a field is how a cursor loses one.

4. **Regenerate `.ai/next-steps.md`** (git-tracked — this is the durable human ledger). Keep it to ~20–40 lines, in this shape:
   - **Now:** current phase/sprint + status (one line).
   - **Just done:** 2–5 bullets of what this session accomplished (+ commit hashes).
   - **Next:** the imperative next action + which model should do it + any open HITL Gate.
   - **Pointers:** `{roadmap}` + the active sprint_plan path (do not copy their content — link to them).
   Regenerate the whole file (it is a cursor, not an append log — history lives in git + the roadmap).
   State no **regenerable aggregates**: no counts, no check inventories, no lists a
   command can re-emit — name the deriving command or the authority instead
   (`reference/conventions.md` § *Prose economy*). Two things stay: the cursor's own
   fields — status, commit hashes, the assigned model — which are `next-steps.md`'s job
   as the git-tracked ledger behind git-ignored `.ai/state.json`, and the critic pass's
   round count + stopping condition, which no command can re-derive and which the next
   session cannot otherwise learn. The rule bars restating what a command or another file
   already answers.

5. **Commit `.ai/next-steps.md` as its own docs-only PR against `{pr_base}`.** The cursor
   sync travels as a small, standalone, docs-only PR, separate from whatever code PR this
   session's work landed on. Do it now, don't just remind:
   - If the current branch is a code branch (e.g. mid-implementation, or the just-pushed
     feature branch), do **not** commit the cursor sync there — switch to `{pr_base}`, cut
     a fresh small branch (e.g. `docs/sync-cursor-<slug>`), and commit `.ai/next-steps.md`
     there. If a `/way-of-working:handoff` runs directly on `{pr_base}` with nothing else
     in flight, cutting a fresh branch from it is still correct — never commit straight to
     `{pr_base}`.

     ```bash
     git fetch origin {pr_base} && git checkout {pr_base} && git pull \
       && git checkout -b docs/sync-cursor-<slug>
     ```

     **One chain, and it can abort — at either of two links.** Step 4 has just rewritten
     tracked `.ai/next-steps.md`, and which link refuses turns on whether that file's
     *committed* content differs between the branch you are leaving and `{pr_base}` — not
     on whether your local `{pr_base}` is up to date:
     - **It differs** → `git checkout {pr_base}` refuses outright (*"Please commit your
       changes or stash them before you switch branches"*), because the switch would have
       to overwrite your edit.
     - **It does not differ** — the ordinary case, a code branch that never committed a
       cursor change of its own → the checkout **succeeds** and carries the modified file
       across. `git pull` then aborts instead (*"Your local changes … would be overwritten
       by merge"*) whenever the fetch brings a change to that file, which is exactly when
       `{pr_base}` has had a cursor sync since this branch was cut. Do not go looking only
       for the checkout error; this is the link you will hit most.

     Either way, **stop and say so**: name the blocking file and hand it to the human. Do
     not commit on the current branch to get past it — that is how a cursor sync ends up
     on a code branch, which is the thing this step exists to prevent — and do not `git
     stash` on the human's behalf.

     Without the `&&` chain, **both** failures produce a wrong branch instead of an error,
     and neither announces itself: after an aborted `checkout` the `checkout -b` cuts the
     cursor branch off the **code branch**, and after an aborted `pull` it cuts off
     `{pr_base}` at the commit your local copy is still on — **stale**, because the merge
     that would have advanced it is the step that just failed. Same wrong-base defect, one
     layer quieter.

     **If the chain stops at `git pull`, you are now standing on `{pr_base}` with the
     modified cursor in the tree.** That is not a state to commit out of either — `{pr_base}`
     is protected and this step never commits to it. Report it as the blocking state,
     naming the branch you ended up on, and let the human resolve it.
   - **This holds even when the cursor describes work that currently lives only on an
     unmerged code branch** — a second session handing off before the first session's PR has
     merged (a "stacked" handoff). There is **no exception** for that case, because
     `.ai/next-steps.md` is *regenerated wholesale* (step 4), not patched: the sync carries
     no code context, so a fresh `{pr_base}`-cut branch always applies cleanly even though
     `{pr_base}` lacks the code being described. A cursor that names an open PR is doing its
     job — it points forward and does not wait for that PR to merge; the docs sync merging
     before the code PR is fine and expected. Committing the sync onto the code branch
     instead only bundles cursor churn into the code PR's review, which is the muddle this
     whole step exists to prevent.
   - `git add .ai/next-steps.md` (only that file — this step never bundles unrelated
     dirty state; if other files are also dirty, surface that separately and let the
     human decide).
   - Commit, push, and open the PR with `gh pr create --base {pr_base}`. Length-check the
     title first (`printf '%s' "$TITLE" | wc -c`, ≤72) and expect every check in
     `{ruleset.required_checks}` to run. If `{review.ci_gate}` is set, a docs-only PR
     touching none of `{code_paths}` is exempt from it; if `{review.ci_gate}` is `null`,
     there is no review gate to be exempt from — say nothing about one. This push has no
     reach preflight of its own and carries the same push-identity exposure as
     `/way-of-working:ship` step 1 — a 403 here is diagnosed the same way
     (`reference/conventions.md` § *Push identity*).
   - **Never merge it.** The human's merge is the approval. Report the PR URL and stop.
   - `.ai/state.json` is git-ignored and needs no commit; it already travels with the
     working tree for this machine.
   - If something *else* is dirty beyond `.ai/next-steps.md` (leftover from this
     session's work), don't fold it into the docs PR — surface it and let the human
     decide; a `/way-of-working:resume` still expects `last_commit` to match HEAD and a clean tree, and
     unrelated dirty state costs the next session its auto-start.
   - **Keep this PR touching `.ai/next-steps.md` and nothing else — that is load-bearing.**
     `last_commit` is set (step 4) *before* this commit exists, so once the human merges,
     HEAD has moved past the cursor. `/way-of-working:resume` step 2's classifier forgives
     exactly that, and only that: a `cursor-sync` result, which means the path list is
     **only** `.ai/next-steps.md`. Fold anything else into this PR and the next session loses its
     auto-start and waits for a human "go" instead. This is also why the fix lives on the
     read side: `last_commit` means *the commit whose work this cursor describes*, and a
     squash merge mints a different SHA than the local branch tip anyway, so no value
     written here could match what `/way-of-working:resume` later reads.

6. **Report** the new `sprint_status`, the `next_action`, and the recommended next model in 2–3 lines. If the critic pass was skipped by choice (step 1), say so here. Then **end with the exact next-session command block** — the human runs the mechanical switch (`/clear` / `/model` / `/way-of-working:resume` are harness commands a skill **cannot** execute), so hand them the literal keystrokes, not a description:

   ```
   Next session:
     <new window>            # required if this crosses the review gate; otherwise /clear is fine
     /model <model>          # per assigned_model
     /way-of-working:resume
   ```

   **A review boundary needs a genuinely new session, not `/clear`.** If `{review.ci_gate}`
   is set and the `next_action` is posting that review (any coding→review handoff), say
   **new window/session** explicitly: `/clear` resets context but does not make the reviewer
   a *separate invocation*, and the fresh-session review is an **integrity property**, not
   just context hygiene. For a same-person non-review switch (e.g. planning→coding),
   `/clear` → `/model` → `/way-of-working:resume` **in place** is acceptable for context — a new session is
   what the docs specify, but the integrity concern doesn't apply. Fill in the actual model
   from `assigned_model` so it's paste-ready.

## Guardrails
- Never write secrets into `.ai/next-steps.md` or `.ai/state.json`.
- `.ai/next-steps.md` points into `{roadmap}` and the sprint files; it must not become a second copy of them.
- `/way-of-working:handoff` writes the `next_action` that `/way-of-working:resume` may execute **without a further prompt** (see `/way-of-working:resume` step 6). Phrase it as a precise, bounded imperative that you would be content to see carried out unattended — not a vague direction that needs a human to interpret it. If the next step genuinely needs a decision, that is what `hitl_gate` is for: open one.
