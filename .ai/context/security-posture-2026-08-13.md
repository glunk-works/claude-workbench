# Security posture snapshot — `glunk-works`, 2026-08-13

Read-only capture of all 8 org repos, taken **before any setting was flipped**, per
[#28](https://github.com/glunk-works/claude-workbench/issues/28) decision 8 and its review
item 6 ("no snapshot before destructive changes"). Captured as `Seuss27`, `admin` on all 8.
All 8 repos are public and none are archived.

## Per-repo settings

| Repo | PVR | Secret scan | Push prot | Validity checks | Dependabot alerts | Dependabot sec. updates |
|---|---|---|---|---|---|---|
| appsec-triage-agent | **off** | enabled | enabled | disabled | enabled | enabled |
| bedrock-serverless-rag | on | enabled | enabled | disabled | enabled | enabled |
| bounty-infra | **off** | enabled | enabled | disabled | enabled | enabled |
| claude-workbench | on | enabled | enabled | disabled | enabled | enabled |
| global-bootstrap | **off** | enabled | enabled | disabled | enabled | enabled |
| loop-orchestrator | **off** | enabled | enabled | disabled | enabled | enabled |
| pm-agent-loop | on | enabled | enabled | disabled | enabled | enabled |
| scope-core | on | enabled | enabled | disabled | enabled | enabled |

Sources: `GET /repos/{owner}/{repo}` (`.security_and_analysis.*`),
`GET /repos/{owner}/{repo}/private-vulnerability-reporting`, and
`GET /repos/{owner}/{repo}/vulnerability-alerts` (204 = enabled, 404 = disabled).

## Alerts — all states, not only open

Zero secret-scanning alerts, zero Dependabot alerts, on every repo. This includes
`bedrock-serverless-rag`, which #28 singled out as the urgent case: its history has already
been scanned and is clean, so review item 2's "enabling secret scanning may surface live
historical credentials" risk did not materialise.

Code scanning: only `bounty-infra` has any analysis (0 open alerts); the other 7 return
`no analysis found`.

## Org level

- New-repo defaults on `glunk-works`: Dependabot alerts, Dependabot security updates, secret
  scanning, and push protection are all **on**; advanced security is off.
- Code security configurations: only GitHub's built-in global preset `GitHub recommended`
  (id 17). It is **not** the default for new repos and is **attached to zero repos** — the
  posture above is per-repo settings, not a configuration.

## Delta against #28's survey, and what it means

#28's survey (2026-08-11) recorded secret scanning and push protection **off** on
`claude-workbench`, `scope-core`, and `bedrock-serverless-rag`, and Dependabot alerts **off**
on `bedrock-serverless-rag`. None of that holds two days later.

The cause cannot be established: `GET /orgs/glunk-works/audit-log` returns 404 on this
plan. GitHub's default-on rollout for public repositories would explain the secret-scanning
and push-protection columns, but not `bedrock-serverless-rag`'s Dependabot alerts, which is
not covered by any default that applies to existing repos.

**The operative lesson is the decay rate, not the cause.** A hand-captured posture survey was
materially wrong about the one repo the whole initiative was prioritised around, within two
days. Decision 8's remaining work is what this snapshot says it is, not what the survey said.

## What decision 8 actually reduced to

Enabling private vulnerability reporting on the four repos where it was off:
`loop-orchestrator`, `global-bootstrap`, `bounty-infra`, `appsec-triage-agent`. Every other
control named in decision 8 was already satisfied on all 8 repos.

Out of decision 8's scope, recorded but not acted on: secret-scanning **validity checks** are
disabled on all 8, and 7 of 8 repos have no code scanning at all.

## After — verified 2026-08-13, decision 8 complete

The four `PUT /repos/{owner}/{repo}/private-vulnerability-reporting` calls were run by the
repo owner directly (the session's tooling declined the write). Re-reading all 8 repos from
the same endpoints as the before-table:

| Control | Before | After |
|---|---|---|
| Private vulnerability reporting | 4 of 8 | **8 of 8** |
| Secret scanning | 8 of 8 | 8 of 8 |
| Push protection | 8 of 8 | 8 of 8 |
| Dependabot alerts | 8 of 8 | 8 of 8 |

All four controls named in decision 8 are now on across every `glunk-works` repo, and the
posture is uniform for the first time. Nothing else was changed; secret scanning was already
on everywhere, so no new history scan was triggered and no alert surfaced.

This re-read *is* review item 5's missing verification step: the survey that opened the work
is the check that closes it.

## Validity checks — attempted 2026-08-14, declined (#44)

[#44](https://github.com/glunk-works/claude-workbench/issues/44) proposed enabling
secret-scanning **validity checks** on all 8 repos — the item recorded above as outside
decision 8's scope. It was attempted and **declined: the feature is not available on this
org's plan.**

`PATCH /repos/{owner}/{repo}` with
`security_and_analysis.secret_scanning_validity_checks.status=enabled` returns **200 and
changes nothing.** Re-reading all 8 repos afterwards showed `disabled`, unchanged. Two further
reads explain why:

- `GET /orgs/glunk-works` reports
  `secret_scanning_validity_checks_enabled_for_new_repositories: null` — not `false`. The org
  plan (`free`) cannot express the setting at all.
- The only code security configuration offering it, GitHub's built-in `GitHub recommended`
  preset, pairs `secret_scanning_validity_checks: enabled` with `advanced_security: enabled`.

Validity checks require **GitHub Secret Protection** ($19/committer/month), which requires
GitHub Team ($4/user/month) or Enterprise. For a solo maintainer that is ~$276/year, bought to
prioritise a secret-scanning alert queue this snapshot recorded as **empty on all 8 repos, in
every state**. Declined on that basis; reversible if the org's plan or alert volume changes.

**The operative lesson is that a 200 is not a confirmation.** The write was accepted, reported
success, and did nothing. Only the re-read caught it — the snapshot-change-re-read discipline
review item 6 imposed for *destructive* changes turns out to matter just as much for a change
that silently never happens.

Two corrections to #44 as filed, recorded so the next reader does not repeat them:

- Its cost claim ("One setting per repo… no per-repo judgment") was wrong. The true cost is a
  plan upgrade, not a setting.
- Its `gh api -f 'security_and_analysis[secret_scanning_validity_checks][status]=enabled'`
  form does not nest: `-f` does not expand bracket notation into a nested object, so it sends
  a flat key the endpoint ignores. A nested JSON body via `--input` is required. This was
  **not** the cause of the no-op — the corrected form was run and no-ops identically — but it
  would have masked the licensing finding as a syntax error.

This does **not** extend to code scanning: CodeQL is free for public repositories, so
[#45](https://github.com/glunk-works/claude-workbench/issues/45) is unaffected by this gate.
