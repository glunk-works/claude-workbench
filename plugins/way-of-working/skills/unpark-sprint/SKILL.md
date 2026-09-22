---
name: unpark-sprint
description: >-
  Restore a parked sprint from .ai/parked/ to the live cursor behind a hitl_gate that
  forces re-verification against what merged since, as one docs-only cursor-sync PR.
  Mechanical — any model may run it. Never merges.
---

# /way-of-working:unpark-sprint <id> — bring a parked sprint back

The inverse of `/way-of-working:park-sprint`. **An unpark never leaves a cursor that can
auto-start**: the restored `next_action` was written against an older HEAD, so a human
re-verifies it before `/way-of-working:resume` may run it unattended.

**Read `.ai/project.yml` first** for `{pr_base}`, `{code_paths}`,
`{ruleset.required_checks}`, `{review.ci_gate}`.

## Preconditions — fail closed, stop at the first that fails

1. `.ai/parked/<id>-state.json` and `.ai/parked/<id>-next-steps.md` both exist.
2. The live cursor is free: `.ai/state.json`'s `sprint_status` is `done`, **or** its own
   `current_sprint_id` has a snapshot under `.ai/parked/` — the swap case, where
   `/way-of-working:park-sprint` just wrote it and the live copy is a duplicate. Any
   other cursor is in flight — stop and say so.
3. The tree is clean, except a swap's new snapshots — step 1 overwrites the ledger, losing
   any uncommitted edit.

## Steps

1. **Restore.** Move `.ai/parked/<id>-state.json` over `.ai/state.json` and
   `.ai/parked/<id>-next-steps.md` over `.ai/next-steps.md`, deleting the parked copies —
   one copy of a cursor, ever. Read `parked_at` and `parked_from_commit` off the snapshot,
   then drop the three `parked_*` fields from the live cursor.
2. **Re-point and gate.** Set `last_commit` to `git rev-parse --short HEAD`. Write
   `hitl_gate` as: `parked <parked_at> at <parked_from_commit>; re-verify next_action
   against what merged since: git log <parked_from_commit>..HEAD --oneline`. That range
   means what it looks like only while `git merge-base --is-ancestor <parked_from_commit>
   HEAD` holds — park records the commit on `{pr_base}`, so it normally does. If it does
   not, or the commit is unreadable, write `git log --since=<parked_at> --oneline` into
   the gate instead and say why. Only the human closes this gate.
3. **Update the ledger.** Replace the **HITL Gate** line with the gate text and add one
   **Just done** line, `unparked <id> at <HEAD>` — in a swap, also `parked <other-id>:
   <parked_reason>`. Never copy the parked list in; the directory is the authority. Leave
   the rest as parked.
4. **Commit as one docs-only cursor-sync PR** per `/way-of-working:handoff` step 5. The
   delta — deletions under `.ai/parked/`, a swap's new snapshots, `.ai/next-steps.md` —
   is what `cursor-drift.sh` classifies as `cursor-sync`. Nothing else goes in. **Never
   merge.** Report the PR URL and stop.

## Guardrails

- Mechanical: the re-verification is the human's, through the gate.
- Never unpark over an in-flight cursor; never leave `hitl_gate` reading `NONE OPEN`.
