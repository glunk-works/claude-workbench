# Staged: `release-tag-creation` ruleset — for the admin to run

Per [#104](https://github.com/glunk-works/claude-workbench/issues/104)'s decision record
([comment](https://github.com/glunk-works/claude-workbench/issues/104#issuecomment-5801462976)),
option B. This is remaining-order step 3: create the ruleset **after** step 2 (a dry run of
`release.yml`, approved through the `release` environment).

**What the dry run does and does not prove.** `gh release create` is skipped entirely on a
dry run (`if: ${{ !inputs.dry_run }}`), so a dry run proves the environment approval fires and
the App token mints — it never calls `gh release create` with that token. The first time that
call actually runs is remaining-order step 4, the real `v0.10.0` release: that run is the
first live test of the App token's write access, the ruleset's bypass (already created by
step 3, below), and `gh release create --target` accepting an App-minted token, all at once.

The harness's own classifier blocks `gh api` writes to org-level repo settings, so this
session staged the command below instead of running it. `gh` identity `Seuss27` already
carries `admin: true` on this repo, so the call needs no auth change — the block is on the
write itself.

## Why a separate ruleset, not a bypass actor added to `protected-release-tags`

A bypass actor applies to **every** rule in the ruleset it's listed on. Adding the App to
`protected-release-tags` (`deletion`, `non_fast_forward`, `update`) would also let it delete
or move existing tags — not just create new ones. So `protected-release-tags` stays
unchanged, with no bypass actors, and this new ruleset carries only `creation`, with the App
as its only bypass actor. The App can create `v*` tags and still can't move or delete them.

## The command

```bash
gh api repos/glunk-works/claude-workbench/rulesets \
  --method POST \
  --input - <<'JSON'
{
  "name": "release-tag-creation",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 5051322,
      "actor_type": "Integration",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/v*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "creation" }
  ]
}
JSON
```

`actor_id` is `5051322` — the `claude-workbench-release` App's ID (not an installation ID),
per the decision record's "Setup done and verified" section. `actor_type: "Integration"` is
GitHub's ruleset vocabulary for a GitHub App bypass actor.

## Verify after creating it

**Use the detail endpoint, not the list.** `GET /rulesets` (plural, no id) returns only a
summary — `id`, `name`, `target`, `enforcement`, timestamps — with no `rules`,
`bypass_actors`, or `conditions` fields at all. Checking those against the list response
can't fail: a wrongly-added bypass actor would pass silently. Look up the id, then fetch that
ruleset's own detail:

```bash
id=$(gh api repos/glunk-works/claude-workbench/rulesets --jq '.[] | select(.name=="release-tag-creation") | .id')
gh api repos/glunk-works/claude-workbench/rulesets/$id
```

Confirm: `target: "tag"`, `enforcement: "active"`, exactly one rule (`creation`), exactly one
bypass actor (`actor_id: 5051322`, `actor_type: "Integration"`, `bypass_mode: "always"`), and
`ref_name.include` is `["refs/tags/v*"]`. Then confirm `protected-release-tags` itself is
untouched — still `deletion`/`non_fast_forward`/`update` only, still no bypass actors — the
same way, by its own id:

```bash
id=$(gh api repos/glunk-works/claude-workbench/rulesets --jq '.[] | select(.name=="protected-release-tags") | .id')
gh api repos/glunk-works/claude-workbench/rulesets/$id
```

## Then the real release (remaining-order step 4)

Dispatch `release.yml` with `dry_run: false` to cut `v0.10.0`. It must create its tag. This is
the run the note above flags as the first real exercise of the App token's write path — watch
it, not just the dry run, before treating the ruleset as proven.

## Then run the two probes from the decision record (remaining-order step 5)

Both must be **rejected** — but a probe workflow with no explicit `permissions:` block runs
under this repo's default (`contents: read`), so it can fail with a plain 403
"Resource not accessible by integration" before the ruleset is ever consulted. That failure
looks identical to a rejection in the run log but proves nothing: it's an auth-scope error,
not a rule violation, and would pass the probe for the wrong reason on the one check that's
supposed to distinguish option B from option A. The workflow probe (#2 below) must declare
`permissions: contents: write` for itself — the hand push (#1) has no workflow to declare it
in, and reaches the ruleset check on the pusher's own write access instead. Either way,
"rejected" means the error names a rule violation (`git push` shows a `GH013:`-prefixed
message; the API shows `Repository rule violations found ... Cannot create ref`), never a
bare 403 "Resource not accessible by integration" — that's an auth-scope failure, not a
ruleset rejection, and would pass the probe for the wrong reason.

Delete the probe tag or branch if either gets through.

1. **Hand push:** `git push origin v0.0.0-probe` from a write-access identity.
2. **Branch-workflow push:** push a branch whose own `on: push` workflow declares
   `permissions: contents: write` and tries to create a `v*` tag using `GITHUB_TOKEN`. This is
   the attack option A (an Actions-app bypass) would not have stopped — it's the probe that
   actually distinguishes B from A.

## Known follow-up, not blocking: `create-github-app-token`'s `app-id` input is deprecated

`release.yml`'s App-token step uses `app-id: ${{ vars.RELEASE_APP_ID }}`. At
`actions/create-github-app-token@bcd2ba4…` (`v3.2.0`), `app-id` still works but is marked
deprecated in favor of `client-id`, and a future major version could remove it — loudly, not
silently, since minting would then fail outright. Migrating means adding a new environment
variable (the App's Client ID, `Iv23liiXFVp3ZyvLFJ5j`, e.g. as `RELEASE_APP_CLIENT_ID`) to the
`release` environment — an admin action, same as the ruleset above — so it's recorded here
rather than fixed in this PR. Worth doing before `v3.2.0`'s successor drops `app-id`, not
before this ships.
