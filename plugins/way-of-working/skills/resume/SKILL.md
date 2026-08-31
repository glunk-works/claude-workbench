---
name: resume
description: >-
  Rehydrate a fresh dev session from .ai/ externalized state — read the cursor, adopt the
  assigned persona/model, and state the exact pick-up point. Then start the next_action
  unattended IF the cursor is clean and unambiguous (hitl_gate NONE OPEN, sprint_status
  implementing, model matches, no drift); otherwise state the pick-up point and wait. Fails
  closed — an open, missing, or unreadable gate always waits. Run this at the START of a
  session working on this repo.
---

# /way-of-working:resume — rehydrate a fresh session from externalized state

Goal: start a new (lean) session already knowing exactly where the last one left off,
without re-reading the whole repo. This is the counterpart to `/way-of-working:handoff`.

**Read `.ai/project.yml` first.** Keys below in braces — `{roadmap}`, `{ruleset.name}` — are
read from it, never typed as literals. If it is missing or unreadable, say so and skip only
the steps that need it (step 4 in particular); never guess a ruleset name or a check list.
See `reference/project-schema.md`.

## Same-conversation shortcut

If this `/way-of-working:resume` is invoked **within the same live conversation** as an earlier one in
this repo (no `/clear` in between — e.g. a `/model` switch mid-session, not a fresh
session), steps 3 (branch prune) and 4 (ruleset check) may cite their **already-known
result** instead of re-running — but only when you can positively rule out an invalidating
event since the last check: for step 3, no PR has merged since the last prune scan; for
step 4, no permissions/ruleset-touching action **and no identity change** has occurred
since — an account switch invalidates the reach check that step now opens with. Say which you're
reusing and why (`Ruleset check: still healthy, confirmed earlier this conversation — no
ruleset-touching action since.`). Step 2 (`git log`/`git status`) should still run — git
state changes routinely mid-session (commits, pushes, merges) — but skip a redundant
`.ai/state.json` **Read** if you already hold its current content in context and have not
edited it since.

**Default to the full checklist whenever unsure.** This shortcut exists to cut *provably*
idempotent re-checks (both steps 3 and 4 are read-only, external, and rarely change), not
to weaken the fail-closed posture below — if you cannot positively rule out an invalidating
event, run the check.

## Steps

1. **Read the cursor** (in this order, stop reading once you have enough):
   - `.ai/state.json` — the machine cursor (`current_phase`, `current_sprint_id`, `sprint_status`, `assigned_model`, `assigned_persona`, `last_commit`, `next_action`, `hitl_gate`, `pointers`). If it is missing, fall back to `.ai/next-steps.md` alone — and note that a `/way-of-working:resume` running on `next-steps.md` alone can never auto-start (step 6): no cursor, no unattended work.
   - `.ai/next-steps.md` — the human ledger: what was just done, what's next, which model to use, HITL Gate status.
   - The `pointers.sprint_plan` file (the active `{sprints_dir}/*/sprint_plan.md`) — the task list for the current sprint.
   - `{roadmap}` — read only its **status table** + its **next action** line, not the whole file, unless the next action needs the decisions log (`{decisions.log}`).

2. **Check reality vs. the cursor.** Run `git log --oneline -5` and `git status --short`. If
   the tree is dirty, surface that — a previous session may not have finished a
   `/way-of-working:handoff`.

   Then classify `last_commit` against HEAD with the plugin's own script — this is a
   deterministic predicate, not a judgment call, and prose already got it wrong twice (plain
   SHA equality, then a commit-*range* form that only means what it looks like when
   `last_commit` is an ancestor of HEAD — squash-merge routinely makes it not one). `bin/` is
   on the Bash tool's `PATH` while the plugin is enabled, so call it by bare name, no
   `${CLAUDE_PLUGIN_ROOT}` needed:
   ```bash
   cursor-drift.sh <last_commit>
   ```
   It prints exactly one of `clean | cursor-sync | drift | unreadable`, always from a
   two-argument tree diff — **never** a commit range, and never a commit count, both of
   which silently break under squash-merge. The **policy** — what a session does with each
   answer — stays here, not in the script:

   - **`clean`** — `last_commit` is HEAD. Not drift.
   - **`cursor-sync`** — HEAD differs from `last_commit` only in `.ai/next-steps.md`. **Not
     drift.** This is the expected shape of a merged `/way-of-working:handoff`: it sets
     `last_commit` to HEAD *before* committing `.ai/next-steps.md` and opening that commit as
     a docs-only PR, so the moment the human merges it, HEAD has moved past `last_commit` by
     exactly the cursor-sync commit. `.ai/state.json` is git-ignored, so nothing corrects
     `last_commit` afterwards — recognising this case is required, not optional, or auto-start
     can never fire in the intended flow.
   - **`drift`** — anything else differs too. If the work branch named by `last_commit`
     simply hasn't merged yet, this is the **correct** answer, not a false alarm: the cursor
     describes work `{pr_base}` does not have yet. Wait. (Rejected: widening the allowlist to
     "docs-shaped paths" generally — a roadmap or sprint-plan edit between sessions can
     invalidate the very `next_action` auto-start is about to run unattended, which is the
     one thing this check exists to catch.)
   - **`unreadable`** — git cannot read `last_commit` at all. Wait.

   Say which case you found in one line, e.g. `HEAD differs from last_commit only in
   .ai/next-steps.md — the merged cursor-sync PR, not drift.` Anything the script cannot
   classify as `clean` or `cursor-sync` is drift.

3. **Prune squash-merged local branches** (standard practice — squash-merge is the default here, and `git branch --merged {pr_base}` **cannot** see a squash-merged branch because the squash makes a new commit the branch never became an ancestor of; so ask GitHub which PRs merged). One read-only `gh` call, then a safe `-D` on **only** the branches whose PR GitHub reports `merged` — never an unmerged or PR-less branch, never `{pr_base}`, never the current branch:
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
   `-D` is safe only **per commit**, not per branch. Merged-ness is confirmed out-of-band,
   but a merged branch whose local tip has moved since the push still deletes without
   complaint — and a squash-merged branch's commits are unreachable, so that work is gone
   with no warning. So the candidate test asks GitHub *which commit it merged*
   (`headRefOid`, free in the call already being made), and the deletion happens only when
   the local tip **is** that commit.

   **Do not substitute the obvious "is my tip pushed?" test** — `git rev-list --count
   origin/$b..$b`. GitHub deletes the head branch on merge, and the first `git fetch
   --prune` (or `fetch.prune=true`, or `git remote prune`) drops the local tracking ref;
   after that `origin/<branch>` resolves for no merged branch at all, the count command
   fails, and any fallback that fails safe skips **everything**. The prune becomes a
   permanent no-op that reports every branch as carrying unpushed work. `headRefOid` is
   immune — the PR record keeps it after the branch is gone.

   Report in the pick-up summary in **at most one line**, and **never drop a skip** — a
   skipped branch is stranded work, and it is the one outcome here worth a human's
   attention (e.g. `Pruned 6 squash-merged local branches.` / `Pruned 5; skipped feat/x —
   its tip is not what GitHub merged.` / `No stale branches to prune.`). This is hygiene,
   not a gate — never block the session on it; if the `gh` call fails, skip pruning and
   say so.

4. **Check the branch-protection ruleset for drift.** A scheduled drift job catches drift
   between sessions; this catches it at the moment work resumes, which in a solo repo is
   when nearly every change begins.

   **First, establish that this session can actually reach the repo.** One read-only call,
   before the ruleset call:
   ```bash
   gh api repos/{repo} --jq .permissions     # e.g. {"admin":true,"push":true,…}
   ```
   If it errors, or returns neither `admin` nor `push`, **stop here** — do not make the
   ruleset call, whose answer could not mean anything. Report, naming the identity
   (`gh api user --jq .login`):
   `Ruleset check: could not run — authenticated as <login>, which lacks access to {repo}.`

   This is not belt-and-braces. **"Couldn't look" has two causes that need opposite
   responses** — the ruleset is genuinely weakened (a security finding, act on it), or this
   session is the wrong identity (nothing is wrong with the ruleset and the whole preflight
   is meaningless) — and GitHub answers an unreachable resource with **`404 Not Found`, not
   `403`**. So without this call the failure reads as *"that ruleset does not exist"*:
   indistinguishable from the finding this step exists to raise, and pointing the wrong way.

   > **Never infer reach from `gh auth status`.** It reports token **scope**, and scope is
   > not reach. The two come apart exactly when it matters: an account with no membership in
   > the owning org can advertise a *broader* scope list than the one that actually works, so
   > the operator reads more capability and gets none — green checkmarks, zero access.
   > (`gh auth switch` with no argument is the same trap: with one account authenticated it
   > prints a success line for a no-op, which reads as confirmation that an identity change
   > took effect.) Ask the **repo** what this token can do; never ask the token what it
   > claims, and never parse that output.

   Then the ruleset itself. One read-only call, no new token scope:
   ```bash
   gh api repos/{repo}/rules/branches/{pr_base}
   ```
   Confirm the response carries **every** rule type in `{ruleset.rule_types}`, that the
   ruleset named `{ruleset.name}` is among those applying, and — if
   `required_status_checks` is one of them — that its contexts cover **every** name in
   `{ruleset.required_checks}`. Report in the pick-up summary, **at most one line**:
   - Healthy → e.g. `Ruleset check: healthy ({N} rule types, {M} required checks).`
   - Weakened or missing → impossible to miss; name exactly what is absent. The reach check
     above is what earns this verdict the right to be stated as a finding rather than a
     maybe.
   - The call itself failed (network/auth), or `.ai/project.yml` did not supply the
     expected shape → report **inconclusive**, never healthy, and say **which** of the two
     it was — an unreachable identity and a failed lookup are different reports. A preflight
     that cannot tell "healthy" from "couldn't look" is the whole defect it exists to catch,
     in miniature; one that cannot tell "couldn't look" from "isn't there" is that same
     defect one layer down.

   This is a report, not a gate — never block or fail the session on its result.

5. **Adopt the assigned persona/model.** If `assigned_model` does not match the model you are running as, say so explicitly and recommend the user `/model` switch before continuing. The role→model mapping is `{models}` (typically architect for planning/review, coder for implementation — see `reference/workflow.md`).

6. **State the pick-up point** in 3–6 lines: current phase/sprint, sprint_status, the single next action, any open HITL Gate, the ruleset check result, and the branch-prune result.

   Then **either start the next action or wait**, per the rule below.

   **Auto-start** — begin the `next_action` immediately, no "go" needed, only when **all** hold:
   - `hitl_gate` is present and reads `NONE OPEN`;
   - `sprint_status` is `implementing`;
   - the running model matches `assigned_model` (step 5);
   - step 2's `cursor-drift.sh` reported `clean` or `cursor-sync` (either is "no drift")
     **and** the tree is clean.

   Otherwise **state the pick-up point and wait.** In particular: always wait on
   `planning` (the planning pass is one question at a time — that dialogue *is* the
   work), on any open or unreadable gate, on a model mismatch, and on any drift.

   > **Fail closed.** A missing, empty, or unparseable `hitl_gate`, a `state.json` that
   > won't parse, or a `sprint_status` you can't classify all mean **wait** — never
   > proceed. "I couldn't tell whether a gate was open" is not "no gate is open"; that
   > conflation is the same defect as an inconclusive ruleset check reported as healthy.
   >
   > **The `cursor-sync` carve-out above does not soften this**, and must not be read as
   > licence to wave through a delta that merely *looks* routine. It is narrow on purpose:
   > **one named file, verified by the script.** A delta you did not run `cursor-drift.sh`
   > against, or one it classified as `drift` because it carries any path besides
   > `.ai/next-steps.md`, **waits** — however routine its story sounds. Treating some *other*
   > `drift` result as probably harmless would be a real loosening, not a clarification: a
   > roadmap or sprint-plan edit between sessions can invalidate the very `next_action` about
   > to run unattended. If you find yourself reasoning about why a `drift` result is probably
   > fine, that is the failure this block exists to stop.

   Say which branch you took and why in one line (`Auto-starting: gate NONE OPEN,
   status implementing, cursor clean.` / `Waiting: HITL Gate open on the sprint 41 plan.`)
   so the choice is visible and you can stop it.

   **Why auto-start is not a lost approval:** the `next_action` was written by the
   previous session's `/way-of-working:handoff` — which the human reviewed and approved *then*.
   Re-approving it at the start of the next session approves the same decision twice, and
   in practice that second approval is a content-free "go" the overwhelming majority of the
   time. The approval that carries real signal is the **`hitl_gate`**, and it is still
   absolutely enforced. Auto-start removes a rubber stamp, not a gate. It also never
   crosses a merge or review boundary: `/way-of-working:critic-gate` still proposes and the human still
   picks, the human still merges, and nothing here posts a review.

   > **If `{review.ci_gate}` is set and the next action is posting that review:** the review
   > body must **open with the verbatim header and attestation** held in
   > `{review.ci_gate.header}` and `{review.ci_gate.attestation}`. The
   > `{review.ci_gate.check}` check matches both by literal `contains()` — **copy them
   > byte-for-byte out of `.ai/project.yml`; do not retype or reword them.** A reworded
   > attestation fails the gate seconds after posting even though it reads identically to a
   > human. Those strings are frozen wire values, not prose; see
   > `reference/project-schema.md`.
   >
   > **If `{review.ci_gate}` is `null`, this repo has no review CI gate** — there is no
   > review to post and nothing here applies. Say nothing about one.

## Load-on-demand
Only read the plugin's `reference/conventions.md`, `reference/workflow.md`, or this repo's
own `.ai/context/` if the next action actually needs them. The point of `/way-of-working:resume` is a
cheap, targeted rehydrate — not reloading everything.
