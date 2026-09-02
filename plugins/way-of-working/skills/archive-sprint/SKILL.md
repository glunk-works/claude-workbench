---
name: archive-sprint
description: >-
  Retire a COMPLETED sprint that has passed its HITL Gate and is committed — snapshot its
  .ai/next-steps.md into .ai/archive/, compact the deep record (move completed narrative and
  items closed during the sprint, resolved and declined alike, to archive files), advance
  .ai/state.json to the next sprint, and seed a fresh next-steps.md. Run ONLY on sprint
  completion; /way-of-working:handoff and /way-of-working:resume never archive.
---

# /way-of-working:archive-sprint — retire a completed sprint and bootstrap the next

Goal: close out a finished sprint cleanly and set up the next one, keeping the live
cursor small and moving completed detail out of routine context. This is the ONLY
command that archives — do not invoke it for ordinary session switches.

**Read `.ai/project.yml` first** for `{roadmap}`, `{sprints_dir}`, `{pr_base}`, `{models}`,
`{backlog}`, `{agents.enabled}`, and `{load_bearing_docs}`.

## Preconditions (verify ALL before doing anything)

1. The sprint's HITL Gate is **passed** — the user approved it (ask if unclear — never assume).
2. The work is **committed** (`git status --short` clean, or only unrelated changes). If dirty, stop and tell the user to commit first.
3. `{roadmap}` reflects the sprint as done (status row + commit hash recorded). If not, do that first (or flag it).
4. **Verification ledger — "complete" must not overclaim "verified live."** If this sprint
   marks an item **complete** (or flips `{roadmap}` to done), confirm the docs make the
   **hermetic-vs-live** distinction explicit and that any verification the hermetic suite
   structurally *cannot* make is **deferred and tracked**, not silently assumed. For any
   surface with a **live** side the tests can't reach (a real inbound delivery, real spend,
   a real external API, real infrastructure), state plainly "hermetically verified; live
   smoke deferred → <tracked item>" rather than "done/live/working end-to-end."

   The tracked item is a backlog entry per `{backlog}`: a GitHub issue cited as `#N` when
   `{backlog.kind}` is `github_issues`, or an item in `{backlog.path}` cited as
   `{backlog.item_prefix}N` when it is `file`. **If you cannot point to where the live check
   is tracked, that tracking is the missing step** — create it before archiving. Search the
   `_archive` sibling before creating one, so you do not duplicate an item that was
   compacted out of the live file. But **an archived or closed item does not satisfy this
   precondition** — deferred live verification needs tracking that is still *outstanding*,
   and the archive holds resolved and declined items alike. Found there and still open:
   that is the tracking. Found there and closed: check whether the verification actually
   happened; if it did not, this precondition is unmet and a fresh item is the fix.

   If `{backlog.repo}` is set, that backlog lives in a **sibling repo** and every `gh issue`
   call takes `--repo {backlog.repo}` (`gh issue create --repo {backlog.repo} …`). Confirm
   reach first — `gh api repos/{backlog.repo} --jq .permissions`, no `pull` means stop and
   report the identity from `gh api user --jq .login` — because an unreachable repo answers
   `404`, not `403`, and a precondition that cannot tell "not tracked" from "could not look"
   is the same defect this one exists to catch. **Never archive against a backlog you could
   not read.** See `reference/project-schema.md`.

   This is a real, recurring failure mode: a surface whose whole external side had only ever
   run against fakes is easy to stamp "passes live," and a human has to catch it. Its
   sibling is `docs-consistency` for prose-vs-code drift; this one is claim-vs-evidence.

5. **Blocking preconditions — every one is marked met, with a pointer to its evidence.**
   Precondition 4 asks whether a *deliverable's* completion claim is backed by evidence. This
   asks the same question one layer down, about the sprint's **preconditions**: the criteria
   that gated a specific step rather than describing an outcome.

   Read the sprint plan (`pointers.sprint_plan`) for criteria marked **`BLOCKING:`** — the
   convention in `reference/conventions.md` § *Blocking preconditions*. For each one, confirm
   it is marked met **and** that you can point to where its satisfaction is recorded: the PR
   that relied on it, a command output, or a tracked backlog item per `{backlog}`. Search
   the `_archive` sibling as well as the live file (`reference/project-schema.md` derives
   the path and says how to treat one that does not exist), and check a cited issue with
   `gh issue view <N> --json state` rather than listing open ones — evidence that was
   closed or compacted out of the live record is still evidence, and reporting it as
   missing is the false-dangling-citation failure, not a finding.

   - **Cannot find the evidence → that is the finding.** Ask the human directly whether the
     criterion was satisfied. If yes, get it recorded before archiving (a line on the
     relevant PR, or a backlog item saying what remains attested-but-unproven). If no, the
     sprint is not archivable.
   - **A sprint plan with no `BLOCKING:` markers** is a normal and common answer — say so in
     one line and move on. Do not manufacture preconditions, and do not retroactively
     reinterpret ordinary acceptance criteria as blocking ones.

   **Why this is not covered by precondition 1.** A HITL Gate can be genuinely passed while
   the criterion underneath it was never evidenced — the gate approves the *plan or the
   outcome*, not the precondition's satisfaction. Observed live: a criterion gating two
   applies against the only state file recording an org-shared federation endpoint was in
   fact satisfied, but the roadmap still read "outstanding," neither PR mentioned it, and
   `/way-of-working:critic-gate`, `/way-of-working:ship`, and `/way-of-working:handoff` all
   passed over it. It surfaced only because a human was asked. A criterion whose satisfaction
   is recorded nowhere is **indistinguishable from one that was skipped**, and that is the
   whole defect.

If any precondition fails, STOP and report why — do not archive.

## Steps

1. **Snapshot** the current `.ai/next-steps.md` to `.ai/archive/<current_sprint_id>-next-steps.md` (`.ai/archive/` is git-ignored). This preserves the sprint's final cursor for manual history queries.

2. **Compact the deep record (move, don't rewrite) — before the cursor advances**, while
   `current_sprint_id` still names the closed sprint. A sprint close is the compaction
   trigger (`reference/conventions.md` § *Prose economy*) — this is what keeps `{roadmap}`
   and a file-kind `{backlog}` from growing without bound as a standing per-session token
   cost. Content-preserving moves only.

   **Survey first, then cut the branch, then edit — in that order.** Work out what would
   move without changing anything yet. If the answer is nothing — no narrative to archive,
   no closed file-kind items, no deletable annotations — say so in one line, `git checkout
   {pr_base}`, and go to step 3: no branch, no commit, no PR, and step 6 reports no
   compaction. Switch to `{pr_base}` even on that exit — step 5 never prunes the branch you
   are standing on, so staying on the just-merged sprint branch would exempt the one branch
   a sprint-boundary prune exists to reap.

   **Confirm the sprint's work is actually in `{pr_base}` before surveying against it.**
   Precondition 2 asks only that the work is *committed*; everything below reads `{pr_base}`
   and treats that reading as authoritative. If the sprint has not merged, `{pr_base}` does
   not yet contain the sprint this close is closing and the survey is against the wrong tree.
   **Test it by content, on `{pr_base}`: does it carry what precondition 3 just verified —
   the sprint's status and its closing commit hash in `{roadmap}`?** Present → proceed;
   absent → say so and skip the compaction, and the next close picks it up.

   Do **not** test this by looking the branch up in `gh pr list --json headRefName`. Squash
   merge is what makes a branch-name lookup unreliable in the first place, and by this point
   in a normal close you are typically standing on `{pr_base}` already — the human merged on
   GitHub and the head branch is gone — so a current-branch lookup answers "not merged" for
   the very state the step is written for. A repo with no sprint cadence has no sprint branch
   to look up at all. The content test has none of those failure modes.

   The survey is **provisional**: it reads the tree you are standing on, and the checkout
   below replaces that with `{pr_base}`'s, which may have moved since this sprint branched.
   Re-read the sources on the new branch before editing and let that reading win — a
   section another PR already compacted is not yours to move again, and one that arrived
   since is in scope. If the re-read turns up nothing to move after all, take the
   nothing-moved exit and drop the branch you cut — **in that order**, `git checkout
   {pr_base}` first: `git branch -D` refuses to delete the branch the worktree is on
   (`error: cannot delete branch … used by worktree at …`).

   Otherwise **cut the branch before touching a file** — one chain, so nothing downstream
   runs if any link fails:

   ```bash
   git fetch origin {pr_base} && git checkout {pr_base} \
     && git merge --ff-only origin/{pr_base} \
     && git checkout -b docs/compact-<sprint>
   ```

   The order is the whole point. Editing first and switching after does not work: `git
   checkout` **aborts** with "your local changes would be overwritten" whenever the branch
   you are leaving and `{pr_base}` differ in a file you have touched — and `{roadmap}` and
   `{backlog}` are the likeliest files in the repo to have diverged. At that moment git's
   own advice is *"commit your changes"*, which on the just-merged sprint branch means
   committing onto a branch step 5 will `git branch -D`, silently and unrecoverably.
   **Never edit on `{pr_base}`, and never on the just-merged sprint branch.**

   **`git merge --ff-only origin/{pr_base}`, not a plain `git pull`, and name the ref.** A
   plain pull **succeeds** on a local `{pr_base}` that has diverged — with `pull.rebase=false`
   it merges — so every link in the chain returns zero and the compaction branch is cut from
   a base carrying an unrelated local commit, which then rides into the compaction PR. The
   chain's guard never fires because nothing failed. Divergence is reachable from this
   skill's own loop: step 6 asks the human to commit the `next-steps.md` change, and
   committing it on `{pr_base}` is exactly what diverges it. `--ff-only` turns that silent
   merge into a loud stop. Name `origin/{pr_base}` explicitly rather than letting the merge
   resolve `@{upstream}` — a bare form follows whatever upstream the branch is configured
   with, which can fast-forward to a different ref and still return zero, and fails with
   `fatal: No remote for the current branch.` when there is none.

   **The chain matters as much as the order.** Precondition 2 admits a tree with unrelated
   changes, so the checkout can abort here too — and an unchained `git checkout -b` after
   an abort cuts the compaction branch off whatever you were standing on, which is the one
   state this whole arrangement exists to avoid. If any link fails: **stop, and hand it to
   the human, naming the link that failed and its actual error** — a blocked checkout ("this
   file has uncommitted changes") and a refused `--ff-only` ("local `{pr_base}` has diverged")
   are different problems with different fixes, and reporting the first for the second sends
   them after a file that is not the issue. Do not commit anything yourself (it is not yours
   and not part of the compaction), do not `git stash` on their behalf, and do not proceed on
   the current branch. A compaction deferred to the next close costs nothing; a compaction on
   the wrong branch is the failure mode.

   **Then confirm no *tracked* file is modified** — `git diff --quiet && git diff --cached
   --quiet` both exit 0. A dirty tracked file that does not differ between the sprint branch
   and `{pr_base}` rides across the checkout *without* aborting, and if it is one of the
   sources below, the explicit-path staging further down will commit someone else's edit
   under the compaction's subject. Not clean → stop and hand it to the human, as above.
   Test tracked changes specifically, not `git status --short`: that also lists untracked
   files, and an untracked scratch file cannot be swept in by a path-scoped `git add` — it
   is not a reason to refuse to compact.

   - Move the closed sprint's completed execution narrative out of `{roadmap}` into
     `{roadmap}`'s **`_archive` sibling** — the same derivation `reference/project-schema.md`
     defines for a file-kind `{backlog}`, applied to `{roadmap}`'s path. Move it verbatim.
     Move only what is unambiguously narrative about this sprint's execution; decisions and
     whatever the repo's roadmap keeps as current status stay put — when in doubt, leave it
     in place. Before moving a section, grep the repo for inbound links to its anchor; where
     one exists, leave a one-line pointer at the vacated anchor rather than a dead link.
   - For a file-kind `{backlog}`, move items **closed during this sprint — resolved *and*
     declined** — into the `_archive` sibling of `{backlog.path}`, keeping each item's id
     anchor so citations still resolve. A declined item is as closed as a completed one and
     belongs out of the live record; every reader of the sibling
     (`/way-of-working:retro`, the `docs-consistency` agent, this skill's own preconditions)
     is written expecting to find both there, and treats the sibling as the file-kind
     equivalent of `--state closed`.
   - Delete inline correction annotations (strikethroughs, "this used to say…") **only
     where the annotation itself names the action it gates and you can confirm from the
     repo that that action closed** — a cited `{backlog}` item closed **as completed**, or
     a merged PR. A declined or not-planned item does **not** close the action: the
     correction it gates is still live. `state` alone cannot tell you which you have — it
     reads `CLOSED` for both — so ask for the field that can:
     `gh issue view <N> --json state,stateReason` returns `COMPLETED` or `NOT_PLANNED`.
     Delete the whole construct, struck text included; its story is in git and the PR
     record. **An annotation that names no action, or whose action you cannot confirm
     closed, stays.** This is the one bullet that produces no destination artifact, so a
     wrong judgement leaves nothing to grep for — when in doubt, leave it.

   **Derive both `_archive` paths from `reference/project-schema.md`; do not re-derive
   either here.** The rule is basename-only and has cases (no extension, a leading dot, a
   dot in a directory name) that a from-memory guess gets wrong, and a wrong destination
   path is a move whose archive file nobody reads. Deriving `{roadmap}`'s archive the same
   way is what keeps it **beside the live record**, as `reference/conventions.md`
   § *Prose economy* requires, and what lets a repo with no sprint cadence compact its
   roadmap at all.

   **Check the destinations are not ignored — before staging, not after.**

   ```bash
   git check-ignore <each archive path>     # must name NOTHING
   ```

   It exits 1 when nothing matches, so read its *output*, not its exit status. And run it
   **here**, ahead of the `git add`: `git check-ignore` is index-aware, so once a path is
   staged it reports nothing for that path even when `.gitignore` plainly matches it —
   verified. Run after staging, this check passes by construction and proves nothing about
   the condition it exists to detect. (`--no-index` also restores the answer if you have
   already staged.)

   **Then stage by explicit path** — `git add <each source> <each archive file>`, never
   `git add -A` or `git commit -a`. The archive files are untracked until added, and
   committing the sources without them is how a move silently becomes a deletion. The
   explicit paths matter for a second reason: precondition 2 admits a tree with unrelated
   changes, so a directory-wide or all-files add would sweep someone else's work into a
   commit labelled as a compaction.

   **A non-zero `git add` is a stop, and it is not all-or-nothing.** Given an ignored
   destination it stages the sources anyway, prints the hint, and exits 1 — leaving exactly
   the deletion-without-destination this step exists to prevent, already in the index.
   Verified. Check the exit status, and on failure unstage **those paths specifically** —
   `git reset -- <the paths you just added>`, never a bare `git reset`, which would also
   clear anything the human had staged.

   **Then verify the move actually was one, before committing.** `git status --short` is
   not sufficient: it is blind to an archive file that was never written at all — the more
   likely failure, where the text was deleted and lost. Check both:
   - `git diff --cached --stat -- <each archive path>` shows an **addition** side for the
     archive files **themselves**. Scope it to those paths: a whole-index `--stat` shows
     insertions from the pointer lines the narrative bullet asks you to leave at vacated
     anchors, so unscoped it reports a healthy addition side while no archive file ever
     entered the index.
   - every line removed from a source is greppable, **verbatim**, in a staged archive file.

   **The correction-annotation exception, and the only thing that keeps it honest.** A
   deleted annotation has no destination, so it satisfies neither check — and in a repo with
   a `github_issues` backlog, deletions may be *all* a compaction does, leaving both checks
   inapplicable and the bright-line guardrail resting on the agent's own say-so that a
   passage was an annotation. So **enumerate every removal claiming the exception in the
   commit body and the PR body**: the removed text, the action it named, and the evidence
   that action closed (`#N` with its `stateReason`, or the merged PR). An exception nobody
   can see is not an exception the human checkpoint below can review — and this is the one
   path in the whole step with nothing to grep for afterwards.

   **Then commit, push, and open the PR** on the branch cut above: subject `docs: compact
   the deep record at <sprint> close`, then `gh pr create --base {pr_base}`. Pushing is
   what makes the content durable — until then it exists in exactly one place. This push
   has no reach preflight of its own and carries the same push-identity exposure as
   `/way-of-working:ship` step 1; a `403` here is diagnosed the same way.

   Report `git show --stat HEAD` so the human sees what the close reclaimed, and hand them
   the PR link. **That PR is the human checkpoint for this step** — the sprint's own HITL
   Gate approved the sprint, not this compaction. Do not merge it yourself; the human's
   merge is the approval, as everywhere else.

   **Then `git checkout {pr_base}`** before going on. The remaining steps regenerate
   `.ai/next-steps.md`, and leaving HEAD on the compaction branch would land the cursor
   commit on the compaction PR — breaking `/way-of-working:handoff`'s requirement that its
   PR touch `.ai/next-steps.md` and nothing else, from the other side. Committing the
   compaction onto `{pr_base}` instead breaks it from the same side: `handoff` cuts its
   cursor branch from `{pr_base}`, so the compaction rides into the cursor PR. Its own
   branch is what keeps the two apart. (A compaction left *uncommitted* does not ride in —
   `handoff` stages `.ai/next-steps.md` by name and has an explicit rule for other dirty
   state — but it can block `handoff`'s branch cut, and otherwise surfaces to the human as
   unexplained dirty state: either way, a stop in a place they did not ask for one.)

   **A compaction PR merges before the next `/way-of-working:ship` refreshes a stale
   branch against `{pr_base}`** — and when it does, that merge is the incoming side of the
   ledger-conflict rule in `/way-of-working:ship` step 1. That rule **surfaces** what this
   step archived: it keeps both sides, as always, and reports each removal to the human
   ranked by whether the archive appears to carry the item. It does **not** prevent a
   resurrection — nothing mechanical does, and step 1 says so. The compaction is undone only
   if a human, looking at that report, keeps an entry the archive already holds.

   If `docs-consistency` is in `{agents.enabled}`, propose it on the compaction PR. Give it
   the check shape explicitly, because this is not its usual contradiction hunt: **did a
   *live* claim get moved into an archive, and is each moved passage byte-identical to what
   left the source?** Without that framing the archive reads to it as exactly the
   intentional historical prose its charter tells it not to flag, and it will correctly
   report nothing. If it is not enabled, say plainly that the compaction gets no critic
   look. A move-only diff converges in one round; a compaction that wants to **rewrite**
   what it moves is out of scope for this step — file it as its own item. Do not add the
   archive files to `{load_bearing_docs}`: they are historical record, not live claims. If
   that key is a glob wide enough to sweep them in, narrow the glob.

3. **Advance `.ai/state.json`** to the next sprint: set `current_sprint_id` / `current_phase` to the next unit from `{roadmap}`, `sprint_status: "planning"`, and `assigned_model` / `assigned_persona` to the planning role in `{models}` (the next step after completion is always planning/review). Update `last_commit`, and set `next_action` to "plan <next sprint/phase>". Point `pointers.sprint_plan` at the next `{sprints_dir}/*/sprint_plan.md` (or note it does not exist yet).

4. **Seed a fresh `.ai/next-steps.md`** for the next unit: **Now** = next phase/sprint in `planning`; **Just done** = one line noting the prior sprint archived + its commit; **Next** = "plan <next unit>" + the planning model; **Pointers** = `{roadmap}` + the next sprint_plan (or "to be written").

5. **Prune squash-merged local branches** (a sprint boundary is when the just-merged `sprint/NN-*` branch becomes dead — the "squash trap"). With squash merges, `git branch --merged {pr_base}` **cannot** see these branches; ask GitHub which PRs merged and `-D` **only** those — never an unmerged or PR-less branch, never `{pr_base}`, never the current branch:

   ```bash
   base=$(yq -r .pr_base .ai/project.yml)      # or read it however you like
   merged=$(gh pr list --state merged --limit 300 --json headRefName,headRefOid \
              -q '.[] | "\(.headRefName) \(.headRefOid)"') \
     || { echo "gh call failed -- skipping the prune"; merged=; }
   cur=$(git branch --show-current)
   for b in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
     case "$b" in "$base"|"$cur") continue;; esac
     tip_gh=$(printf '%s\n' "$merged" | awk -v b="$b" '$1 == b { print $2; exit }')
     [ -n "$tip_gh" ] || continue                    # no merged PR -- not a candidate
     if [ "$(git rev-parse "$b")" = "$tip_gh" ]; then
       git branch -D "$b" && echo "pruned $b"
     else
       echo "skipped $b -- merged, but its tip is not the commit GitHub merged"
     fi
   done
   ```

   Report which branches were pruned, and every skip the loop printed, with its reason (or "none"). A branch with no merged PR is not a candidate and is correctly silent — it is not a skip and does not belong in the report. Hygiene, not a gate — if the `gh` call fails, skip and say so.

   **Why the deletion is gated on a commit, not on merged-ness.** `-D` is safe only
   **per commit**, not per branch: merged-ness is confirmed out-of-band, but a merged
   branch whose local tip has moved since the push still deletes without complaint, and
   because a squash-merged branch's commits are unreachable that work is gone with no
   warning. `headRefOid` — the commit GitHub actually merged — comes free in the `gh pr
   list` call already being made, so the branch is deleted only when its local tip **is**
   that commit, and the skip message names the real reason.

   **Why not `origin/<branch>`.** The obvious test — "is my tip pushed?", `git rev-list
   --count origin/$b..$b` — reads the remote-tracking ref, and that ref stops resolving
   once the head branch is deleted on the remote: by the repo's `deleteBranchOnMerge`
   setting, by the PR page's *Delete branch* button, or by hand, followed by any `git fetch
   --prune` (or `fetch.prune=true`, or `git remote prune`). From then on the count command
   fails for that branch and a fallback that fails safe skips it **permanently** — telling
   the operator it "carries local commits that are not pushed" when it does not, and
   implying a push that is no longer possible.

   The trap is that **how much of the prune this disables is set by a repo setting the test
   never consults**, so it is invisible where it is written and total somewhere else: where
   branches are deleted on merge it eventually skips every candidate, and where they are
   not it looks flawless. `headRefOid` does not depend on that setting at all — the PR
   record keeps the merged commit after the branch is gone. `git branch --contains <tip>
   {pr_base}` is no use either: it is empty for *every* squash-merged branch, which is the
   premise of the squash trap this prune exists for.

6. **Report** what was archived, the new `current_sprint_id`, the next action, and the branches pruned. If step 2 opened a compaction PR, say what it reclaimed and link it, and note it is awaiting the human's merge like any other PR; if nothing moved, say that instead of naming a commit that does not exist. What remains uncommitted is the tracked `next-steps.md` change from step 4 — remind the user to commit that if they want it durable. Confirm with `git status --short` that the tree holds only that, so the next session starts from a state `/way-of-working:resume` can classify. If this same session did the sprint's work (so its friction is in context), offer a **`/way-of-working:retro`** pass before moving on — a sprint close is a natural retrospective moment; skip it silently if the working session was elsewhere.

7. **Consider bumping the plugin pin.** A sprint close is the one ritual that reliably
   recurs, which makes it the right moment to check whether `.claude/settings.json` points
   at the newest tag of this plugin's source repo. Tag-pinning makes upgrades opt-in, and
   opt-in without a trigger means never. Mention the current pin and whether a newer tag
   exists; bumping it is a one-line PR the human decides on — do not bump it silently.

   **Say what the bump would bring, not just that one exists.** Read the plugin's
   `CHANGELOG.md` for the entries between the pinned tag and the newest one, and surface any
   marked as needing a migration — "a newer tag exists" is not a decidable prompt, and a
   breaking change discovered *after* the bump is discovered in the worst place.

   **Bumping the pin is three steps, and skipping either of the last two is silent.** Editing
   the pin changes what is *pinned*; it does not change what is *loaded*.

   ```bash
   # 1. edit the ref in .claude/settings.json, then:
   claude plugin update <plugin>@<marketplace>   # 2. fetch the newly pinned tag
   # 3. restart the session — the CLI says "restart required to apply", and a
   #    running session keeps executing the copy it started with
   claude plugin list                            # verify: does it report the new version?
   ```

   **Verify with `claude plugin list`, never by looking for a new cache directory.** The old
   version's directory is **not** removed — the cache holds one directory per version, so
   "a new directory appeared" is true even when the session is still running the old code.
   That is precisely how this hides.

## Guardrails
- Compaction (step 2) may remove a line from `{roadmap}` or `{backlog}` **only when the identical bytes appear in an archive file staged, and then committed, in the same change** — verify before reporting, per step 2's checks. That is the bright line, and it is checkable before the commit rather than a claim about intent: a move that cannot show its destination is a deletion, whatever it was meant to be. The single exception is a correction annotation, which by definition has no destination — so it is fenced instead by a narrower test (the annotation must name the action it gates, and that action must be confirmably closed **as completed**, not merely `CLOSED`) plus the requirement that every removal claiming it is enumerated with its evidence in the commit and PR body. Self-certification with nothing to grep for afterwards is exactly why that enumeration is not optional. Compaction never rewrites what it moves, the sprint_plan files stay in place, and nothing here ever touches git history.
- Never archive an un-approved or uncommitted sprint.
- The branch prune deletes **only** branches whose PR GitHub reports `merged` (via `gh`); it never touches an unmerged branch, a branch with no PR, `{pr_base}`, the current branch, or a branch whose local tip is not the commit GitHub merged. `git branch -D` is safe here precisely because merged-ness is confirmed out-of-band (a squash-merged branch looks "unmerged" to git) — but that argument covers the commit GitHub merged and nothing added since, which is why the tip check (against `headRefOid`, never against `origin/<branch>`) is part of the prune and not an optional refinement.
