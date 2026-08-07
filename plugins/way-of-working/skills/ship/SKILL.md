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

**Read `.ai/project.yml` first** for `{pr_base}`, `{repo}`, `{code_paths}`, and
`{review.ci_gate}`. Commit and PR-title grammar is not repo-specific — it lives in
`reference/conventions.md`; read it rather than restating it here.

## Steps

1. **Preflight the branch.** Run `git rev-parse --abbrev-ref HEAD`.
   - **On `{pr_base}`?** Cut a branch first — a plain commit/push to a protected base is
     rejected by the `{ruleset.name}` ruleset (GH013). Name it for the work per
     `reference/conventions.md` § *Branch names*: `sprint/NN-slug` for sprint tasks, else a
     typed prefix matching the change (`docs/…`, `chore/…`, `fix/…`, `ci/…`). The branch is
     cut **from `{pr_base}`**.
   - **Already on a work branch?** Confirm it was cut from `{pr_base}` and just add to it.
   - Never rebase/force-push a pushed branch. To refresh a stale branch, merge `{pr_base}`
     **into** it. A conflict in an append-only ledger file (a backlog, a changelog) is
     usually *two additions* — keep **both** sides.

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

6. **Label on the three axes** if labels are being used: type (`bug`/`feature`/`docs`/
   `chore`), `area/*` (mirrors the scope), `status/*` — see `reference/conventions.md`
   § *Issue + label taxonomy*. Machine-emitted labels stay namespaced under this repo's own
   name, derived from `{repo}`.

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
