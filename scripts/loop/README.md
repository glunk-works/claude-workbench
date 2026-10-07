# scripts/loop

Host tooling for the orchestrator loop (`WB-D23`). Never on an adopter's `PATH`, outside the
coupling gate. See `docs/proposals/orchestrator-m2-decisions.md` for what each piece is for.

## baseline.sh: the PR-flow baseline

Read-only. Derives work PRs, cursor PRs per work PR, median open-to-merge, the likely-dependent
share, wave overlap and an open-to-merge time per work PR for one repo from its merged-PR
history on GitHub. The method is in the script's header. `open_to_merge_min_per_work_pr` is
wait-to-merge time, not keyboard time (GitHub does not record attention), and it is **not** the
M2b exit metric: that needs a different source. The dependent and overlap shares print `n/a`
under 21 work PRs.

```
bash scripts/loop/baseline.sh <owner/repo> [--days 60] [--until YYYY-MM-DD]
```

Pass `--until` to reproduce an earlier run; the window is the merged PRs in the `--days` days
ending on the `--until` day, that day included. Tests: `sh tests/loop-baseline.test.sh`.

### Adoption step: run it before enabling the loop on a repo

1. Run `baseline.sh` against the repo and read the numbers. Do this **before** the first
   dispatch: afterwards the loop's own PRs are in the history and the "before" is gone.
2. If cursor_prs_per_work_pr is high (the brief saw 1.3 in devcontainers, where cursor PRs were 57% of merges), check that the repo
   has adopted the plugin version that addresses it (v0.17.0's no-op handoff); otherwise the baseline is not a valid
   "before".
3. Add one line to the table below: the repo, the date the loop was enabled and the window the
   baseline used (`--days`, `--until`). **Never record the numbers.** They are re-derivable
   from that window, as long as it still falls inside the newest 1000 merged PRs (the script warns when it hits that limit).

| Repo | Loop enabled | Baseline window |
|---|---|---|

## launch.sh: the assembled loop container

One scripted build-and-launch of the whole plan v9 § 7.3 container (`#317`): verify the base
image's build provenance, build the loop image, create the `--internal`,
`gateway_mode_ipv4=isolated` network and the allowlisting proxy, run the preflight from outside
(`docker inspect`) and from inside (probes by IP), then run the coder launch line on a trivial
task in a seeded work volume and check the result. It refuses to start the session if any
preflight check fails. It is the container, not the driver: the clone, the post-exit checks,
the push and the PR belong to the driver-core issues, and the attack pass is `#318`.

```
LOOP_PREFLIGHT_ONLY=1 bash scripts/loop/launch.sh    # everything except the model call; no credential
LOOP_CREDENTIAL_FILE=<file> bash scripts/loop/launch.sh
```

Run it under Git Bash on the loop host; the variables are listed in the script's header. The
credential is the first line of `LOOP_CREDENTIAL_FILE`, piped to the container's stdin: never
mounted, never in `docker inspect`. `LOOP_VERIFY_GH_TOKEN` is the token for the provenance check
when the ambient `gh` identity cannot read the base image's attestations (the base is published
by `603-Identity`); it is passed to that one command only.

| File | What it is |
|---|---|
| `Dockerfile` | The loop layer: base pinned by tag and digest, `claude` pinned by version and sha256 in `/usr/local/bin`, auto-update off, non-root `USER`, the files below baked in root-owned |
| `managed-settings.json` | Root-owned `/etc/claude-code/managed-settings.json`: the `allowManaged*` and `strictPluginOnlyCustomization` keys, `sandbox.enabled: false`, the allow list and the deny rules. The plan's PreToolUse guards are not in it yet (`allowManagedHooksOnly` means no hook runs); the attack pass (`#318`) decides what is missing |
| `proxy.py` | CONNECT-only allowlisting proxy, run from the same image; refuses IP literals, `host.docker.internal` and allowlisted names that resolve to a non-global address |
| `entrypoint.sh` | Reads the credential from stdin and hands it to the `claude` process only |
| `stop-schema.json` | The `--json-schema` the coder must answer with |

Bumping a pin is an edit in the `Dockerfile` (the base: one line; `claude`: the version and its
sha256): `launch.sh` reads the base digest and the
`claude` version back out of it, and the provenance check then covers the new digest. The
managed settings' human-only-path denies are this repo's own list (`orchestration.human_only_paths`
in `.ai/project.yml`): `allowManagedPermissionRulesOnly` ignores deny rules from anywhere else, so
a second repo's loop image needs its own copy. `LOOP_ALLOW_HOSTS` replaces the proxy's list
rather than adding to it, so a widened list names the four defaults as well. Known residual, handed to the attack pass (`#318`) by name: the managed deny rules stop the file tools,
not the allowed `git` subcommands, whose options (`--pathspec-from-file`, `commit -F`, `diff` on a path
outside the tree) can read files such as `/proc/<pid>/environ`, where the credential sits. A deny
list cannot express git's option parsing, so this container does not claim the credential is
unreadable by the session; `GIT_CONFIG_GLOBAL=/dev/null` and the `.git` denies only close the
git-config code-execution route. Tests: `sh tests/loop-proxy.test.sh` (the proxy's
decision; the in-container probes are `launch.sh`'s preflight).
