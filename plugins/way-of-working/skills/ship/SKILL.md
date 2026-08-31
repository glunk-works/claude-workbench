---
name: ship
description: >-
  Close out a finished task — commit the working tree with a conventions-correct message,
  push to a branch cut from the PR base (never the base itself), and open a PR with a
  length-checked title. Stops at the open PR — never merges, never --approve, never
  force-pushes. Run when work is done and you want it on a PR.
---

# /way-of-working:ship — commit, push, and open the PR (then stop)

Goal: turn a finished working tree into an open PR against `{pr_base}`, with every repo
convention applied by construction — so the recurring slips (over-length PR title,
committing on the base branch, a wrong scope) can't happen. This skill **opens** the PR and
**stops**. It never merges, `--approve`s, or force-pushes — the human's merge is the
approval.

**Read `.ai/project.yml` first** for `{pr_base}`, `{repo}`, `{code_paths}`,
`{review.ci_gate}`, and — for the ledger-conflict rule in step 1 — `{backlog}`. Commit and PR-title grammar is not repo-specific — it lives in
`reference/conventions.md`; read it rather than restating it here. Step 5 also reads
`pointers.sprint_plan` from `.ai/state.json` when a cursor exists.

## Steps

1. **Preflight the branch.** Run `git rev-parse --abbrev-ref HEAD`.
   - **On `{pr_base}`?** Cut a branch first — a plain commit/push to a protected base is
     rejected by the `{ruleset.name}` ruleset (GH013). Name it for the work per
     `reference/conventions.md` § *Branch names*: `sprint/NN-slug` for sprint tasks, else a
     typed prefix matching the change (`docs/…`, `chore/…`, `fix/…`, `ci/…`). The branch is
     cut **from `{pr_base}`**.
   - **Already on a work branch?** Confirm it was cut from `{pr_base}` and just add to it.
   - Never rebase/force-push a pushed branch. To refresh a stale branch, merge `{pr_base}`
     **into** it. A conflict in a ledger file (a backlog, a changelog) is usually *two
     additions* — **keep both sides**. That default is load-bearing: it is the only one of
     the two possible errors that is recoverable.

     One narrow exception, and it must be **proved before it is applied**: where the
     incoming side is a compaction move (`/way-of-working:archive-sprint`'s compaction
     step), an already-archived item is a *deletion*, not an addition, and resurrecting it
     into the live file undoes the close. Prove it per item, not per hunk — grep the
     item's **ID** out of the `_archive` sibling — for a file-kind `{backlog}`, that is
     `{backlog.path}` with `_archive` inserted before its extension (`docs/backlog.md` →
     `docs/backlog_archive.md`), per `reference/project-schema.md`. Where there is no such
     file to grep — a `github_issues` backlog, a changelog, a sibling-repo backlog you
     cannot reach, or an `_archive` file that is itself in conflict — the test cannot be
     run, so the exception does not apply and the default stands: keep both. **Found there → keep it archived. Not
     found there → it is an addition; keep it.** Never infer from the shape of the hunk:
     a compaction deletion and your own branch's new neighbouring item look identical in
     a conflict, and a new item dropped here is unrecoverable once the branch is
     squash-merged and pruned. The rule is scoped to *items with ids*; moved `{roadmap}`
     narrative has no id to grep, so it falls to keep-both, which at worst resurrects
     prose a later compaction moves again — the recoverable error — squashing leaves the branch's commits unreachable, so
     there is no side of the merge left to recover it from.
   - **Push-reach preflight, before any commit:**
     ```bash
     gh api repos/{repo} --jq .permissions.push   # substitute {repo}'s real owner/name —
                                                   # gh expands {repo} itself, and a literal
                                                   # brace produces an indistinguishable 404
     ```
     - Errors (repo unreachable / wrong identity entirely) → stop, before committing
       anything, and tell the human, naming the identity (`gh api user --jq .login`). If
       `{repo}` was left unsubstituted, the error is this same 404 — check that first,
       since it means "not run correctly" rather than "no access."
     - Returns `false` → stop the same way — this identity can see the repo but cannot
       push to it.
     - Only `true` clears this check. (Don't "fix" a 404 by widening the call to
       `repos/{owner}/{repo}` — `gh` resolves those from the local git remote, not from
       `.ai/project.yml`'s `repo`, so on a fork or a mismatched remote it silently
       preflights the wrong repo.)

     This only verifies **`gh`'s** identity — `git push` can still resolve a different,
     write-less account through its own credential helper and fail later regardless of a
     healthy result here (see `reference/conventions.md` § *Push identity*). If the push in
     step 3 403s despite this check passing, that mismatch is the first thing to check —
     use the workaround documented there — though a 403 can also mean SSO authorization,
     an IP allow-list, or a credential that expired between this check and the push.

2. **Review the diff, then compose the commit.** `git status --short` + `git diff --staged`
   (stage with `git add` as needed). Write the message per `reference/conventions.md`
   § *Message grammar* — Conventional Commits, imperative subject, ≤72 chars, no trailing
   period. Two things that need repo knowledge rather than the conventions file:
   - **The `scope` reuses one of this repo's own module boundaries**, so commit vocabulary
     matches architecture vocabulary. Those boundaries are local truth — read them from the
     repo's `CLAUDE.md` (or `.ai/context/`), not from this skill and not from memory.
   - **A `!` breaking-change marker carries whatever migration obligation this repo
     defines** for the surface being broken (a schema-version bump, a migration function, a
     documented upgrade note). If the repo defines one, it lands **in the same commit**.
   - If commits are signed, a signing *timeout* usually means the host pinentry is waiting
     for input — answer it and re-run the commit; it is not a commit failure.

3. **Push the branch** (`git push -u origin <branch>`). Push freely to the work branch,
   **never to `{pr_base}`**. Once asked to push in a session, keep pushing later commits
   without re-confirming — but always to the branch.

4. **Length-check the PR title BEFORE creating the PR.** This is the recurring mistake —
   never eyeball it:

   ```bash
   TITLE="type(scope): imperative subject"
   printf '%s' "$TITLE" | wc -c        # must be ≤ 72
   ```

   A squash merge makes the **PR title** the commit subject, so the title — not the commit
   — is the enforced surface (`reference/conventions.md` § *PR titles*). If >72, shorten
   and re-check.

5. **Open the PR against `{pr_base}`.**
   `gh pr create --base {pr_base} --title "$TITLE" --body "…"`. Body: a `## What` / `## Why`
   summary, and the scope (which boundary changed). If `{review.ci_gate}` is set and this
   diff touches none of `{code_paths}`, note that the review gate is exempt for this PR.

   **If this change relies on a blocking precondition, record its satisfaction here.** Read
   `pointers.sprint_plan` from `.ai/state.json` (skip this if there is no cursor or no sprint
   plan — a one-off change has no plan to consult) and check it for criteria marked
   **`BLOCKING:`** per `reference/conventions.md` § *Blocking preconditions*. If one of them
   gates the step this PR performs, add a line to the body naming **what was done, when, and
   how it was verified** — not the criterion restated, and not the criterion cited as
   *rationale*, which reads like coverage and is not.

   Read the plan rather than answering from memory: a precondition satisfied "as far as this
   session recalls" is the exact failure this exists to close — evidence that lives in
   someone's memory has already failed for the next reader. If a criterion gates this change
   and you cannot confirm it was met, **say so in the PR body and tell the human** rather
   than opening quietly; that is a question for them, not a blocker this skill resolves.

6. **Label on the three axes** if labels are being used: type (`bug`/`feature`/`docs`/
   `chore`), `area/*` (mirrors the scope), `status/*` — see `reference/conventions.md`
   § *Issue + label taxonomy*. Machine-emitted labels stay namespaced under **the emitting
   system**; for a label this skill emits, that emitter is the repo's own automation, so the
   namespace is **the repo's own name** — the bare name from `{repo}`, never the `owner/name`
   pair. That is the general rule applied, not a second rule. The other case, where a repo's
   emitter is a separately-named engine, is real and is covered in `conventions.md` — but it
   is never what *this* skill emits, so it never changes the answer here.

7. **If a review gate applies, flag it — do not satisfy it here.**
   - **`{review.ci_gate}` is set and the diff touches `{code_paths}`:** the
     `{review.ci_gate.check}` check stays red until a **fresh-session** review is posted
     against the PR's current head commit. `/way-of-working:ship` does **not** post that review — switching
     model mid-session is not a review session. Tell the user the PR needs the `/way-of-working:handoff` →
     new session → `/way-of-working:resume` → review → post sequence.
   - **`{review.ci_gate}` is `null`:** this repo has no review CI gate. Say nothing about
     one — do not invent a review step, and do not describe the PR as exempt from a gate
     that does not exist. The PR is complete at step 8.

8. **Stop at the open PR.** Report the PR URL and, if you want, hand off to `/way-of-working:pr-checks <N>`
   to watch the required checks. **No `gh pr merge`, no `gh pr review --approve`, no
   `git push --force`** — the merge is the human's.

## Guardrail summary

Branch from `{pr_base}` · push to the branch never the base · title ≤72 (measured, not
eyeballed) · base `{pr_base}` · commit per `reference/conventions.md` · **never merge /
approve / force-push**.
