---
name: pr-checks
description: >-
  Report the status of a PR's required checks and give an explicit merge-ready verdict
  WITHOUT merging. Run when asked whether a PR is green / ready to merge, or to poll a PR
  whose checks are still running. Reports ALL required checks (never a subset), decodes the
  skipped/BLOCKED/conflict traps, and never merges — the human's merge is the approval.
---

# /pr-checks — report required-check status and merge-readiness (never merge)

Goal: answer "is PR #N ready to merge?" with a trustworthy, complete verdict — every
required check named and classified — and stop there. **Never** merge, `--approve`, or
force-push. The human's merge is the approval. This is a read-only status skill.

Argument: a PR number (e.g. `/pr-checks 94`). If none is given, resolve it from the
current branch with `gh pr view --json number`.

## The required checks

**Read `.ai/project.yml` first.** `{ruleset.required_checks}` is the authoritative list —
the checks the `{ruleset.name}` ruleset requires on `{pr_base}`.

Report **every** name in that list, every time. A partial "looks green" is exactly the trap
that causes early merges. If a required check is *absent* from the results, that is a
finding, not a pass — a required check that never got created still blocks the merge.

Report **only** those names as required. Other checks may run on the PR; they are
informational and must not be presented as gating, or the verdict overstates what is
actually enforced.

> **Without `.ai/project.yml`, this skill cannot give a verdict.** Say
> `no .ai/project.yml — cannot determine the required-check set` and report the raw
> `gh pr checks` output as *unclassified*. Never infer the required list from what happens
> to have run: a check can run without being required, and a required check can be missing
> entirely — which is the exact case worth catching.

## Steps

1. **Pull status in one shot.** Run:

   ```bash
   gh pr checks <N>                       # per-check state (pass/fail/pending/skipping)
   gh pr view <N> --json number,title,mergeable,mergeStateStatus,isDraft,headRefName,baseRefName,url
   ```

   `gh pr checks` exits non-zero when any check is failing/pending — that is expected, not
   an error; read its output regardless.

2. **Classify each required check.** Report `green` / `red` / `pending` / `missing` for
   every name in `{ruleset.required_checks}`. Then decode the ambiguous states — this is
   where the value is:

   - **`skipped` ≠ `failure`, but also ≠ a free pass.** A job can report `skipped` two ways:
     (a) a *deliberate condition* — e.g. on a PR touching none of `{code_paths}`, a test
     job's steps may short-circuit, and a review gate may be exempt. Those skips are
     legitimately green-equivalent. (b) a `needs:` dependency **failed** — the downstream
     job then reports `skipped` too. That is a *red*, masquerading. Confirm which by
     checking whether any upstream job actually failed before you call a skip benign.
   - **`mergeStateStatus: BLOCKED` with nothing red or pending** = GitHub re-evaluation
     lag, **not** a problem. Say so and wait — do **not** intervene, re-run, or push.
   - **`mergeable: CONFLICTING`** = the PR is out of date / has conflicts and may be
     running **zero** CI silently. GitHub cannot build the merge ref when a PR is not
     mergeable, so `pull_request` workflows never start — and zero checks looks almost
     identical to checks still queuing. A "green" here proves nothing. Flag it and note the
     branch needs refreshing (merge `{pr_base}` *into* the branch — never force-push).
   - **`isDraft: true`** — checks may be intentionally incomplete; surface it.

3. **Check for the superseded-review-run trap** — only when `{review.ci_gate}` is set. Skip
   this step entirely when it is `null`; there is no review check to go stale.

   A repo whose review gate fires on both `pull_request` and `pull_request_review` gets
   *two* `{review.ci_gate.check}` check-runs on one commit: the first fails correctly (no
   review posted yet), the second passes once the review is posted — and **the failed one
   never self-clears**. The signature is `BLOCKED` + a failing rollup + both a `success`
   **and** a `failure` for that check name on the same SHA:

   ```bash
   SHA=$(gh pr view <N> --json headRefOid -q .headRefOid)
   gh api "repos/{repo}/commits/$SHA/check-runs" \
     --jq '.check_runs[] | select(.name=="{review.ci_gate.check}") | {id, conclusion, url: .html_url}'
   ```

   If a review is genuinely posted and its own run is green, the fix is to **re-run the
   stale failed run** — `gh run rerun <old_failed_run_id>` (the run id is in the failed
   check-run's URL) — and **never a new push**: a push changes the SHA and re-arms the trap.
   Re-running a stale CI check is not merging, approving, or force-pushing; it is the one
   sanctioned write this skill makes, and only on this exact, confirmed signature.

4. **State a single explicit verdict.** One of:
   - **READY** — every check in `{ruleset.required_checks}` is green (or legitimately
     skipped per step 2a) **and** `mergeable` is not `CONFLICTING`. Tell the user "PR #N is
     ready to merge — merge it yourself; I will not." List every required check with its
     state so the readiness is auditable.
   - **STALE-RED (auto-clearable)** — only possible when `{review.ci_gate}` is set. The
     *only* red is a superseded `{review.ci_gate.check}` failure on the head SHA (the step-3
     signature), the review is posted, and its own run is green. This is not a real failure.
     Offer to `gh run rerun <old_failed_run_id>` (or, in a `/loop`/scheduled context, do it
     and re-poll); it clears to READY with no push. Say clearly this is the stale-run
     workaround, not a merge.
   - **NOT READY (red)** — a *genuine* failure (any red that is not the stale-red above).
     Name every failing check and, for each, the one-line reason from its job log
     (`gh run view <run-id> --job <job-id> --log` grep'd to the failure).
   - **PENDING** — name which checks are still running. If invoked from a `/loop` or a
     scheduled run, reschedule another poll; otherwise tell the user it's still running
     and offer to re-check.

5. **Never act on the PR** — with one narrow, documented exception. No `gh pr merge`, no
   `gh pr review --approve`, no `git push --force`, ever. If the user asks you to merge,
   confirm the verdict is READY and hand it back — the merge click is theirs. The **only**
   sanctioned write is `gh run rerun <old_failed_run_id>` on a **confirmed** stale review
   run (step 3).

## Report shape

List every required check by name with its state, then the merge state, then one verdict
line. The example below is shaped for an 8-check repo with a review gate; the names and the
count come from `{ruleset.required_checks}`, so a repo with four checks prints four.

```
PR #94 — "test(core): land the mutation-audit fix verdicts" (sprint/38-t3 → main)

  lint             ✅ pass        secrets-scan       ✅ pass
  format-check     ✅ pass        dependency-audit   ✅ pass
  test             ✅ pass        sbom               ✅ pass
  pr-title         ✅ pass        <review gate>      ✅ pass (docs-only, exempt)

  mergeable: MERGEABLE   state: CLEAN

Verdict: READY — all 8 required checks green. Merge it yourself when you're ready; I won't.
```
