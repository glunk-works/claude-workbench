---
name: archive-sprint
description: >-
  Retire a COMPLETED sprint that has passed its HITL Gate and is committed — snapshot its
  .ai/next-steps.md into .ai/archive/, advance .ai/state.json to the next sprint, and seed a
  fresh next-steps.md. Run ONLY on sprint completion; /way-of-working:handoff and /way-of-working:resume never archive.
---

# /way-of-working:archive-sprint — retire a completed sprint and bootstrap the next

Goal: close out a finished sprint cleanly and set up the next one, keeping the live
cursor small and moving completed detail out of routine context. This is the ONLY
command that archives — do not invoke it for ordinary session switches.

**Read `.ai/project.yml` first** for `{roadmap}`, `{sprints_dir}`, `{pr_base}`, `{models}`,
and `{backlog}`.

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

2. **Advance `.ai/state.json`** to the next sprint: set `current_sprint_id` / `current_phase` to the next unit from `{roadmap}`, `sprint_status: "planning"`, and `assigned_model` / `assigned_persona` to the planning role in `{models}` (the next step after completion is always planning/review). Update `last_commit`, and set `next_action` to "plan <next sprint/phase>". Point `pointers.sprint_plan` at the next `{sprints_dir}/*/sprint_plan.md` (or note it does not exist yet).

3. **Seed a fresh `.ai/next-steps.md`** for the next unit: **Now** = next phase/sprint in `planning`; **Just done** = one line noting the prior sprint archived + its commit; **Next** = "plan <next unit>" + the planning model; **Pointers** = `{roadmap}` + the next sprint_plan (or "to be written").

4. **Prune squash-merged local branches** (a sprint boundary is when the just-merged `sprint/NN-*` branch becomes dead — the "squash trap"). With squash merges, `git branch --merged {pr_base}` **cannot** see these branches; ask GitHub which PRs merged and `-D` **only** those — never an unmerged or PR-less branch, never `{pr_base}`, never the current branch:

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
   that commit, and the skip message names the real reason. The comparison uses a bare `git
   rev-parse "$b"` on purpose: `$b` comes from `%(refname:short)`, which renders a branch
   shadowed by a same-named tag as `heads/<name>`, so the bare form resolves correctly — do
   not "tighten" it to `refs/heads/$b`, which in that case does not resolve at all.

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

5. **Report** what was archived, the new `current_sprint_id`, the next action, and the branches pruned. Remind the user to commit the archival (the tracked `next-steps.md` change + `{roadmap}`) if they want it durable. If this same session did the sprint's work (so its friction is in context), offer a **`/way-of-working:retro`** pass before moving on — a sprint close is a natural retrospective moment; skip it silently if the working session was elsewhere.

6. **Consider bumping the plugin pin.** A sprint close is the one ritual that reliably
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
- Never delete `{roadmap}` history or the sprint_plan files — archival only moves the `.ai/` cursor snapshot; the deep record stays in the repo's docs and in git.
- Never archive an un-approved or uncommitted sprint.
- The branch prune deletes **only** branches whose PR GitHub reports `merged` (via `gh`); it never touches an unmerged branch, a branch with no PR, `{pr_base}`, the current branch, or a branch whose local tip is not the commit GitHub merged. `git branch -D` is safe here precisely because merged-ness is confirmed out-of-band (a squash-merged branch looks "unmerged" to git) — but that argument covers the commit GitHub merged and nothing added since, which is why the tip check (against `headRefOid`, never against `origin/<branch>`) is part of the prune and not an optional refinement.
