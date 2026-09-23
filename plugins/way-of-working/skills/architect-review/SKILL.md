---
name: architect-review
description: >-
  Post the fresh-session Architect Review a PR's review CI gate requires, verify the gate
  went green on the head SHA, and file the non-blocking findings. Run in a NEW session that
  did not author the diff. Never approves, never merges.
---

# /way-of-working:architect-review — satisfy the fresh-session review gate (never approve)

Goal: the act `{review.ci_gate}` exists to enforce — a review of a PR's diff by a session
that did not write it, posted so the gate goes green on the head commit. This skill is the
gate's **satisfier**. The `architect` *subagent* is the `/way-of-working:critic-gate` pre-review
and is never this: a subagent spawned mid-work is not a fresh session.

Argument: a PR number in the repo whose checkout you are standing in, at its root, **on
`{pr_base}`** — `git branch --show-current` prints the branch the file below names as
`pr_base`. Not there yet, including on the PR's own branch, whose `.ai/project.yml` is the
author's: `git switch {pr_base} && git pull --ff-only`, then proceed.

**Read `.ai/project.yml` from that checkout, now synced,** for `{review.ci_gate}`,
`{models.architect}`, `{repo}`, `{pr_base}`, `{code_paths}`, `{decisions.prefix}`,
`{threat_model}`, `{ruleset.required_checks}`, and `{backlog}`. Missing or unreadable: stop;
never guess a gate (`reference/project-schema.md`). Every step fails closed. Each code block
is one tool call — shell state does not survive between calls.

## Steps

1. **Is there a gate, and is this the right session?** `{review.ci_gate}` `null`: say the
   repo has no review gate and stop — there is nothing to satisfy;
   `/way-of-working:critic-gate` is the critic look such a repo gets. Otherwise compare the
   model you are running as with `{models.architect}` and say so in one line.

2. **State the integrity precondition once, then honor it.** If this session's context
   contains authoring the diff — you wrote it, then `/clear`ed or `/model`-switched —
   **stop and do not post.** CI cannot observe a session boundary; the attestation you
   paste in step 7 is what makes reviewing your own work a *knowing false statement*
   rather than something that quietly happens.

3. **Pin the target.** `gh pr view <N> --json headRefOid,headRefName,baseRefName,files`;
   `baseRefName` must be `{pr_base}` — a PR based on any other branch is a stop, since
   that base is a branch its author can edit. Check whether the PR touches `{code_paths}` (or
   `{review.ci_gate.triggers_on}` where set). An exempt PR (docs, sprint plan, `.ai/`
   cursor) gets one plain statement and no review posted for the gate's sake.

4. **Check the other required checks first** — invoke `/way-of-working:pr-checks <N>`
   through the Skill tool rather than re-deriving it. Expect the gate itself to read
   `absent` or `failure`: that is what you are about to satisfy. Review only a PR whose other required
   checks are green, unless the human says otherwise: a fix pushed after your review moves
   the head and re-arms the gate.

5. **Load context lean.** The PR body; the sprint-plan task row it links; the
   `{decisions.prefix}` ids and `{threat_model}` boundaries it names; the critic-gate
   outcome recorded on the PR. Not the whole plan, not the whole repo.

6. **Review by execution, in a scratch worktree.** Fetch the head, `git worktree add
   <tmp> <sha>`, and reproduce each claim the PR makes: run the test it says it added,
   the gate it says is green, the command it says now fails. Plant a mutation to witness
   a guard go red, then remove it. This runs the PR's code with your credentials: do it
   where the author is trusted or the worktree is sandboxed, and read no config from the
   worktree. No subagent fan-out by default — the fresh session *is* the architect; spawn
   a critic only for an angle you name, and verify its findings before they enter the
   review. Line-anchored defects may go inline; the scope verdict goes in the body you
   post next. `git worktree remove` when done.

7. **Compose and post.** The body **opens** with `{review.ci_gate.header}` and
   `{review.ci_gate.attestation}`, each on its own line, copied byte for byte from the
   synced `.ai/project.yml` — `yq -er`, or any reader that emits the scalar unchanged and
   fails on a missing one — never typed from memory. A chain that stops before printing the
   path is a stop:

   ```bash
   T=$(mktemp -d) &&
   { yq -er .review.ci_gate.header .ai/project.yml && echo &&
     yq -er .review.ci_gate.attestation .ai/project.yml && echo; } > "$T/review.md" &&
   [ "$(grep -c . "$T/review.md")" -eq 2 ] && echo "$T/review.md"
   ```

   Append to that file, in order: `Reviewed against head <sha>`; the verdict; ranked
   findings, each with its reproduction; what you independently verified. Post with
   `gh pr review <N> --comment --body-file <that path>`. **Never `--approve`, never
   `--request-changes`, never merge**: the merge is the human's approval, and a
   Claude-issued approval would be a gate approving itself.

8. **Verify the post took.** Poll until `{review.ci_gate.check}` reads `success` on the
   head SHA — bounded, about 90 s — through the tested predicate, which reads **both**
   surfaces a gate can post to. The `&&` chain is load-bearing: a failed call must never
   reach it, since a missing document reads as `absent`:

   ```bash
   SHA=$(gh pr view <N> --json headRefOid -q .headRefOid) && T=$(mktemp -d) &&
   gh api --paginate "repos/{repo}/commits/$SHA/status" \
     --jq '.statuses[] | ["status", .context, .state] | @tsv' > "$T/s.tsv" &&
   gh api --paginate "repos/{repo}/commits/$SHA/check-runs" \
     --jq '.check_runs[] | ["check-run", .name, .status, (.conclusion // "")] | @tsv' > "$T/c.tsv" &&
   cat "$T/s.tsv" "$T/c.tsv" > "$T/gate.tsv" &&
   review-gate-state.sh "{review.ci_gate.check}" < "$T/gate.tsv" && echo "$SHA"
   ```

   Anything but `success` on stdout — `pending`, `failure`, `absent`, or nothing at all
   (exit 2) — is not green. On exit 0 say which shape carried the gate (its stderr line).
   Still not `success` at the bound: diagnose **in this order** and say which it was.
   (a) **The head moved** — the printed SHA is not the one you reviewed; the review is
   posted again against the new head. (b) **A string mismatch** —
   `gh api --paginate repos/{repo}/pulls/<N>/reviews --jq '.[].body' | grep -cF` each
   value (`reference/project-schema.md` § `review.ci_gate`). (c) **The gate's job never posted** — read its log
   (`gh run view <run-id> --log`); a rerun is not the fix. The other shape, `success` here
   while the PR still shows a red, is the **runner trap**: a status posted from a job whose
   name is not in `{ruleset.required_checks}` leaves that job's own check-run red until
   `gh run rerun`, and it blocks nothing (its name is no schema key;
   `review.ci_gate.runner_job` is a possible later one, not added). Then report the merge
   verdict in `/way-of-working:pr-checks` language: READY, STALE-RED, NOT READY, or
   PENDING.

9. **File every non-blocking finding now, one item each,** per `{backlog}`. For
   `github_issues`: `gh issue create`, quoting the finding's reproduction and labeled per
   `reference/conventions.md`; when `{backlog.repo}` is set, reach first, chained —
   `gh api repos/{backlog.repo} --jq .permissions && gh issue create --repo {backlog.repo} …`.
   For `file`, an entry in `{backlog.path}` under the next `{backlog.item_prefix}` id.
   **Findings never travel in `next_action`.**

10. **End with the pointer:** `/way-of-working:handoff`. The cursor's next action is the
    human's merge or the fix-and-repost loop — never a second review from this session.

## Guardrails

- `--comment` only. No `--approve`, no `--request-changes`, no `gh pr merge`, no push to
  the branch, no `--force`.
- The two frozen strings are copied from `.ai/project.yml` on `{pr_base}`, never typed.
  Why: `reference/project-schema.md`, and nowhere else in full.
- Wrong session (step 2), no gate (step 1), unreadable schema, a moved head, strings you
  could not copy byte for byte: each is a stated stop, never a best effort.
