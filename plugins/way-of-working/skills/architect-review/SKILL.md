---
name: architect-review
description: >-
  Post the fresh-session Architect Review a PR's review CI gate requires, verify the gate
  went green on the head SHA, and file non-blocking findings. Run in a NEW session that
  didn't author the diff. Never approves, never merges.
---

# /way-of-working:architect-review — satisfy the fresh-session review gate (never approve)

Goal: satisfy what `{review.ci_gate}` enforces — a review of a PR's diff by a session that
didn't write it, posted so it goes green on the head commit. The `architect` *subagent* is
`/way-of-working:critic-gate`'s pre-review, never this: spawned mid-work isn't a fresh
session.

Argument: a PR number in the repo whose checkout you are standing in, at its root. Wherever
you start — already on `{pr_base}`, on the PR's own branch (whose `.ai/project.yml` is the
author's), or anywhere else — sync onto `{pr_base}`, chained so a failed link stops,
catching a dirty or unpushed local copy the merge alone would miss:

```bash
git fetch -q origin {pr_base} && git switch {pr_base} &&
git merge --ff-only "origin/{pr_base}" &&
git diff --quiet "origin/{pr_base}" -- :/.ai/project.yml
```

**Read `.ai/project.yml` from that checkout, now verified synced,** for `{review.ci_gate}`,
`{models.architect}`, `{repo}`, `{pr_base}`, `{code_paths}`, `{decisions.prefix}`,
`{threat_model}`, `{ruleset.name}`, `{ruleset.rule_types}`, `{ruleset.required_checks}`,
and `{backlog}` — missing or unreadable is a stop, and so is this `{pr_base}` not matching
`git branch --show-current`: a second-hop branch can name itself honestly yet not be the
one you're on. Never guess a gate (`reference/project-schema.md`).

Then anchor both `{repo}` and `{pr_base}` to `origin` itself, not `gh`'s default-remote
guess (can be `upstream` in a fork):

```bash
U=$(git remote get-url origin) && gh repo view "$U" --json nameWithOwner,defaultBranchRef \
  --jq '[.nameWithOwner, (.defaultBranchRef.name // "")] | @tsv'
```

The call failing, or its first field not `{repo}`, is an unconditional stop: nothing below
means anything against the wrong repo. The second field is the default branch: equal to
`{pr_base}` proceeds; not equal — the schema's long-migration case
(`reference/project-schema.md` § `repo`, `pr_base`) — confirm `{ruleset.name}` protects
`{pr_base}` via `/way-of-working:resume` step 4's ruleset check; proceed only then. Neither
holds: stop, naming both branch values. Every step fails closed; shell state does not
survive between calls.

## Steps

1. **Is there a gate, is this the right session?** `{review.ci_gate}` `null`: say so and
   stop — `/way-of-working:critic-gate` is the look such a repo gets. Otherwise compare
   your running model with `{models.architect}`.

2. **State the integrity precondition, then honor it.** If this context contains
   authoring the diff — you wrote it, then `/clear`ed or `/model`-switched —
   **stop and do not post.** CI cannot observe a session boundary; the attestation you
   paste in step 7 turns reviewing your own work into a *knowing false statement*.

3. **Pin the target.** `gh pr view <N> --json headRefOid,baseRefName,files`;
   `baseRefName` must be the anchored `{pr_base}` — any other branch is a stop. Check
   whether the PR touches `{code_paths}` (or `{review.ci_gate.triggers_on}`). An exempt PR
   (docs, sprint plan, `.ai/` cursor) gets one plain statement, no review posted.

4. **Check the other required checks first** — invoke `/way-of-working:pr-checks <N>` via
   the Skill tool. The gate reads `absent` or `failure` here: what you're about to satisfy;
   `success` already means a review satisfied this SHA, so ask why first. Review only a
   PR whose other checks are green, unless the human says otherwise: a fix pushed after
   review moves the head and re-arms the gate.

5. **Load context lean.** The PR body; its sprint-plan task row; `{decisions.prefix}`
   ids and `{threat_model}` boundaries it names; the critic-gate outcome. Not the whole
   plan, not the whole repo.

6. **Review by execution, in a scratch worktree.** Fetch the head, `git worktree add
   <tmp> <sha>`, and reproduce each claim: the added test, the gate it says is
   green, the command it says now fails. Plant a mutation to witness a guard go red,
   then remove it. This runs the PR's code with your credentials: do it
   only where the author is trusted or the worktree is sandboxed, and read no config from
   it — the worktree shares this checkout's `.git`. No subagent fan-out by default — the
   fresh session *is* the architect; spawn a critic only for a named angle, its findings
   verified first.
   Line-anchored defects may go inline; the scope verdict goes in the body posted next.
   `git worktree remove` when done, back at the main checkout's root — step 7 re-reads
   `.ai/project.yml` from there.

7. **Compose and post.** The body **opens** with `{review.ci_gate.header}` and
   `{review.ci_gate.attestation}`, each on its own line, copied byte for byte from the
   synced `.ai/project.yml` — `yq -er`, or any reader that emits the scalar unchanged and
   fails on a missing one — never typed from memory. A chain that stops before printing
   the path is a stop:

   ```bash
   T=$(mktemp -d) &&
   { yq -er .review.ci_gate.header .ai/project.yml && echo &&
     yq -er .review.ci_gate.attestation .ai/project.yml && echo; } > "$T/review.md" &&
   [ "$(grep -c . "$T/review.md")" -eq 2 ] && echo "$T/review.md"
   ```

   Append to that file, in order: `Reviewed against head <sha>`; the verdict; ranked
   findings with reproductions; what you independently verified. Post with
   `gh pr review <N> --comment --body-file <that path>`. **Never `--approve`, never
   `--request-changes`, never merge**: the merge is the human's approval, and a
   Claude-issued approval would be a gate approving itself.

8. **Verify the post took.** Poll until `{review.ci_gate.check}` reads `success` on the
   head SHA — bounded, about 90 s — through the tested predicate, reading **both**
   surfaces it posts to; name which carried it. The `&&` chain is load-bearing: a failed
   call must never reach it, since a missing document reads as `absent`:

   ```bash
   for i in $(seq 6); do
     SHA=$(gh pr view <N> --json headRefOid -q .headRefOid) && T=$(mktemp -d) &&
     gh api --paginate "repos/{repo}/commits/$SHA/status" \
       --jq '.statuses[] | ["status", .context, .state] | @tsv' > "$T/s.tsv" &&
     gh api --paginate "repos/{repo}/commits/$SHA/check-runs" \
       --jq '.check_runs[] | ["check-run", .name, .status, (.conclusion // "")] | @tsv' > "$T/c.tsv" &&
     cat "$T/s.tsv" "$T/c.tsv" > "$T/gate.tsv" &&
     G=$(review-gate-state.sh "{review.ci_gate.check}" < "$T/gate.tsv") && echo "$G $SHA" &&
     [ "$G" = success ] && break
     sleep 15
   done
   ```

   Any word but `success`, or nothing (exit 2), is not green. Not `success` at the bound:
   diagnose **in order**. (a) **Head moved** — the printed SHA isn't the one
   reviewed; repost against the new head. (b) **String mismatch** — `gh api --paginate
   repos/{repo}/pulls/<N>/reviews --jq '.[].body' | grep -cF` each value
   (`reference/project-schema.md` § `review.ci_gate`). (c) **Job never posted** — read its
   log (`gh run view <run-id> --log`); a rerun isn't the fix. The **runner trap**:
   `success` while the PR shows red comes from a job not in `{ruleset.required_checks}` —
   its check-run stays red until `gh run rerun`, blocking nothing. Report the verdict in
   `/way-of-working:pr-checks` language: READY, STALE-RED, NOT READY, or PENDING.

9. **File every non-blocking finding, one item each,** per `{backlog}`. For
   `github_issues`: `gh issue create`, quoting its reproduction, labeled per
   `reference/conventions.md`; `{backlog.repo}` set: reach first —
   `gh api repos/{backlog.repo} --jq .permissions && gh issue create --repo {backlog.repo} …`.
   For `file`, an entry in `{backlog.path}` under the next `{backlog.item_prefix}` id.
   **Findings never travel in `next_action`.**

10. **End with the pointer:** `/way-of-working:handoff`. Next: the human's merge, or the
    fix-and-repost loop — never a second review from this session.

## Guardrails

- `--comment` only. No `--approve`, no `--request-changes`, no `gh pr merge`, no push to
  the branch, no `--force`.
- The two frozen strings are copied from `.ai/project.yml` on `{pr_base}`, never typed —
  why: `reference/project-schema.md`.
- Wrong session, no gate, unreadable schema, a moved head: each is a stop, never a best
  effort.
