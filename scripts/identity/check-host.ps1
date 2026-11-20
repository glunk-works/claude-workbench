#Requires -Version 7.2
<#
.SYNOPSIS
  Report what the Windows host needs to run the launchers (issue #1434). It reports and never fixes: it
  installs, updates, registers, enables or edits nothing.

.DESCRIPTION
  Run it on the host, from PowerShell 7.2+, from the clone install-host-tools.ps1 installs from, like
  install-host-tools.ps1 and register-broker-task.ps1 (it is not installed into bin). It prints one line
  per check, in this order. HOME is the -WowHome path as given; a commit is printed as its 40 characters.

    pwsh ok VERSION | pwsh old VERSION 7.2 | pwsh missing | pwsh unknown
      from `pwsh --version` on PowerShell's PATH; no three-part version or a non-zero exit is unknown.
    yq ok VERSION | yq old VERSION MINIMUM | yq missing | yq unknown
      from Test-YqVersion (wow-launch-common.ps1, the one place the minimum is written) on `yq --version`.
    gh ok | gh missing
    bin HOME ok COMMIT | bin HOME behind N COMMIT | bin HOME not-on-base COMMIT | bin HOME unknown COMMIT
    | bin HOME no-manifest | bin HOME missing
      the home's installed bin: the commit on the first line of bin\MANIFEST against
      refs/remotes/<Remote>/<Base> of the source clone, after one `git fetch --quiet <Remote> <Base>`.
      unknown is no git on PATH, a failed fetch, or a commit the clone does not have.
    task HOME ok NAME | task HOME disabled NAME | task HOME none | task HOME unknown
      one line per scheduled task whose first action runs bin\broker.ps1 of that home (letter case and
      slash direction ignored); unknown when Get-ScheduledTask is not available or throws. A review-poll
      task, or another home's broker, never matches.

  Exit code: 0 when every line is ok, 1 otherwise, 2 for the home refusal. An empty -WowHome, or one starting with ~
  (any platform), or on Windows with a slash (the MSYS form), is refused with one message and no other
  line: give the home as a full Windows path. The home is never converted. A -Remote or -Base that is
  not a plain ref name is refused the same way.

  Its only writes are those of the one `git fetch` in the source clone.

  Honest limit. Like install-host-tools.ps1 it runs git in the source clone, and if a container can write
  that clone it can plant git config or hooks that run here, so run it from a clone no container opens.
  The `--version` runs have no timeout, as in the launchers.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$WowHome = $(if ($env:WOW_HOME) { $env:WOW_HOME } else { Join-Path $HOME '.config/glunk-identity' }),
  [string]$SourceRepo,
  [string]$Remote = 'origin',
  [string]$Base = 'main'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Test-HomeRefused <home> [OnWindows]: true for a home this check will not read (empty, starting with ~, or on Windows
# starting with a slash, the MSYS form). It decides only; OnWindows is the seam ConvertFrom-MsysDrivePath uses.
function Test-HomeRefused([string]$Path, [bool]$OnWindows = $IsWindows) {
  if ([string]::IsNullOrEmpty($Path)) { return $true }
  if ($Path.StartsWith('~')) { return $true }
  if ($OnWindows -and $Path.StartsWith('/')) { return $true }
  $false
}

function Stop-Refused([string]$Message) {
  [Console]::Error.WriteLine("check-host: $Message")
  exit 2
}

if (Test-HomeRefused $WowHome) { Stop-Refused 'give -WowHome as a full Windows path (not empty, not starting with ~, not the /-leading MSYS form)' }

. (Join-Path $PSScriptRoot 'task-process.ps1')
. (Join-Path $PSScriptRoot 'wow-launch-common.ps1')

if (-not (Test-RefName $Remote) -or -not (Test-RefName $Base)) { Stop-Refused '-Remote and -Base must be plain ref names' }
if (-not $SourceRepo) { $SourceRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

$script:allOk = $true
# Out-Line <status> <text>: one output line (control characters become '?'); anything but status ok makes the exit 1.
function Out-Line([string]$Status, [string]$Text) {
  if ($Status -cne 'ok') { $script:allOk = $false }
  [Console]::Out.WriteLine([regex]::Replace($Text, '\p{Cc}', '?'))
}

# Find-App <name>: the application on PATH, or $null (an alias or function cannot shadow it).
function Find-App([string]$Name) {
  $f = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($f) { $f.Source }
}

# Get-VersionText <exe>: the --version output as text, or $null when it cannot run or exits non-zero.
function Get-VersionText([string]$Exe) {
  try {
    $r = Invoke-Tool $Exe @('--version')
    if ($r.Code -ne 0) { return $null }
    [Text.Encoding]::UTF8.GetString($r.Out)
  } catch { $null }
}

# --- pwsh, yq, gh ---------------------------------------------------------------------------------
$pwshExe = Find-App 'pwsh'
if (-not $pwshExe) { Out-Line 'missing' 'pwsh missing' }
else {
  $t = Get-VersionText $pwshExe
  $m = if ($null -ne $t) { [regex]::Match($t, 'PowerShell ([0-9]+\.[0-9]+\.[0-9]+)') } else { $null }
  if (-not $m -or -not $m.Success) { Out-Line 'unknown' 'pwsh unknown' }
  elseif ([version]$m.Groups[1].Value -ge [version]'7.2') { Out-Line 'ok' "pwsh ok $($m.Groups[1].Value)" }
  else { Out-Line 'old' "pwsh old $($m.Groups[1].Value) 7.2" }
}

$yqExe = Find-App 'yq'
if (-not $yqExe) { Out-Line 'missing' 'yq missing' }
else {
  $t = Get-VersionText $yqExe
  if ($null -eq $t) { Out-Line 'unknown' 'yq unknown' }
  else {
    $v = Test-YqVersion $t
    if ($v.Status -ceq 'ok') { Out-Line 'ok' "yq ok $($v.Found)" }
    elseif ($v.Status -ceq 'older') { Out-Line 'old' "yq old $($v.Found) $($v.Minimum)" }
    else { Out-Line 'unknown' 'yq unknown' }
  }
}

if (Find-App 'gh') { Out-Line 'ok' 'gh ok' } else { Out-Line 'missing' 'gh missing' }

# --- the home's installed bin ----------------------------------------------------------------------
$full = [IO.Path]::GetFullPath($WowHome)
$trim = $full.TrimEnd('\', '/')
if ($trim) { $full = $trim }
$bin = Join-Path $full 'bin'

# Get-BinLine: the status word and the rest of the line for the bin check.
function Get-BinLine {
  if (-not (Test-Path -LiteralPath $bin -PathType Container)) { return @('missing', "bin $WowHome missing") }
  $manifest = Join-Path $bin 'MANIFEST'
  $first = $null
  if (Test-Path -LiteralPath $manifest -PathType Leaf) {
    try { $first = [IO.File]::ReadLines($manifest) | Select-Object -First 1 } catch { $first = $null }
  }
  $mm = if ($null -ne $first) { [regex]::Match([string]$first, '\Acommit ([0-9a-f]{40})\z', 'None') } else { $null }
  if (-not $mm -or -not $mm.Success) { return @('no-manifest', "bin $WowHome no-manifest") }
  $commit = $mm.Groups[1].Value
  $unknown = @('unknown', "bin $WowHome unknown $commit")
  $git = Find-App 'git'
  if (-not $git) { return $unknown }
  $ref = "refs/remotes/$Remote/$Base"
  try {
    if ((Invoke-Tool $git @('-C', $SourceRepo, 'fetch', '--quiet', $Remote, $Base)).Code -ne 0) { return $unknown }
    $anc = Invoke-Tool $git @('-C', $SourceRepo, 'merge-base', '--is-ancestor', $commit, $ref)
    if ($anc.Code -eq 1) { return @('not-on-base', "bin $WowHome not-on-base $commit") }
    if ($anc.Code -ne 0) { return $unknown }
    $cnt = Invoke-Tool $git @('-C', $SourceRepo, 'rev-list', '--count', "$commit..$ref")
    if ($cnt.Code -ne 0) { return $unknown }
    $n = [Text.Encoding]::UTF8.GetString($cnt.Out).Trim()
    if ($n -cnotmatch '\A[0-9]+\z') { return $unknown }
    if ([int]$n -eq 0) { return @('ok', "bin $WowHome ok $commit") }
    return @('behind', "bin $WowHome behind $n $commit")
  } catch { return $unknown }
}
$b = Get-BinLine
Out-Line $b[0] $b[1]

# --- the home's broker task ------------------------------------------------------------------------
$want = Format-PathKey ($full + '\bin\broker.ps1')
$tasks = $null
$taskFail = $false
if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { $taskFail = $true }
else { try { $tasks = @(Get-ScheduledTask) } catch { $taskFail = $true } }
if ($taskFail) { Out-Line 'unknown' "task $WowHome unknown" }
else {
  $matched = 0
  foreach ($task in $tasks) {
    $actions = @(if ($task.PSObject.Properties['Actions']) { $task.Actions })
    if ($actions.Count -eq 0 -or -not $actions[0].PSObject.Properties['Arguments']) { continue }
    $span = Get-FileArgSpan ([string]$actions[0].Arguments)
    if (-not $span) { continue }
    $p = [regex]::Match($span, '"([^"]+)"').Groups[1].Value
    if ((Format-PathKey $p) -cne $want) { continue }
    $matched++
    $enabled = $task.PSObject.Properties['Settings'] -and $task.Settings -and $task.Settings.PSObject.Properties['Enabled'] -and $task.Settings.Enabled -eq $true
    if ($enabled) { Out-Line 'ok' "task $WowHome ok $($task.TaskName)" }
    else { Out-Line 'disabled' "task $WowHome disabled $($task.TaskName)" }
  }
  if ($matched -eq 0) { Out-Line 'none' "task $WowHome none" }
}

exit $(if ($script:allOk) { 0 } else { 1 })
