# Prompt: write sprint-orchestrator plan v9

Paste everything below the line into a fresh Claude Code session running **Fable 5.1**, with
the working directory `C:\Users\SR116\projects\glunk-works\claude-workbench`.

---

Your job is to write `docs/proposals/sprint-orchestrator-plan-v9.md` by applying decisions and
test results to v8. You are an editor, not a reviewer. Do not commit or push. Do not open
`docs/proposals/analysis/session-export/`. Do not edit any input file below.

## Inputs, read in this order

1. `docs/proposals/V9-EDIT-SPEC.md`: the edit spec, with five maintainer decisions (D1–D5),
   a nine-item editorial bundle, the § 6.8 content, and § 0/§ 9/§ 10 updates. Its "Rules for
   the editing session" bind you.
2. `docs/proposals/V9-TEST-RESULTS.md`: the three tests the spec says ran first (§ 8.7, § 8.8
   as amended by D1, § 8.5 checks 1–3 as amended by D2), plus four maintainer decisions taken
   because of the results. **Where it contradicts the spec, it wins** (the spec says so). Apply
   it and list each such case in your hand-back.
3. `docs/proposals/GITHUB-APP-EVALUATION.md`: the evaluation and scratch-repo test behind
   results-file decision 4 (the loop identity becomes a GitHub App).
4. `docs/proposals/sprint-orchestrator-plan-v8.md`: the base text (2,338 lines). Copy it to
   `docs/proposals/analysis/orchestrator-plan-v8.md` first, as every earlier pass did.

## What changed since the spec was written (from the results file; it wins)

Each line names the results-file section to apply from. These are the contradictions and
additions you are most likely to miss; the results file is authoritative on each.

1. **Sandbox (results decision 1).** The loop container runs **without** Claude Code's sandbox
   (`sandbox.enabled: false`). It cannot start under Docker's default seccomp profile, and
   `enableWeakerNestedSandbox` does not help. This supersedes the parts of spec bundle 2 that
   restate the sandbox's "remaining reasons". Bundle 2's correction that the sandbox does not
   protect the `--plugin-dir` copy still stands as a correction of v8's claims. Carry the
   § 6.2 residuals and the two new § 9 items.
2. **Critic launch line (results decision 2).** D1's critic line gains
   `--tools "<the agent's frontmatter tools>"`; without it `--restricted` strips the agent's
   Bash. Plugin loading is observable from the **stream-json `system/init` event**, not from the
   result JSON. In 2.1.289 the json result has no `plugins` or `plugin_errors` keys, so spec L72
   is wrong.
3. **Coder launch line (B1).** Add `--add-dir /tmp`. Under `--restricted`, `/tmp` is not a
   working directory, contrary to v8 L1567–1568. Note that managed `Bash(...)` allow rules did
   not cover a command that expands `$VAR`, or that takes a path outside the working
   directories, under `dontAsk`.
4. **§ 8.7 tested.** It passed. Rewrite the preflight probe: an `isolated` network has **no
   gateway**, and Docker gave the subnet's `.1` to a container, once the proxy. So the
   preflight asserts "no Gateway" from `docker network inspect`, then probes the VM's addresses
   and `host.docker.internal`'s address **by IP** (it does not resolve on internal networks).
   The test confirms spec bundle 6: the `--internal` gateway reaches the VM, not Windows.
5. **§ 8.5 checks 1–3 tested.**
   - C1 and C2 passed. Option (a) stands; the (e) fallback is not triggered.
   - C3: the admin sees `BLOCKED`, so resume's cursor-sync merge needs `--admin`. The plugin
     change and the `merge-guard.sh` amendment are unblocked.
   - v8 § 4.4's "the server applies bypass regardless of `--admin`" is now **[T]**.
6. **D2's signal replaced (results decision 3).** `viewerCanMergeAsAdmin` read `false` for an
   admin who then merged; drop it. The preflight uses `current_user_can_bypass: never` on every
   applicable ruleset, plus the `update` rule present, per dispatch. Per PR, once checks are
   green, `mergeStateStatus` must be `BLOCKED` as the loop identity.
7. **Loop identity (results decision 4).** A **GitHub App**, not the machine user. This meets D3
   condition (1): an outside-collaborator machine user cannot get a per-repo token. Rewrite
   § 7.2, the § 6.2 rows, D3's PAT wording and the preflight per decision 4's list.
   - Record the one-hour token expiry as an **open** v9 design question.
   - Keep the maintainer's framing: the App is the default "unless/until there is a reason to
     switch".
8. **§ 8.1, any identity.** `author_association` depends on who reads it. The maintainer's own
   issue reads `CONTRIBUTOR` to the loop's credential. So the driver's author-trust reads use the
   maintainer's view, never the loop token. Note too that the § 8.1 name rule (v8 L1779–1783) is
   a decision not yet implemented: `plan-anchor.sh` checks no author today.
9. **Spec bundle 5 refinement.** devcontainers `release-tags` (24335229) carries four rules
   (`creation`, `update`, `deletion`, `non_fast_forward`), not `update` alone.
10. **Side observations to place where they fit:**
    - four builtin plugins load under `--restricted`;
    - the config dir collects `remote-settings.json` and `policy-limits.json`;
    - the OAuth token was absent from the sandboxed Bash environment (untested without the
      sandbox);
    - public issues are readable with no Issues permission.

## How to mark things

- **[O3]** for facts the spec cites (add the legend line the spec gives).
- **[T]** for anything the tests observed. Add to the § 4 legend: "tested on this machine on
  2026-10-04/05 (`V9-TEST-RESULTS.md`, `GITHUB-APP-EVALUATION.md`)".
- Add a "Tested (2026-10-04/05)" note under § 8.5, § 8.7 and § 8.8, plus one for the identity
  decision.
- Decisions from the spec are *Decided (2026-10-04, after the v9 review)*. Decisions from the
  results file keep their own dates and the wording "after the tests" or "after the App test".
- Move every answered item out of § 9's "never executed" lists, and add the new open items from
  the results file's decisions 1, 2 and 4 and from the D3 observation.

## Who you are, for the header and § 0

- The v9 **review** was Opus 5.5.
- The **tests and the App evaluation** were a separate Opus 5.5 session, the same family as the
  reviewer. The results file carries its bias note; carry that note into § 6.8.
- You, the **editor**, are Fable 5.1. Name yourself.
- For the first time since v5, the reviewer did not write the draft, and the results were
  executed rather than reasoned.

## Rules

- **Apply; do not re-review.** Do not reopen any decision (spec D1–D5, results decisions 1–4).
- Do not re-verify evidence unless an edit cannot be made without it.
- If an instruction can't be applied as written (a line moved, a sentence gone), apply its
  intent and list the deviation in your hand-back, not in the plan.
- **Keep v9 no longer than v8 where you can.** The spec notes that nobody counted the document's
  size as a review cost. Prefer replacing superseded text to stacking new notes on old ones;
  keep history in § 6.8, not inline.
- Read-only on GitHub.

## Hand-back (under 400 words)

- the v9 path and its line count against v8's 2,338;
- each place the results file overrode the spec, one line each;
- each deviation from an instruction, with the reason;
- anything in the inputs you could not reconcile, quoted, without resolving it yourself.

The only review after v9 is a diff check against `V9-EDIT-SPEC.md`, `V9-TEST-RESULTS.md` and
`GITHUB-APP-EVALUATION.md`.
