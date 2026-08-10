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
   merged=$(gh pr list --state merged --limit 300 --json headRefName -q '.[].headRefName')
   cur=$(git branch --show-current)
   for b in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
     case "$b" in "$base"|"$cur") continue;; esac
     printf '%s\n' "$merged" | grep -qxF "$b" && git branch -D "$b" && echo "pruned $b"
   done
   ```

   Report which branches were pruned (or "none"). Hygiene, not a gate — if the `gh` call fails, skip and say so.

5. **Report** what was archived, the new `current_sprint_id`, the next action, and the branches pruned. Remind the user to commit the archival (the tracked `next-steps.md` change + `{roadmap}`) if they want it durable. If this same session did the sprint's work (so its friction is in context), offer a **`/way-of-working:retro`** pass before moving on — a sprint close is a natural retrospective moment; skip it silently if the working session was elsewhere.

6. **Consider bumping the plugin pin.** A sprint close is the one ritual that reliably
   recurs, which makes it the right moment to check whether `.claude/settings.json` points
   at the newest `claude-workbench` tag. Tag-pinning makes upgrades opt-in, and opt-in
   without a trigger means never. Mention the current pin and whether a newer tag exists;
   bumping it is a one-line PR the human decides on — do not bump it silently.

   **Say what the bump would bring, not just that one exists.** Read the plugin's
   `CHANGELOG.md` for the entries between the pinned tag and the newest one, and surface any
   marked as needing a migration — "a newer tag exists" is not a decidable prompt, and a
   breaking change discovered *after* the bump is discovered in the worst place. Pair a bump
   with a plugin-cache clear and confirm the version actually rotated: a pin bump has been
   observed not to be honored by the local cache.

## Guardrails
- Never delete `{roadmap}` history or the sprint_plan files — archival only moves the `.ai/` cursor snapshot; the deep record stays in the repo's docs and in git.
- Never archive an un-approved or uncommitted sprint.
- The branch prune deletes **only** branches whose PR GitHub reports `merged` (via `gh`); it never touches an unmerged branch, a branch with no PR, `{pr_base}`, or the current branch. `git branch -D` is safe here precisely because merged-ness is confirmed out-of-band (a squash-merged branch looks "unmerged" to git).
