# The claude-workbench dev container

WB-D24, issue #393. The container is `.devcontainer/`, from the 603-Identity/devcontainers
template. A session in it is meant to reach GitHub only as the dev App, and is expected to when
the container is entered through the driver launcher (`wow-driver.ps1`, below), never a hand
`devcontainer up`. The launcher recreates the container and then `docker exec`s into the container it reports; the maintainer's live run after merge is to confirm that, and until
then it is unconfirmed; the other hazards below remain regardless. VS Code attach is
unsupported (#720, `WB-D33`): even with the host setting
`dev.containers.gitCredentialHelperConfigLocation` at `none`, an attach opens an IPC channel
that serves the host's git credential (see Hazards that remain).

## How it gets its token

- The host broker (`scripts/identity/broker.ps1`) keeps `~/.config/glunk-identity/tokens/glunk-works/claude-workbench/dev-token`
  current: the token on line 1, its `expires_at` on line 2. The broker's scheduled task starts pwsh through
  `conhost.exe --headless`, so it opens no window; re-running `register-broker-task.ps1` brings an older registration up to date. Endpoint security software and public detection rules for headless conhost may flag that launch as a living-off-the-land pattern, and an alert on this task is expected; the flagged command line should show `conhost.exe` from the system directory starting pwsh on the installed copy of `bin\broker.ps1` under `WOW_HOME`, though a match shows only that the launch has this task's shape, not that the task or the installed script is unmodified.
- `devcontainer.json` bind-mounts that **directory**, read-only, once, at `/run/wow`. A
  single-file mount would keep showing the file the broker replaced by atomic rename. Nothing else
  under the host's `glunk-identity` directory is mounted. The mount source names the GitHub repo
  (`glunk-works/claude-workbench`, owner-qualified, as the shared template requires and matched
  case-sensitively against `github.repository`), not the checkout folder, so a clone folder with
  another name still mounts the right directory; it must exist, which `install-host-tools.ps1`
  ensures for each repo in `broker.json`. The broker writes the dev token only to
  `tokens/<owner>/<repo>/dev-token` (`WB-D42`, `#1276`, `#1340`); a bare `tokens/<repo>` directory is a
  leftover the maintainer removes. The
  `dev-token` script reads the `dev-token` file there, and the plugin's SessionStart banner reads `admin-token` there
  (`/run/wow/admin-token`, the fixed path it looks at); `wow-admin <owner/name>` writes the admin token into the same
  host directory (when `WOW_HOME` is the default directory, as *Opening it* already requires),
  `tokens/<owner>/<repo>/admin-token`, and nowhere else (`#1340`). The change
  takes effect when the driver launcher's start-of-day path recreates the container.
- The reader, the wrapper and the credential helper are the base image flavour's
  (603-Identity/devcontainers, `FROM` in `.devcontainer/Dockerfile`), at the paths named here;
  this repo no longer carries a copy of them for the container. `/usr/local/libexec/dev-token` reads the file **on every call** and refuses
  unless it holds a live installation token; its margin and exit codes are the flavour's, in
  603-Identity/devcontainers `images/devapp/files/dev-token`. The review image's own copy
  (`scripts/identity/review/dev-token`, tested by `tests/dev-token.test.sh`) refuses under 5 minutes left.
- `/usr/local/bin/gh` is a shim that sets `GH_TOKEN` from it for that one call and runs the real
  `gh` (`/usr/local/libexec/gh-real`). git's system credential helper is the same
  reader. The token is never exported into a long-lived environment variable. When the token is
  refused, the helper answers `quit=1`, so git stops instead of trying another helper; the
  image sets `GIT_TERMINAL_PROMPT=0` as `ENV`, and `devcontainer.json` carries no VS Code settings.
  For the host side, `dev.containers.gitCredentialHelperConfigLocation`
  set to `none` keeps Dev Containers' helper out of git's config. It does not stop the channel
  behind that helper from answering once VS Code attaches (#720), so the container is not
  attached to.
- The container holds no `gh` login. The template's GitHub VS Code extensions are left out, as
  they sign in with the human's account.

## Opening it

- Open a **full clone** that is not the one `install-host-tools.ps1` installs from, runs git in,
  or runs host-side reviews in (a host session still runs git in its review clone, under a map
  too), and not a worktree of any of those (a worktree shares that clone's `.git`, hooks and
  config, and its `.git` file points at a host path git cannot follow in the container). A
  container-writable source clone is host code execution beside the App keys.
- **Enter it with the driver launcher** (#728), from `pwsh` 7.2+ on the host (not Git Bash), as the installed copy, never from a checkout:
  ```powershell
  pwsh -File $env:WOW_HOME\bin\wow-driver.ps1 -Clone <clone> -Reference <other clone>
  ```
  The path is `$env:WOW_HOME\bin`, or `$HOME\.config\glunk-identity\bin` when `WOW_HOME` is unset.
  Set `WOW_HOME` once as a user-level environment variable (not only in one shell's profile),
  written as a drive letter, a colon, then forward slashes throughout, with no backslash and no
  trailing slash; pwsh and Git Bash both accept that form:
  ```powershell
  [Environment]::SetEnvironmentVariable('WOW_HOME', '<path>', 'User')
  ```
  A shell opened before the change does not see it. `<path>` is the identity directory already in
  use, the default `.config/glunk-identity` directory under the user profile: the dev container's
  token mount reads the repo's `tokens/` subdirectory under that default directory, and nothing
  else, whatever `WOW_HOME` says. If the bin directory goes on Git Bash's `PATH`, add it in the
  form `cygpath -u` prints, because `PATH` splits at the drive colon.
  If `WOW_HOME` is already in MSYS form (`/c/...`), both launchers convert `-WowHome` with
  `cygpath -w` through the first `sh` on PowerShell's `PATH`, as the register scripts and `broker.ps1`
  do; with no `sh` there they convert only the drive form and refuse any other `/`-leading form. A
  failed conversion is refused and says to give the Windows form. A forward-slash UNC `WowHome`
  (`//server/share/...`) is unsupported and both launchers refuse it on Windows. The script path in the `pwsh -File
  $env:WOW_HOME\bin\...` commands is not converted: either set the user-level variable in the form
  above or spell the script path in that form. `install-host-tools.ps1` refuses an MSYS-form `WowHome`.
  `yq` must be on PowerShell's `PATH`, v4.54.1 or newer; both launchers refuse an older or unidentifiable `yq`
  before any docker call. The driver launcher also needs `gh` on PowerShell's `PATH`, on both paths, and for a
  start of day a `gh` login that can read the origin repository. The driver launcher runs the checks below in the safe order, so that order is
  the only one it offers.
  - **`-Clone`** is the clone the container opens (an absolute directory, not a link, whose leaf
    follows Docker's volume-name rule and whose whole path holds only letters, digits, space, `.`,
    `_` and `-`: `devcontainer.cmd` re-parses `&`, `|`, `^`, `%` and `"` through `cmd.exe`).
    **`-Reference`** is a different full clone that no container opens, with a different folder name from the clone (the two would share the `<leaf>-tmp` volume), for example the one
    `install-host-tools.ps1` installs from (its `.git` a directory, not a worktree's file); git runs
    there and never in the clone, whose `.git` config and hooks a container can write. **`-WowHome`**
    defaults as in `install-host-tools.ps1`. After its argument checks the driver launcher starts every
    process from it, never from the directory it was started in, and refuses (exit 2) a `-WowHome` that is or
    sits inside `-Reference`, so no process it starts has the clone or the Reference as its working directory.
    `-Remote` (default `origin`) and `-Base` (default `main`)
    name the ref in the Reference whose commit and model are read; `-Base` is also the branch the compare
    checks on the origin.
  - **Which path.** The clone's containers are those on its `<leaf>-tmp` volume plus those whose
    `devcontainer.local_folder` label names it (`docker ps -a`, both listings, every state). None, or
    one stopped, is **start of day**. Exactly one, running, is **attach**. Anything else refuses and
    names each id: `docker stop` the running one, `docker rm` a leftover (such as one VS Code made),
    then rerun. A container started by hand with a bind of the clone but neither the label nor the
    `-tmp` volume is invisible to both listings. A container on the Reference's volume or labelled
    with the Reference refuses on both paths.
  - **Start of day** compares the clone's `.devcontainer/` with the committed copy (same files, same
    bytes, no link anywhere; a CRLF checkout is refused as intended). The Reference names the commit at
    `<Remote>/<Base>`, but the copy is read through the API with the host `gh`, and only after the compare
    API reports that commit `identical` with or `behind` the origin's `<Base>`, so a commit that exists only
    in the Reference or in a fork refuses. The committed tree must hold `.devcontainer/devcontainer.json`.
    An older commit on `<Base>` still passes (a downgrade), and the binding is only as strong as `<Base>`'s
    protection against the dev App. It then recreates the container with `devcontainer up --skip-post-attach
    --remove-existing-container`, checks that exactly the container `up` reported is running, writes
    the record, and enters it. Before the fetch it reads the Reference's `<Remote>` repository (one
    github.com url, kept as lowercase `owner/name`) and refuses when the record names this clone and
    a different origin: a Reference of another repository was given. The limit: a start of day with no
    readable four-field record for the clone checks nothing and records whatever origin the Reference
    has, so the check catches a Reference that differs from the first one recorded, not a wrong first one. A clone behind `main` after a `.devcontainer/` merge is brought forward
    without running git on the host: `docker start <id>`, then `docker exec -u app -e
    GIT_TERMINAL_PROMPT=0 -w /workspace <id> git pull --ff-only`, then `docker stop <id>`, then rerun.
  - **The record** is `<WowHome>\driver\<leaf>.json`: `id` (the container, 64 hex digits), `commit`
    (the commit compared against, 40), `clone` (the canonical clone path) and `origin` (the Reference's
    repository as lowercase `owner/name`, never a raw url). Unlike
    the token directory the dev container mounts, it is never mounted into a container. It is written only after the re-list passes, to a
    temp file in the same directory and then renamed.
  - **Why recreate, then `docker exec`.** `WB-D33` requires the compare before every `up` and every
    `devcontainer exec`, because `exec` re-reads `.devcontainer/devcontainer.json` from the host, and
    a running container can rewrite `/workspace/.devcontainer/devcontainer.json`. `docker exec` reads
    no host copy; it reproduces what that file sets for entry (`remoteUser` `app`) as a literal, and `tests/identity-launchers.test.sh` holds it equal; the
    `-e GIT_TERMINAL_PROMPT=0` literal matches the image's own `ENV`.
    `up` on an existing container would reuse the mounts and run arguments it was created with, and
    the compare covers only the files; recreating while nothing runs makes the container's
    configuration come from the file just compared. The session is
    `/usr/local/bin/claude --model <models.architect> --effort medium` in `/workspace`, by absolute
    path so a `claude` earlier on the container's `PATH` is not the one launched. The session gets
    the first message `Driver for <owner>/<name>.`, the Reference's origin repository, on a start of
    day and on attach. It names no command, and any first message gives the session one turn before
    the human types, in which the repo's CLAUDE.md may lead it to run resume. The model is read
    from `.ai/project.yml` at the Reference's `<Remote>/<Base>` and matched to `sonnet`, `opus`,
    `haiku` or `fable`; effort has no config key, so `medium` is fixed in the script.
  - **Attach** is for a driver restart while lanes run in the same container: when the one running
    container is the one the record names, the launcher enters it with `docker exec`, with no compare,
    no `up` and no recreate, so the lanes and spec sessions are undisturbed. It refuses a record with no
    origin (written by an older launcher: stop the container once no lane runs, then rerun at start of day)
    and one whose origin differs from the Reference's. **Why it is sound, and what it trusts.**
    Only a container the start-of-day path created and recorded can reach it. Its mounts and run
    arguments were fixed at creation from the compared file, and `docker exec` reads no host file; an
    in-container edit to `.devcontainer/` matters only at the next `up`, which the start-of-day path
    compares first. Attach trusts everything that has happened to that container since creation. A
    VS Code Reopen or attach keeps the container's id and starts the host credential relay inside it,
    which is neither a mount nor a run argument, so **after any VS Code attach the container must be
    stopped** (`WB-D33`), and the next run takes the start-of-day path. As an accident guard, not a
    boundary, attach first runs a **relay probe** (`docker exec -u root`, a fixed script): it lists
    `/tmp/vscode-remote-containers-*` and greps every `/proc/<pid>/cmdline` for the relay processes;
    any output, or a nonzero exit, refuses.
  - **Attach's residuals.** The container runs the configuration of the commit it was created from,
    and keeps the image built then (the `claude` pin, the coreutils links, the `pwsh` pin), even if `main`'s
    `.devcontainer/` has moved since; the launcher prints that commit and warns when `.devcontainer/`
    has changed since, and the container should then be recreated at start of day once the lanes are
    done. Attach still fetches the Reference for the model, so an offline driver restart refuses.
  - **A live-run check for the maintainer, after the first start of day and after every start of day
    that follows a `FROM` bump:** `docker inspect` of the recreated container
    shows only the workspace mount and the `mounts` entries `devcontainer.json` declares, since the pinned base image might
    declare a `VOLUME`. The same check witnesses the controls the `FROM` image provides, each once per
    recreate:
    - The container's environment, from PowerShell on the host (not cmd, which does not treat single
      quotes as quoting): `docker inspect -f '{{json .Config.Env}}' <containerId>` lists
      `GIT_TERMINAL_PROMPT=0`, `DISABLE_UPDATES=1` and `DISABLE_AUTOUPDATER=1`. It reads the container's
      configuration, not a `docker exec` shell, whose `-e GIT_TERMINAL_PROMPT=0` would mask a missing image `ENV`.
    - From the `docker exec` shell as `app` in `/workspace` (the *By hand* command),
      `git config --get commit.gpgsign` and `git config --get tag.gpgsign` each print `false`.
    - In the same `docker exec` shell, `stat -c '%U %a' /etc/claude-code/managed-settings.json` prints `root 444` (root-owned, not
      writable by `app`). `jq` on that file shows `.env.DISABLE_UPDATES` and `.env.DISABLE_AUTOUPDATER`
      are both the string `"1"`, and `.requiredMinimumVersion` and `.requiredMaximumVersion` both equal
      the leading version number `/usr/local/bin/claude --version` prints (by absolute path, so a
      `claude` earlier on `PATH` is not the one compared).
    - In the same shell, `command -v timeout` prints `/usr/local/bin/timeout`, the GNU coreutils link; the fuller check
      is under *GNU coreutils, not uutils*.

    This is a check for the human, not launcher code.
- **By hand.** The driver launcher is the only way a container is created: no hand `devcontainer up`,
  no host VS Code Dev Containers, and no host git in a checkout a container mounts. To get a shell in the
  recorded running container, from PowerShell or cmd on the host (not Git Bash):
  ```sh
  docker exec -it -u app -e GIT_TERMINAL_PROMPT=0 -w /workspace <containerId> bash -l
  ```
  `<containerId>` is the id the launcher prints as `started <id>` or `attaching to <id>`. Run
  `/usr/local/bin/claude` instead of `bash -l` to start Claude Code directly. Run the channel check below
  after the first start of day.
- **Do not attach VS Code** (Reopen in Container, Rebuild, Attach to Running Container) (#720, `WB-D33`).
  Attach is what opens the host credential channel. There is no VS Code window inside the
  container: edit files from the container shell, and do not use the Claude Code VS Code panel
  there.
- Reviewer tokens never enter this container. App-mode review runs on the host through
  `wow-review`, run from `$WOW_HOME/bin` and never from a checkout. The review session clones from
  GitHub into its own tmpfs volume. Neither the session token nor the post token ever enters a
  dev container, and `/way-of-working:architect-review` run here, under an `identities` map,
  posts nothing and prints the launcher command.

## Adding a repo to this host

This is the host-side procedure that brings another repository of the same org into a dev
container acting as the dev App, on the shared-template route (`WB-D42`, its migration step 7).
It is written for a repository `<owner>/<repo>`, for example `glunk-works/<repo>`, in GitHub's
canonical case, and it needs no reading of this repo's `.devcontainer/`, scripts or config.
Do the steps in order. It documents the steps and performs none.

1. **Confirm the precondition (nothing is performed here).** The
   repo's whole ruleset cutover is done: the cutover's last PR (PR 2 where the two-PR order
   applies) is merged, and the gate's check is pinned (integration 15368) in the repo's checks
   ruleset, not merely the approval side. The cutover, and the approval ruleset's read-back with who reads it, are the plugin's
   `reference/cutover.md` (*The order*, *The approval side*); confirm that items 1 to 6 of *The
   approval side* are in place, that every item of that read-back passed, and that the checks ruleset reads back
   the same way (`enforcement` `active`, the default branch targeted, `bypass_actors` an empty
   list) with the gate's check pinned. Why: the broker keeps a write token current for every repo it lists, and
   with approvals at 0 a dev-App token could merge a green PR.
2. **Confirm the reviewer App (the App owner or an org owner; installs nothing).** It was
   installed on the repo before the cutover's PR 1 merged, since from that merge on a gated PR
   passes only with that App's review (`reference/cutover.md`, *The order*).
3. **Bring in the repo's `.devcontainer/` from the shared template (as one PR in
   that repo).** Take it from 603-Identity/devcontainers, with the template's
   `devcontainer-image.yml` workflow (it runs `verify / verify`). It replaces any existing
   `.devcontainer/` whole: its devcontainer Features and a `remoteUser` other than `app` go with
   it (`WB-D42`, *Per repo*). It carries a workflow file, so it is pushed and approved as
   `reference/cutover.md` (*The approval side*) requires for a workflow PR, never pushed by the
   dev App. It merges under the repo's own gate before the repo's first start of day, since the
   driver launcher compares the clone's `.devcontainer/` with the committed copy. The per-repo
   values, as the template's header lists them, are:
   - the token mount source `tokens/<owner>/<repo>` under the default identity directory (which
     `WOW_HOME` must be, per *Opening it*), equal to the repo's `github.repository` in GitHub's
     canonical case;
   - the `FROM` line: the dev-App flavour, or its tofu variant for a tofu repo, by tag and digest,
     and any root-run extras before the final `USER` line;
   - an optional loopback-only `appPort`.

   Nothing else differs from the template.
4. **Add the repo to the broker (the operator, on the host), only after step 1.** Add it, or replace any
   bare entry for it, as an `owner/name` entry, in GitHub's canonical case, to the identity home's `broker.json` and
   `review-poll.json`, never a bare name: the broker and a `wow-admin` mint refuse a bare entry, and only an `owner/name` entry makes the broker write
   `tokens/<owner>/<repo>`, the directory the template mounts at `/run/wow`. Then rerun
   `install-host-tools.ps1` through `register-broker-task.ps1`, from a claude-workbench clone no
   container opens, at origin's `main` (it stops the broker task around the swap). That creates
   `tokens/<owner>/<repo>`. Its cross-check must print no warning, and
   `broker.log` must show no `config:` line after the edit (a `broker.json` the broker refuses
   stops every repo's mint, not only the new one). One identity home serves one org: a repo of
   another owner needs its own home, which this section does not cover.
5. **Install the dev App and the loop App on the repo (whoever owns the installation, in the
   browser).** Add the repo to each App's existing installation. A pending permission request on
   an installation is not accepted in this procedure.
6. **Prove it with one read-only mint (the operator, on the host from Git Bash).** Run the
   installed `mint.sh` under the home's `bin`, with the `dev` entry of `apps.json` (`client_id`,
   `installation_id`, and the key file named there), and:
   - `--repos` the bare name half of the `owner/name` entry, because `mint.sh` refuses a slash;
   - `--perms contents=read` and `--strict`;
   - `--out` a file in a fresh directory no container mounts, removed afterwards without
     printing it.

   Exit 0 proves the dev installation covers the repo. One limit: removing the file does not
   revoke the token, which stays live until it expires. Then confirm, without printing line 1,
   that `tokens/<owner>/<repo>/dev-token` exists and that its second line, `expires_at`, is in the
   future; the broker writes it on its next pass.
7. **Enter the container (the operator, on the host).** The clone the container opens and the
   `-Reference` clone follow the `-Clone` and `-Reference` rules in *Opening it*, and the
   launcher prerequisites listed there apply, among them a host `gh` login that can read the
   repo and the `.ai/project.yml` the launcher reads at `-Base`, which names `models.architect`.
   Both folder names are unique among the checkouts on this host, since volumes and the driver
   record are keyed by folder name. One limit for a repo that had a container before: the
   Reference is a fresh second clone no container has ever opened, and the earlier container is
   removed and its per-folder volumes reset first, with the `docker volume rm` command under *The
   `claude` binary*, since the old home volume can hold a PAT login. Then run:
   ```powershell
   pwsh -File $env:WOW_HOME\bin\wow-driver.ps1 -Clone <clone> -Reference <second clone>
   ```
   After the first start of day, run the checks this file already gives: in the new container,
   from a `docker exec` shell, the channel check under *Hazards that remain* and the
   agent-socket check under *What it still carries from the template*; and the live-run check
   under *Opening it*, whose `docker inspect` steps run on the host and whose other steps run in
   that `docker exec` shell.

## Lanes

A lane is a second Claude session building one task in parallel with the driver session. The
driver runs in `/workspace`; every lane runs in the same container, in a worktree under
`/tmp/lanes/N` (`N` the task issue number); a spec session (below) gets a detached worktree
there too, named `spec-` and six letters or digits. `/tmp` is the per-repo `-tmp` volume, so it is
writable under the read-only root and the worktree's `.git` file points at a path the
container can follow. A host worktree beside the checkout cannot be used: the container sees
only `/workspace`, and its `.git` file names a host path.

- **Prepare, report on and clean up lanes** (driver, in `/workspace`, the main worktree) through
  `/way-of-working:lanes`, which calls the plugin's `bin/lane.sh` in four modes: `prep`, `status`,
  `done` and `groups`. `bin/lane.sh` runs only from the installed plugin, never as a working-tree copy by
  path, because it finds its siblings beside itself; no lane is prepped until a release carrying it
  is installed. Prepare a lane with:
  ```sh
  lane.sh prep N M BRANCH CRITICS [ALSO]
  ```
  `M` is the milestone the driver expects the task to be on, `BRANCH` is `TYPE/SLUG` and
  `CRITICS` a comma list of `architect`, `security-critic` and `docs-consistency`. `ALSO`, when
  given, is a comma list of issues folded into `N`: each is checked open, not a pull request and on `M`, like the task, and the
  prompt names them as issues the PR also closes. It reads the
  project file from the default branch's committed copy (the lanes directory is its `lanes.dir`) and
  its sibling scripts from the installed plugin, needs an installation token that reaches the
  repository, finds the approved spec with `spec-find.sh`,
  checks the task is open, not a pull request and on milestone `M`, cuts the worktree from
  `origin/<pr_base>` with `--no-track` (so nothing pushes to `main` by accident), and writes
  `N-prompt.md` in the lanes directory outside the worktree. The prompt names the task and milestone (the
  container clone has no `.ai/state.json`, so `coder.md`'s checks need them named), the installed
  plugin's `agents/coder.md`, the spec pin (`PIN_ID`, `PIN_UP`), the mode, the critics, the closes line when `ALSO` is given, the lane rules
  and a `PATH` line that puts the installed plugin's `bin/` first. It never holds issue or
  comment text. It prints `worktree=`, `branch=`, `found=`, `milestone=`, `prompt=` and
  `prompt-sha256=`. If a step from the base fetch on fails it undoes what it did, as far as it
  can, and prints `failed`. `prep` stops with one word instead: `not-main`, `no-lanes`, `unsafe-dir`, `unreadable`,
  `repo-mismatch`, `backlog-case`, `unreached`, `not-map`, `finder: WORD`, `bad-issue` or `exists`. To clear an `exists`
  caused by a stale name, run `git branch -dr origin/BRANCH` for a lingering remote-tracking
  ref, or `git config --remove-section branch.BRANCH` for leftover config, or pick another
  branch name.
  After ship, the lane sets its PR's milestone to `M` when `M` is still open, and reports
  the outcome; with a separate backlog repository it sets none. When the lane's PR is reported to
  the driver, the driver confirms the milestone. `P` is the PR number `lane.sh status` prints for
  the lane (found by branch, not taken from the lane's report), `M` the milestone number the driver
  passed to `prep`, and `OWNER/REPO` the repository the `repo` key of the project file names. The
  confirm read is `gh api repos/OWNER/REPO/pulls/P --jq '.milestone.number // 0'`: it prints `M`
  when the lane's write took, `0` when the PR has no milestone, and fails for a number that is not a
  pull request. Only when it prints `0`, milestone `M` is still open (`gh api
  repos/OWNER/REPO/milestones/M --jq .state` prints `open`) and the backlog is the repo, the driver
  gives the maintainer this one line, the endpoint and form the lane prompt's write uses (`-F`, so
  the milestone goes as a number), setting no other field:
  `gh api -X PATCH repos/OWNER/REPO/issues/P -F milestone=M --jq .milestone.number`. The driver
  then runs the confirm read again; the write took only when it prints `M`. With a separate backlog
  repository no milestone is set.
  The `PATH` line is written by the script and its text is checked by the fixture. A Bash tool
  call does not keep exports, so the lane prefixes the line, and checks that `command -v
  spec-find.sh` finds the installed plugin's copy, on every call that runs a plugin script. No lane
  has run it that way yet.
- **Report on the lanes**: `lane.sh status` prints one tab-separated row per lane, ordered by issue:
  the repository, `<backlog repo>#N`, the branch, the PR (`#P STATE`, `-` for none, `ambiguous`), a display-only
  checks word and the spec (`found` or the finder's word), or `none`. It removes and edits nothing, but fetches the default branch, as every mode does. Two code
  repositories sharing a backlog can each hold a lane `N`, which is why the repository and the
  backlog number are both printed. `/way-of-working:pr-checks` stays the merge verdict.
- **Another repo on the same host.** The same installed `wow-lane.ps1` starts a lane for another
  repository, given that repository's `-Clone` and `-Reference`. The command carries the hash that
  `prep` printed in that repository's container, that repository's issue, and the model from that
  repository's `models.coder`. A lane belongs to its container, so `prep`, `status`, `done` and `groups` run in
  the container of the repository the lane is for.
- **Start the lane** (#762) from the host, in its own terminal, from `pwsh` 7.2+, as the installed
  copy beside the driver launcher:
  ```powershell
  pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Clone <clone> -Reference <other clone> -Issue N -Hash HASH
  ```
  `HASH` is the `prompt-sha256` that `prep` printed. It takes `wow-driver.ps1`'s `-Clone`,
  `-Reference`, `-WowHome` and `-Base`, and `-Remote` names the remote in the Reference only. Before
  any interactive `docker exec` it checks the installed copy (the MANIFEST), the arguments, that
  the clone has exactly one container, running, and the Reference none, that the driver
  record names that container and the clone, and the relay probe; for all three modes it refuses a
  record with no origin and one whose origin differs from the Reference's, then reads the model
  (`models.coder`, not for `-SpecSweep`) and the lanes directory (`lanes.dir`) from the Reference at
  `-Base`, refusing all three modes when `lanes` is not declared or its `dir` is bad (the directory
  can differ from what `lane.sh` reads when `-Base` is not the default branch), then checks in the
  container, as `app`, that the lanes directory is safe, `<lanes.dir>/N` is a worktree, `<lanes.dir>/N-prompt.md` is a regular file and
  its sha256 is `HASH`. It needs the driver's start of day to have recorded the container, and it
  never writes the record. It then enters the container with `docker exec -it -u app -e
  GIT_TERMINAL_PROMPT=0 -w <lanes.dir>/N`, into `/usr/local/bin/claude --model <models.coder>`, and sends the lane
  this first message:
  > Lane for <owner>/<name> issue #N. In one Bash call, run: T=$(mktemp -d); cp <lanes.dir>/N-prompt.md $T/p.md;
  > sha256sum $T/p.md; echo $T/p.md. Stop unless that call printed the hash HASH. If it did, read only that copy and
  > follow it.

  The copy that was hashed is the copy that is followed. The check in the container is an accident
  guard: it runs as `app`, the same user as every lane. Do not use a second `devcontainer exec`
  beside a running session: `exec` re-reads `devcontainer.json` from the host, and that file has to
  be checked first (see *Opening it*).
- **Start a spec session** (#762), the same way:
  ```powershell
  pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Clone <clone> -Reference <other clone> -Spec N[,N...]
  ```
  Up to ten issue numbers, in order. It makes a detached worktree at the Reference's base commit
  under `<lanes.dir>/spec-XXXXXX` (refusing if the container clone's `origin/<Base>`
  is another commit than the Reference's), starts a session there on `models.architect` at `--effort high`, and sends it a
  first message that names the origin repository and asks it to
  run `/way-of-working:spec-task` for each issue in turn and build nothing. When the session exits it
  removes the worktree, without `--force`, only if it is still that detached worktree at that
  commit. Otherwise it keeps it, prints its path and exits 1. The likely cause is an untracked file
  the session left, such as `.claude/settings.local.json` after a "don't ask again" answer (it is
  not gitignored): inspect it, then run `git -C /workspace worktree remove --force
  /tmp/lanes/spec-XXXXXX` in a `docker exec` shell, or `git worktree remove` once it is clean, and
  only then `rm /tmp/lanes/record-spec-XXXXXX` (the launcher prints both lines). Beside the worktree
  the launcher writes a record, `/tmp/lanes/record-spec-XXXXXX`: the issue list, a space and the
  launch time in Unix seconds. It is removed with the worktree and kept with a kept one. A `-Spec`
  run refuses, before the container clone's fetch and before any worktree or record is made, when a spec session already running in the
  container (a `claude` process whose working directory is a `spec-` leaf under `/tmp/lanes`, also
  one whose directory was removed) covers any issue in the new list. The refusal names that
  session's worktree, process id and issues. A running session with no readable record counts
  as `unknown` and refuses every `-Spec` run until the maintainer stops it. This is an accident
  guard: two runs started close together can both pass it. `lane.sh done` neither sees nor
  removes a spec worktree.
- **List spec sessions** (#891):
  ```powershell
  pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Clone <clone> -Reference <other clone> -SpecSweep
  ```
  It lists every spec worktree directory, spec record and running spec-session process under
  the lanes directory, one line per running session and per leaf with none, with the issues and the launch time from the record (`unknown`
  without a readable one) and the process id (`no process` for a kept directory or an orphan
  record; a directory that is gone is marked so). It kills and removes nothing and starts no session, but it fetches in the Reference, as the other
  modes do: stopping a stray session, and removing its worktree and then its record, are done by hand.
  It runs the same origin check as the lane and spec modes, so it refuses a driver record with no
  origin or another repository's, and needs the Reference to fetch. The sweep refuses, listing
  nothing, when the lanes directory in the container is a link, not a directory, or
  not owned by the container user, as the lane and spec modes do; a missing lanes directory is not refused.
- **Driver handoff points** (#729). The driver runs `/way-of-working:handoff` after each lane PR
  merges and its `lane.sh done N` has run, after each batch of spec sessions, and whenever the
  status line shows `handoff` (60% or more of context used), rather than only when the context runs low.
- **Context controls** (#729). The project `.claude/settings.json` sets a status line that shows
  `ctx NN%`, the integer part of the session's context use (`ctx --` before the first message). The
  plugin's `PreCompact` and `PostCompact` hooks fire on an automatic compaction only (matcher `auto`):
  the first adds instructions to the summary to keep the next action, any open gate and every in-flight
  lane, and the second shows a line telling the driver to run handoff before new work. Both stay silent
  in a lane or spec worktree and outside a main worktree, never block a compaction, and a manual
  `/compact` runs neither. At 60% or more of context used the line reads `ctx NN% handoff` (#792). Lane state
  reads `lanes: { dir: /tmp/lanes }` in `.ai/project.yml` (#793; kept by the maintainer or driver), and
  `bin/lane-state.sh` lets handoff record the live lanes and
  resume report them, and `lane.sh status` reads it with `lane-state.sh` too.
- **Identity.** Every session, driver or lane, acts as the dev App through the container's `gh`
  shim and git credential helper. Do not prefix commands with `GH_TOKEN`. Suites run natively
  (no WSL), and commits are unsigned (`WB-D25`), so no `timeout 90` around signing.
- **Runtime of `tests/identity-review.test.sh` (#755).** Run alone on the container as built
  (GNU `timeout`), it takes 26 s on 28 cores (`nproc`), its sections running at once (#955); it took
  92 s before that. With the uutils `timeout` first on `PATH` the run with the sections one after
  another took 775 s, measured before #935, which overruns even the Bash tool's 600 s maximum (its default is 120 s). The cause is
  the `timeout` build: a run makes about 7,500 `timeout` calls across the launcher's wrapped
  docker and gh calls. An isolated `timeout 5 true` measured 62.2 ms with uutils against 0.8 ms
  with GNU, a 61.4 ms difference; that varies with load, and the suite's effective overhead is
  higher, about 90 ms per call. The other uutils tools' share was not measured. Run the suite
  alone, in its own Bash call, with the tool timeout at least 52 s (twice the 26 s). On a container whose
  `timeout --version` names uutils, the bound is about 1550 s: run the suite in the background, or
  stop and ask the maintainer. `scripts/test-all.sh` starts this suite with its pool; run it in one
  Bash call at the tool's 600 s maximum and stop and report if that call times out. If `command -v timeout` prints `/usr/bin/timeout`, the container
  predates #741 and the maintainer recreates it, on the host: after every lane, every spec session and the driver
  session have exited, `docker stop` the container, then run the driver launcher (start of day), and run *The check after a rebuild* in
  *GNU coreutils, not uutils*, which is also how to tell such a container. If it prints another
  path, a uutils copy in `~/.local/bin` shadows the links: the maintainer removes that copy (it
  survives a recreate, so recreating does not fix it).
  A lane never recreates the container.
- **Reviews** still run on the host through `wow-review`; in the container
  `/way-of-working:architect-review` prints the launcher command.
- **Lane rules that still apply:**
  - Lanes never run `/way-of-working:resume`, `/way-of-working:handoff`,
    `/way-of-working:plan-sprint` or `/way-of-working:archive-sprint`, and never write the `.ai/` cursor (another `.ai/` path only when the
    spec's *Files touched* lists it).
  - A lane never merges, approves or force-pushes. It works in its own worktree and does not
    edit `/workspace`'s working tree (the worktree's `.git` lives under `/workspace/.git`, so its
    commits and refs land there).
  - A session that drafted a spec, or read an issue's body, never builds that issue.
  - Every PR needs a code-owner approval; approving one with auto-merge armed merges it.
- **Cleanup** after the lane's PR merges (driver, in `/workspace`, and only after the lane
  session has exited): `lane.sh done N`, through `/way-of-working:lanes`. It removes the worktree, deletes the branch
  and removes the prompt file, but only if a same-repository PR from that branch merged into
  the base and `prune-verdict.sh` reads `delete`; the branch is deleted with `git update-ref -d`
  against the judged tip, never `git branch -D`.
  - On `kept X skip-ahead` or `kept X skip-unfetchable`, the worktree stays. Inspect it, then
    you may run `git worktree remove` and keep the branch.
  - On `missing`, run `git worktree prune --dry-run -v` first, since `git worktree prune`
    prunes every stale entry, other lanes' and kept spec worktrees included.
  - After its success lines `done` prints `next` lines: the groups `lane-groups.sh` computes for the
    task's milestone, less the issues of live lanes and issues whose `shared` field names one, or
    `next none` or `next unreadable`. A live lane is a lane worktree `lane-state.sh` lists (not a
    directory), and stays live until its own `done`, merged or not. It is checked for path overlap
    whatever its issue's milestone, but only when `lane-groups.sh` could read its spec paths. A
    `lane-state.sh list` that fails or prints `unreadable` makes the result `next unreadable`. The
    lines never change its exit status.
  - `not-main`, `no-lanes`, `unsafe-dir`, `unreadable`, `repo-mismatch`, `backlog-case`, `not-map`, `no-lane`,
    `not-merged`, `ambiguous` and `kept X unreadable` remove nothing, and so does
    `kept X checked-out` unless the second checkout appears just before the worktree is removed.
    `dirty` leaves the worktree and branch. An `unreadable` after the worktree was removed (the
    re-read of the worktree list failed) leaves the branch, its config and the prompt file: finish
    by hand. `kept X moved` (the branch holds a commit the lane
    made after the verdict) and that late `kept X checked-out` leave the branch and the prompt
    file for you to look at; the worktree is already gone.
  - `failed` means the config probe or removal, or the prompt file removal, failed after the
    branch was deleted; finish by hand with `git config --remove-section branch.X` and `rm` of
    the prompt file.
- **Fallback**, untried: if lanes in one container stop working, use one full clone and one
  container per lane, as *Opening it* describes. Each clone gets its own home volume, so the
  Claude login and the plugin install happen once per clone.

**Trial record.** The first container lane (#707) was built by the hand steps this section then described, and the proposed shape
worked as written: it launched with no changes, read its spec through the finder, built, ran
the gate natively, ran `critic-gate`, and shipped as the dev App with auto-merge armed. Nothing
in the procedure changed. The trial filed follow-ups #727, #728 and #729.

## Hazards that remain

- **`/workspace` is read-write**, so a session can edit `.devcontainer/` (an `initializeCommand`,
  wider mounts) and the host runs it at the next `devcontainer up`, Reopen or Rebuild. The launcher
  compares `.devcontainer/` with the committed copy it reads through the API (at a commit the compare API
  places on the origin's base branch, not from a clone a container can reach) before every `up`, and offers
  no `devcontainer exec`. Its start-of-day order is: it lists the clone's containers and refuses to start
  a day while one runs (it attaches instead only to the one recorded, running container), compares,
  recreates and enters with `docker exec`. The compare only holds while no
  container that mounts the clone is running, since any of them can write the file, so a running session could
  change it between the compare and the CLI's read; that also means no second `devcontainer exec`
  shell beside a running session, since `devcontainer exec` re-reads the host file. A `docker exec`
  into the recorded running container, which is what attach, lanes and spec sessions do, reads no host file and is
  allowed. The reasons: the CLI runs `initializeCommand` on the host on each `up`, even
  against a container that already exists, and `exec` re-reads `.devcontainer/devcontainer.json`
  from the host each call (its `remoteUser`, with any `${localEnv:*}` it names resolved from the
  host's environment), so a session's edit could copy a host environment variable into the
  container. A container created before this change keeps its old lifecycle commands until it is
  recreated, so it has no backstop.
- **VS Code's forwarded git credential channel (#720, `WB-D33`).** A VS Code attach opens it, and
  the fix is not to attach. Tested on 2026-10-17 with the VS Code user setting
  `dev.containers.gitCredentialHelperConfigLocation` at `none`: every attach still creates the
  helper client (`/tmp/vscode-remote-containers-<uuid>.js`), its socket and
  `REMOTE_CONTAINERS_IPC`, and calling the client directly returned the host's GitHub credential,
  so a process in the container could act on GitHub as the human. Keep the setting at `none`
  anyway, in every VS Code profile that keeps its own settings, as defense in depth for an
  accidental attach. The container's `postStartCommand` removes only the helper client,
  `/tmp/vscode-remote-containers-*.js`, at every start, and its `postAttachCommand` only warns that
  the repo is opened through the launcher, as the template's do (`WB-D33`, amended by `#1226`):
  a backstop only. The relay VS Code starts keeps running inside the container after its socket
  path is removed, and VS Code may recreate the files at a later attach or reconnect, so an
  accidental attach is narrowed, not closed. **One limit follows from the narrowed removal:** after
  an attach, a file of that prefix that is not a `.js` file (the IPC socket) stays on the `-tmp`
  volume, which survives a recreate, so the launchers' relay probe (attach and every lane run, not
  start of day) keeps refusing after the start-of-day recreate until the leftover files are
  removed in the container start of day created: `docker exec -u app ID /bin/sh -c "/bin/rm -f
  /tmp/vscode-remote-containers-*"`, with `ID` the id the start-of-day run printed as `started ID`
  (the shell expands the glob; `docker exec` alone would pass it literally and remove nothing),
  then the same `docker exec -u app ID /bin/sh -c` form running `/bin/ls -d
  /tmp/vscode-remote-containers-*` lists no file. Removing the `-tmp` volume instead would also
  delete every lane and spec worktree under `/tmp/lanes`. The check, from a `docker exec` shell, starts with the no-channel
  test: `echo "${REMOTE_CONTAINERS_IPC:-unset}"` prints `unset`,
  `ls /tmp/vscode-remote-containers-* 2>/dev/null` prints nothing, and
  `grep -la '[v]scode-remote-containers-server\|[v]scode-server' /proc/[0-9]*/cmdline 2>/dev/null`
  prints nothing. Anything but `unset` from the first, or any output from the second or third,
  fails the check. The first cannot see a live channel at all (the variable exists only in VS Code's own
  processes), and the second cannot see a relay left running after its socket path is gone;
  the third can, within this container.
  After an accidental attach, close the VS Code window (or it will offer to reconnect) and stop
  the container at once (`docker stop`), which ends the relay, so that the next driver launcher run takes
  the start-of-day path;
  the exposure runs from the attach until that stop. A running Claude session, or code from a PR it
  builds, counts as untrusted, so in normal use treat every credential the host's git helpers can
  return (each GitHub account, each host) as exposed and rotate it, and sign out of the GitHub account in VS Code and revoke its OAuth grant on github.com, since the git askpass channel an attach opens answers with that sign-in. The start-time removal also
  loses a race against a process already watching `/tmp`, which can read the new client and
  connect before the removal runs.
  On the CLI path the test is the second and third checks plus the launcher's container listing. Do not
  run the masked credential test below there: when the `ls` check printed nothing no client file
  exists, so it has nothing to call and its lack of a `password=`
  line proves nothing. It is the diagnostic that established #720, kept for a maintainer
  investigating an attach, run from the VS Code-attached terminal of that attach (the client finds
  its socket through `REMOTE_CONTAINERS_IPC`, set only there), only while a client file is still
  there (when the `ls` check printed one), and only if the maintainer chooses to delay the stop:
  running it pulls the host credential into the container. It hides any secret it gets on screen.
  A pass is a well-formed helper reply with no `password=` line and no sign-in prompt on the host;
  an error or empty output is not a pass:
  ```sh
  N=$(ls -d ~/.vscode-server/bin/*/node | head -n 1)
  H=$(ls /tmp/vscode-remote-containers-[0-9a-f]*.js | head -n 1)
  printf 'protocol=https\nhost=github.com\n\n' | timeout 30 "$N" "$H" git-credential-helper get 2>&1 \
    | sed -E 's/^(password|oauth_refresh_token)=.*/\1=<present, hidden>/'
  ```
- **A forwarded host ssh-agent** is not blocked: git's SSH remotes are rewritten to https, but
  `ssh git@github.com` would authenticate with a GitHub key loaded in the host agent. Keep no
  GitHub key in the agent that VS Code forwards, and no key that is registered on GitHub as a
  signing key: `git -c gpg.format=ssh -c user.signingkey=... commit -S` (or `tag -s`) would sign as the human through
  it, and the commit would show Verified.
- **A forwarded GPG agent socket** was not found by the live check on 2026-10-17, which ran from
  a VS Code-attached terminal and says nothing yet about the CLI path; run the check in "What it
  still carries from the template" after the first `up`, and again after a Dev Containers CLI update
  (`WB-D25`, #574).
- **A reused home volume** can hold a human `gh auth login` PAT from an earlier container; the
  shim overrides it, but `/usr/local/libexec/gh-real` does not. `docker volume rm <checkout folder>-home`
  before first use.

## What it still carries from the template

The host's `~/.gitconfig.d` is mounted read-only, and `git-identity.sh` copies the author name
and email from it, so commits carry the human's author identity and are pushed by the App.

It carries **no commit signing** (`WB-D25`, #574). Container commits and tags are unsigned:
the flavour image removes `gpg`, `gpg-agent`, `gpgconf`, `gpg-connect-agent` and `gpgsm` and
writes its unsigned marker, which keeps `commit.gpgsign` and `tag.gpgsign` off, not `containerEnv`, which `devcontainer.json` no longer carries (a repo-local
`gpgsign = true` wins, and the commit then fails for want of gpg); the
template's `gpg-check.sh` does not run at start.
`main` stays signed because every merge is a squash merge, which GitHub signs.

Deleting the tools does not by itself prove VS Code stops forwarding the agent socket, and if an
agent is still forwarded, any process in the container can sign as the human by talking to the
socket directly. The live check came back empty on 2026-10-17, during the #397 cutover attempt,
from a VS Code-attached terminal: that says nothing yet about the CLI path.
Run it from a `docker exec` shell:

```sh
find /home/app /tmp /run /var/tmp /dev/shm -type s -name 'S.gpg-agent*'
```

Those are the writable mounts where an agent socket can land, which `find -xdev` from `/`
would skip. Output means a socket is forwarded; no output is the pass. A "Permission denied"
line is not a pass: rerun it with `docker exec -u root`.
A socket file that predates the container's start and refuses a connection is a dead file left on the
home volume by an earlier container, not a forwarded socket (python `socket.connect` shows `ConnectionRefusedError`);
`docker volume rm <checkout folder>-home` clears it.

## Claude login

`claude /login` once inside the container, from a `docker exec` shell. The credential lives in the per-checkout home volume
`<checkout folder>-home`, and `docker volume rm <checkout folder>-home`
removes it. The login lives on the volume; the binary does not.

## The `claude` binary

- **Where it comes from.** The `FROM` image's flavour (603-Identity/devcontainers):
  `/usr/local/bin/claude`, root-owned, at a pinned version checked at build time against its
  SHA-256. Auto-update is off through `DISABLE_UPDATES` and `DISABLE_AUTOUPDATER` as image `ENV`
  and through the root-owned `/etc/claude-code/managed-settings.json`, which a settings file cannot
  override, sets both in `env` and pins the version with `requiredMinimumVersion` and
  `requiredMaximumVersion`; its content comes with the `FROM` digest. The read-only root filesystem
  keeps the binary from being replaced, but not an updater writing a newer copy to `~/.local` on
  the home volume, so those settings are the control. `DISABLE_UPDATES` blocks a manual
  `claude update` as well. After a rebuild,
  `stat -c '%U %a' /etc/claude-code/managed-settings.json` prints `root 444`. Per Claude Code's
  managed-settings documentation ("How Claude Code combines managed sources"), `env` merges per
  variable across managed sources, so server-managed settings, if this account ever receives them,
  override this pin only if they set `DISABLE_AUTOUPDATER` themselves.
- **How to bump it.** A bump of this container's `claude` comes with a `FROM` bump (a new digest
  from the flavour's "Build images" run, which `verify / verify` checks). The two Dockerfiles that
  still carry the pin, `scripts/identity/review/` and `scripts/loop/`, are edited together in
  `CLAUDE_VERSION` and `CLAUDE_SHA256` (Dependabot does not track them, and
  `tests/review-image.test.sh` holds them equal). Take the sha256 from that version's release
  `manifest.json` (the `linux-x64` entry). A `FROM` bump needs the container recreated too; recreate it: after every lane, every spec session and the driver session have exited, `docker stop` it, then
  run the driver launcher (start of day), then run the live-run check under *Opening it*.
- **Clearing a stopgap install.** A copy from the native installer lives on the home volume, and
  `~/.local/bin` leads `PATH`, so it shadows the image's. Remove `~/.local/bin/claude` and
  `~/.local/share/claude`, then check with `command -v claude` (should print
  `/usr/local/bin/claude`) and `claude --version` (should print the pinned version).
- **What this does not close.** The binary cannot be modified, but which `claude` runs can be:
  anything earlier on `PATH` shadows it (`type -a claude` lists every match). Hooks in
  `~/.claude/settings.json` and startup code in `~/.bashrc` are still on the writable home volume, as are, for
  example, `~/.profile`, `~/.claude.json` and `~/.local/bin`, so a session can still persist code
  that runs in the next one. The VS Code extension's own `claude` is outside the pin too (VS Code
  attach is unsupported here). `docker volume rm <checkout folder>-home <checkout folder>-tmp <checkout folder>-venv <checkout folder>-node_modules`
  (after removing the containers that use them; removing `-tmp` also deletes every lane and spec worktree under `/tmp/lanes`) resets the container's own state, not the `/workspace` checkout, whose `.claude/` and
  `.git/hooks` or `.git/config` a session can also write and which must be checked separately.

## GNU coreutils, not uutils

- **Why.** The base image is Ubuntu 26.04, where the plain coreutils names (`timeout`, `date`,
  `tail` and the rest) are the Rust uutils build. Its `timeout` adds about 100 ms to every call,
  which `scripts/identity/wow-review`, `tests/identity-review.test.sh` and other suites and plugin
  scripts pay, and some uutils tools give wrong results: `date +%s%3N` ignores the width and prints
  nanoseconds. CI and Git Bash run GNU, so the container was the odd one out (#741).
- **Where it comes from.** The `FROM` image's flavour links the GNU tools under their plain names
  in `/usr/local/bin`, which comes before `/usr/bin` on `PATH`; how it does so is reviewed in
  603-Identity/devcontainers, and this repo's Dockerfile builds none of it.
- **What it covers.** Parity with CI for coreutils only. The container's `awk` (mawk) and `sh`
  (dash) are unchanged. `tests/dev-token.test.sh` assumes GNU `date`.
- **What it does not cover.** Callers that bypass `PATH` still get uutils: absolute `/usr/bin/...`
  or `/bin/...` paths (`/bin` is the usrmerge link to `/usr/bin`), a `PATH` reset to
  `/usr/bin:/bin`, and `env -i` with no `PATH` (libc's default is `/bin:/usr/bin`). A
  `#!/usr/bin/env` shebang runs only `env` itself from uutils; the script's own calls go through
  `PATH` and get GNU. Anything earlier on `PATH` wins, and `~/.local/bin` leads it. The
  uutils-only extras (for example `hashsum`) and `/usr/sbin/gnuchroot` are not linked. The review
  image and the loop image are separate (#760).
- **The check after a rebuild**, which comes after every lane, every spec session and the driver session have exited, `docker stop` of the
  container, and the driver launcher (start of day):
  `command -v timeout` prints `/usr/local/bin/timeout`, `timeout --version` names GNU coreutils on
  its first line, `date +%s%3N` prints 13 digits, and `ls ~/.local/bin` lists no coreutils name (a
  copy there, on the home volume, would shadow the links).

## PowerShell

- **Where it comes from.** The image (#893): the `linux-x64` tarball of the version in
  `PWSH_VERSION` in `.devcontainer/Dockerfile`, this repo's one extra on top of the flavour, its SHA-256 (`PWSH_SHA256`) checked at build time
  with `sha256sum -c`, extracted root-owned and without group or other write under `/opt/microsoft/powershell/7` and linked from
  `/usr/local/bin/pwsh`. A build-time assertion fails the build if `pwsh` does not run or reports
  another version. This is what lets `tests/identity-launchers.test.sh` and
  `tests/identity-broker.test.sh` run in lanes instead of printing `SKIP - pwsh not on PATH`.
- **Why invariant globalization.** `pwsh` runs with `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`, so it
  needs no `libicu`. The base image ships no apt lists, and a build-time package fetch the `FROM` digest does not pin is
  refused here. Telemetry is off
  (`POWERSHELL_TELEMETRY_OPTOUT=1`). Both are set by one `ENV` line in the Dockerfile, which `docker exec`
  also sees.
- **How to bump it.** Edit both `ARG` lines. Dependabot does not track a pin inside a `RUN`. Take the
  hash from the release's `hashes.sha256` list (the `linux-x64.tar.gz` entry) and confirm it by
  downloading the file and running `sha256sum` on it. Then recreate the container by the
  procedure in *The `claude` binary*.
- **What it does not cover.** Only this image: the review and loop images are unchanged. A `pwsh`
  earlier on `PATH` shadows it. Under invariant globalization culture-aware string comparisons run
  ordinal, so a sort or comparison result can differ from CI and the host.
- **The check after a rebuild**: `command -v pwsh` prints `/usr/local/bin/pwsh`, `pwsh --version`
  names the pinned version, and `sh tests/identity-launchers.test.sh` and
  `sh tests/identity-broker.test.sh` no longer print their pwsh SKIP line (the broker suite's Task
  Scheduler case skips off Windows and runs in CI's `tests-windows` job).

## Adopted from the template, and not

The template's `devcontainer-image.yml` (`verify / verify`) and `secret-scan.yml` (`secrets / scan`)
are adopted, unchanged, and are not required checks: making either one required is a ruleset
decision for the maintainer, so a red result blocks no merge. The template's
`architect-review-gate.yml` is not adopted: this repo keeps its own gate workflow of that name
(#458, `WB-D37`). The attestation command to check the pinned digest by hand is in
`.devcontainer/Dockerfile`'s header (written for the tofu variant: use the `devcontainer-devapp` name).
