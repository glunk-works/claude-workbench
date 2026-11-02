#Requires -Version 7.2
<#
.SYNOPSIS
  Shared helpers for the host launchers wow-driver.ps1 and wow-lane.ps1 (WB-D24, WB-D33, issues
  #728 and #762). Dot-sourced, never run.

.DESCRIPTION
  Functions only, with no top-level statements: a launcher dot-sources this file only after its own
  inline MANIFEST check, and nothing here runs before that check. Like the launchers it runs only
  from the installed copy in $WOW_HOME/bin (install-host-tools.ps1), never from a checkout.

  What is here: the argument checks and the canonical-path resolution; tool resolution and the host yq
  version check; the two process runners (every external call goes through ProcessStartInfo.ArgumentList, one element per
  argument, never a joined string); the commit and model read from the Reference clone; the in-process
  git blob id; the Reference's origin repository (the one configured url, as lowercase owner/name,
  never echoed); the strict record read (four fields: id, commit, clone, origin; the old three-field shape reads with no origin) and the atomic
  record write; the two container listings; the relay probe. The launcher sets $script:LaunchProg and $script:LaunchUsage before calling any of it.

  Honest limit. Everything above is an accident guard. If a container can write the Reference clone
  it can plant git config or hooks that run when git runs there; the control is a Reference clone no
  container opens. wow-lane.ps1 dot-sources this file, relies on its id validation, and reads the
  driver record without ever writing it.
#>

# Stop-Launch <message> [code]: one line on stderr, then exit. Anything outside printable ASCII
# becomes '?', so a file name from the clone cannot send escape sequences to the terminal.
function Stop-Launch([string]$Message, [int]$Code = 1) {
  $safe = [regex]::Replace($Message, '[^\x20-\x7E]', '?')
  [Console]::Error.WriteLine("$($script:LaunchProg): $safe")
  if ($Code -eq 2) { [Console]::Error.WriteLine($script:LaunchUsage) }
  exit $Code
}

function Stop-BadArgument([string]$Message) { Stop-Launch $Message 2 }

function Write-LaunchLine([string]$Text) { [Console]::Out.WriteLine($Text) }

function Test-Hex([string]$Value, [int]$Length) {
  $null -ne $Value -and $Value -cmatch "\A[0-9a-f]{$Length}\z"
}

function Test-RefName([string]$Value) {
  $null -ne $Value -and $Value -cmatch '\A[A-Za-z0-9._/-]+\z' -and $Value -notmatch '\A[-/]' -and
    $Value -notmatch '/\z' -and $Value -notmatch '\.\.' -and $Value -notmatch '//'
}

# --- canonical paths ---------------------------------------------------------------------------

function Test-ReparsePoint([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $null -ne $item.LinkTarget
}

# Get-FinalPath <path>: the on-disk path, links in the parents followed, every component in its
# on-disk casing. Windows asks the file system (GetFinalPathNameByHandle); elsewhere each component is
# looked up in its parent's listing and a link is followed with ResolveLinkTarget.
function Get-FinalPath([string]$Path) {
  if ($IsWindows) {
    if (-not ('WowLaunch.Native' -as [type])) {
      Add-Type -Namespace WowLaunch -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern System.IntPtr CreateFileW(string name, uint access, uint share, System.IntPtr sec, uint disp, uint flags, System.IntPtr tmpl);
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern uint GetFinalPathNameByHandleW(System.IntPtr h, System.Text.StringBuilder buf, uint len, uint flags);
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern bool CloseHandle(System.IntPtr h);
'@
    }
    # FILE_FLAG_BACKUP_SEMANTICS opens a directory; access 0, share read/write/delete, OPEN_EXISTING.
    $h = [WowLaunch.Native]::CreateFileW($Path, 0, 7, [IntPtr]::Zero, 3, 0x02000000, [IntPtr]::Zero)
    if ($h -eq [IntPtr](-1)) { throw "cannot open $Path" }
    try {
      $sb = [Text.StringBuilder]::new(4096)
      $n = [WowLaunch.Native]::GetFinalPathNameByHandleW($h, $sb, 4096, 0)
      if ($n -eq 0 -or $n -ge 4096) { throw "cannot resolve $Path" }
    } finally { $null = [WowLaunch.Native]::CloseHandle($h) }
    $final = $sb.ToString()
    if ($final.StartsWith('\\?\UNC\')) { throw "$Path is on a network share" }
    if ($final.StartsWith('\\?\')) { $final = $final.Substring(4) }
    return $final.TrimEnd('\')
  }
  $full = [IO.Path]::GetFullPath($Path)
  $root = [IO.Path]::GetPathRoot($full)
  $cur = $root
  foreach ($c in $full.Substring($root.Length).Split([char[]]@('/', '\'), [StringSplitOptions]::RemoveEmptyEntries)) {
    $real = $null
    foreach ($e in [IO.Directory]::EnumerateFileSystemEntries($cur)) {
      $n = [IO.Path]::GetFileName($e)
      if ($n -ceq $c) { $real = $n; break }
      if ($null -eq $real -and $n -ieq $c) { $real = $n }
    }
    if ($null -eq $real) { throw "$Path does not exist" }
    $next = Join-Path $cur $real
    $item = Get-Item -LiteralPath $next -Force
    if ($null -ne $item.LinkTarget) {
      $t = $item.ResolveLinkTarget($true)
      if ($null -eq $t) { throw "$next is a broken link" }
      $next = Get-FinalPath $t.FullName
    }
    $cur = $next
  }
  $cur
}

# Format-PathKey <path>: the form two paths are compared in (case-insensitive, one separator, none trailing).
function Format-PathKey([string]$Path) { $Path.Replace('/', '\').TrimEnd('\').ToLowerInvariant() }

function Test-PathInside([string]$Outer, [string]$Inner) {
  $o = Format-PathKey $Outer; $i = Format-PathKey $Inner
  $i -eq $o -or $i.StartsWith($o + '\')
}

# ConvertFrom-MsysDrivePath <name> <path> [<is-windows>]: on Windows, the Git Bash tools may hold WOW_HOME in MSYS form
# (/c/x) and pwsh does not resolve that. Off Windows, or for a value not starting with /, the value comes back
# unchanged. A value starting with // (a forward-slash network path) exits 2: unsupported. Any other /-leading value is
# converted by `cygpath -w` run through the first sh on PATH (kept only when it is an existing file), as
# register-broker-task.ps1 finds and runs it, so the host's real mount prefix applies. A value holding & | ^ % " < > '
# exits 2 before sh runs (an sh.cmd would run through cmd.exe); a nonzero exit or empty output from sh exits 2 naming
# the fix. An sh that cannot be started at all throws and exits 1 through the launcher's outer catch. With no sh
# found, the fixed drive-prefix conversion applies (Git for Windows' default: /c, /c/, /c/x become C:/, C:/x; any other
# /-leading value exits 2); on a host with another prefix that converted path is a different directory, which the
# launcher's bin-under-WowHome check then refuses.
function ConvertFrom-MsysDrivePath([string]$Name, [string]$Path, [bool]$OnWindows = $IsWindows) {
  if (-not $OnWindows -or -not $Path.StartsWith('/')) { return $Path }
  if ($Path.StartsWith('//')) { Stop-BadArgument "$Name is a forward-slash network path, which is unsupported; give a local Windows path" }
  # -ErrorAction SilentlyContinue: the launchers run with $ErrorActionPreference = 'Stop', so a missing sh would throw.
  $found = Get-Command sh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  $sh = if ($found -and (Test-Path -LiteralPath $found.Source -PathType Leaf)) { $found.Source }
  if ($sh) {
    if ($Path -cmatch "[&|^%`"<>']") {
      Stop-BadArgument "$Name is in MSYS form and holds one of & | ^ % `" < > ', which cannot go through sh; give its Windows form (what cygpath -w prints)"
    }
    $r = Invoke-Tool $sh @('-c', 'cygpath -w "$1"', 'sh', $Path)
    $conv = [Text.Encoding]::UTF8.GetString($r.Out).TrimEnd("`r", "`n")
    if ($r.Code -ne 0) { Stop-BadArgument "$Name is in MSYS form and the cygpath -w conversion through sh failed (exit $($r.Code)); give its Windows form (what cygpath -w prints)" }
    if ($conv -eq '') { Stop-BadArgument "$Name is in MSYS form and the cygpath -w conversion through sh printed nothing; give its Windows form (what cygpath -w prints)" }
    return $conv
  }
  if ($Path -cmatch '\A/([A-Za-z])(?:/(.*))?\z') { return "$($Matches[1].ToUpperInvariant()):/$($Matches[2])" }
  Stop-BadArgument "$Name is in MSYS form and no sh was found on PATH to convert it; give its Windows form (what cygpath -w prints)"
}

# Resolve-LaunchDir <name> <path> [-Plain]: the argument checks shared by -Clone, -Reference and (with -Plain, which
# allows a link and skips the leaf and character rules) -WowHome; exit 2. Returns the final path.
function Resolve-LaunchDir([string]$Name, [string]$Path, [switch]$Plain) {
  if ([string]::IsNullOrEmpty($Path)) { Stop-BadArgument "$Name is required" }
  if (-not [IO.Path]::IsPathFullyQualified($Path)) { Stop-BadArgument "$Name must be an absolute path" }
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Stop-BadArgument "$Name is not an existing directory" }
  if (-not $Plain -and (Test-ReparsePoint $Path)) { Stop-BadArgument "$Name is a link or reparse point" }
  try { $final = Get-FinalPath $Path } catch { Stop-BadArgument "$Name cannot be resolved: $($_.Exception.Message)" }
  $given = $Path.TrimEnd('\', '/')
  if (-not $Plain) {
    # The leaf as given must be the leaf on disk, case included: the volume names derive from it.
    if ([IO.Path]::GetFileName($given) -cne [IO.Path]::GetFileName($final)) { Stop-BadArgument "$Name leaf differs from the on-disk name" }
    if ($final -cnotmatch '\A([A-Za-z]:)?[\\/A-Za-z0-9 ._-]+\z') {
      Stop-BadArgument "$Name path may hold only letters, digits, space, . _ - and separators (cmd.exe re-parses the rest)"
    }
    $leaf = [IO.Path]::GetFileName($final)
    if ($leaf -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9._-]*\z') { Stop-BadArgument "$Name leaf must match [A-Za-z0-9][A-Za-z0-9._-]*" }
  }
  $final
}

# --- tools and runners -------------------------------------------------------------------------

# Resolve-Tool <name>: one application on PATH (an alias or function of the same name cannot shadow it).
function Resolve-Tool([string]$Name) {
  $found = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $found) { Stop-Launch "$Name not found on PATH" }
  $found.Source
}

# Test-YqVersion <text>: the minimum host yq (a literal here, in no other launcher file) against the text
# `yq --version` printed. Status is ok (at or above the minimum, no maximum), older (Found holds the parsed
# version, for ok too) or unparseable; every outcome carries Minimum. Only mikefarah's one-line form parses.
# Why the minimum is 4.54.1: the expression Get-ReferenceLanesDir (wow-lane.ps1) passes to yq uses the
# if/then/else/end form, and a host yq v4.53.6 fails on it (#1256). v4.54.1 is the first release with yq's
# if/then/else/end operator (v4.54.1, mikefarah/yq#2871); no release exists between v4.53.6 and v4.54.1.
# The minimum moves down only after every yq expression the launchers pass has been run on the lower release
# and works; it moves up when a launcher starts depending on a newer yq feature. A change to $min updates
# this comment in the same change.
function Test-YqVersion([string]$Text) {
  $min = '4.54.1'
  $r = { param($s, $f) [pscustomobject]@{ Status = $s; Found = $f; Minimum = $min } }
  $line = if ($null -eq $Text) { '' } else { $Text.TrimEnd() }
  $m = [regex]::Match($line, '\Ayq \(https://github\.com/mikefarah/yq/\) version v([0-9]{1,9})\.([0-9]{1,9})\.([0-9]{1,9})\z', 'None')
  if (-not $m.Success) { return & $r 'unparseable' $null }
  $have = @(1, 2, 3 | ForEach-Object { [int]$m.Groups[$_].Value })
  $want = @($min.Split('.') | ForEach-Object { [int]$_ })
  $found = $have -join '.'
  foreach ($i in 0..2) {
    if ($have[$i] -gt $want[$i]) { return & $r 'ok' $found }
    if ($have[$i] -lt $want[$i]) { return & $r 'older' $found }
  }
  & $r 'ok' $found
}

# Assert-YqVersion <yq path>: refuses (exit 1) a host yq below the minimum or one whose version cannot be read,
# before any docker or git call. A failed `yq --version` reads as unparseable; its output is never echoed.
function Assert-YqVersion([string]$Yq) {
  $run = Invoke-Tool $Yq @('--version')
  $v = Test-YqVersion $(if ($run.Code -eq 0) { [Text.Encoding]::UTF8.GetString($run.Out) } else { '' })
  if ($v.Status -ceq 'older') { Stop-Launch "yq v$($v.Found) is older than the required v$($v.Minimum): upgrade the host's yq and rerun" }
  if ($v.Status -ceq 'unparseable') { Stop-Launch "no yq version could be read from yq --version; v$($v.Minimum) or newer is required" }
}

# Invoke-Tool: stdout as bytes, the exit code, and stderr text. Stderr goes to the console with
# -InheritStderr (progress for the human), else it is captured; both outputs are read as they arrive,
# so no pipe can fill and deadlock. Never refuses by itself: Get-ToolText does.
function Invoke-Tool([string]$Exe, [string[]]$Arguments, [byte[]]$Stdin, [switch]$InheritStderr) {
  $psi = [Diagnostics.ProcessStartInfo]::new($Exe)
  foreach ($x in $Arguments) { $psi.ArgumentList.Add($x) }
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = -not $InheritStderr
  $psi.RedirectStandardInput = $null -ne $Stdin
  $p = [Diagnostics.Process]::Start($psi)
  $outMs = [IO.MemoryStream]::new()
  $outTask = $p.StandardOutput.BaseStream.CopyToAsync($outMs)
  $errTask = if (-not $InheritStderr) { $p.StandardError.ReadToEndAsync() }
  if ($null -ne $Stdin) {
    try { $p.StandardInput.BaseStream.Write($Stdin, 0, $Stdin.Length) } catch [IO.IOException] { } finally { $p.StandardInput.Close() }
  }
  $p.WaitForExit()
  $outTask.Wait()
  [pscustomobject]@{ Code = $p.ExitCode; Out = $outMs.ToArray(); Err = $(if ($errTask) { $errTask.Result } else { '' }) }
}

# Get-ToolText: stdout as UTF-8 text, refusing on a nonzero exit (empty output from a failed call is never a result).
function Get-ToolText([string]$Exe, [string[]]$Arguments, [switch]$InheritStderr) {
  $r = Invoke-Tool $Exe $Arguments -InheritStderr:$InheritStderr
  if ($r.Code -ne 0) { $verb = @($Arguments | Where-Object { $_ -cmatch '\A[a-z][a-z-]*\z' })[0]
    Stop-Launch "$([IO.Path]::GetFileNameWithoutExtension($Exe)) $verb failed (exit $($r.Code))" }
  [Text.Encoding]::UTF8.GetString($r.Out)
}

# Invoke-Session: the interactive session. Inherits the console; its exit code is returned as is.
function Invoke-Session([string]$Exe, [string[]]$Arguments) {
  $psi = [Diagnostics.ProcessStartInfo]::new($Exe)
  foreach ($x in $Arguments) { $psi.ArgumentList.Add($x) }
  $psi.UseShellExecute = $false
  $p = [Diagnostics.Process]::Start($psi)
  $p.WaitForExit()
  $p.ExitCode
}

# --- the Reference clone: commit, model, .devcontainer tree --------------------------------------

# Get-ReferenceCommit: fetch <remote> <base> in the Reference, resolve refs/remotes/<remote>/<base> once.
function Get-ReferenceCommit([string]$Git, [string]$Reference, [string]$Remote, [string]$Base) {
  $null = Get-ToolText $Git @('-C', $Reference, 'fetch', '--quiet', $Remote, $Base)
  $c = (Get-ToolText $Git @('-C', $Reference, 'rev-parse', '--verify', "refs/remotes/$Remote/$Base^{commit}")).Trim()
  if (-not (Test-Hex $c 40)) { Stop-Launch "refs/remotes/$Remote/$Base did not resolve to a commit" }
  $c
}

# Get-RoleModel: models.<role> from .ai/project.yml at that commit, matched to the fixed set. The
# value returned is the script's own literal, never the text read.
function Get-RoleModel([string]$Git, [string]$Yq, [string]$Reference, [string]$Commit, [ValidateSet('architect', 'coder')][string]$Role) {
  $blob = Invoke-Tool $Git @('-C', $Reference, 'cat-file', 'blob', "$($Commit):.ai/project.yml")
  if ($blob.Code -ne 0) { Stop-Launch "cannot read .ai/project.yml at $Commit in the Reference clone" }
  $r = Invoke-Tool $Yq @('-r', ".models.$Role") -Stdin $blob.Out
  if ($r.Code -ne 0) { Stop-Launch "yq could not read models.$Role" }
  switch -CaseSensitive ([Text.Encoding]::UTF8.GetString($r.Out).Trim()) {
    'sonnet' { return 'sonnet' }
    'opus' { return 'opus' }
    'haiku' { return 'haiku' }
    'fable' { return 'fable' }
    default { Stop-Launch "models.$Role is not one of sonnet, opus, haiku, fable" }
  }
}

# Get-BlobId <file>: git's blob id, in-process: SHA-1 over "blob <len>", a NUL byte, then the bytes.
function Get-BlobId([string]$Path) {
  $len = ([IO.FileInfo]::new($Path)).Length
  $sha = [Security.Cryptography.SHA1]::Create()
  $fs = [IO.File]::OpenRead($Path)
  try {
    $head = [byte[]]([Text.Encoding]::ASCII.GetBytes("blob $len") + [byte]0)
    $null = $sha.TransformBlock($head, 0, $head.Length, $null, 0)
    $buf = [byte[]]::new(81920)
    while (($n = $fs.Read($buf, 0, $buf.Length)) -gt 0) { $null = $sha.TransformBlock($buf, 0, $n, $null, 0) }
    $null = $sha.TransformFinalBlock([byte[]]::new(0), 0, 0)
    ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLowerInvariant()
  } finally { $fs.Dispose(); $sha.Dispose() }
}

# Get-CommittedDevTree: relative path -> blob id of every file under .devcontainer/ at the commit.
function Get-CommittedDevTree([string]$Git, [string]$Reference, [string]$Commit) {
  $text = Get-ToolText $Git @('-C', $Reference, 'ls-tree', '-r', '-z', $Commit, '--', '.devcontainer')
  $tree = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal) # case-sensitive: Dockerfile and dockerfile stay two files
  foreach ($rec in $text.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
    if ($rec -cnotmatch '\A(\d{6}) (blob|commit|tree) ([0-9a-f]{40})\t(.+)\z') { Stop-Launch 'unreadable git ls-tree record' }
    if ($Matches[1] -cne '100644' -and $Matches[1] -cne '100755') { Stop-Launch "$($Matches[4]) is not a regular file at $Commit" }
    $tree[$Matches[4]] = $Matches[3]
  }
  if ($tree.Count -eq 0) { Stop-Launch ".devcontainer/ has no files at $Commit" }
  $tree
}

# Get-DiskDevFiles: relative path -> full path of every file under <Clone>/.devcontainer. A reparse
# point anywhere, the directory itself included, refuses.
function Get-DiskDevFiles([string]$Clone) {
  $root = Join-Path $Clone '.devcontainer'
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { Stop-Launch '.devcontainer/ is missing from the clone' }
  if (Test-ReparsePoint $root) { Stop-Launch '.devcontainer is a link or reparse point' }
  $files = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
  $stack = [Collections.Generic.Stack[string]]::new()
  $stack.Push($root)
  while ($stack.Count -gt 0) {
    $d = $stack.Pop()
    foreach ($e in [IO.Directory]::EnumerateFileSystemEntries($d)) {
      if ([IO.Path]::GetFileName($e) -cnotmatch '\A[A-Za-z0-9._-]+\z') { Stop-Launch "a file name under .devcontainer/ holds characters outside letters, digits, . _ -: $($e.Substring($Clone.Length))" }
      $rel = $e.Substring($Clone.Length).TrimStart('\', '/').Replace('\', '/')
      $attr = [IO.File]::GetAttributes($e)
      if ($attr -band [IO.FileAttributes]::ReparsePoint) { Stop-Launch "$rel is a link or reparse point" }
      if ($attr -band [IO.FileAttributes]::Directory) { $stack.Push($e) } else { $files[$rel] = $e }
    }
  }
  $files
}

# Test-DevTree: the clone's .devcontainer/ equals the commit's, file set and bytes. Refuses naming the first difference.
function Test-DevTree([string]$Git, [string]$Reference, [string]$Clone, [string]$Commit) {
  $want = Get-CommittedDevTree $Git $Reference $Commit
  $have = Get-DiskDevFiles $Clone
  foreach ($rel in ($want.Keys | Sort-Object -CaseSensitive)) {
    if (-not $have.ContainsKey($rel)) { Stop-Launch "$rel is missing from the clone but committed on the base" }
  }
  foreach ($rel in ($have.Keys | Sort-Object -CaseSensitive)) {
    if (-not $want.ContainsKey($rel)) { Stop-Launch "$rel is in the clone but not committed on the base" }
  }
  foreach ($rel in ($want.Keys | Sort-Object -CaseSensitive)) {
    if ((Get-BlobId $have[$rel]) -cne $want[$rel]) { Stop-Launch "$rel differs from the base" }
  }
}

# Get-DevTreeId: the id of the .devcontainer tree at a commit, or $null when git cannot read it.
function Get-DevTreeId([string]$Git, [string]$Reference, [string]$Commit) {
  $r = Invoke-Tool $Git @('-C', $Reference, 'rev-parse', '--verify', "$($Commit):.devcontainer")
  if ($r.Code -ne 0) { return $null }
  $id = [Text.Encoding]::UTF8.GetString($r.Out).Trim()
  if (Test-Hex $id 40) { $id } else { $null }
}

# --- the record --------------------------------------------------------------------------------

function Get-RecordPath([string]$WowHome, [string]$Leaf) { Join-Path (Join-Path $WowHome 'driver') "$Leaf.json" }

# Get-ReferenceOrigin: the Reference's <Remote> repository as lowercase owner/name, from the one configured
# url (git runs only in the Reference). Only the three github.com forms are accepted: https (a plain user
# name before the host is dropped, a password part refuses), git@github.com:owner/name and
# ssh://git@github.com/owner/name, each with an optional .git. It reads the configured url, not where an
# insteadOf rewrite sends the fetch. A refusal never prints the url.
function Get-ReferenceOrigin([string]$Git, [string]$Reference, [string]$Remote) {
  $r = Invoke-Tool $Git @('-C', $Reference, 'config', '--get-all', "remote.$Remote.url")
  if ($r.Code -ne 0) { Stop-Launch "the Reference clone has no $Remote url" }
  $vals = @([Text.Encoding]::UTF8.GetString($r.Out).Split("`n") | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ -ne '' })
  if ($vals.Count -ne 1) { Stop-Launch "the Reference clone's $Remote must have exactly one url" }
  $seg = '([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?'
  foreach ($form in @("https://(?:[A-Za-z0-9._-]+@)?github\.com/$seg", "git@github\.com:$seg", "ssh://git@github\.com/$seg")) {
    $m = [regex]::Match($vals[0], "\A$form\z")
    if ($m.Success) { return ("$($m.Groups[1].Value)/$($m.Groups[2].Value)").ToLowerInvariant() }
  }
  Stop-Launch "the Reference clone's $Remote url is not a github.com https or ssh url of the accepted forms"
}

function Test-OriginShape([string]$Value) { $Value -cmatch '\A[a-z0-9._-]+/[a-z0-9._-]+\z' }

# Get-RecordResult: { Record; Error }. Record is $null with Error $null when the file is absent. A record in the
# old three-field shape reads with origin $null; anything else outside the four fields in their shapes is an Error.
function Get-RecordResult([string]$Path) {
  $bad = { param($m) [pscustomobject]@{ Record = $null; Error = $m } }
  if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Record = $null; Error = $null } }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Test-ReparsePoint $Path)) { return & $bad 'the driver record is not a regular file' }
  if (([IO.FileInfo]::new($Path)).Length -gt 4096) { return & $bad 'the driver record is larger than 4 KiB' }
  try { $o = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop } catch { return & $bad 'the driver record is not valid JSON' }
  if ($o -isnot [pscustomobject]) { return & $bad 'the driver record is not a JSON object' }
  $names = @($o.PSObject.Properties.Name | Sort-Object -CaseSensitive)
  $want3 = $names.Count -eq 3 -and $names[0] -ceq 'clone' -and $names[1] -ceq 'commit' -and $names[2] -ceq 'id'
  $want4 = $names.Count -eq 4 -and $names[0] -ceq 'clone' -and $names[1] -ceq 'commit' -and $names[2] -ceq 'id' -and $names[3] -ceq 'origin'
  if (-not $want3 -and -not $want4) { return & $bad 'the driver record must hold exactly id, commit, clone and origin' }
  foreach ($n in $names) { if ($o.$n -isnot [string]) { return & $bad "the driver record's $n is not a string" } }
  if (-not (Test-Hex $o.id 64)) { return & $bad "the driver record's id is not 64 lowercase hex digits" }
  if (-not (Test-Hex $o.commit 40)) { return & $bad "the driver record's commit is not 40 lowercase hex digits" }
  $origin = $null
  if ($want4) {
    if (-not (Test-OriginShape $o.origin)) { return & $bad "the driver record's origin is not a lowercase owner/name" }
    $origin = $o.origin
  }
  [pscustomobject]@{ Record = [pscustomobject]@{ id = $o.id; commit = $o.commit; clone = $o.clone; origin = $origin }; Error = $null }
}

# Read-Record: $null when absent; refuses on anything but the four fields in their shapes. A record in the
# old three-field shape is returned with origin $null, for the caller to refuse or replace. With -NoRefuse
# anything the strict read would refuse returns $null instead (start of day only).
function Read-Record([string]$Path, [switch]$NoRefuse) {
  $r = Get-RecordResult $Path
  if ($null -ne $r.Error) { if ($NoRefuse) { return $null } else { Stop-Launch $r.Error } }
  $r.Record
}

# Write-Record: a temp file in the same directory, then a rename over the old record.
function Write-Record([string]$Path, [string]$Id, [string]$Commit, [string]$Clone, [string]$Origin) {
  if (-not (Test-Hex $Id 64) -or -not (Test-Hex $Commit 40)) { Stop-Launch 'refusing to record a malformed id or commit' }
  if (-not (Test-OriginShape $Origin)) { Stop-Launch 'refusing to record a malformed origin' }
  $dir = Split-Path -Parent $Path
  if (Test-Path -LiteralPath $dir) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container) -or (Test-ReparsePoint $dir)) { Stop-Launch 'driver/ under WowHome is not a plain directory' }
  } else { $null = New-Item -ItemType Directory -Path $dir }
  $tmp = Join-Path $dir ".$([IO.Path]::GetFileName($Path)).$([guid]::NewGuid().ToString('N')).tmp"
  try {
    $json = [ordered]@{ id = $Id; commit = $Commit; clone = $Clone; origin = $Origin } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText($tmp, $json + "`n")
    [IO.File]::Move($tmp, $Path, $true)
  } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}

# --- containers --------------------------------------------------------------------------------

function ConvertFrom-PsLines([string]$Text, [bool]$WithLabel) {
  $lines = $Text -split "`n"
  if ($lines.Count -gt 0 -and $lines[-1] -eq '') { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
  $rx = if ($WithLabel) { '\A([0-9a-f]{64}) ([a-z]+) (.*)\z' } else { '\A([0-9a-f]{64}) ([a-z]+)\z' }
  foreach ($l in $lines) {
    $l = $l.TrimEnd("`r")
    if ($l -cnotmatch $rx) { Stop-Launch 'unreadable docker ps line' }
    [pscustomobject]@{ Id = $Matches[1]; State = $Matches[2]; Label = $(if ($WithLabel) { $Matches[3] } else { $null }) }
  }
}

# Get-LaunchContainers: every container (any state) on <leaf>-tmp, plus those whose
# devcontainer.local_folder label names the path: the union of two listings, by id. Label values are
# data, compared and never put on a command line.
function Get-LaunchContainers([string]$Docker, [string]$Path, [string]$Leaf) {
  $bq = [string][char]96
  $byVolume = ConvertFrom-PsLines (Get-ToolText $Docker @('ps', '-a', '--no-trunc', '--filter', "volume=${Leaf}-tmp", '--format', '{{.ID}} {{.State}}')) $false
  $fmt = '{{.ID}} {{.State}} {{.Label ' + $bq + 'devcontainer.local_folder' + $bq + '}}'
  $byLabel = ConvertFrom-PsLines (Get-ToolText $Docker @('ps', '-a', '--no-trunc', '--filter', 'label=devcontainer.local_folder', '--format', $fmt)) $true
  $set = [ordered]@{}
  foreach ($c in @($byVolume)) { $set[$c.Id] = $c }
  $want = Format-PathKey $Path
  foreach ($c in @($byLabel)) { if ((Format-PathKey $c.Label) -eq $want -and -not $set.Contains($c.Id)) { $set[$c.Id] = $c } }
  @($set.Values)
}

# Assert-KnownStates: any state but running, exited or created refuses, wherever it appears.
function Assert-KnownStates($Containers) {
  foreach ($c in @($Containers)) {
    if ($c.State -cne 'running' -and $c.State -cne 'exited' -and $c.State -cne 'created') {
      Stop-Launch "container $($c.Id) is $($c.State): stop it (docker stop $($c.Id)), then rerun"
    }
  }
}

# --- the relay probe (attach, and every wow-lane.ps1 run) -------------------------------------------------------------

# An accident guard, not a boundary. ls and grep by absolute path: it runs as root, and ~/.local/bin on the writable home volume may lead PATH. No & | ^ % or " in the script: it may pass through cmd.exe on a stub.
function Get-RelayProbeScript {
  "/bin/ls -d /tmp/vscode-remote-containers-* 2>/dev/null; /bin/grep -l -a -s -e '[v]scode-remote-containers-server' -e '[v]scode-server' /proc/[0-9]*/cmdline 2>/dev/null; exit 0"
}

function Test-RelayProbe([string]$Docker, [string]$Id) {
  if (-not (Test-Hex $Id 64)) { Stop-Launch 'refusing to probe a malformed container id' }
  $r = Invoke-Tool $Docker @('exec', '-u', 'root', $Id, '/bin/sh', '-c', (Get-RelayProbeScript))
  if ($r.Code -ne 0 -or $r.Out.Length -ne 0) {
    Stop-Launch 'a VS Code attach may have reached this container: stop it (WB-D33), then rerun at start of day'
  }
}
