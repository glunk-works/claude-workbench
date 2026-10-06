---
name: pr-checks
description: >-
  Report the status of a PR's required checks and give an explicit merge-ready verdict
  WITHOUT merging. Run when asked whether a PR is green / ready to merge, or to poll a PR
  whose checks are still running. Reports ALL required checks (never a subset), decodes the
  skipped/BLOCKED/conflict traps, and never merges — the human's merge is the approval.
---

# /way-of-working:pr-checks — report required-check status and merge-readiness (never merge)

Goal: answer "is PR #N ready to merge?" with a trustworthy, complete verdict — every
required check named and classified — and stop there. **Never** merge, `--approve`, or
force-push. The human's merge is the approval. This is a read-only status skill.

Argument: a PR number (e.g. `/way-of-working:pr-checks 94`). If none is given, resolve it from the
current branch with `gh pr view --json number,url` — and stop with "could not tell" unless
that `url` is under `{repo}`: a checkout whose remote is a fork or mirror would otherwise
resolve a different PR than the one every later call reads (`gh pr view --repo` cannot
resolve a PR without a number).

## The required checks

**Read `.ai/project.yml` first.** `{ruleset.required_checks}` is the authoritative list —
the checks the `{ruleset.name}` ruleset requires on `{pr_base}`.

Report **every** name in that list, every time. A partial "looks green" is exactly the trap
that causes early merges. If a required check is *absent* from the results, that is a
finding, not a pass — a required check that never got created still blocks the merge.

Report **only** those names as required — plus, where the *Classify each required check*
step's `BLOCKED` bullet fetches them, any context the branch's own `required_status_checks`
rule names, reported as *also required by the branch's rule*. Other checks may run on the
PR; they are informational and must not be presented as gating, or the verdict overstates
what is actually enforced.

> **Without `.ai/project.yml`, this skill cannot give a verdict.** Say
> `no .ai/project.yml — cannot determine the required-check set` and report the raw
> `gh pr checks` output as *unclassified*. Never infer the required list from what happens
> to have run: a check can run without being required, and a required check can be absent
> entirely — which is the exact case worth catching.

## Steps

1. **Pull status in one shot.** Run:

   ```bash
   gh pr view <N> --repo {repo} --json number,title,mergeable,mergeStateStatus,reviewDecision,isDraft,headRefName,headRefOid,baseRefName,url
   gh pr checks <N> --repo {repo}         # per-check state (pass/fail/pending/skipping)
   ```

   Every `gh pr` call in this skill that takes the PR number names `--repo {repo}` (the
   argument-resolution call above checks the repo instead), so the PR state and the rules
   read below come from the same repository. The view comes **first** on purpose: a push
   or a retarget between the two calls then shows up when `headRefOid` and `baseRefName`
   are re-read before a verdict that names a merge command (see *READY (admin merge)*),
   rather than being absorbed into the checks.

   `gh pr checks` exits non-zero when any check is failing/pending — that is expected, not
   an error; read its output regardless.

2. **Classify each required check.** Report `green` / `red` / `pending` / `absent` for
   every name in `{ruleset.required_checks}` — the same word the *Read the review gate on
   both surfaces it can post to* step's predicate uses for the identical fact on the
   review-gate check, so a reviewer never sees two words for one state. Then decode the ambiguous states — this is where the value is:

   - **`skipped` ≠ `failure`, but also ≠ a free pass.** A job can report `skipped` two ways:
     (a) a *deliberate condition* — e.g. on a PR touching none of `{code_paths}`, a test
     job's steps may short-circuit, and a review gate may be exempt. Those skips are
     legitimately green-equivalent. (b) a `needs:` dependency **failed** — the downstream
     job then reports `skipped` too. That is a *red*, masquerading. Confirm which by
     checking whether any upstream job actually failed before you call a skip benign.
   - **`mergeStateStatus: BLOCKED` with nothing red or pending** has two readings, and
     the branch's rules decide which. On a repo carrying a restrict-updates ruleset (an
     `update` rule whose only bypass actor is the repository admin role) every green PR
     reads `BLOCKED`, to every viewer, for good — waiting never clears it. Without an
     `update` rule it is usually GitHub re-evaluation lag, though a rule that holds a PR at
     `BLOCKED` the same way (an unresolved conversation, a required deployment) can be
     the cause. Let the tested predicate say which (`#224`); it keys on the `update` rule,
     not on who may bypass it, and it refuses to answer when such a rule applies
     (`#248`).

     The branch to read the rules for is the PR's own base (`baseRefName`), never
     `{pr_base}` — a PR into another branch is judged by that branch's rules. **A branch
     name is untrusted text** (git allows `$`, `(`, `;`, `&` and `|` in one), so it is
     read **inside** each block, validated, and used only as `"$B"` — never typed into a
     command by hand, which is how an attacker's branch name would run on this machine
     (`bin/review-base-anchor.sh` reads its branch inside the script too, though it
     validates with `git check-ref-format` rather than a character set). Two blocks, each one
     chain, for the same reason the review-gate block below is one — a failed call must
     never reach what follows it:

     ```bash
     # (a) the contexts the branch's own required_status_checks rule names
     B=$(gh pr view <N> --repo {repo} --json baseRefName -q .baseRefName) &&
     case "$B" in '' | *[!A-Za-z0-9._/-]*) false ;; esac &&
     gh api --paginate "repos/{repo}/rules/branches/$B" \
       --jq '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
     ```

     If (a) fails, the verdict is COULD NOT TELL and (b) is not run — never compute
     `<green>` from `{ruleset.required_checks}` alone, which is the stale-list failure this
     call exists to close.

     ```bash
     # (b) ask the predicate
     B=$(gh pr view <N> --repo {repo} --json baseRefName -q .baseRefName) &&
     case "$B" in '' | *[!A-Za-z0-9._/-]*) false ;; esac &&
     T=$(gh api --paginate "repos/{repo}/rules/branches/$B" --jq '.[] | .type + (if .type=="pull_request" then " approvals=\(.parameters.required_approving_review_count // 0) threads=\(.parameters.required_review_thread_resolution // false) codeowner=\(.parameters.require_code_owner_review // false) reviewers=\([.parameters.required_reviewers[]?] | length)" elif .type=="required_status_checks" then " app_pinned=\([.parameters.required_status_checks[]? | select(.integration_id != null)] | length)" else "" end)') &&
     { [ -z "$T" ] || printf '%s\n' "$T"; } | blocked-state.sh BLOCKED <green> 2>&1
     ```

     The rule list is captured first (`T=$(…) &&`), so a failed `gh api` stops the chain
     before the predicate — a pipe straight from `gh` would hide that failure — and the
     pipeline's status is the predicate's own. An empty `T` (no rules apply) sends nothing,
     which the predicate reads as "no `update` rule". Each line is a rule type, plus
     `key=value` words for the two types whose parameters matter (`pull_request`,
     `required_status_checks`), so the predicate can see an approval count, thread
     resolution, code-owner review, required reviewers, or a check pinned to an app (`#248`). `2>&1` is so that
     when the predicate refuses (exit 2, nothing on stdout) its one stderr line, which
     names the rules it cannot evaluate, reaches this session to be quoted in the verdict.

     `<green>` is `1` only when **all** of these hold, otherwise `0`: every check in the
     union of `{ruleset.required_checks}` **and** the contexts (a) printed is green (or
     legitimately skipped), with none pending, red, or missing a run; `{ruleset.required_checks}`
     is not empty (an empty list is no evidence, not a vacuous pass); and `reviewDecision`
     is neither `REVIEW_REQUIRED` nor `CHANGES_REQUESTED`. A context (a) names that is not in
     `{ruleset.required_checks}` is reported as *also required by the branch's rule* — it
     gates the merge, so it is not "informational". The script's header carries the rest.
     This block runs only for a `BLOCKED` PR, so the script's fourth word, `not-blocked`,
     never comes from it. Read what it prints strictly: **exactly one** of these three
     words is an answer, and
     anything else — no output, a different word, a non-zero status — is "could not tell":
     - **`lag`** — no `update` rule applies. Usually GitHub is still re-evaluating: say so
       and wait — do **not** intervene, re-run, or push. The predicate has already
       ruled out the rules it can evaluate; if it persists, a rule type it ignores
       (`workflows`, say) may be holding the PR. The verdict is PENDING, below.
     - **`admin-merge-ready`** — the checks and review are in order and an `update` rule
       applies, which on its own keeps a green PR `BLOCKED`. Not lag; do not say wait. The
       verdict is READY (admin merge), below.
     - **`blocked`** — the checks, the review, or the check list are not in order
       (including an empty `{ruleset.required_checks}`, or a context (a) named that has no
       run); report those, not the rule. The verdict is NOT READY or PENDING by what is
       actually wrong.
     - **Could not tell** (exit 2, a failed call, or any other output) — never lag and
       never ready. The verdict is COULD NOT TELL, below. When the output is the
       predicate's `cannot judge a green BLOCKED PR past rules it cannot evaluate: <rules>`
       line, the rules it names (an approval count, thread resolution, a required
       deployment, a check pinned to an app …) are the reason; quote them in the verdict
       instead of a generic caveat.
   - **`mergeable: CONFLICTING`** = the PR is out of date / has conflicts and may be
     running **zero** CI silently. GitHub cannot build the merge ref when a PR is not
     mergeable, so `pull_request` workflows never start — and zero checks looks almost
     identical to checks still queuing. A "green" here proves nothing. Flag it and note the
     branch needs refreshing (merge `{pr_base}` *into* the branch — never force-push).
   - **`isDraft: true`** — checks may be intentionally incomplete; surface it.

3. **Read the review gate on both surfaces it can post to** — only when `{review.ci_gate}`
   is set. Skip this step entirely when it is `null`; there is no review check to go stale.

   A review gate reaches a commit as a **check-run** (the implicit one a workflow job
   creates, named after the job) or as a **commit status** (posted explicitly against the
   resolved head SHA by a job that may be named anything — invisible to a check-runs
   query, which is how this step used to miss it). Read both and let the tested predicate
   resolve them; its header carries the rule — any success on either surface is `success`,
   because a posted review cannot be un-posted; `pending` beats `failure`; `absent` means
   neither surface carries the name:

   ```bash
   SHA=$(gh pr view <N> --repo {repo} --json headRefOid -q .headRefOid) && T=$(mktemp -d) &&
   gh api --paginate "repos/{repo}/commits/$SHA/status" \
     --jq '.statuses[] | ["status", .context, .state] | @tsv' > "$T/s.tsv" &&
   gh api --paginate "repos/{repo}/commits/$SHA/check-runs" \
     --jq '.check_runs[] | ["check-run", .name, .status, (.conclusion // "")] | @tsv' > "$T/c.tsv" &&
   cat "$T/s.tsv" "$T/c.tsv" > "$T/gate.tsv" &&
   review-gate-state.sh "{review.ci_gate.check}" < "$T/gate.tsv"
   ```

   Run it as **one** block: the `&&` chain is load-bearing, because a `gh api` call or a
   file read that failed must never reach the predicate — a document that never arrived
   reads as `absent` — and shell state does not survive between tool calls. On exit 0 its
   stderr line says what each surface carried: **say which shape the gate took** in the
   report. Exit 2 (nothing on stdout) means it could not answer — treat that as not green.

   **The superseded-run trap.** A repo whose gate fires on both `pull_request` and
   `pull_request_review` gets *two* `{review.ci_gate.check}` check-runs on one commit: the
   first fails correctly (no review posted yet), the second passes once the review is
   posted — and **the failed one never self-clears**. The signature is the predicate
   reading `success` while `mergeStateStatus` is `BLOCKED` with a failing rollup, a
   `failure` of the gate's name still on the SHA beside the `success`:

   ```bash
   SHA=$(gh pr view <N> --repo {repo} --json headRefOid -q .headRefOid) &&
   gh api --paginate "repos/{repo}/commits/$SHA/check-runs" \
     --jq '.check_runs[] | select(.name=="{review.ci_gate.check}") | {id, conclusion, url: .html_url}'
   ```

   A status-shaped gate wears the same trap in a different coat: the job that posted the
   green status keeps its own red check-run, under its *job* name, until re-run. Where that
   job's name is not in `{ruleset.required_checks}` it blocks nothing and the verdict is
   READY (or READY (admin merge), on a branch carrying an `update` rule) with a note;
   where it is, treat it exactly as above. Either way the fix is to
   **re-run the stale failed run** — `gh run rerun <old_failed_run_id>` (the run id is in
   the failed check-run's URL) — and **never a new push**: a push changes the SHA and
   re-arms the trap. Re-running a stale CI check is not merging, approving, or
   force-pushing; it is the one sanctioned write this skill makes, only on this exact,
   confirmed signature, and only a run id reached from a check-run whose name is
   `{review.ci_gate.check}` or in `{ruleset.required_checks}` — a rerun re-executes that
   whole workflow run, so the name pins which run you may pick, not what runs.

4. **State a single explicit verdict.** One of:
   - **READY** — every check in `{ruleset.required_checks}` is green (or legitimately
     skipped per the *Classify each required check* step's (a)) **and** `mergeable` is not
     `CONFLICTING` **and** `mergeStateStatus` is not `BLOCKED` — a `BLOCKED` PR is never
     plain READY: it is READY (admin merge), PENDING, NOT READY or COULD NOT TELL by what
     `blocked-state.sh` printed (the *Classify each required check* step's bullet maps each
     word). Tell the user "PR #N is
     ready to merge — merge it yourself; I will not." List every required check with its
     state so the readiness is auditable.
   - **READY (admin merge)** — `blocked-state.sh` printed `admin-merge-ready`: every
     required check is green, the review is not blocking, and an `update` rule applies,
     which on its own keeps a green PR `BLOCKED`. Tell the user "PR #N into `<baseRefName>`
     has every required check green and reads BLOCKED because an update rule applies. As
     `<login>`, the restrict-updates ruleset reports `current_user_can_bypass: <value>` —
     merge it yourself, `gh pr merge <N> --repo {repo} --squash --admin
     --match-head-commit <headRefOid>`, or the web UI's bypass box; I will not." Get
     `<login>` and each `<value>` from one more block, the same shape as (a) and (b)
     (the branch read and validated inside it, used only as `"$B"`):

     ```bash
     # (c) the active identity, and its bypass state per ruleset carrying an update rule
     B=$(gh pr view <N> --repo {repo} --json baseRefName -q .baseRefName) &&
     case "$B" in '' | *[!A-Za-z0-9._/-]*) false ;; esac &&
     L=$(gh api user --jq .login) &&
     I=$(gh api --paginate "repos/{repo}/rules/branches/$B" \
           --jq '.[] | select(.type=="update") | .ruleset_id') &&
     printf 'login %s\n' "$L" &&
     for id in $I; do
       case "$id" in '' | *[!0-9]*) echo "bad-id"; break ;; esac
       printf '%s %s\n' "$id" "$(gh api "repos/{repo}/rulesets/$id" --jq '.current_user_can_bypass // ""')"
     done
     ```

     Report one `<value>` per ruleset when there is more than one. A `never` on any of them
     means this identity cannot perform the `--admin` merge: say so instead, and tell the
     human to merge in the web UI **signed in as a bypass-capable account**, or to run that
     one `gh` command as one (a per-command token, not `gh auth switch`). The verdict stays
     READY (admin merge), since the checks are what it judges. `<login>` is the identity
     **this session's `gh` runs as**; it holds for the human's merge only if theirs is the
     same account — say so. **Never switch the account yourself** (`gh auth switch` is
     global on a host with a concurrent session) — the advice is the human's to act on. A
     failed block, no ruleset line after `login`, a `bad-id` line, or a value that is empty
     or not one of `always`, `pull_requests_only`, `exempt`, `never`, is reported as "could
     not confirm which identity can bypass", never with a value filled in. The base is named so the human sees what the verdict was judged against. Re-read
     `headRefOid` **and** `baseRefName`
     (`gh pr view <N> --repo {repo} --json headRefOid,baseRefName`) just before stating
     this verdict: if either differs from what the *Pull status in one shot* step read, a
     push or a retarget landed since and the checks and rules describe something else —
     start over from that step rather than pin or name the new, unchecked state. Otherwise
     use that `headRefOid`, so a later push is refused rather than merged unchecked (a
     retarget after the verdict is not pinnable: `gh pr merge` has no flag for the base).
     List every required check with its state. This is **not** "bypass the checks": `--admin` still enforces
     every ruleset the admin cannot bypass, which is why the checks must be green first —
     whether the admin can bypass the ruleset holding them is not visible from here (block
     (c) reads only the rulesets carrying an `update` rule). And
     this verdict means the predicate was given the parameters of the two rule types that need them and
     found none it could not judge (`#248`): an approval count, required reviewers, thread resolution,
     code-owner review, a required deployment, code scanning, signatures, a merge queue or
     a check pinned to an app each make it COULD NOT TELL instead. A rule type outside
     that list (`workflows`, a commit-message pattern) it ignores, and the admin's bypass
     would skip those too.
     `blocked-state.sh` does not read bypass actors — `current_user_can_bypass` is `never`
     to a non-admin viewer, so for them it is out of reach; block (c) names the identity.
   - **STALE-RED (auto-clearable)** — only possible when `{review.ci_gate}` is set. The
     *Read the review gate on both surfaces it can post to* step's predicate reads
     `success` and the *only* red is a superseded run of the gate's name (or, on a
     status-shaped gate, its required runner job) on the head SHA — that step's signature.
     This is not a real failure.
     Offer to `gh run rerun <old_failed_run_id>` (or, in a `/loop`/scheduled context, do it
     and re-poll); it clears to READY (or READY (admin merge), on a branch carrying an `update` rule) with no
     push. Say clearly this is the stale-run
     workaround, not a merge.
   - **NOT READY (red)** — a *genuine* failure (any red that is not the stale-red above).
     Name every failing check and, for each, the one-line reason from its job log
     (`gh run view <run-id> --job <job-id> --log` grep'd to the failure). Also the verdict
     when `blocked-state.sh` printed `blocked` with every present check green: say the
     review is blocking (`reviewDecision`), that `{ruleset.required_checks}` is empty, or
     name the branch-rule context with no run (*also required by the branch's rule*) when
     it is not merely queued — a run that has not started yet is PENDING, not red.
   - **PENDING** — name which checks are still running; or, when `blocked-state.sh`
     printed `lag` and nothing is running, say GitHub is still re-evaluating the merge
     state — or that a rule type the predicate ignores is holding it.
     If invoked from a `/loop` or a scheduled run, reschedule
     another poll, but **bound it**: after a few polls with nothing changing, say so and
     stop rescheduling rather than waiting on a state that will not clear. Otherwise tell
     the user it's still running and offer to re-check.
   - **COULD NOT TELL** — a call this verdict depends on failed, or `blocked-state.sh`
     printed anything but one of the three words the *Classify each required check* step's
     bullet lists (including `not-blocked`, which that block should never produce). Say
     which — when it is the predicate's `cannot judge … rules it cannot evaluate: <rules>`
     line, name those rules, so the human knows what to check by hand — and give no
     merge-ready verdict.

5. **Never act on the PR** — with one narrow, documented exception. No `gh pr merge`, no
   `gh pr review --approve`, no `git push --force`, ever. If the user asks you to merge,
   confirm the verdict is READY (or READY (admin merge)) and hand it back — the merge click
   is theirs; naming `--admin` in that verdict is advice, never something this skill runs.
   The **only** sanctioned write is `gh run rerun <old_failed_run_id>` on a **confirmed** stale review
   run (the *Read the review gate on both surfaces it can post to* step).

## Report shape

List every required check by name with its state, then the merge state, then one verdict
line. The example below is shaped for an 8-check repo with a review gate; the names and the
count come from `{ruleset.required_checks}`, so a repo with four checks prints four. A
required check with no run on the head SHA prints as `absent` — never omitted — the same
word the *Classify each required check* and *Read the review gate on both surfaces it can
post to* steps use for the identical fact.

```
PR #94 — "test(core): land the mutation-audit fix verdicts" (sprint/38-t3 → main)

  lint             ✅ pass        secrets-scan       ✅ pass
  format-check     ✅ pass        dependency-audit   ✅ pass
  test             ✅ pass        sbom               ✅ pass
  pr-title         ✅ pass        <review gate>      ✅ pass (docs-only, exempt)

  mergeable: MERGEABLE   state: CLEAN

Verdict: READY — all 8 required checks green. Merge it yourself when you're ready; I won't.
```

On a repo whose branch carries a restrict-updates rule the state line reads `state: BLOCKED`
and the verdict line is `Verdict: READY (admin merge) into main — all 8 required checks
green (plus any contexts the branch rule names, listed); an update rule is why it reads
BLOCKED. As octocat, the ruleset reports current_user_can_bypass: pull_requests_only — gh pr
merge 94 --repo {repo} --squash --admin --match-head-commit <headRefOid>. I won't.`
