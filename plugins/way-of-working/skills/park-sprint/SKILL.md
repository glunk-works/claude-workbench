---
name: park-sprint
description: >-
  Set the live sprint aside: snapshot its cursor as tracked files under .ai/parked/, seed
  the live cursor for the next sprint or swap in a parked one, and open one docs-only
  cursor-sync PR. Mechanical — any model. Never merges.
---

# /way-of-working:park-sprint <next-sprint-id> — set one sprint aside, start another

One live cursor is the design. A parked sprint is a tracked snapshot beside it:
`.ai/parked/<id>-state.json` and `.ai/parked/<id>-next-steps.md`. `.ai/parked/` is
**tracked**, unlike git-ignored `.ai/archive/`, because a parked cursor is the only copy of
in-flight state. `/way-of-working:unpark-sprint` brings it back.

**Read `.ai/project.yml` first** for `{pr_base}`, `{sprints_dir}`, `{roadmap}`, `{models}`,
`{code_paths}`, `{ruleset.required_checks}`, `{review.ci_gate}`.

## Preconditions — fail closed, stop at the first that fails

1. `.ai/state.json` exists and parses. `<id>` is its `current_sprint_id`; null means
   nothing to park — say so and stop. `<next-sprint-id>` must differ from `<id>`.
2. The tree is clean: `git status --short` prints nothing. Dirty state is this session's
   work — surface it; never fold it in, never `git stash` it.
3. The snapshots would be tracked: `git check-ignore .ai/parked/<id>-state.json
   .ai/parked/<id>-next-steps.md` must exit **1** and print nothing. Exit 0 prints the
   path a consumer ignore rule swallows, so the PR would carry nothing — stop and name it.
4. No `.ai/parked/<id>-*` exists — a second park would overwrite the first.

## Steps

1. **Snapshot, on the branch you stand on.** `mkdir -p .ai/parked`. Copy `.ai/state.json`
   to `.ai/parked/<id>-state.json`, adding `parked_at` (ISO date) and `parked_reason` (one
   line — ask the human; never invent it). Copy `.ai/next-steps.md` to
   `.ai/parked/<id>-next-steps.md` **unchanged**.
2. **Stand on a current `{pr_base}`**: `git fetch origin {pr_base} && git checkout
   {pr_base} && git pull`. If a link refuses — a fetch failure, or `{pr_base}` already
   carrying `.ai/parked/<id>-*` from a park elsewhere — stop and say which. Then add `parked_from_commit`
   (`git rev-parse --short HEAD`) to the snapshot. Recorded here, on `{pr_base}`, it is
   normally an ancestor of later HEADs, which the range unpark shows the human relies on.
3. **Seed the live cursor.** If both `.ai/parked/<next-sprint-id>-*` files exist, this is
   a **swap**: seed nothing, run `/way-of-working:unpark-sprint <next-sprint-id>` now, and
   let it open the one PR for both. Otherwise follow `/way-of-working:handoff` steps 2 to
   4 by reference — same fields, wholesale rewrite, `hitl_gate` always written.
   `sprint_status` is `planning` unless `{sprints_dir}/<next-sprint-id>*/sprint_plan.md`
   exists, then `implementing`. In the ledger, **Just done** is one line, `parked <id>:
   <parked_reason>`. The directory is the authority for what is parked and the session
   banner derives its `Parked:` line from it; never copy the list into the ledger.
4. **Commit as one docs-only cursor-sync PR** per `/way-of-working:handoff` step 5, with
   three files staged: both snapshots and `.ai/next-steps.md`. That delta is what
   `cursor-drift.sh` classifies as `cursor-sync`, so handoff's "one file" rule reads here
   as "these three and nothing else". In a swap this step does not run — unpark step 4
   opened the PR. **Never merge.** Report the PR URL and stop.

## Guardrails

- Mechanical: no design decision is made here, so any model may run it.
- Never write secrets into a snapshot — it is tracked.
