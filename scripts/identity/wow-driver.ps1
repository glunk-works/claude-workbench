#Requires -Version 7.2

<#
.SYNOPSIS
  Start the driver session in the dev container of -Clone, for the repository of -Reference's origin,
  after the checks that must come first (WB-D24, WB-D33, issue #728).
  Any repository of the org the -WowHome identity home serves works, chosen by -Clone and -Reference,
  or by -Repo once a start of day has recorded both, if it is set up as the
  "Adding a repo to this host" section of claude-workbench's docs/identity/DEV-CONTAINER.md describes
  and its .ai/project.yml at -Base holds the keys the -Reference help names.
  Run it from pwsh 7.2+ on the host, from the installed copy in
  $WOW_HOME\bin (install-host-tools.ps1), never from a checkout.

.DESCRIPTION
  Two paths, chosen by the clone's containers: those on its <leaf>-tmp volume, plus those whose
  devcontainer.local_folder label names it (docker ps -a, every state).

  Start of day (no container, or one stopped container), in order:
    1. compares the clone's .devcontainer/ with the committed copy, same files, same bytes, no link
       anywhere. The Reference clone names the commit (<Remote>/<Base>), but the copy is read through the
       host gh from the API, and only after GitHub's compare API reports that commit identical with or
       behind <Base> of the Reference's origin repository, so a commit that exists only in the Reference
       or in a fork of that origin never passes (an older commit on <Base> still does: a downgrade, and the binding is
       only as strong as <Base>'s protection against the dev App). The committed tree must hold
       .devcontainer/devcontainer.json, which the devcontainer CLI reads before a root .devcontainer.json;
    2. recreates the container: devcontainer up --skip-post-attach --remove-existing-container;
    3. checks that exactly the container up reported is running;
    4. records its id, the commit compared against, the clone's path, the Reference's origin
       repository (lowercase owner/name) and the Reference's path in <WowHome>\driver\<leaf>.json (never mounted into a
       container);
    5. enters it with docker exec, into /usr/local/bin/claude --model <models.architect> --effort medium
       in /workspace, with the first message "Driver for <owner>/<name>." naming the Reference's origin
       repository. It names no command; any first message gives the session one turn before the
       human types, in which the repo's CLAUDE.md may lead it to run resume.

  The binding is to the Reference clone's configured origin. Nothing checks that origin against the
  repository the clone is for: a Reference whose origin is a fork binds to the fork's base branch.
  -Repo picks a record by the origin recorded from that same configured url, so it adds no such check.

  -Repo owner/name takes the place of -Clone and -Reference: both paths are read from the one driver
  record in <WowHome>\driver whose origin is that repository, and then go through the checks a given
  -Clone and -Reference go through. It works once a start of day with -Clone and -Reference has
  written a record holding the Reference path; the first start of day for a repository takes both
  paths. It refuses when no record, or more than one, names the repository, when the match has no
  Reference path (an older record), and when any file in driver\ does not read.

  Before the fetch, both paths read the Reference's <Remote> repository and the driver record. A start
  of day whose record names this clone and a different origin refuses (a Reference of another
  repository was given); attach refuses a record with no origin and one whose origin differs.

  Attach (the driver restarted while lanes run in the same container): when the one running container
  is the one the record names, runs the relay probe and enters it with docker exec. No compare, no up,
  no recreate, so the lanes are undisturbed. An attached container runs the configuration of the
  commit it was created from; the launcher prints that commit and warns when .devcontainer/ has changed
  since. The session gets the same first message as a start of day. It still fetches the Reference clone for the model, so an offline restart refuses.

  Anything else refuses and says what to run. docker exec reads no host copy of
  .devcontainer/devcontainer.json, which a running container can rewrite; devcontainer exec does
  (WB-D33). The docker exec user literal is that file's remoteUser (app); GIT_TERMINAL_PROMPT=0
  matches the flavour image's own ENV and is kept as a literal; tests/identity-launchers.test.sh
  holds the user equal.

  After the argument checks (the sh run that converts an MSYS-form -WowHome aside, which runs before
  -WowHome is known) every external process this launcher starts runs with -WowHome as its working
  directory, never the directory it was started from, so none starts with the Clone or the Reference as
  its working directory; -WowHome may therefore not be, or sit inside, -Reference. git still enters the
  Reference through -C, as before.

  Exit codes: 2 for a bad or missing argument (a usage line on stderr, before any external call, except the
  sh run that converts an MSYS-form -WowHome);
  with -Repo the record lookup (exit 1 when it refuses) runs before the checks of -Remote and -Base,
  so those exit 2 only once a record is found;
  1 for every refusal (a one-line reason on stderr); otherwise the session's own exit code.
  PowerShell's own binding errors (an unknown parameter, a stray positional argument) exit 1 with
  PowerShell's message.

  Honest limit. The MANIFEST check below catches running from a checkout by mistake. It is not a
  boundary: whoever can write this script can write the MANIFEST. A container that can write the
  Reference clone can plant git config or hooks that run when this script runs git there, which is
  host code execution beside the App keys; the Reference must be a clone no container opens. git
  never runs in the Clone, whose .git a container can write.

.PARAMETER Repo
  owner/name, each half letters, digits, . _ -: the repository whose driver record supplies -Clone and
  -Reference. Exclusive with both (exit 2); without it both are required.

.PARAMETER Clone
  The clone the container opens: an absolute existing directory, not a link, whose leaf is the
  Docker volume-name rule and whose path holds only letters, digits, space, . _ - and separators
  (devcontainer.cmd re-parses & | ^ % and " through cmd.exe).

.PARAMETER Reference
  A different full clone that no container opens: its .git a directory, not a file. It supplies the commit, the origin repository and models.architect.
  Its <Remote> must have exactly one github.com url, and its repository must match the driver
  record's origin when there is one.

.PARAMETER WowHome
  Default: $env:WOW_HOME, else $HOME/.config/glunk-identity. The Clone may not contain it.
  On Windows an MSYS form (/c/x) is converted with cygpath -w through the first sh on PATH, as the register scripts do;
  with no sh it falls back to the drive-form conversion (any other /-leading value is refused). A // value is refused.

.PARAMETER Remote
  Default origin.

.PARAMETER Base
  Default main.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Repo,
  [string]$Clone,
  [string]$Reference,
  [string]$WowHome = $(if ($env:WOW_HOME) { $env:WOW_HOME } else { Join-Path $HOME '.config/glunk-identity' }),
  [string]$Remote = 'origin',
  [string]$Base = 'main'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The installed-copy guard: before the helper is dot-sourced, and before anything else runs.
$notInstalled = {
  [Console]::Error.WriteLine('wow-driver: run the installed copy in $WOW_HOME/bin (install-host-tools.ps1)')
  exit 1
}
# First-message template: only @ORIGIN@ is filled, from the Reference's origin repository.
$script:DriverMessage = 'Driver for @ORIGIN@.'

try {
  $manifestPath = Join-Path $PSScriptRoot 'MANIFEST'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { & $notInstalled }
  $manifest = [IO.File]::ReadAllText($manifestPath).Split("`n") | ForEach-Object { $_.TrimEnd("`r") }
  if (@($manifest)[0] -cnotmatch '\Acommit [0-9a-f]{40}\z') { & $notInstalled }
  foreach ($name in 'wow-driver.ps1', 'wow-launch-common.ps1') {
    $own = Join-Path $PSScriptRoot $name
    $rows = @($manifest | Where-Object { $_ -cmatch '\A[0-9a-f]{64}  ' -and $_.Substring(66) -ceq $name })
    if ($rows.Count -ne 1 -or -not (Test-Path -LiteralPath $own -PathType Leaf)) { & $notInstalled }
    if ($rows[0].Substring(0, 64) -cne (Get-FileHash -LiteralPath $own -Algorithm SHA256).Hash.ToLowerInvariant()) { & $notInstalled }
  }
} catch { & $notInstalled }

$script:LaunchProg = 'wow-driver'
$script:LaunchUsage = 'usage: wow-driver.ps1 (-Clone <path> -Reference <path> | -Repo <owner/name>) [-WowHome <path>] [-Remote <name>] [-Base <name>]'
. (Join-Path $PSScriptRoot 'wow-launch-common.ps1')

try {
  # --- arguments: exit 2, before any external call (the one exception: the sh run for an MSYS-form -WowHome) ---
  # -Repo: the two paths come from the driver record, then go through the checks a given pair goes through.
  $wowP = $null
  if ($PSBoundParameters.ContainsKey('Repo')) {
    Assert-RepoArgument $Repo
    if ($PSBoundParameters.ContainsKey('Clone') -or $PSBoundParameters.ContainsKey('Reference')) { Stop-BadArgument '-Repo cannot be combined with -Clone or -Reference' }
    $wowP = Resolve-LaunchDir '-WowHome' (ConvertFrom-MsysDrivePath '-WowHome' $WowHome) -Plain
    $found = Find-RecordByRepo $wowP $Repo
    $Clone = $found.Clone
    $Reference = $found.Reference
  }
  $cloneP = Resolve-LaunchDir '-Clone' $Clone
  $refP = Resolve-LaunchDir '-Reference' $Reference
  $gitDir = Join-Path $refP '.git'
  if (-not (Test-Path -LiteralPath $gitDir -PathType Container)) { Stop-BadArgument '-Reference needs a .git directory (not a file, so not a worktree)' }
  if (Test-ReparsePoint $gitDir) { Stop-BadArgument "-Reference's .git is a link or reparse point" }
  if ((Test-PathInside $cloneP $refP) -or (Test-PathInside $refP $cloneP)) { Stop-BadArgument '-Clone and -Reference may not be, or contain, one another' }
  if ($null -eq $wowP) { $wowP = Resolve-LaunchDir '-WowHome' (ConvertFrom-MsysDrivePath '-WowHome' $WowHome) -Plain }
  if ((Test-PathInside $cloneP $wowP) -or (Test-PathInside $wowP $cloneP)) { Stop-BadArgument '-Clone may not be, contain or sit inside -WowHome' }
  if (Test-PathInside $refP $wowP) { Stop-BadArgument '-WowHome may not be, or sit inside, -Reference' }
  if (-not (Test-RefName $Remote)) { Stop-BadArgument '-Remote is not a plain ref name' }
  if (-not (Test-RefName $Base)) { Stop-BadArgument '-Base is not a plain ref name' }
  $leaf = [IO.Path]::GetFileName($cloneP)
  $refLeaf = [IO.Path]::GetFileName($refP)
  if ($leaf -ieq $refLeaf) { Stop-BadArgument '-Clone and -Reference may not share a folder name: they would share the <leaf>-tmp volume' }
  $script:LaunchWorkDir = $wowP

  # --- installed from bin under the final WowHome -------------------------------------------------
  $binWant = Join-Path $wowP 'bin'
  if ((Format-PathKey (Get-FinalPath $PSScriptRoot)) -ne (Format-PathKey $binWant)) { & $notInstalled }

  $git = Resolve-Tool 'git'
  $gh = Resolve-Tool 'gh'
  $docker = Resolve-Tool 'docker'
  $devcontainer = Resolve-Tool 'devcontainer'
  $yq = Resolve-Tool 'yq'
  Assert-YqVersion $yq

  # --- the Clone's containers: which path --------------------------------------------------------
  $mine = @(Get-LaunchContainers $docker $cloneP $leaf)
  Assert-KnownStates $mine
  $running = @($mine | Where-Object { $_.State -ceq 'running' })
  if ($mine.Count -eq 0 -or ($mine.Count -eq 1 -and $running.Count -eq 0)) { $mode = 'start' }
  elseif ($mine.Count -eq 1) { $mode = 'attach' }
  else {
    $ids = ($mine | ForEach-Object { "$($_.Id) ($($_.State))" }) -join ', '
    Stop-Launch "found $($mine.Count) containers for this clone: $ids. docker stop the running one, docker rm every leftover (such as one VS Code made), then rerun at start of day"
  }

  # --- the Reference: no container may open it, then commit and model -------------------------------
  $refBusy = @(Get-LaunchContainers $docker $refP $refLeaf)
  if ($refBusy.Count -gt 0) {
    Stop-Launch "the Reference clone is in use by container $($refBusy[0].Id): the Reference must be a clone no container opens"
  }
  $refOrigin = Get-ReferenceOrigin $git $refP $Remote
  $record = Get-RecordPath $wowP $leaf
  if ($mode -eq 'start') {
    # Anything the strict read would refuse counts as no record: the start replaces it.
    $old = Read-Record $record -NoRefuse
    if ($null -ne $old -and $null -ne $old.origin -and (Format-PathKey $old.clone) -eq (Format-PathKey $cloneP) -and $old.origin -cne $refOrigin) {
      Stop-Launch "the driver record for this clone names $($old.origin) but the Reference's $Remote is ${refOrigin}: a Reference of another repository was given (delete $record only if the repository really changed)"
    }
  } else {
    $rec = Read-Record $record
    if ($null -ne $rec -and (Format-PathKey $rec.clone) -eq (Format-PathKey $cloneP)) {
      if ($null -eq $rec.origin) { Stop-Launch "the driver record has no origin (written by an older launcher): docker stop $($mine[0].Id) once no lane runs, then rerun at start of day" }
      if ($rec.origin -cne $refOrigin) { Stop-Launch "the driver record names $($rec.origin) but the Reference's $Remote is ${refOrigin}: a Reference of another repository was given" }
    }
  }
  $commit = Get-ReferenceCommit $git $refP $Remote $Base
  $model = Get-RoleModel $git $yq $refP $commit 'architect'

  if ($mode -eq 'start') {
    # 1. the commit is on <Base> of the origin, then compare the committed copy, both through the API
    $rootTree = Assert-CommitOnBase $gh $refOrigin $Base $commit
    Test-DevTree $gh $refOrigin $rootTree $cloneP
    # 2. recreate
    $up = Invoke-Tool $devcontainer @('up', '--skip-post-attach', '--remove-existing-container', '--workspace-folder', $cloneP) -InheritStderr
    if ($up.Code -ne 0) { Stop-Launch "devcontainer up failed (exit $($up.Code))" }
    $lines = @([Text.Encoding]::UTF8.GetString($up.Out).Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($lines.Count -eq 0) { Stop-Launch 'devcontainer up printed no result' }
    $last = $lines[-1]
    try { $res = $last | ConvertFrom-Json -ErrorAction Stop } catch { Stop-Launch 'devcontainer up printed no JSON result' }
    if ($res -isnot [pscustomobject] -or -not $res.PSObject.Properties['outcome'] -or -not $res.PSObject.Properties['containerId']) {
      Stop-Launch 'devcontainer up result lacks outcome or containerId'
    }
    if ($res.outcome -isnot [string] -or $res.outcome -cne 'success') { Stop-Launch 'devcontainer up did not report success' }
    if ($res.containerId -isnot [string] -or -not (Test-Hex $res.containerId 64)) { Stop-Launch 'devcontainer up reported a malformed container id' }
    $id = $res.containerId
    # 3. exactly that container, running
    $after = @(Get-LaunchContainers $docker $cloneP $leaf)
    Assert-KnownStates $after
    if ($after.Count -ne 1 -or $after[0].Id -cne $id -or $after[0].State -cne 'running') {
      $ids = ($after | ForEach-Object { "$($_.Id) ($($_.State))" }) -join ', '
      Stop-Launch "after up, expected only $id running, found: $(if ($ids) { $ids } else { 'none' }). docker stop the new container ($id) and docker rm any other, then rerun"
    }
    # 4. record
    Write-Record $record $id $commit $cloneP $refOrigin $refP
    Write-LaunchLine "started $id from $commit"
  } else {
    # attach
    if ($null -eq $rec) { Stop-Launch "no driver record at $record for the running container: stop it (docker stop $($mine[0].Id)), then rerun at start of day" }
    if ((Format-PathKey $rec.clone) -ne (Format-PathKey $cloneP)) { Stop-Launch 'the driver record names another clone: no two checkouts may share a folder name' }
    $id = $mine[0].Id
    if ($rec.id -cne $id) { Stop-Launch "the running container $id is not the recorded one ($($rec.id)): stop it (docker stop $id), then rerun at start of day" }
    Test-RelayProbe $docker $id
    Write-LaunchLine "attaching to $id, created from $($rec.commit)"
    $then = Get-DevTreeId $git $refP $rec.commit
    $now = Get-DevTreeId $git $refP $commit
    if ($null -eq $now) { Stop-Launch ".devcontainer/ cannot be read at $commit in the Reference clone" }
    if ($null -eq $then) { Write-LaunchLine "the .devcontainer/ tree at $($rec.commit) is unknown to the Reference clone" }
    elseif ($then -cne $now) {
      Write-LaunchLine "$Base's .devcontainer/ has changed since: recreate the container at start of day once the lanes are done"
    }
  }

  $message = $script:DriverMessage.Replace('@ORIGIN@', $refOrigin)
  $code = Invoke-Session $docker @('exec', '-it', '-u', 'app', '-e', 'GIT_TERMINAL_PROMPT=0', '-w', '/workspace', $id,
    '/usr/local/bin/claude', '--model', $model, '--effort', 'medium', $message)
} catch {
  Stop-Launch $_.Exception.Message
}
exit $code
