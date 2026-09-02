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
`{review.ci_gate}`, and — for the ledger-conflict rule in step 1 — `{backlog}`, `{roadmap}`
and `{decisions.prefix}`. Commit and PR-title grammar is not repo-specific — it lives in
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
     additions* — **keep both sides**. That default is load-bearing: of the two errors
     available here it is the recoverable one, because a resurrected entry can be removed
     again while an entry dropped on a branch that is then squash-merged and pruned cannot
     be recovered from anywhere — squashing leaves the branch's own commits unreachable.

     **One case is worth telling the human about, per entry — and it is never applied
     automatically.** Where the
     incoming side is a compaction (`/way-of-working:archive-sprint`'s compaction step), an
     item it removed is a *move*, not an absence, and putting it back into the live file
     undoes the close. Never read that off the hunk: in a conflict, a compaction's removal
     and your own branch's new neighbouring item look identical.

     During a conflicted `git merge {pr_base}`, `MERGE_HEAD` is the incoming side, `HEAD` is
     your branch, and index **stage 1** is the base the merge actually used. Find what the
     incoming side removed, then ask, per removed id, whether that id landed in the same
     side's `_archive` sibling (a **derived** path, never configured — see
     `reference/project-schema.md`):

     ```bash
     ledger=<the conflicted ledger>            # {backlog.path} or {roadmap}
     archive=<its _archive sibling>
     base=$(mktemp); inc=$(mktemp); arc=$(mktemp)
     # Redirect to files and STOP on failure — never `diff <(git show …) <(git show …)`.
     # Process substitution discards the `git show` status, and a failed show leaves an
     # EMPTY file rather than an absent one, so `diff` still exits 1 with a confident-
     # looking answer. Stage 1 is the LEFT argument, so the two failures point opposite
     # ways: a ledger deleted/renamed on the incoming side reports every entry as
     # REMOVED — the dangerous read, since it feeds the whole ledger to the archive
     # lookup — while a missing stage 1 reports every entry as added, which merely
     # looks like the common case. Both are unrunnable; neither should be interpreted.
     git show ":1:$ledger"         >"$base" || { echo "no stage 1 — keep both"; exit; }
     git show "MERGE_HEAD:$ledger" >"$inc"  || { echo "renamed — keep both"; exit; }
     # `|| :` because diff exits 1 whenever the files differ -- which is the only case
     # this step exists for, so under `set -e` it would abort exactly when it matters.
     # Read only the `<` lines. A line the incoming side EDITED shows as both `<` and
     # `>`; looking its id up is harmless (it answers 1, "unresolved") but expected.
     diff "$base" "$inc" || :                             # its `<` lines are the removals
     git show "MERGE_HEAD:$archive" >"$arc" || : >"$arc"  # absent ⇒ empty, not an error
     st=0; entry-anchor.sh "<id>" "$arc" || st=$?; echo "$st"   # once per `<`-line id
     ```

     Quote the `<id>` placeholder as shown, so the line fails loudly like the others rather
     than being read as a shell redirection.

     `entry-anchor.sh` is the plugin's tested predicate for the one question this needs —
     *does this file carry `<id>` at its own entry anchor?* It is on the Bash tool's `PATH`
     by bare name while the plugin is enabled, and answers **0** yes, **1** no, **2** could
     not tell. Why a line-shaped `grep` cannot stand in for it, and which real ledger shapes
     it misses or falsely matches, are argued in its own header — read that, don't restate
     it, and don't reimplement it inline.

     Resolve **per entry, not per hunk** — one hunk can hold a removal and an addition at
     once, and the additions are never in question. **Every branch below keeps both sides.
     This step never deletes an entry**; what the predicate changes is how confidently each
     removal is described to the human, not whether it is applied:

     - **Not removed** — every entry in the base that survives on `MERGE_HEAD`: **keep
       both**, and say nothing further. The ordinary two-additions conflict, and the common
       case.
     - **Removed, and `entry-anchor.sh` answers 0** — keep both, and name the entry to the
       human as **probably moved into the archive by a compaction**, so the likely
       resolution is to drop it from the live file. That is triage, not a verdict: exit 0 is
       strong evidence, and the script's own header refuses to call it proof.
     - **Removed, and it answers 1 or 2** — keep both, and name the entry as
       **unresolved**. `1` is not proof your side added it: a deliberate deletion by the
       incoming side lands there too, and so does a real entry in one of the shapes the
       script misses.

     > **Why exit 0 does not act on its own.** An earlier draft of this step accepted the
     > removal on 0. Every critic round found a new shape where a *citation* answers 0 —
     > markup on a wrapped continuation line, the same inside a block quote, a nested list
     > item, a fenced example whose fence closed early, a lazy paragraph continuation — and
     > each was caught only because someone went looking. The predicate now says of itself
     > that its cost list is "a floor, not a proof". A branch that deletes a live entry
     > unrecoverably cannot hang on a predicate that honest, so it doesn't: the human sees
     > every removal, sorted by how sure the machine is, and a merge conflict is a moment
     > they are already present for.

     > **Ask a revision, never a merge base you computed.** The obvious form — diff
     > `git merge-base HEAD MERGE_HEAD` against `MERGE_HEAD` — is **false under squash-merge,
     > which is this repo's default**. A squash commit is not a descendant of the branch's own
     > commits, so the merge base does not advance past it (this is `WB-D7`'s premise in
     > another command): once your PR squash-merges and you keep working on the branch, that
     > diff replays *your* already merged additions and deletions as if the incoming side had
     > made them. Verified — after a squash-merge it attributed both a decline and an addition
     > made on the work branch to `{pr_base}`. Stage 1 is the base **git itself resolved for
     > this merge**, virtual bases included, so it is right where a recomputed base is not.

     **Where a test cannot be run, the default stands — keep both.** Any `git show` on the
     *ledger* that fails covers it: a ledger the incoming side **renamed or deleted**
     (`fatal: path … exists on disk, but not in 'MERGE_HEAD'` — that wording, not "does not
     exist in", whenever the file is still in your working tree, which is the normal shape
     of this conflict), or an add/add conflict where the path has no stage 1
     at all (`fatal: path … is in the index, but not at stage 1`) — in the latter the file is
     new on both sides, so nothing can have been removed. Narrative with no entry ids falls
     here too, which is the usual shape of removed `{roadmap}` prose: no id, no question to
     ask. So does a removal on a record whose id scheme the schema doesn't give you
     (`{backlog.item_prefix}` for a file-kind backlog, `{decisions.prefix}` for `{roadmap}`).

     A **missing `_archive` sibling** is not one of these — it is a legitimate answer, not a
     failure. The sibling is a derived path, never a promise the file exists; absent, it is
     read as empty, every removed id answers `1` (or `2`), and every one of them is kept and
     named. That is the same outcome by the same rule, which is why the `||` above swallows
     it.

     All of this works only **while the merge is in progress**; `MERGE_HEAD` and stage 1 do
     not exist before it starts or after it is committed or aborted. For a merge already
     committed, the incoming side is `HEAD^2`.
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
