---
name: archive-sprint
description: >-
  Retire a COMPLETED sprint that has passed its HITL Gate and is committed — snapshot its
  .ai/next-steps.md into .ai/archive/, compact the deep record (move completed narrative
  and resolved items to archive files), advance .ai/state.json to the next sprint, and seed
  a fresh next-steps.md. Run ONLY on sprint completion; /way-of-working:handoff and /way-of-working:resume never archive.
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
3. `{roadmap}` reflects the sprint as done, however that repo's roadmap records status, with the closing commit hash. If not, do that first (or flag it).
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
   is tracked, that tracking is the missing step** — create it before archiving.

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
   that relied on it, a command output, or a tracked backlog item per `{backlog}`.

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
   `pointers.sprint_plan` still names the closed sprint. A sprint close is the compaction
   trigger (`reference/conventions.md` § *Prose economy*) — this is what keeps `{roadmap}`
   and a file-kind `{backlog}` from growing without bound as a standing per-session token
   cost. Content-preserving moves only:

   **If `pointers.sprint_plan` is null or names no existing directory** — a repo in a
   steady state with no sprint cadence, which the schema explicitly supports — there is no
   sprint directory to archive beside. Say so in one line and **skip the first bullet
   only**; do not invent a destination path. The other two bullets, and everything after
   them in this step, still apply.

   - Move the closed sprint's completed execution narrative out of `{roadmap}` into
     `execution_record.md` beside the closed sprint's `sprint_plan.md` (the directory
     containing `pointers.sprint_plan`), verbatim. Move only what is unambiguously
     narrative about this sprint's execution; decisions and whatever the repo's roadmap
     keeps as current status stay put — when in doubt, leave it in place. Before moving a
     section, grep the repo for inbound links to its anchor; where one exists, leave a
     one-line pointer at the vacated anchor rather than a dead link.
   - For a file-kind `{backlog}`, move items resolved during this sprint into the archive
     file named by inserting `_archive` before `{backlog.path}`'s extension
     (`docs/backlog.md` → `docs/backlog_archive.md`), keeping each item's ID anchor so
     citations still resolve by grep.
   - Delete inline correction annotations (strikethroughs, "this used to say…") **only
     where the annotation itself names the action it gates and you can confirm from the
     repo that that action closed** — a cited `{backlog}` item closed **as completed**, or
     a merged PR. A declined or not-planned item does not close the action: the correction
     it gates is still live, and `gh issue view` reports both as `CLOSED`. Delete the whole construct, struck text included; its story is in git and
     the PR record. **An annotation that names no action, or whose action you cannot
     confirm closed, stays.** This is the one bullet that produces no destination
     artifact, so a wrong judgement leaves nothing to grep for — when in doubt, leave it.

   **If nothing moved** — no narrative to archive, no resolved file-kind items, no
   deletable annotations — say so in one line and go to step 3. Make no commit, no branch
   and no PR; the rest of this step and step 6's reporting of it do not apply.

   Otherwise: **stage by explicit path** — `git add <each source> <each archive file>`,
   never `git add -A` or `git commit -a`. The archive files are untracked until added, and
   committing the sources without them is how a move silently becomes a deletion. The
   explicit paths matter for a second reason: precondition 2 admits a tree with unrelated
   changes, so a directory-wide or all-files add would sweep someone else's work into a
   commit labelled as a compaction.

   **Then verify the move actually was one, before committing.** `git status --short` is
   not sufficient: it is blind to an archive file that was never written at all (the more
   likely failure — the text was deleted and lost) and it does not list ignored files, so
   a destination caught by the repo's `.gitignore` never enters the index. Check all three:
   - `git diff --cached --stat` shows an **addition** side, not deletions alone;
   - every line removed from a source — **except a correction annotation deleted under the
     bullet above, which by design has no destination** — is greppable, verbatim, in a
     staged archive file;
   - `git check-ignore <archive paths>` names nothing. (It exits 1 when nothing matches,
     so read its *output*, not its exit status.)

   **Then ship the compaction as its own PR, exactly like any other change to tracked
   docs.** Do not simply commit where you stand. A compaction is a destructive edit to the
   consuming repo's own record, and it gets the same treatment every other such edit gets:
   - Switch to `{pr_base}` and pull, then cut a branch from it — `docs/compact-<sprint>`.
     **Never commit straight to `{pr_base}`**, and never onto the just-merged sprint
     branch: that branch's PR is already merged, so the next `/way-of-working:resume` or
     step 5 below will `git branch -D` it, and because a squash-merged branch's commits are
     unreachable, `-D` succeeds silently and takes the compaction with it. An unpushed
     commit on a merged branch is *less* recoverable than an unstaged edit, not more.
   - Commit with subject `docs: compact the deep record at <sprint> close`, push, and open
     the PR. Pushing is what makes the content durable; until then it exists in exactly one
     place.
   - Report `git show --stat HEAD` so the human sees what the close reclaimed, and hand
     them the PR link. **That PR is the human checkpoint for this step** — the sprint's own
     HITL Gate approved the sprint, not this compaction. Do not merge it yourself; the
     human's merge is the approval, as everywhere else.

   Keeping the compaction on its own branch is also what keeps it out of the cursor PR:
   `/way-of-working:handoff` requires its PR to touch `.ai/next-steps.md` and nothing else,
   and it cuts that branch from `{pr_base}` — so a compaction committed on `{pr_base}`, or
   left staged, rides into it either way.

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
   merged=$(gh pr list --state merged --limit 300 --json headRefName -q '.[].headRefName')
   cur=$(git branch --show-current)
   for b in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
     case "$b" in "$base"|"$cur") continue;; esac
     printf '%s\n' "$merged" | grep -qxF "$b" && git branch -D "$b" && echo "pruned $b"
   done
   ```

   Report which branches were pruned (or "none"). Hygiene, not a gate — if the `gh` call fails, skip and say so.

   **`-D` is safe only per-commit, not per-branch.** Merged-ness is confirmed out-of-band,
   but a merged branch that has since received a *local, unpushed* commit still deletes
   without complaint — and because a squash-merged branch's commits are unreachable, that
   work is gone with no warning. Before pruning, skip any branch whose tip is not contained
   in `{pr_base}` and not pushed: `git branch --contains <tip> {pr_base}` empty **and**
   `git rev-parse --verify origin/<branch>` failing means unpushed local work. Report those
   as skipped rather than deleting them.

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
- Compaction (step 2) may remove a line from `{roadmap}` or `{backlog}` **only when the identical bytes appear in an archive file staged, and then committed, in the same change** — verify before reporting, per step 2's three checks. That is the bright line, and it is checkable before the commit rather than a claim about intent: a move that cannot show its destination is a deletion, whatever it was meant to be. The single exception is a correction annotation, which by definition has no destination — so it is fenced by its own narrower test in step 2 (the annotation must name the action it gates, and that action must be confirmably closed) and by nothing else. Compaction never rewrites what it moves, the sprint_plan files stay in place, and nothing here ever touches git history.
- Never archive an un-approved or uncommitted sprint.
- The branch prune deletes **only** branches whose PR GitHub reports `merged` (via `gh`); it never touches an unmerged branch, a branch with no PR, `{pr_base}`, the current branch, or a branch carrying a local unpushed commit. `git branch -D` is safe here precisely because merged-ness is confirmed out-of-band (a squash-merged branch looks "unmerged" to git) — but that argument is about the branch's *merged* commits, not about anything added since, which is why the unpushed-commit check is part of the prune and not an optional refinement.
