# Evaluation: a GitHub App as the loop identity, instead of a machine user

**For:** the maintainer deciding the loop's GitHub identity, and the Fable session writing v9
(this bears on spec D3 and on the open item recorded in `V9-TEST-RESULTS.md`, "Observed during
setup").
**Written:** 2026-10-05 by an Opus 5.5 session, the same session that ran the v9 tests. GitHub
facts below are quoted from docs.github.com, gathered that day by a research subagent; repo facts
are from a read-only sweep of this repo, spot-checked. **The scratch-repo test ran the same day
(2026-10-05, 13:25–13:32 UTC); every check passed. Results are in "Test results" below and
supersede the "not documented" caveats they answer.**
**Scope:** a GitHub App used only as an identity (a token the loop pushes and opens PRs with).
GitHub-hosted agents are out of scope, at the maintainer's direction.

## Why this question exists

Spec D3 requires **one token per repo**. Test C setup showed that the machine user
`603-gh-loop`, as an outside collaborator, **cannot mint a fine-grained token for an org's
repos**. Its only option was a classic token, which is scoped by visibility (`public_repo`) or to
everything (`repo`), never to one repo. The remaining routes were org membership (a paid seat on
a paid org, and `author_association` becomes MEMBER) or a GitHub App.

## Verdict

**A GitHub App fits this plan better than a machine user on every axis that D3, the seat
question and § 7.2 care about. Two properties the plan depends on are undocumented for Apps:
that the restrict-updates rule blocks an App's merge, and what `author_association` an App's PR
gets.** Recommendation: adopt it **conditionally on a scratch-repo test** (below, about an hour,
mostly the maintainer's clicks). If the test passes, the App replaces `603-gh-loop` as the loop
identity. That reverses this session's earlier "keep the account" advice; the reason is D3.

## Comparison

| | Machine user, classic PAT (today) | Machine user as org member, fine-grained PAT | **GitHub App** |
|---|---|---|---|
| Per-repo token (D3) | **No.** `public_repo` or `repo` only | Yes | **Yes.** Install on "Only select repositories", and mint each token for one repo: "use the `repositories` or `repository_ids` body parameters" |
| Per-permission token | No (coarse scopes) | Yes | **Yes**, per token: "use the `permissions` body parameter" |
| Credential lifetime in the loop | up to the PAT's expiry (days–no expiry) | same | **1 hour**: "Installation tokens expire one hour from the time you create them" |
| Long-lived secret | the PAT itself | the PAT itself | the App **private key**: "Private keys do not expire and instead need to be manually revoked" |
| Seat cost | possibly, for private-repo access | **yes**, on a paid org | **none**: "a GitHub App does not consume a GitHub seat" |
| `author_association` on its PRs | COLLABORATOR (trusted by the plugin's allowlists, hence § 8.1's name rule) | MEMBER (trusted) | **not documented** (to test); any value other than OWNER/MEMBER/COLLABORATOR is untrusted by default |
| Can it merge? | the ruleset decides (Test C1: blocked) | the ruleset decides | **the ruleset decides**: merge needs only "'Contents' repository permissions (write)", the same permission it needs to push. **Not yet tested as an App** |
| Workflow-file edits | `public_repo` allows them | can be withheld | can be withheld: no **Workflows** permission (implied by docs, not stated outright; to test) |
| Covers both orgs | one account in both | needs membership in both | a **private** App "can only be installed on the account that owns the app", so **one App per org** (or one public App) |
| Rate limit | 5,000/h per user | same | 5,000/h per installation, up to 12,500 |

## Benefits, concretely

1. **D3 is met as written**: one installation per repo (or per org with select repos), and each
   task's token minted for exactly the dispatched repo with exactly Contents write and Pull
   requests write. The preflight's "PAT's repository access is exactly the dispatched repo"
   becomes `GET /installation/repositories` on the minted token.
2. **The loop container never holds a long-lived GitHub credential.** The driver keeps the
   private key **on the host, outside the container**, mints a one-hour, one-repo token per task,
   and passes only that in. A prompt-injected session can leak at most a token that dies within
   the hour and reaches one repo. With a PAT, the container holds the credential for its whole
   life.
3. **infrastructure-core costs no seat.** The private-repo seat question in D3/§ 8.2 disappears.
4. **The plugin's trust rules already treat it as untrusted.** Every allowlist is fail-closed on
   `OWNER|MEMBER|COLLABORATOR` (`bin/review-sandbox.sh:323–325`, `agents/coder.md:39–40`,
   `skills/resume/SKILL.md:912–913`). An App's PR is almost certainly outside that list, so § 8.1's
   "untrusted by name" rule becomes a backstop rather than the only control. That rule is a v8
   decision (L1779–1783) that `review-sandbox.sh` and `plan-anchor.sh` will return untrusted for
   the loop's login. It is **not implemented yet**; `plan-anchor.sh` checks no author at all
   today.
5. **Option (e) and fork handling become moot**; an App cannot fork.
6. **Its PRs run CI without the approval prompt**: an installation token "lets `pull_request`
   workflows run automatically (without the approval prompt…)".
7. **Attribution**: "API requests made by an app installation are attributed to the app", and
   audit events carry `actor_is_bot`.

## What it changes in the plan (impact)

- **§ 7.2 rewritten.** No machine user, no PAT, no `GH_CONFIG_DIR`. The driver holds the App ID
  and private key, mints a JWT ("RS256", expiry "no more than 10 minutes into the future"), then an
  installation token per task. `orchestration.loop_identity` becomes the App's bot login (format
  `<slug>[bot]` is **not stated** in the docs; to observe).
- **Token expiry vs task length.** A token dies after one hour. A task that runs longer cannot
  push. Either the task fits inside the hour (the turn and budget caps may already ensure it), or
  the driver pushes on the session's behalf after exit, or it refreshes a token file the
  container's git credential helper reads. This is a **design choice v9 must make**.
- **D2/decision 3's preflight reads** ("as the machine user") become reads with an installation
  token. `current_user_can_bypass` is documented to work with installation tokens, but **what it
  means for an App is not stated** (to test). The preflight should also read the ruleset's
  `bypass_actors` (as the admin) and refuse if the App appears there. Apps *can* be bypass
  actors (`actor_type: Integration`), so the danger is someone adding it.
- **§ 8.5 Test C1 must be re-run with the App** as the actor. The docs cover bypass eligibility
  only, not that a non-bypass App is blocked exactly like a user.
- **Plugin code that would break if run under an App token** (repo sweep):
  `gh api user --jq .login` and `gh api repos/{repo} --jq .permissions` reach checks appear in
  seven skill/reference files (e.g. `reference/project-schema.md:279–281`,
  `skills/plan-sprint/SKILL.md:50–51`). Under spec D1 the coder session loads **no plugin**,
  so these do not run in the loop. They matter only if a critic (which loads the plugin) is
  given the App token. **The critics need no GitHub write; give them none**, or a read-only token.
- **v8 § 7.1 step 1 / § 8.4b** derive the review step from a PR "pushed by the maintainer's
  login"; loop PRs pushed by the App will not match. Decide whether that is intended (probably
  yes: loop PRs are not the human's).
- **One App per org.** Two private Apps, one owned by glunk-works and one by 603-Identity, each
  installed on select repos. For the private repo, a third App used only for infrastructure-core
  keeps D3's "never one credential covering both a private and a public repo" at the key level,
  not just the token level. Without it, one private key can mint tokens for every repo its App is
  installed on.

## Costs and risks

- **The private key is the crown jewel.** It never expires, and whoever holds it can mint tokens
  for every repo the App is installed on, until revoked. It lives on the host, readable by the
  driver only, never mounted into a container. Rotate with a second key (up to 25), then delete
  the old one. Per-org, or per-repo, Apps limit what one leaked key reaches.
- **Driver code grows**: JWT signing (RS256), token minting, refresh handling, fixture tests.
  Small, but new, and security-relevant.
- **More moving parts to set up**: register two or three Apps, install each, store keys. An org
  owner must do it.
- **Undocumented behaviour** (each listed under the test): the bot login format, `author_association`,
  whether the restrict rule blocks an App's merge, `current_user_can_bypass` for an App, whether
  withholding Workflows blocks a pushed workflow edit, commit signing over git, and whether the
  Create-PR page's "you must be a member of the organization … to open or update a pull request"
  applies to Apps (Dependabot-style Apps do open PRs, but that is not a documented guarantee).
- **Permission changes need re-approval** at each installation ("their installation will continue
  to use the old permissions" until approved). That is a feature (nothing widens silently), but a
  forgotten approval leaves the old set in force.

## The test that settles it (scratch repo, about an hour)

Uses `glunk-works/wb-ruleset-scratch` as it stands: rulesets A and B, `ci`, open PRs #1 and #2.
Delete it only after this test.

**Maintainer, in the GitHub UI (as Seuss27, an owner of glunk-works):**
1. glunk-works → Settings → Developer settings → GitHub Apps → **New GitHub App**. Name e.g.
   `glunk-loop-test`; homepage any URL; **Webhook: uncheck Active**; repository permissions
   **Contents: Read and write, Pull requests: Read and write**, Metadata: Read; **Workflows: No
   access**; everything else none; "Only on this account". Create.
2. On the App page: note the **App ID**; **Generate a private key**, and save the `.pem` to
   `C:\Users\SR116\.gh-loopbot\app-test.pem`.
3. **Install App** → glunk-works → **Only select repositories → wb-ruleset-scratch**.

**This session (reads, plus minting tokens locally from the key):**
- T1: mint a JWT and an installation token **scoped to one repo and two permissions**; record
  `expires_at`, `GET /installation/repositories`.
- T2: what breaks under the token: `gh api user`, `gh api repos/… --jq .permissions`,
  `current_user_can_bypass` on both rulesets.

**Writes, run as the App** (by this session in manual mode with your approval, or handed to you as
commands):
- T3: push a branch and open a PR; record the bot login, `author_association` as the admin sees
  it, whether `ci` runs without approval, and the commit's verification status.
- T4: try to push a change to `.github/workflows/ci.yml` on a branch (Workflows withheld; expect
  refusal).
- T5 (= C1 for an App): REST-merge the App's own green PR. Expect `405`, rule suite `fail`.

**Cleanup:** uninstall and delete the App, delete the key, then delete the scratch repo.

If T5 merges, an App is not usable under option (a) without a further control, and the machine
user route (with its D3 problem) stays. If T3's `author_association` comes back as OWNER, MEMBER
or COLLABORATOR, the § 8.1 name rule becomes load-bearing again and must be implemented (it is
not today).

## Test results (2026-10-05)

**App:** `glunk-loop-test`, App ID 5197744, Client ID `Iv23lioHuZlD4YOIIMb2`, owned by
glunk-works. It is private, has no webhook, and has repository permissions Contents write, Pull
requests write and Metadata read (no Workflows). It is installed only on `wb-ruleset-scratch`
(installation 168153924). The bot user is `glunk-loop-test[bot]`, id 338142741, type `Bot`.
Tokens were minted locally: an RS256 JWT signed with OpenSSL 3.5.6, then `POST
/app/installations/{id}/access_tokens`. The key, JWT and tokens were never printed. Scripts and
raw output are in this session's scratchpad, `testD/` (`mint.sh`, `t2.sh`–`t4.sh`, `out/`).

| Test | Result | Evidence |
|---|---|---|
| T1 mint with Client ID as `iss` | **PASS** | `ghs_` token; `expires_at` one hour after mint; `repository_selection: selected`, exactly one repo, exactly the requested permissions |
| T1b token for a repo outside the installation | **refused** | `422` "There is at least one repository that does not exist or is not accessible to the parent installation." |
| T1c token with a permission the App lacks (`workflows`) | **refused** | `422` "The permissions requested are not granted to this installation." |
| Permission change needs owner approval | **observed** | after adding Pull requests write, the App showed it but the installation kept `{contents, metadata}` and minting failed with `422` until the owner accepted |
| T2a `GET /installation/repositories` | `total=1`, the scratch repo | the preflight's "exactly the dispatched repo" check works |
| T2b `gh api user` | **`403` "Resource not accessible by integration"** | the plugin's identity line fails under an App token |
| T2c `gh api repos/… --jq .permissions` | **all `false`, `pull` included**, despite Contents write | the plugin's reach check ("no `pull` → stop") **stops wrongly** under an App token |
| T2d `current_user_can_bypass` | **`never`** on both rulesets; `bypass_actors` hidden (`null`) | usable as the preflight's bypass read for the App |
| T3 push and open PR | **PASS**, PR #5 | the org-membership line on the Create-PR page does not stop an App |
| T3 CI on the App's PR | **ran without approval** | `pull_request` run, `conclusion=success`, actor `glunk-loop-test[bot]` |
| T3 `author_association` of the App's PR | **`NONE`** as the admin, as the App and as `603-gh-loop` | outside every allowlist; and, unlike the machine user, the same whoever reads it |
| T3 commit pushed over git | **unsigned** (`verified=false, reason=unsigned`) | no ruleset here requires signatures; one that did would block git pushes by the App |
| T4 push a workflow-file edit | **refused server-side** | "refusing to allow a GitHub App to create or update workflow `.github/workflows/ci.yml` without `workflows` permission"; the branch was not created |
| T5 merge its own green PR | **PASS (refused)** | `gh pr merge` refused client-side; REST `PUT …/merge` → `405` "Repository rule violations found / Cannot update this protected ref."; `gh pr merge --admin` → same, server-side; rule suites `fail` ×2, actor `glunk-loop-test[bot]` |

**Found along the way, not App-specific:** `author_association` depends on who reads it. Issue
glunk-works/claude-workbench#220, opened by Seuss27, reads `MEMBER` to Seuss27 and
**`CONTRIBUTOR`** to both the App and `603-gh-loop`. So **any author-trust check run with the
loop's own credential, App or machine user, would class the maintainer's own issues as
untrusted.** The driver's § 8.1 trust check must read with the maintainer's view (or a read-only
member's), never with the loop's token. v8 does not say whose view it uses.

**Also observed:** public issues and comments are readable with no Issues permission, even in a
repo outside the installation. The loop needs Issues read only on the private repo, and only if
the session reads its spec comment itself.

## Recommendation

*Decided (2026-10-05):* the maintainer adopted the App "unless/until there is a reason to
switch"; recorded as decision 4 in `V9-TEST-RESULTS.md`.

**The test passed.** What it settled:
- the restrict-updates rule blocks an App's merge;
- the App's PRs are `NONE`, untrusted by default;
- withholding Workflows blocks workflow edits server-side;
- one-repo, two-permission, one-hour tokens work as documented.

v9 should adopt:
- **one private App per org**, plus a dedicated one for infrastructure-core;
- each installed on "Only select repositories";
- no Workflows permission;
- the key on the host only;
- one token per task, minted for one repo and two permissions;
- a preflight that refuses to dispatch when the App appears in any `bypass_actors`, or when
  `current_user_can_bypass` is anything but `never`.

`603-gh-loop` is then not needed as the loop identity. Keep it only if you want a fallback.

Additions from the test:
- the driver's author-trust reads use the maintainer's view, not the App token (finding above);
- critics and anything else that loads the plugin never run under the App token, because the
  plugin's reach checks fail closed on it (T2b, T2c);
- v9 still chooses how a task longer than the one-hour token pushes its work (unchanged by the
  test).

**Cleanup (maintainer):**
- glunk-works → Settings → GitHub Apps → `glunk-loop-test` → Advanced → **Delete GitHub App**
  (this also uninstalls it and invalidates its keys);
- delete `C:\Users\SR116\.gh-loopbot\app-test.pem`;
- then delete the scratch repo, and revoke `603-gh-loop`'s token as already listed.

This session deleted the JWT and token files it wrote.
