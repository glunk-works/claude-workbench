# Identity model proof on wb-ruleset-scratch (#376)

Proof cases a-k from #376, run against `glunk-works/wb-ruleset-scratch` with the three
WB-D24 Apps (`glunk-dev`, `glunk-review`, `glunk-admin`) and the rulesets saved in
[docs/identity/scratch-rulesets/](../identity/scratch-rulesets/). Two sessions. Raw API output
follows the summary, in the order it was run. Each entry names the identity it ran as.

## Summary

| Case | Claim | Result |
|---|---|---|
| a | dev App can't self-approve or self-merge | **Pass.** Approve: 422 "Can not approve your own pull request". Merge: 405 "Waiting on code owner review". |
| b | a push dismisses an approval | **Pass.** After a dev-App push the approval reads `DISMISSED`, `reviewDecision: REVIEW_REQUIRED` (PR 1, PR 8). |
| c | auto-merge fires after the approval | **Pass with one stall, filed as #432.** Fired 16s (PR 4), 10s (PR 7) and 4s (PR 8) after the approval. PR 1 read `CLEAN`/`APPROVED` with auto-merge armed for 3+ minutes and never fired; a direct dev-App merge pinned to the head then succeeded. PR 8 repeated PR 1's exact sequence and fired. |
| d | a fake status is ignored, a real one counts | **Pass.** With no status: "Required status check is expected". With a `success` posted by a user: "was not set by the expected GitHub app". The Actions-posted status satisfied the rule on every merged PR. Caveat: the combined-status API reads `success` after the fake, so only the ruleset, not that read, tells the sources apart. |
| e | the second code owner's approval merges | **Pass.** JaredGroves-603's approval made PR 5 `CLEAN` and it merged. Precondition: the owner needs write access. Before the invite, the merge message named only Seuss27; after it, "JaredGroves-603 and/or Seuss27". |
| f | the reviewer App's COMMENT is attributable to its stable ID; it can't approve, merge or push | **Pass (re-run).** COMMENT recorded as `glunk-review[bot]`, id 339841158, type Bot. Its APPROVE is accepted but changes nothing (`REVIEW_REQUIRED`, merge still "Waiting on code owner review"). Merge: 403. Push: 403. The scratch repo has no reviewer-ID CI gate, so what is proven is the stable attribution a gate keys on. The session-1 attempt is void (see its note). |
| g | revoking a token kills it | **Pass.** After `wow-admin --revoke` the same token gets 401 "Bad credentials". |
| h | no workflow or release-tag writes | **Pass after a scratch-config fix, filed as #433 for the other repos.** Workflow file: 403. Moving or deleting a `v*` tag: refused by the ruleset. Creating a `v*` tag or a release succeeded until a `creation` rule was added to `wb-tags` (as claude-workbench's `release-tag-creation` already has), after which both were refused ("creations being restricted"). |
| i | the App token reaches only its installation | **Pass.** `installation/repositories` lists only the scratch repo. `.permissions` on the repo reads all `false` for an App token, so it is not a reach signal. |
| j | update-branch works for the dev App | **Pass.** Works with `allow_update_branch: false` (that setting only hides the UI button). 422 "no new commits" when main hasn't moved. |
| k | auto-merge on an already-mergeable PR | **Refused by GitHub, handled by `gh`.** The raw mutation fails with "Pull request is in clean status", as documented. `gh pr merge --auto` merges immediately in that state (`isImmediatelyMergeable`), so `ship` never sees the refusal. Noted on #386, whose "not armed" path won't occur. |

Also observed: the dev App gets 403 on the rule-suites API, so it cannot read why a rule
blocked; the merge error text is the only explanation it sees.

## Configuration changes made during the proof

- **glunk-review** was installed with `pull_requests: write` only, as #372 specified, but `wow-review-mint` (#374) requests `contents`, `checks` and `statuses` read as
  well, so no reviewer token could be minted. The App and its installation now hold
  `contents: read, checks: read, statuses: read, pull_requests: write`. WB-D24 is amended to
  match.
- **glunk-admin** gained `contents: write` and `pull_requests: write` beside the specified
  administration, workflows, environments and actions, because `wow-admin`'s default mint
  requests them. `--perms` narrows any one mint.
- **JaredGroves-603** was invited to the scratch repo with write access (case e).
- **wb-tags** gained a `creation` rule (case h).

## Side effects of the void session-1 case f

Four calls labelled "review App token" ran as JaredGroves-603, a human code owner, not the
reviewer App. They approved and merged PR 6 and pushed `f-reviewer.txt` to `case-f`. Only the
scratch repo was touched. The session-2 helper refuses any token that cannot list its
installation's repositories, which a user token cannot.

## Raw output, session 1 (2026-10-08 evening, UTC 2026-10-09 00:17-01:41)

#### i: reach probe -- .permissions on the repo as the dev App

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch --jq .permissions

```
{"admin":false,"maintain":false,"pull":false,"push":false,"triage":false}
```
exit: 0

#### i: reach probe -- installation repositories

as: dev App token
$ gh api installation/repositories --jq [.total_count,(.repositories|map(.full_name))]

```
[1,["glunk-works/wb-ruleset-scratch"]]
```
exit: 0

#### a: create branch case-a

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-a -f sha=fe67508bcb741339d974e22bf194a6f421c8ceed --jq .ref

```
refs/heads/case-a
```
exit: 0

#### a: commit a file on case-a

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-a.txt -f message=case a -f branch=case-a -f content=Y2FzZSBhCg== --jq .commit.sha

```
39c8020f8dd646d087adf9721f5b4dea0ad8cbd2
```
exit: 0

#### a: open PR

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case a -f head=case-a -f base=main --jq [.number,.state,.user.login]

```
[1,"open","glunk-dev[bot]"]
```
exit: 0

#### a: dev App approves its own PR

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1/reviews -f event=APPROVE -f body=self approve

```
{"message":"Unprocessable Entity","errors":["Review Can not approve your own pull request"],"documentation_url":"https://docs.github.com/rest/pulls/reviews#create-a-review-for-a-pull-request","status":"422"}gh: Unprocessable Entity (HTTP 422)
```
exit: 1

#### a: dev App merges its own PR (no approval)

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/1/merge -f merge_method=squash

```
{"message":"Repository rule violations found\n\nWaiting on code owner review from Seuss27.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}gh: Repository rule violations found

Waiting on code owner review from Seuss27.

 (HTTP 405)
```
exit: 1

#### a: PR 1 merge state after workflow

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1 --jq [.mergeable,.mergeable_state,.merged]

```
[true,"blocked",false]
```
exit: 0

#### a: statuses on PR 1 head

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/case-a/status --jq [.state,(.statuses|map([.context,.state,.creator.login]))]

```
["success",[["scratch/status","success",null]]]
```
exit: 0

#### setup: CODEOWNERS location

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/contents/.github/CODEOWNERS --jq .content|@base64d

```
* @Seuss27 @JaredGroves-603
```
exit: 0

#### setup: CODEOWNERS (docs/)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/contents/docs/CODEOWNERS --jq .path

```
{"message":"Not Found","documentation_url":"https://docs.github.com/rest/repos/contents#get-repository-content","status":"404"}gh: Not Found (HTTP 404)
```
exit: 1

#### d: required-check pin vs the workflow's status -- rule suites for PR 1 head

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/rulesets/rule-suites?ref=refs/heads/case-a&per_page=5 --jq .[]|[.evaluation_result,.result,.actor_name]

```
{"message":"Resource not accessible by integration","documentation_url":"https://docs.github.com/rest/repos/rule-suites#list-repository-rule-suites","status":"403"}gh: Resource not accessible by integration (HTTP 403)
```
exit: 1

#### d: combined check state per GraphQL (required contexts)

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:1){mergeStateStatus reviewDecision commits(last:1){nodes{commit{statusCheckRollup{state contexts(first:10){nodes{__typename ... on StatusContext{context state isRequired(pullRequestNumber:1)}}}}}}}}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"BLOCKED","reviewDecision":"REVIEW_REQUIRED","commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS","contexts":{"nodes":[{"__typename":"CheckRun"},{"__typename":"StatusContext","context":"scratch/status","state":"SUCCESS","isRequired":true}]}}}}]}}}}}
```
exit: 0

#### h: create branch case-g

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-g -f sha=fe67508bcb741339d974e22bf194a6f421c8ceed --jq .ref

```
refs/heads/case-g
```
exit: 0

#### h: write a workflow file on a branch

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/.github/workflows/evil.yml -f message=case g workflow -f branch=case-g -f content=bmFtZTogZXZpbApvbjogcHVzaApqb2JzOiB7fQo= --jq .commit.sha

```
{"message":"Resource not accessible by integration","documentation_url":"https://docs.github.com/rest/repos/contents#create-or-update-file-contents","status":"403"}gh: Resource not accessible by integration (HTTP 403)
```
exit: 1

#### h: create tag v-case-g

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/tags/v-case-g -f sha=fe67508bcb741339d974e22bf194a6f421c8ceed --jq .ref

```
refs/tags/v-case-g
```
exit: 0

#### h: move the tag (force update)

as: dev App token
$ gh api -X PATCH repos/glunk-works/wb-ruleset-scratch/git/refs/tags/v-case-g -f sha=39c8020f8dd646d087adf9721f5b4dea0ad8cbd2 -F force=true --jq .ref

```
{"message":"Repository rule violations found\n\nCannot update this protected ref.\n\n","documentation_url":"https://docs.github.com/rest/git/refs#update-a-reference","status":"422"}gh: Repository rule violations found

Cannot update this protected ref.

 (HTTP 422)
```
exit: 1

#### h: delete the tag

as: dev App token
$ gh api -X DELETE repos/glunk-works/wb-ruleset-scratch/git/refs/tags/v-case-g

```
{"message":"Repository rule violations found\n\nCannot delete this tag\n\n","documentation_url":"https://docs.github.com/rest/git/refs#delete-a-reference","status":"422"}gh: Repository rule violations found

Cannot delete this tag

 (HTTP 422)
```
exit: 1

#### h: create a release (tag write via releases)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/releases -f tag_name=v-case-g-rel -f target_commitish=main --jq .tag_name

```
v-case-g-rel
```
exit: 0

#### d: create branch case-d

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-d -f sha=fe67508bcb741339d974e22bf194a6f421c8ceed --jq .ref

```
refs/heads/case-d
```
exit: 0

#### d: commit with [skip ci] so no real status is posted

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-d.txt -f message=case d [skip ci] -f branch=case-d -f content=Y2FzZSBkCg== --jq .commit.sha

```
7caa2052adf05715188a5ebda737e5a390dce562
```
exit: 0

#### d: open PR 2

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case d -f head=case-d -f base=main --jq [.number,.head.sha]

```
[2,"7caa2052adf05715188a5ebda737e5a390dce562"]
```
exit: 0

#### d: PR 2 statuses before any fake (expect none)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/case-d/status --jq [.state,(.statuses|length)]

```
["pending",0]
```
exit: 0

#### d: PR 2 required-check state before fake

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:2){mergeStateStatus commits(last:1){nodes{commit{statusCheckRollup{state}}}}}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"BLOCKED","commits":{"nodes":[{"commit":{"statusCheckRollup":null}}]}}}}}
```
exit: 0

#### d: merge PR 2 before fake

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/2/merge -f merge_method=squash

```
{"message":"Repository rule violations found\n\nWaiting on code owner review from Seuss27.\n\nRequired status check \"scratch/status\" is expected.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}gh: Repository rule violations found

Waiting on code owner review from Seuss27.

Required status check "scratch/status" is expected.

 (HTTP 405)
```
exit: 1

#### d: post a FAKE scratch/status=success on PR 2's head from a non-Actions source (the maintainer's user account, via the default gh login)

as: none (identity not recorded; superseded by the maintainer-token entry below)
$ gh api repos/glunk-works/wb-ruleset-scratch/statuses/7caa2052adf05715188a5ebda737e5a390dce562 -f state=success -f context=scratch/status -f description=fake, not from Actions --jq [.context,.state,.creator.login]

```
{"message":"Not Found","documentation_url":"https://docs.github.com/rest/commits/statuses#create-a-commit-status","status":"404"}gh: Not Found (HTTP 404)
```
exit: 1

#### d: statuses after the fake

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/case-d/status --jq [.state,(.statuses|map([.context,.state,.creator.login]))]

```
["pending",[]]
```
exit: 0

#### d: merge PR 2 after the fake

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/2/merge -f merge_method=squash

```
{"message":"Repository rule violations found\n\nWaiting on code owner review from Seuss27.\n\nRequired status check \"scratch/status\" is expected.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}gh: Repository rule violations found

Waiting on code owner review from Seuss27.

Required status check "scratch/status" is expected.

 (HTTP 405)
```
exit: 1

#### d: post a FAKE scratch/status=success on PR 2's head from a non-Actions source (the maintainer's user account)

as: maintainer (Seuss27 user token, not an App)
$ gh api repos/glunk-works/wb-ruleset-scratch/statuses/7caa2052adf05715188a5ebda737e5a390dce562 -f state=success -f context=scratch/status -f description=fake, not from Actions --jq [.context,.state,.creator.login]

```
["scratch/status","success","Seuss27"]
```
exit: 0

#### d: statuses after the fake

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/case-d/status --jq [.state,(.statuses|map([.context,.state,.creator.login]))]

```
["success",[["scratch/status","success",null]]]
```
exit: 0

#### d: merge PR 2 after the fake

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/2/merge -f merge_method=squash

```
{"message":"Repository rule violations found\n\nWaiting on code owner review from Seuss27.\n\nRequired status check \"scratch/status\" was not set by the expected GitHub app.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}gh: Repository rule violations found

Waiting on code owner review from Seuss27.

Required status check "scratch/status" was not set by the expected GitHub app.

 (HTTP 405)
```
exit: 1

#### b: PR 1 after the human approval

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:1){mergeStateStatus reviewDecision reviews(first:5){nodes{author{login} state}}}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"CLEAN","reviewDecision":"APPROVED","reviews":{"nodes":[{"author":{"login":"Seuss27"},"state":"APPROVED"}]}}}}}
```
exit: 0

#### b: dev App pushes a second commit to case-a

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-a-2.txt -f message=case b push after approval -f branch=case-a -f content=Y2FzZSBiCg== --jq .commit.sha

```
0e1aa6fcec1e28fea576b0848ee9c8f583ede796
```
exit: 0

#### b: PR 1 after the push (approval stale?)

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:1){mergeStateStatus reviewDecision reviews(first:5){nodes{author{login} state}}}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"BLOCKED","reviewDecision":"REVIEW_REQUIRED","reviews":{"nodes":[{"author":{"login":"Seuss27"},"state":"DISMISSED"}]}}}}}
```
exit: 0

#### b: reviews list after the push

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1/reviews --jq map([.user.login,.state,.commit_id])

```
[["Seuss27","DISMISSED","39c8020f8dd646d087adf9721f5b4dea0ad8cbd2"]]
```
exit: 0

#### c: arm auto-merge (squash, pinned to the head) as the dev App, before any approval

as: dev App token
$ gh api graphql -f query=mutation($id:ID!,$oid:GitObjectID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH,expectedHeadOid:$oid}){pullRequest{autoMergeRequest{enabledBy{login} mergeMethod} state}}} -f id=PR_kwDOVBmbD88AAAABHcddyQ -f oid=0e1aa6fcec1e28fea576b0848ee9c8f583ede796

```
{"data":{"enablePullRequestAutoMerge":{"pullRequest":{"autoMergeRequest":{"enabledBy":{"login":"glunk-dev"},"mergeMethod":"SQUASH"},"state":"OPEN"}}}}
```
exit: 0

#### c: PR 1 state with auto-merge armed

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1 --jq [.state,.merged,.mergeable_state,.auto_merge.merge_method]

```
["open",false,"blocked","squash"]
```
exit: 0

#### c: PR 1 after the re-approval

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1 --jq [.state,.merged,.merged_by.login,.merge_commit_sha]

```
["open",false,null,"770885cf2aa8cad606e0656cb725eb5756b204d7"]
```
exit: 0

#### c: main head after the merge

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/main --jq [.sha,.commit.message,.commit.committer.name]

```
["fe67508bcb741339d974e22bf194a6f421c8ceed","chore: add CODEOWNERS and status-posting workflow","Jared Groves"]
```
exit: 0

#### j: PR 2 behind main? mergeable_state

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/2 --jq [.mergeable_state,.head.sha]

```
["blocked","7caa2052adf05715188a5ebda737e5a390dce562"]
```
exit: 0

#### j: update-branch on PR 2 as the dev App (allow_update_branch is false on the repo)

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/2/update-branch -f expected_head_sha=7caa2052adf05715188a5ebda737e5a390dce562

```
{"message":"There are no new commits on the base branch.","documentation_url":"https://docs.github.com/rest/pulls/pulls#update-a-pull-request-branch","status":"422"}gh: There are no new commits on the base branch. (HTTP 422)
```
exit: 1

#### j: PR 2 after update-branch

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/2 --jq [.mergeable_state,.head.sha]

```
["blocked","7caa2052adf05715188a5ebda737e5a390dce562"]
```
exit: 0

#### c: PR 1 state, reviews and auto-merge

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:1){state merged mergeStateStatus reviewDecision autoMergeRequest{enabledBy{login}} headRefOid reviews(first:5){nodes{author{login} state commit{oid}}}}}}

```
{"data":{"repository":{"pullRequest":{"state":"OPEN","merged":false,"mergeStateStatus":"CLEAN","reviewDecision":"APPROVED","autoMergeRequest":{"enabledBy":{"login":"glunk-dev"}},"headRefOid":"0e1aa6fcec1e28fea576b0848ee9c8f583ede796","reviews":{"nodes":[{"author":{"login":"Seuss27"},"state":"DISMISSED","commit":{"oid":"39c8020f8dd646d087adf9721f5b4dea0ad8cbd2"}},{"author":{"login":"Seuss27"},"state":"APPROVED","commit":{"oid":"0e1aa6fcec1e28fea576b0848ee9c8f583ede796"}}]}}}}}
```
exit: 0

#### c: PR 1 a minute later

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1 --jq [.state,.merged,.merged_by.login,.mergeable_state,.auto_merge.enabled_by.login]

```
["open",false,null,"clean","glunk-dev[bot]"]
```
exit: 0

#### c: PR 1 timeline events

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/issues/1/timeline --jq .[]|[.event,.actor.login,.created_at]|@tsv

```
committed		
review_requested	glunk-dev[bot]	2026-10-09T00:51:55Z
reviewed		
committed		
review_dismissed	glunk-dev[bot]	2026-10-09T00:57:08Z
auto_squash_enabled	glunk-dev[bot]	2026-10-09T00:57:50Z
reviewed		
```
exit: 0

#### c: PR 1 ~5 minutes after the approval

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1 --jq [.state,.merged,.mergeable_state,.auto_merge.enabled_by.login,.updated_at]

```
["open",false,"clean","glunk-dev[bot]","2026-10-09T00:58:37Z"]
```
exit: 0

#### c: scratch repo workflow runs since the approval

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/actions/runs --jq .workflow_runs[0:4]|map([.id,.event,.conclusion,.created_at])

```
[[37867354304,"pull_request","success","2026-10-09T00:57:11Z"],[37866921372,"pull_request","success","2026-10-09T00:51:58Z"],[37863994513,"push","success","2026-10-09T00:17:15Z"]]
```
exit: 0

#### c: repo merge settings

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch --jq [.allow_auto_merge,.allow_squash_merge,.allow_merge_commit,.allow_rebase_merge]

```
[true,true,true,true]
```
exit: 0

#### c: dev App merges the approved, clean PR 1 directly (auto-merge had not fired)

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/1/merge -f merge_method=squash -f sha=0e1aa6fcec1e28fea576b0848ee9c8f583ede796

```
{"sha":"9fcd24177462ab85a5d479c1b5f0659fb067a451","merged":true,"message":"Pull Request successfully merged"}
```
exit: 0

#### c: PR 1 final

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/1 --jq [.state,.merged,.merged_by.login]

```
["closed",true,"glunk-dev[bot]"]
```
exit: 0

#### j: PR 2 mergeable_state now that main moved

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/2 --jq [.mergeable_state,.head.sha]

```
["unknown","7caa2052adf05715188a5ebda737e5a390dce562"]
```
exit: 0

#### j: update-branch on PR 2, main has moved

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/2/update-branch -f expected_head_sha=7caa2052adf05715188a5ebda737e5a390dce562

```
{"message":"Updating pull request branch.","url":"https://api.github.com/repos/glunk-works/wb-ruleset-scratch/pulls/2"}
```
exit: 0

#### j: PR 2 after update-branch

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/2 --jq [.mergeable_state,.head.sha]

```
["blocked","7a16e2ca993d7a3955d7a531348f473257b0482f"]
```
exit: 0

#### e/k: create branch case-e

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-e -f sha=9fcd24177462ab85a5d479c1b5f0659fb067a451 --jq .ref

```
refs/heads/case-e
```
exit: 0

#### e/k: commit on case-e

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-e.txt -f message=case e and k -f branch=case-e -f content=Y2FzZSBlCg== --jq .commit.sha

```
44ea1b548ec598b4326863dcbb3fe2613e291b92
```
exit: 0

#### e/k: open PR 3

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case e and k -f head=case-e -f base=main --jq [.number,.head.sha]

```
[3,"44ea1b548ec598b4326863dcbb3fe2613e291b92"]
```
exit: 0

#### e/k: PR 3 state before any approval

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:3){mergeStateStatus reviewDecision}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"BLOCKED","reviewDecision":"REVIEW_REQUIRED"}}}}
```
exit: 0

#### e: PR 3 outcome

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/3 --jq [.state,.merged,.merged_by.login,.merge_commit_sha]

```
["open",false,null,"a8a43f0379d61f0d657bdbac8205474a0a356ab2"]
```
exit: 0

#### e: reviews on PR 3

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/3/reviews --jq map([.user.login,.state,.submitted_at])

```
[["Seuss27","APPROVED","2026-10-09T01:04:48Z"]]
```
exit: 0

#### e: PR 3 timeline

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/issues/3/timeline --jq .[]|[.event,.actor.login,.created_at]|@tsv

```
committed		
review_requested	glunk-dev[bot]	2026-10-09T01:02:38Z
reviewed		
```
exit: 0

#### e: PR 3 outcome (re-read)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/3 --jq [.state,.merged,.merged_by.login,.merge_commit_sha]

```
["open",false,null,"a8a43f0379d61f0d657bdbac8205474a0a356ab2"]
```
exit: 0

#### e: reviews on PR 3 (re-read)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/3/reviews --jq map([.user.login,.state,.submitted_at])

```
[["Seuss27","APPROVED","2026-10-09T01:04:48Z"]]
```
exit: 0

#### e: main head

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/main --jq [.sha,.commit.message,.author.login]

```
["9fcd24177462ab85a5d479c1b5f0659fb067a451","case a (#1)\n\n* case a\n\n* case b push after approval\n\n---------\n\nCo-authored-by: glunk-dev[bot] \u003c339840170+glunk-dev[bot]@users.noreply.github.com\u003e","glunk-dev[bot]"]
```
exit: 0

#### k: PR 3 state before arming (approved, clean)

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:3){mergeStateStatus reviewDecision headRefOid id}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"CLEAN","reviewDecision":"APPROVED","headRefOid":"44ea1b548ec598b4326863dcbb3fe2613e291b92","id":"PR_kwDOVBmbD88AAAABHchlZw"}}}}
```
exit: 0

#### k: arm auto-merge on the already-mergeable PR 3

as: dev App token
$ gh api graphql -f query=mutation($id:ID!,$oid:GitObjectID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH,expectedHeadOid:$oid}){pullRequest{autoMergeRequest{enabledBy{login}} state merged}}} -f id=PR_kwDOVBmbD88AAAABHchlZw -f oid=44ea1b548ec598b4326863dcbb3fe2613e291b92

```
{"data":{"enablePullRequestAutoMerge":null},"errors":[{"type":"UNPROCESSABLE","path":["enablePullRequestAutoMerge"],"locations":[{"line":1,"column":37}],"message":"Pull request Pull request is in clean status"}]}gh: Pull request Pull request is in clean status
```
exit: 1

#### k: PR 3 after arming

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/3 --jq [.state,.merged,.merged_by.login,.auto_merge.enabled_by.login]

```
["open",false,null,null]
```
exit: 0

#### e: create branch case-e2

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-e2 -f sha=9fcd24177462ab85a5d479c1b5f0659fb067a451 --jq .ref

```
refs/heads/case-e2
```
exit: 0

#### e: commit on case-e2

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-e2.txt -f message=case e second owner -f branch=case-e2 -f content=Y2FzZSBlMgo= --jq .commit.sha

```
4d3284ee3e95b44d24e72a679947d62a32db07a5
```
exit: 0

#### e: open PR 4

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case e second code owner -f head=case-e2 -f base=main --jq [.number,.head.sha]

```
[4,"4d3284ee3e95b44d24e72a679947d62a32db07a5"]
```
exit: 0

#### e: collaborators on the scratch repo

as: admin App token
$ gh api repos/glunk-works/wb-ruleset-scratch/collaborators?affiliation=all --jq map([.login,.permissions.push,.role_name])

```
[]
```
exit: 0

#### e: is JaredGroves-603 a collaborator

as: admin App token
$ gh api repos/glunk-works/wb-ruleset-scratch/collaborators/JaredGroves-603/permission --jq [.permission,.user.login]

```
["read","JaredGroves-603"]
```
exit: 0

#### e: invitations pending

as: admin App token
$ gh api repos/glunk-works/wb-ruleset-scratch/invitations --jq map([.invitee.login,.permissions])

```
[]
```
exit: 0

#### e: org membership of JaredGroves-603

as: admin App token
$ gh api orgs/glunk-works/members/JaredGroves-603 -i

```
HTTP/2.0 404 Not Found
Access-Control-Allow-Origin: *
Access-Control-Expose-Headers: ETag, Link, Location, Retry-After, X-GitHub-OTP, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Used, X-RateLimit-Resource, X-RateLimit-Reset, X-OAuth-Scopes, X-Accepted-OAuth-Scopes, X-Poll-Interval, X-GitHub-Media-Type, X-GitHub-SSO, X-GitHub-Request-Id, Deprecation, Sunset, Warning
Content-Security-Policy: default-src 'none'
Content-Type: application/json; charset=utf-8
Date: Fri, 09 Oct 2026 01:08:15 GMT
Referrer-Policy: origin-when-cross-origin, strict-origin-when-cross-origin
Server: github.com
Strict-Transport-Security: max-age=31536000; includeSubdomains; preload
Vary: Accept-Encoding, Accept, X-Requested-With
X-Accepted-Github-Permissions: members=read
X-Content-Type-Options: nosniff
X-Frame-Options: deny
X-Github-Api-Version-Selected: 2022-11-28
X-Github-Edge-Region: iad
X-Github-Media-Type: github.v3; format=json
X-Github-Request-Id: C540:165415:1EAB509:64B0D46:6AC83E7F
X-Ratelimit-Limit: 5000
X-Ratelimit-Remaining: 4995
X-Ratelimit-Reset: 1791511693
X-Ratelimit-Resource: core
X-Ratelimit-Used: 5
X-Xss-Protection: 0

{"message":"User does not exist or is not a public member of the organization","documentation_url":"https://docs.github.com/rest/orgs/members#check-public-organization-membership-for-a-user","status":"404"}gh: User does not exist or is not a public member of the organization (HTTP 404)
```
exit: 1

#### e: invite JaredGroves-603 as a collaborator with write (push)

as: admin App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/collaborators/JaredGroves-603 -f permission=push --jq [.id,.invitee.login,.permissions,.html_url]

```
[336850686,"JaredGroves-603","write","https://github.com/glunk-works/wb-ruleset-scratch/invitations"]
```
exit: 0

#### e: pending invitations

as: admin App token
$ gh api repos/glunk-works/wb-ruleset-scratch/invitations --jq map([.invitee.login,.permissions,.html_url])

```
[["JaredGroves-603","write","https://github.com/glunk-works/wb-ruleset-scratch/invitations"]]
```
exit: 0

#### e: JaredGroves-603 permission after accepting

as: admin App token
$ gh api repos/glunk-works/wb-ruleset-scratch/collaborators/JaredGroves-603/permission --jq [.permission,.user.login]

```
["write","JaredGroves-603"]
```
exit: 0

#### e: merge attempt on PR 4 before approval (message lists who is awaited)

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/4/merge -f merge_method=squash

```
{"message":"Repository rule violations found\n\nWaiting on code owner review from JaredGroves-603 and/or Seuss27.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}gh: Repository rule violations found

Waiting on code owner review from JaredGroves-603 and/or Seuss27.

 (HTTP 405)
```
exit: 1

#### e: create branch case-e3

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-e3 -f sha=9fcd24177462ab85a5d479c1b5f0659fb067a451 --jq .ref

```
refs/heads/case-e3
```
exit: 0

#### e: commit on case-e3

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-e3.txt -f message=case e third try -f branch=case-e3 -f content=Y2FzZSBlMwo= --jq .commit.sha

```
eb5cd49b90cdcc5afef400f7f0aded086a36e58d
```
exit: 0

#### e: open PR 5 (opened after JaredGroves-603 had write)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case e after write access -f head=case-e3 -f base=main --jq [.number,.head.sha]

```
[5,"eb5cd49b90cdcc5afef400f7f0aded086a36e58d"]
```
exit: 0

#### e: PR 5 merge message

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/5/merge -f merge_method=squash

```
{"message":"Repository rule violations found\n\nWaiting on code owner review from JaredGroves-603 and/or Seuss27.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}gh: Repository rule violations found

Waiting on code owner review from JaredGroves-603 and/or Seuss27.

 (HTTP 405)
```
exit: 1

#### e: PR 4 reviews so far

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/4/reviews --jq map([.user.login,.state])

```
[]
```
exit: 0

#### e: PR 5 after JaredGroves-603's approval

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:5){mergeStateStatus reviewDecision reviews(first:5){nodes{author{login} state authorAssociation}}}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"CLEAN","reviewDecision":"APPROVED","reviews":{"nodes":[{"author":{"login":"JaredGroves-603"},"state":"APPROVED","authorAssociation":"COLLABORATOR"}]}}}}}
```
exit: 0

#### e: PR 5 outcome

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/5 --jq [.state,.merged,.merged_by.login,.merge_commit_sha]

```
["closed",true,"JaredGroves-603","558785c2cf4dff6e8882fbc43eb4679e91a67f73"]
```
exit: 0

#### e: main head

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/main --jq [.sha,.commit.message]

```
["558785c2cf4dff6e8882fbc43eb4679e91a67f73","Merge pull request #5 from glunk-works/case-e3\n\ncase e after write access"]
```
exit: 0

#### c (retry): PR 4 state before arming

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:4){mergeStateStatus reviewDecision headRefOid id}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"UNKNOWN","reviewDecision":"REVIEW_REQUIRED","headRefOid":"4d3284ee3e95b44d24e72a679947d62a32db07a5","id":"PR_kwDOVBmbD88AAAABHcjgWg"}}}}
```
exit: 0

#### c (retry): arm auto-merge on PR 4 before approval

as: dev App token
$ gh api graphql -f query=mutation($id:ID!,$oid:GitObjectID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH,expectedHeadOid:$oid}){pullRequest{autoMergeRequest{enabledBy{login} mergeMethod}}}} -f id=PR_kwDOVBmbD88AAAABHcjgWg -f oid=4d3284ee3e95b44d24e72a679947d62a32db07a5

```
{"data":{"enablePullRequestAutoMerge":{"pullRequest":{"autoMergeRequest":{"enabledBy":{"login":"glunk-dev"},"mergeMethod":"SQUASH"}}}}}
```
exit: 0

#### c (retry): PR 4 right after approval

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:4){state merged mergeStateStatus reviewDecision autoMergeRequest{enabledBy{login}} reviews(first:3){nodes{author{login} state}}}}}

```
{"data":{"repository":{"pullRequest":{"state":"OPEN","merged":false,"mergeStateStatus":"CLEAN","reviewDecision":"APPROVED","autoMergeRequest":{"enabledBy":{"login":"glunk-dev"}},"reviews":{"nodes":[{"author":{"login":"JaredGroves-603"},"state":"APPROVED"}]}}}}}
```
exit: 0

#### c (retry): PR 4 ~90s after approval

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:4){state merged mergeStateStatus reviewDecision autoMergeRequest{enabledBy{login}} reviews(first:3){nodes{author{login} state}}}}}

```
{"data":{"repository":{"pullRequest":{"state":"MERGED","merged":true,"mergeStateStatus":"UNKNOWN","reviewDecision":"APPROVED","autoMergeRequest":{"enabledBy":{"login":"glunk-dev"}},"reviews":{"nodes":[{"author":{"login":"JaredGroves-603"},"state":"APPROVED"}]}}}}}
```
exit: 0

#### c (retry): PR 4 who merged and when

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/4 --jq [.merged_by.login,.merged_at,.merge_commit_sha]

```
["glunk-dev[bot]","2026-10-09T01:14:14Z","5932287b4acfb52028a81f0541bc9f2c0601c282"]
```
exit: 0

#### c (retry): PR 4 timeline

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/issues/4/timeline --jq .[]|[.event,.actor.login,.created_at]|@tsv

```
committed		
review_requested	glunk-dev[bot]	2026-10-09T01:07:30Z
auto_squash_enabled	glunk-dev[bot]	2026-10-09T01:13:02Z
committed		
review_requested	JaredGroves-603	2026-10-09T01:13:19Z
reviewed		
merged	glunk-dev[bot]	2026-10-09T01:14:14Z
closed	glunk-dev[bot]	2026-10-09T01:14:15Z
```
exit: 0

#### c: PR 1 timeline (for comparison)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/issues/1/timeline --jq .[]|[.event,.actor.login,.created_at]|@tsv

```
committed		
review_requested	glunk-dev[bot]	2026-10-09T00:51:55Z
reviewed		
committed		
review_dismissed	glunk-dev[bot]	2026-10-09T00:57:08Z
auto_squash_enabled	glunk-dev[bot]	2026-10-09T00:57:50Z
reviewed		
merged	glunk-dev[bot]	2026-10-09T01:02:01Z
closed	glunk-dev[bot]	2026-10-09T01:02:01Z
```
exit: 0

#### f: create branch case-f

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-f -f sha=5932287b4acfb52028a81f0541bc9f2c0601c282 --jq .ref

```
refs/heads/case-f
```
exit: 0

#### f: commit on case-f

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-f.txt -f message=case f -f branch=case-f -f content=Y2FzZSBmCg== --jq .commit.sha

```
1cc5aa50e9b5a12d5cc583cfe9aaecf0465a6aa5
```
exit: 0

#### f: open PR 6

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case f reviewer -f head=case-f -f base=main --jq [.number,.head.sha]

```
[6,"1cc5aa50e9b5a12d5cc583cfe9aaecf0465a6aa5"]
```
exit: 0

#### g: revoke the admin token, then use it (run by the maintainer, pasted from the terminal)

```
$ T=$(sed -n 1p ~/.config/glunk-identity/tokens/wb-ruleset-scratch/admin-token)
$ sh scripts/identity/wow-admin wb-ruleset-scratch --revoke
revoked the admin token for wb-ruleset-scratch
$ GH_TOKEN=$T gh api repos/glunk-works/wb-ruleset-scratch --jq .full_name
{
  "message": "Bad credentials",
  "documentation_url": "https://docs.github.com/rest",
  "status": "401"
}
gh: Bad credentials (HTTP 401)
```

#### f: reviewer App posts a COMMENT review on PR 6

as: review App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/6/reviews -f event=COMMENT -f body=fresh-session review, comment only --jq [.id,.user.login,.user.id,.state,.commit_id]

```
[5464793688,"JaredGroves-603",281693088,"COMMENTED","1cc5aa50e9b5a12d5cc583cfe9aaecf0465a6aa5"]
```
exit: 0

#### f: reviewer App tries APPROVE on PR 6

as: review App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/6/reviews -f event=APPROVE -f body=should not be allowed --jq [.user.login,.state]

```
["JaredGroves-603","APPROVED"]
```
exit: 0

#### f: PR 6 reviews as read back

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/6/reviews --jq map([.user.login,.user.id,.state,.author_association])

```
[["JaredGroves-603",281693088,"COMMENTED","COLLABORATOR"],["JaredGroves-603",281693088,"APPROVED","COLLABORATOR"]]
```
exit: 0

#### f: PR 6 merge state after the COMMENT

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:6){mergeStateStatus reviewDecision}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"CLEAN","reviewDecision":"APPROVED"}}}}
```
exit: 0

#### f: reviewer App tries to merge

as: review App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/6/merge -f merge_method=squash

```
{"sha":"e228b2420c4889db12d13aac352cda8fbf36136d","merged":true,"message":"Pull Request successfully merged"}
```
exit: 0

#### f: reviewer App tries to push a file

as: review App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/f-reviewer.txt -f message=x -f branch=case-f -f content=eAo= --jq .commit.sha

```
bad72e8fbf455a9443b8d96d3d81f5d7fb53d11f
```
exit: 0

#### f: VOID -- the four "review App token" calls above ran as JaredGroves-603, not glunk-review[bot]

Every call labelled `review App token` returned `user.login` JaredGroves-603 (id 281693088), a
human code owner with write access. So these results show what that user account can do, not
what the reviewer App can do. They also made real changes: an APPROVE on PR 6, the merge of PR 6
(e228b24), and a commit pushed to case-f (bad72e8). On 2026-10-09 the reviewer App, both as
configured and as installed, held only `metadata: read, pull_requests: write`, while
`wow-review-mint` asks for `contents=read,checks=read,statuses=read,pull_requests=write`.
A mint therefore cannot have produced the token on file. Case f is re-run after the
reviewer App is fixed.

## Raw output, session 2 (2026-10-09, UTC 10:15-10:40)

#### f (re-run): reach probe -- installation repositories as the reviewer App

as: review App token
$ gh api installation/repositories --jq [.total_count,(.repositories|map(.full_name))]

```
[1,["glunk-works/wb-ruleset-scratch"]]
```
exit: 0

#### f (re-run): main head

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/main --jq .sha

```
e228b2420c4889db12d13aac352cda8fbf36136d
```
exit: 0

#### f (re-run): create branch case-f2

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-f2 -f sha=e228b2420c4889db12d13aac352cda8fbf36136d --jq .ref

```
refs/heads/case-f2
```
exit: 0

#### f (re-run): commit on case-f2

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-f2.txt -f message=case f re-run -f branch=case-f2 -f content=Y2FzZSBmMgo= --jq .commit.sha

```
2b4bfc179385a9637be07eb275221dccb661a4a7
```
exit: 0

#### f (re-run): open PR

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case f re-run (reviewer App) -f head=case-f2 -f base=main --jq [.number,.head.sha,.user.login]

```
[7,"2b4bfc179385a9637be07eb275221dccb661a4a7","glunk-dev[bot]"]
```
exit: 0

#### f (re-run): reviewer App posts a COMMENT review on PR 7

as: review App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/7/reviews -f event=COMMENT -f body=fresh-session review, comment only --jq [.id,.user.login,.user.id,.user.type,.state,.commit_id]

```
[5468756613,"glunk-review[bot]",339841158,"Bot","COMMENTED","2b4bfc179385a9637be07eb275221dccb661a4a7"]
```
exit: 0

#### f (re-run): PR 7 merge state after the COMMENT

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:7){mergeStateStatus reviewDecision reviews(first:5){nodes{author{login ... on Bot{databaseId}} state}}}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"BLOCKED","reviewDecision":"REVIEW_REQUIRED","reviews":{"nodes":[{"author":{"login":"glunk-review","databaseId":339841158},"state":"COMMENTED"}]}}}}}
```
exit: 0

#### f (re-run): the reviewer App's bot user, by public lookup

as: maintainer (Seuss27 user token, not an App)
$ gh api users/glunk-review[bot] --jq [.login,.id,.type]

```
["glunk-review[bot]",339841158,"Bot"]
```
exit: 0

#### f (re-run): reviewer App tries APPROVE on PR 7

as: review App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/7/reviews -f event=APPROVE -f body=should not count --jq [.user.login,.state]

```
["glunk-review[bot]","APPROVED"]
```
exit: 0

#### f (re-run): PR 7 merge state after the reviewer App's APPROVE

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:7){mergeStateStatus reviewDecision reviews(first:5){nodes{author{login} state}}}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"BLOCKED","reviewDecision":"REVIEW_REQUIRED","reviews":{"nodes":[{"author":{"login":"glunk-review"},"state":"COMMENTED"},{"author":{"login":"glunk-review"},"state":"APPROVED"}]}}}}}
```
exit: 0

#### f (re-run): reviewer App tries to merge PR 7

as: review App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/7/merge -f merge_method=squash

```
{"message":"Resource not accessible by integration","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"403"}gh: Resource not accessible by integration (HTTP 403)
```
exit: 1

#### f (re-run): reviewer App tries to push a file to case-f2

as: review App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/f2-reviewer.txt -f message=x -f branch=case-f2 -f content=eAo= --jq .commit.sha

```
{"message":"Resource not accessible by integration","documentation_url":"https://docs.github.com/rest/repos/contents#create-or-update-file-contents","status":"403"}gh: Resource not accessible by integration (HTTP 403)
```
exit: 1

#### f (re-run): dev App merge attempt on PR 7 (message lists what is awaited)

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/pulls/7/merge -f merge_method=squash

```
{"message":"Repository rule violations found\n\nWaiting on code owner review from JaredGroves-603 and/or Seuss27.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}gh: Repository rule violations found

Waiting on code owner review from JaredGroves-603 and/or Seuss27.

 (HTTP 405)
```
exit: 1

#### c1: PR 7 node id, head, state before arming

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:7){id headRefOid mergeStateStatus reviewDecision commits(last:1){nodes{commit{statusCheckRollup{state}}}}}}} --jq .data.repository.pullRequest|[.id,.headRefOid,.mergeStateStatus,.commits.nodes[0].commit.statusCheckRollup.state]|@tsv

```
PR_kwDOVBmbD88AAAABHgxX4Q	2b4bfc179385a9637be07eb275221dccb661a4a7	BLOCKED	SUCCESS
```
exit: 0

#### c1: dev App arms auto-merge on PR 7 (squash, pinned head)

as: dev App token
$ gh api graphql -f query=mutation($id:ID!,$oid:GitObjectID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH,expectedHeadOid:$oid}){pullRequest{autoMergeRequest{enabledBy{login} mergeMethod enabledAt}}}} -f id=PR_kwDOVBmbD88AAAABHgxX4Q -f oid=2b4bfc179385a9637be07eb275221dccb661a4a7

```
{"data":{"enablePullRequestAutoMerge":{"pullRequest":{"autoMergeRequest":{"enabledBy":{"login":"glunk-dev"},"mergeMethod":"SQUASH","enabledAt":"2026-10-09T10:19:34Z"}}}}}
```
exit: 0

#### c1: PR 7 after the Seuss27 approval

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/7 --jq [.state,.merged,.merged_by.login,.merged_at,.auto_merge.enabled_by.login]

```
["closed",true,"glunk-dev[bot]","2026-10-09T10:20:13Z","glunk-dev[bot]"]
```
exit: 0

#### c1: PR 7 reviews

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/7/reviews --jq map([.user.login,.state,.submitted_at])

```
[["glunk-review[bot]","COMMENTED","2026-10-09T10:18:48Z"],["glunk-review[bot]","APPROVED","2026-10-09T10:18:59Z"],["Seuss27","APPROVED","2026-10-09T10:20:03Z"]]
```
exit: 0

#### c2: main head

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/commits/main --jq .sha

```
888bcdd80ebd51011489f4f0089264b2192e1b71
```
exit: 0

#### c2: create branch case-c2

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/heads/case-c2 -f sha=888bcdd80ebd51011489f4f0089264b2192e1b71 --jq .ref

```
refs/heads/case-c2
```
exit: 0

#### c2: commit on case-c2

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-c2.txt -f message=case c2 -f branch=case-c2 -f content=Y2FzZSBjMgo= --jq .commit.sha

```
d3b53e2fe873c098e7cd56c4cfb2c6ee0ac3d4a9
```
exit: 0

#### c2: open PR

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls -f title=case c2 (dismissal then re-approval) -f head=case-c2 -f base=main --jq [.number,.head.sha]

```
[8,"d3b53e2fe873c098e7cd56c4cfb2c6ee0ac3d4a9"]
```
exit: 0

#### c2: PR 8 after the first approval

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:8){mergeStateStatus reviewDecision merged}}}

```
{"data":{"repository":{"pullRequest":{"mergeStateStatus":"CLEAN","reviewDecision":"APPROVED","merged":false}}}}
```
exit: 0

#### c2: dev App pushes a second commit to case-c2

as: dev App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/contents/case-c2-2.txt -f message=case c2 push after approval -f branch=case-c2 -f content=YzIgMgo= --jq .commit.sha

```
b4c23de28ff0825248c43b30faf42cc9700ea6f0
```
exit: 0

#### c2: PR 8 after the push (approval dismissed?)

as: dev App token
$ gh api graphql -f query={repository(owner:"glunk-works",name:"wb-ruleset-scratch"){pullRequest(number:8){id headRefOid mergeStateStatus reviewDecision reviews(first:5){nodes{author{login} state}}}}}

```
{"data":{"repository":{"pullRequest":{"id":"PR_kwDOVBmbD88AAAABHgywhQ","headRefOid":"b4c23de28ff0825248c43b30faf42cc9700ea6f0","mergeStateStatus":"BLOCKED","reviewDecision":"REVIEW_REQUIRED","reviews":{"nodes":[{"author":{"login":"Seuss27"},"state":"DISMISSED"}]}}}}}
```
exit: 0

#### c2: dev App arms auto-merge on PR 8 (squash, pinned head)

as: dev App token
$ gh api graphql -f query=mutation($id:ID!,$oid:GitObjectID!){enablePullRequestAutoMerge(input:{pullRequestId:$id,mergeMethod:SQUASH,expectedHeadOid:$oid}){pullRequest{autoMergeRequest{enabledBy{login} enabledAt}}}} -f id=PR_kwDOVBmbD88AAAABHgywhQ -f oid=b4c23de28ff0825248c43b30faf42cc9700ea6f0

```
{"data":{"enablePullRequestAutoMerge":{"pullRequest":{"autoMergeRequest":{"enabledBy":{"login":"glunk-dev"},"enabledAt":"2026-10-09T10:21:50Z"}}}}}
```
exit: 0

#### c2: PR 8 after the re-approval

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/8 --jq [.state,.merged,.merged_by.login,.merged_at]

```
["closed",true,"glunk-dev[bot]","2026-10-09T10:22:55Z"]
```
exit: 0

#### c2: PR 8 reviews

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/pulls/8/reviews --jq map([.user.login,.state,.submitted_at,.commit_id[0:7]])

```
[["Seuss27","DISMISSED","2026-10-09T10:21:24Z","d3b53e2"],["Seuss27","APPROVED","2026-10-09T10:22:51Z","b4c23de"]]
```
exit: 0

#### h: add a creation rule to wb-tags (docs/identity/scratch-rulesets/tags.json)

as: admin App token
$ gh api -X PUT repos/glunk-works/wb-ruleset-scratch/rulesets/24758201 --input docs/identity/scratch-rulesets/tags.json --jq [.name,.enforcement,(.rules|map(.type)),.bypass_actors]

```
["wb-tags","active",["deletion","non_fast_forward","update","creation"],[]]
```
exit: 0

#### h (after creation rule): dev App creates tag v-case-h2

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/tags/v-case-h2 -f sha=6a7a2b3fd9fd5be2b1314b40a7875ab4e54a7a6b --jq .ref

```
{"message":"Reference update failed","documentation_url":"https://docs.github.com/rest/git/refs#create-a-reference","status":"422"}gh: Reference update failed (HTTP 422)
```
exit: 1

#### h (after creation rule): dev App creates a release with a new tag

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/releases -f tag_name=v-case-h2-rel -f target_commitish=main --jq [.tag_name,.draft]

```
{"message":"Validation Failed","errors":[{"resource":"Release","code":"custom","field":"pre_receive","message":"pre_receive Repository rule violations found\n\nCannot create ref due to creations being restricted.\n\n"},{"resource":"Release","code":"custom","message":"Published releases must have a valid tag"}],"documentation_url":"https://docs.github.com/rest/releases/releases#create-a-release","status":"422"}gh: Validation Failed (HTTP 422)
```
exit: 1

#### h (after creation rule): dev App creates a non-v tag (outside the pattern; expected allowed)

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/refs -f ref=refs/tags/scratch-h2 -f sha=6a7a2b3fd9fd5be2b1314b40a7875ab4e54a7a6b --jq .ref

```
refs/tags/scratch-h2
```
exit: 0

#### h (after creation rule): tags matching v-case-h2*

as: dev App token
$ gh api repos/glunk-works/wb-ruleset-scratch/git/matching-refs/tags/v-case-h2 --jq map(.ref)

```
[]
```
exit: 0
