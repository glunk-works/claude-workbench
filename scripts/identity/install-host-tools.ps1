#Requires -Version 7.2
<#
.SYNOPSIS
  Install the host identity scripts into $WowHome\bin, and the review image's build context into
  $WowHome\bin\review, from committed code (WB-D24, issues #392, #634). The clean-tree check covers
  every source directory of both.

.DESCRIPTION
  The broker, mint.sh and the wow-* commands run on the host next to every App key. A dev
  container bind-mounts a checkout of this repo read-write, so code run by path from a checkout is
  code a container can edit. This copies the scripts out of git instead, into a directory no
  container mounts, and everything on the host runs from that copy. Re-running it is the upgrade.

  What it does, in order, stopping at the first failure:
    1. Finds the source checkout (-SourceRepo, default the one holding this script).
    2. Checks, changing nothing in $WowHome: no source directory in the table below
       (scripts/identity, scripts/loop, plugins/way-of-working/bin) has an
       uncommitted change, and HEAD is an ancestor of refs/remotes/<Remote>/<Base> after a fetch (which does update that
       remote-tracking ref): reviewed, merged code, not a worktree or an unpushed branch. HEAD is
       resolved once, and that commit is what is exported and recorded. Every table entry must
       exist at that commit.
    3. Only then (and only past -WhatIf / -Confirm) disables the scheduled task named by -StopTask,
       if it exists, stops it and ends the processes running its -File path (stopping the task ends
       conhost, not the pwsh it started), waiting for them (a broker action with no quoted -File path gets a warning and no process is ended), so a refusal above never leaves the broker
       down. The task is enabled again after the swap, on failure too, if it was enabled before; a run
       killed between the disable and that re-enable leaves it disabled until the register script runs.
    4. Exports the files from that commit (git cat-file blob: the stored bytes, so no working-tree
       edit and no CRLF conversion) into $WowHome\bin.new, writes MANIFEST there (the commit, the
       install time, each file's sha256 and destination path relative to bin, so the human can
       compare the commit with GitHub), and
       swaps it in for $WowHome\bin. Besides the host scripts that is bin\review, the review image's
       build context (#634): the Dockerfile plus exactly the files it copies, flat. The old bin is kept as bin.old until the swap succeeds and is
       put back if it fails; a leftover bin.old with no bin is restored on the next run.
    5. Creates <tokens root>\<owner>\<repo> (the tokens root is $WowHome\tokens, or the default home's tokens when $WowHome holds
       a tokens-root file holding exactly default-home, #1568; the default home and its tokens are made when absent) for each "owner/name" entry in broker.json (a
       container mount whose source is missing fails to start; the broker writes only that
       directory, #1340). An admin-token file already in such a directory (a leftover from before #1608, which wow-admin no longer writes there) gets one warning naming its path and `wow-admin <owner/name> --revoke`; it is never deleted. A bare-name entry creates nothing and gets one fixed warning line that names it
       and says the broker refuses it. An entry failing the broker's per-half name rule is skipped (the broker alone refuses a shared name half or an owner equal to another entry's name). A bad
       broker.json is a warning here, not a failed install. It then
       cross-checks, when broker.json names at least one valid repo, broker.json, review-poll.json and
       the tokens\ directories. The broker.json and review-poll.json comparison is by bare repo name
       (the name half of an owner/name entry; case-insensitive, owner ignored) and warns, one fixed
       line per mismatch (an absent review-poll.json is not compared; an unreadable one gets one fixed line), about a poll entry with
       no broker.json entry and a broker.json entry with no poll entry. When $WowHome holds a tokens-root file the loop over top-level tokens
       directories is skipped (the shared root holds the other home's owners). A tokens-root file in a refusal state (other content, empty, a symbolic link,
       a directory, an empty HOME, or in the default home itself, reached through a link or written in another letter case) gets one fixed warning line naming the file and no token directory is created; the rest of the step runs as usual. A top-level tokens\ directory that is not
       the owner half of any entry gets one fixed line too (a leftover bare directory, for example). In the default home the loop also accepts the owner halves named in the
       broker.json of each home beside it that holds a valid tokens-root file, so such a home's owner directory is not named, unless that owner equals, ignoring case,
       the name half of an entry in the default home's own broker.json (#1599). It also warns once, with a count and no entry text, when review-poll.json
       has string entries it cannot read as owner/name. It only warns: the install's result never changes and no list is edited.
    6. Writes the wowd, wowl and wowend launcher shortcuts into the PowerShell profile (-ProfilePath, default
       $PROFILE.CurrentUserAllHosts), as one block between the lines "# >>> way-of-working launchers >>>" and
       "# <<< way-of-working launchers <<<", touching only the text between them: a profile with no marker line gets the block
       appended, one start and one later end marker line get their lines replaced, any other count or order is reported and
       left alone. The block holds $WowHomes, owner to identity home, read from the broker.json of the default home and of
       every home beside it that holds a valid tokens-root file (nothing is created); an owner two homes name is left out,
       and a home whose broker.json cannot be read is skipped. The block carries nothing that changes between runs, so a second
       run leaves the profile byte-identical. One output line says what happened (profile block added|updated|unchanged in
       <path>); every other line it prints starts "profile:" and is plain output, not a warning. A failure here is one "profile: not
       written" line and never changes the install's result: bin is already swapped. A new shell picks the block up.

  Honest limit. The checks in step 2 catch accidents (an unreviewed worktree, a checkout about to
  be deleted). They do not narrow the hostile case. If a container can write the source clone, it
  can plant .git config or hooks that run on the host when this script runs git (core.fsmonitor on
  `status`, core.sshCommand on `fetch`), and it can edit this very script, which runs from that
  clone's working tree. That is host code execution beside the App keys, before any check. The
  control is to run this from a clone no container opens; #393's container must open a different
  clone or a volume. "Ancestor of main" also accepts an older merged commit (a downgrade).

  Put $WowHome/bin on Git Bash's PATH to run wow-admin, wow-preflight, wow-readback, wow-review and wow-review-mint from the
  installed copy (wow-review finds wow-review-mint beside itself). Run on its own it does not stop a running
  broker unless -StopTask is given; a held file then fails the swap cleanly.

  The driver launcher is not a Git Bash command. Run
  it from pwsh 7.2+ on the host, as the installed copy under $env:WOW_HOME\bin, or under the default
  $HOME\.config\glunk-identity\bin when WOW_HOME is unset (docs/identity/DEV-CONTAINER.md, Opening it):
    pwsh -File $env:WOW_HOME\bin\wow-driver.ps1 -Clone <clone> -Reference <other clone>
  The lane and spec launcher, wow-lane.ps1, runs the same way, beside the driver's container (#762):
    pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Clone <clone> -Reference <other clone> -Issue N -Hash HASH
    pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Clone <clone> -Reference <other clone> -Spec N[,N...]
  The first start of day for a repository takes the two paths; it records them in the driver record, and the
  installed launchers' own -Repo owner/name form then reads them, so a day's commands carry no paths:
    pwsh -File $env:WOW_HOME\bin\wow-driver.ps1 -Repo <owner/name>
    pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Repo <owner/name> -Spec N[,N...]
    pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Repo <owner/name> -Issue N -Hash HASH
    pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Repo <owner/name> -EndDay
  With an MSYS-form WOW_HOME (/c/...) the $env:WOW_HOME script path in those commands does not resolve in
  pwsh, so give the installed copy's path in Windows form.
  yq (mikefarah v4, v4.54.1 or newer; the launchers refuse an older or unidentifiable yq) must be on PowerShell's PATH too. It runs only from there: it checks the MANIFEST.
  The wowd, wowl and wowend shortcuts step 6 writes are the short form of the -Repo commands above: wowd <owner/name> runs the
  wow-driver.ps1 one, wowl <owner/name> [switches] the wow-lane.ps1 ones, wowend <owner/name> is wowl <owner/name> -EndDay. The first
  start of day for a repository still runs wow-driver.ps1 directly with -Clone and -Reference.
  The driver launcher also needs gh on PowerShell's PATH, on both paths (attach too), and for a start of day a gh login that can read the origin repository.

.PARAMETER SourceRepo
  The git checkout to install from. Default: the repository containing this script.

.PARAMETER StopTask
  A scheduled task to disable and stop just before the swap, with the processes running its -File path
  ended and waited for, then enabled again after it (register-broker-task.ps1 passes its own). A broker action with no
  quoted -File path gets a warning and no process is ended.

.PARAMETER ProfilePath
  The PowerShell profile file step 6 writes the launcher shortcuts into. Default: $PROFILE.CurrentUserAllHosts.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$WowHome = $(if ($env:WOW_HOME) { $env:WOW_HOME } else { Join-Path $HOME '.config/glunk-identity' }),
  [string]$SourceRepo,
  [string]$Remote = 'origin',
  [string]$Base = 'main',
  [string]$StopTask,
  [string]$ProfilePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Committed source path -> destination path under bin/, one pair per line. The leading comma is
# required: without it PowerShell flattens the lines inside @( ... ) into one list of bare strings
# instead of pairs. bin/review/ is the review image's build context: the Dockerfile plus exactly the
# files it copies (tests/review-image.test.sh holds the two lists equal).
$table = @(
  ,@('scripts/identity/broker.ps1', 'broker.ps1')
  ,@('scripts/identity/mint.sh', 'mint.sh')
  ,@('scripts/identity/wow-common.sh', 'wow-common.sh')
  ,@('scripts/identity/wow-review-mint', 'wow-review-mint')
  ,@('scripts/identity/wow-admin', 'wow-admin')
  ,@('scripts/identity/wow-preflight', 'wow-preflight')
  ,@('scripts/identity/wow-readback', 'wow-readback')
  ,@('scripts/identity/wow-review', 'wow-review')
  ,@('scripts/identity/wow-review-poll', 'wow-review-poll')
  ,@('scripts/identity/wow-driver.ps1', 'wow-driver.ps1')
  ,@('scripts/identity/wow-launch-common.ps1', 'wow-launch-common.ps1')
  ,@('scripts/identity/wow-lane.ps1', 'wow-lane.ps1')
  ,@('plugins/way-of-working/bin/review-gate-state.sh', 'review-gate-state.sh')
  ,@('plugins/way-of-working/bin/token-check.sh', 'token-check.sh')
  ,@('plugins/way-of-working/bin/gh-identity.sh', 'gh-identity.sh')
  ,@('plugins/way-of-working/bin/ruleset-drift.sh', 'ruleset-drift.sh')
  ,@('scripts/identity/review/Dockerfile', 'review/Dockerfile')
  ,@('scripts/identity/review/entrypoint.sh', 'review/entrypoint.sh')
  ,@('scripts/identity/review/outbox-read', 'review/outbox-read')
  ,@('scripts/identity/review/managed-settings.json', 'review/managed-settings.json')
  ,@('scripts/identity/review/dev-token', 'review/dev-token')
  ,@('scripts/identity/review/gh', 'review/gh')
  ,@('plugins/way-of-working/bin/token-check.sh', 'review/token-check.sh')
  ,@('plugins/way-of-working/bin/gh-identity.sh', 'review/gh-identity.sh')
  ,@('scripts/loop/inject.py', 'review/inject.py')
  ,@('scripts/loop/proxy.py', 'review/proxy.py')
)
$srcDirs = @($table | ForEach-Object { $_[0].Substring(0, $_[0].LastIndexOf('/')) } | Select-Object -Unique)

# One git, resolved once, as an application: an alias or function named git in a profile cannot shadow it.
$found = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$gitExe = if ($found) { $found.Source }
if (-not $gitExe) { throw 'git not found on PATH' }

# The default-home rule, as broker.ps1 writes it (#1571).
function Resolve-RealPath([string]$p) {
  # every symbolic link or junction on the path is followed one hop at a time, as cd -P does: the components of a link's target are
  # walked too, and a .. goes to the physical parent of the directory reached so far (#1571)
  if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path (Get-Location).ProviderPath $p }
  $cur = [IO.Path]::GetPathRoot($p)
  $rest = @($p.Substring($cur.Length) -split '[\\/]' | Where-Object { $_ })
  $hops = 0
  while ($rest.Count -gt 0) {
    $seg = $rest[0]
    $rest = @($rest | Select-Object -Skip 1)
    if ($seg -eq '.') { continue }
    if ($seg -eq '..') { $par = [IO.Path]::GetDirectoryName($cur); if ($par) { $cur = $par }; continue }
    $cur = Join-Path $cur $seg
    $it = Get-Item -LiteralPath $cur -Force -ErrorAction SilentlyContinue
    if ($it -and $it.LinkType -and $it.LinkType -ne 'HardLink') {
      if (++$hops -gt 40) { throw "too many links resolving $p" }
      if ($it.LinkType -eq 'Junction') { $lt = $it.ResolveLinkTarget($false).FullName } else { $lt = [string]$it.LinkTarget }
      if (-not $lt) { throw "cannot resolve $cur" }
      if ([IO.Path]::IsPathRooted($lt)) { $cur = [IO.Path]::GetPathRoot($lt); $lt = $lt.Substring($cur.Length) }
      else { $cur = [IO.Path]::GetDirectoryName($cur) }
      $rest = @($lt -split '[\\/]' | Where-Object { $_ }) + $rest
    }
  }
  $cur
}
# Test-IsDefaultHome <home> <default home>: equal paths, or equal after links are followed, ignoring letter case (#1571).
function Test-IsDefaultHome([string]$h, [string]$d) {
  if ([IO.Path]::GetFullPath($h).TrimEnd('\', '/') -ieq [IO.Path]::GetFullPath($d).TrimEnd('\', '/')) { return $true }
  if (-not (Test-Path -LiteralPath $d)) { return $false }
  (Resolve-RealPath $h) -ieq (Resolve-RealPath $d)
}

# --- the profile block: the wowd, wowl and wowend shortcuts (#1595) ----------------------------
$script:ProfileStart = '# >>> way-of-working launchers >>>'
$script:ProfileEnd = '# <<< way-of-working launchers <<<'
# One launcher shortcut as it is written into the profile. @@NAME@@ and @@SCRIPT@@ are the only holes. An array argument (-Spec 7,8) is
# one argument, joined with commas; WOW_PROFILE_ECHO=1 prints the command instead of running it.
$script:LauncherTemplate = @'
function @@NAME@@ {
  $r = if ($args.Count -ge 1) { $args[0] }
  if ($r -isnot [string] -or $r -cnotmatch '\A[^/\s]+/[^/\s]+\z') { throw 'usage: @@NAME@@ <owner/name> [arguments]' }
  $o = $r.Split('/')[0]
  if (-not $WowHomes.ContainsKey($o)) { throw "@@NAME@@: no identity home for owner $o in `$WowHomes" }
  $rest = @($args | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [array]) { $_ -join ',' } else { $_ } })
  $cmd = @('-NoProfile', '-File', (Join-Path (Join-Path $WowHomes[$o] 'bin') '@@SCRIPT@@'), '-Repo', $r) + $rest
  if ($env:WOW_PROFILE_ECHO -eq '1') { 'pwsh ' + ($cmd -join ' ') } else { & pwsh @cmd }
}
'@
$script:EndDayFunction = @'
function wowend {
  $first = @($args | Select-Object -First 1)
  $rest = @($args | Select-Object -Skip 1)
  wowl @first -EndDay @rest
}
'@

# Get-SiblingHomes <default home>: the homes beside the default home that deliver into it, in the order the profile map reads them: each
# directory in its parent folder, not a link, not the default home, holding a tokens-root file that is a regular file or hard link whose
# bytes are exactly default-home (optionally followed by one LF or one CRLF). Reads only. Shared by the profile map and the step-5 check.
function Get-SiblingHomes([string]$dh) {
  $out = [Collections.Generic.List[string]]::new()
  $parent = [IO.Path]::GetDirectoryName($dh)
  if ($parent -and (Test-Path -LiteralPath $parent -PathType Container)) {
    $sibs = @(Get-ChildItem -LiteralPath $parent -Directory -Force | Where-Object { -not $_.LinkType } | Sort-Object { $_.Name.ToLowerInvariant() }, Name)
    foreach ($d in $sibs) {
      if ($d.FullName -ieq $dh) { continue }
      $tr = Get-Item -LiteralPath (Join-Path $d.FullName 'tokens-root') -Force -ErrorAction SilentlyContinue
      if (-not $tr -or $tr.PSIsContainer -or ($tr.LinkType -and $tr.LinkType -ne 'HardLink')) { continue }
      try { $tt = [Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($tr.FullName)) } catch { continue }
      $okForm = $false
      foreach ($w in @('default-home', "default-home`n", "default-home`r`n")) { if ([string]::Equals($tt, $w, [StringComparison]::Ordinal)) { $okForm = $true } }
      if (-not $okForm) { continue }
      if (Test-IsDefaultHome $d.FullName $dh) { continue }
      $out.Add($d.FullName)
    }
  }
  , @($out)
}
# Read-HomeOwners <broker.json path>: lower-case owner -> first spelling, for each entry of exactly two halves that pass the name rule.
# Throws when the file is not JSON or has no single case-sensitive repos list. Shared by the profile map and the step-5 check.
function Read-HomeOwners([string]$cfg) {
  $mine = [ordered]@{}
  $j = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json -ErrorAction Stop
  $prop = @(if ($j -is [pscustomobject]) { $j.PSObject.Properties | Where-Object { $_.Name -ceq 'repos' } })
  if ($prop.Count -ne 1 -or $prop[0].Value -isnot [object[]]) { throw 'no repos list' }
  foreach ($r in $prop[0].Value) {
    if ($r -isnot [string]) { continue }
    $parts = $r.Split('/')
    if ($parts.Count -ne 2) { continue }
    $okParts = @($parts | Where-Object { $_ -cmatch '\A[A-Za-z0-9._-]+\z' -and $_ -cnotmatch '\A[-.]' -and $_ -cnotmatch '\.\z' })
    if ($okParts.Count -ne 2) { continue }
    $k = $parts[0].ToLowerInvariant()
    if (-not $mine.Contains($k)) { $mine[$k] = $parts[0] }
  }
  $mine
}

# Get-ProfileOwnerMap <default home>: the owner-to-home map the block holds. Reads only, creates nothing. Returns the ordered
# entries (Owner, Home) and the profile: lines to print.
function Get-ProfileOwnerMap([string]$dh) {
  $notes = [Collections.Generic.List[string]]::new()
  $homes = [Collections.Generic.List[string]]::new()
  $homes.Add($dh)
  foreach ($sh in (Get-SiblingHomes $dh)) { $homes.Add($sh) }
  $named = [ordered]@{} # lower-case owner -> @{ Owner = first spelling; Homes = @(...) }
  foreach ($h in $homes) {
    $cfg = Join-Path $h 'broker.json'
    if (-not (Test-Path -LiteralPath $cfg -PathType Leaf)) { continue }
    try {
      $mine = Read-HomeOwners $cfg
    } catch {
      $notes.Add("profile: $cfg unreadable, its owners are not mapped")
      continue
    }
    foreach ($k in $mine.Keys) {
      if (-not $named.Contains($k)) { $named[$k] = @{ Owner = $mine[$k]; Homes = [Collections.Generic.List[string]]::new() } }
      $named[$k].Homes.Add($h)
    }
  }
  $keys = [string[]]@($named.Keys)
  [Array]::Sort($keys, [StringComparer]::Ordinal)
  $entries = @()
  foreach ($k in $keys) {
    $e = $named[$k]
    if ($e.Homes.Count -gt 1) { $notes.Add("profile: owner $($e.Owner) is named by $($e.Homes -join ' and '), so it is not mapped"); continue }
    $entries += , @($e.Owner, $e.Homes[0])
  }
  [pscustomobject]@{ Entries = $entries; Notes = @($notes) }
}

# New-ProfileBlock <entries> <eol>: the block's text, no trailing line break. Nothing in it changes between runs.
function New-ProfileBlock($entries, [string]$eol) {
  $q = { param($v) "'" + [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($v) + "'" }
  $l = [Collections.Generic.List[string]]::new()
  $l.Add($script:ProfileStart)
  $l.Add('# Written by scripts/identity/install-host-tools.ps1, which replaces any edit between these two marker lines.')
  $l.Add('$WowHomes = @{')
  foreach ($e in $entries) { $l.Add('  ' + (& $q $e[0]) + ' = ' + (& $q $e[1])) }
  $l.Add('}')
  foreach ($f in @(@('wowd', 'wow-driver.ps1'), @('wowl', 'wow-lane.ps1'))) {
    foreach ($t in $script:LauncherTemplate.Replace('@@NAME@@', $f[0]).Replace('@@SCRIPT@@', $f[1]).Split("`n")) { $l.Add($t.TrimEnd("`r")) }
  }
  foreach ($t in $script:EndDayFunction.Split("`n")) { $l.Add($t.TrimEnd("`r")) }
  $l.Add($script:ProfileEnd)
  $l -join $eol
}

# Write-ProfileBlock <profile path> : prints the step's lines; any failure is one "profile: not written" line.
function Write-ProfileBlock([string]$path) {
  try {
    if (-not $HOME) { throw 'HOME is empty, so there is no default home to read' }
    if (-not $path) { $path = $PROFILE.CurrentUserAllHosts }
    if (-not $path) { throw 'no profile path' }
    $path = [IO.Path]::GetFullPath($path)
    $dh = [IO.Path]::GetFullPath((Join-Path $HOME '.config/glunk-identity'))
    $map = Get-ProfileOwnerMap $dh
    $map.Notes
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -and $item.LinkType -ne 'HardLink') { "profile: $path is a link; left alone"; return }
    if ($item -and $item.PSIsContainer) { "profile: $path is a directory; left alone"; return }
    if ($item -and $item -isnot [IO.FileInfo]) { "profile: $path is not a regular file; left alone"; return }
    $utf8 = [Text.UTF8Encoding]::new($false)
    $nl = [Environment]::NewLine
    $existing = $null
    if ($item) { $existing = [IO.File]::ReadAllBytes($path) }
    if ($null -eq $existing) {
      $dir = [IO.Path]::GetDirectoryName($path)
      if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir }
      $out = $utf8.GetBytes((New-ProfileBlock $map.Entries $nl) + $nl)
      $verb = 'added'
    } else {
      if ($existing.Length -ge 2 -and (($existing[0] -eq 0xFF -and $existing[1] -eq 0xFE) -or ($existing[0] -eq 0xFE -and $existing[1] -eq 0xFF))) {
        "profile: $path starts with a UTF-16 byte order mark; the install cannot update it and left it alone"; return
      }
      # Bytes map one to one onto Latin-1 characters, so the file is searched as text and spliced as bytes, never decoded.
      $text = [Text.Encoding]::Latin1.GetString($existing)
      $bom = if ($existing.Length -ge 3 -and $existing[0] -eq 0xEF -and $existing[1] -eq 0xBB -and $existing[2] -eq 0xBF) { 3 } else { 0 }
      $firstLf = $text.IndexOf([char]10) # char overloads and ordinal compares: string IndexOf and -ceq are culture-aware, and under ICU "`r`n" is one unit
      $eol = if ($firstLf -gt 0 -and $text[$firstLf - 1] -eq [char]13) { "`r`n" } else { "`n" }
      $starts = @(); $ends = @(); $pos = 0
      while ($pos -le $text.Length) {
        $lf = $text.IndexOf([char]10, $pos)
        $lineEnd = if ($lf -lt 0) { $text.Length } else { $lf }
        $from = if ($pos -eq 0) { $bom } else { $pos }
        $content = $text.Substring($from, [Math]::Max(0, $lineEnd - $from))
        if ($content.Length -gt 0 -and $content[$content.Length - 1] -eq [char]13) { $content = $content.Substring(0, $content.Length - 1) }
        $contentEnd = $from + $content.Length
        if ([string]::Equals($content, $script:ProfileStart, [StringComparison]::Ordinal)) { $starts += , @($from, $contentEnd) }
        elseif ([string]::Equals($content, $script:ProfileEnd, [StringComparison]::Ordinal)) { $ends += , @($from, $contentEnd) }
        if ($lf -lt 0) { break }
        $pos = $lf + 1
      }
      $block = $utf8.GetBytes((New-ProfileBlock $map.Entries $eol))
      if ($starts.Count -eq 0 -and $ends.Count -eq 0) {
        $ms = [IO.MemoryStream]::new()
        $ms.Write($existing, 0, $existing.Length)
        if ($existing.Length -gt 0 -and $existing[$existing.Length - 1] -ne 10) { $b = $utf8.GetBytes($eol); $ms.Write($b, 0, $b.Length) }
        $ms.Write($block, 0, $block.Length)
        $b = $utf8.GetBytes($eol); $ms.Write($b, 0, $b.Length)
        $out = $ms.ToArray()
        $verb = 'added'
      } elseif ($starts.Count -eq 1 -and $ends.Count -eq 1 -and $starts[0][0] -lt $ends[0][0]) {
        $ms = [IO.MemoryStream]::new()
        $ms.Write($existing, 0, $starts[0][0])
        $ms.Write($block, 0, $block.Length)
        $ms.Write($existing, $ends[0][1], $existing.Length - $ends[0][1])
        $out = $ms.ToArray()
        $verb = 'updated'
      } else {
        "profile: $path has $($starts.Count) start and $($ends.Count) end marker lines in a form the install cannot update; fix the block by hand"; return
      }
      if ([Linq.Enumerable]::SequenceEqual([byte[]]$existing, [byte[]]$out)) { "profile block unchanged in $path"; return }
    }
    $tmpFile = Join-Path ([IO.Path]::GetDirectoryName($path)) (".wow-profile-$([Guid]::NewGuid().ToString('N')).tmp")
    try {
      [IO.File]::WriteAllBytes($tmpFile, $out)
      [IO.File]::Move($tmpFile, $path, $true)
    } catch {
      Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
      throw
    }
    "profile block $verb in $path"
  } catch {
    "profile: not written ($($_.Exception.Message))"
  }
}

# Invoke-Git <args...>: stdout as text (trailing newline trimmed); stderr is kept apart, used only in the error.
function Invoke-Git([string[]]$a) {
  $psi = [Diagnostics.ProcessStartInfo]::new($gitExe)
  foreach ($x in @('-C', $script:repo) + $a) { $psi.ArgumentList.Add($x) }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $p = [Diagnostics.Process]::Start($psi)
  $errTask = $p.StandardError.ReadToEndAsync()
  $out = $p.StandardOutput.ReadToEnd()
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "git $($a -join ' ') failed: $($errTask.Result.Trim())" }
  $out.TrimEnd("`r", "`n")
}

# Export-Blob <rev:path> <dest>: the committed bytes, exactly as stored (no filters, no text conversion).
function Export-Blob([string]$spec, [string]$dest) {
  $psi = [Diagnostics.ProcessStartInfo]::new($gitExe)
  foreach ($x in '-C', $script:repo, 'cat-file', 'blob', $spec) { $psi.ArgumentList.Add($x) }
  $psi.RedirectStandardOutput = $true
  $psi.UseShellExecute = $false
  $p = [Diagnostics.Process]::Start($psi)
  $fs = [IO.File]::Create($dest)
  try { $p.StandardOutput.BaseStream.CopyTo($fs) } finally { $fs.Dispose() }
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "git cat-file blob $spec failed" }
}

if ($IsWindows -and $WowHome.StartsWith('/')) { throw "WowHome $WowHome is in MSYS form; pass -WowHome in Windows form, or run register-broker-task.ps1, which converts it" }
if (-not (Test-Path -LiteralPath $WowHome -PathType Container)) { throw "WowHome $WowHome does not exist" }
$WowHome = (Resolve-Path -LiteralPath $WowHome).ProviderPath.TrimEnd('\')
if (-not $SourceRepo) { $SourceRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$script:repo = $SourceRepo
$null = Invoke-Git @('rev-parse', '--git-dir')

# --- checks: nothing under $WowHome changes until they all pass -----------------------------
foreach ($d in $srcDirs) {
  if (Invoke-Git @('status', '--porcelain', '--', $d)) { throw "$d has uncommitted changes; commit and merge them first" }
}
$null = Invoke-Git @('fetch', '--quiet', $Remote, $Base)
$head = Invoke-Git @('rev-parse', '--verify', 'HEAD^{commit}')
$remoteRef = "refs/remotes/$Remote/$Base" # full name: a local branch or tag called origin/main must not win
try { $null = Invoke-Git @('merge-base', '--is-ancestor', $head, $remoteRef) }
catch { throw "HEAD ($($head.Substring(0, 12))) is not on $Remote/$Base; install from merged code" }
foreach ($e in $table) { $null = Invoke-Git @('cat-file', '-e', "$($head):$($e[0])") }

# --- install ----------------------------------------------------------------------------------
$bin = Join-Path $WowHome 'bin'
$new = Join-Path $WowHome 'bin.new'
$old = Join-Path $WowHome 'bin.old'
if ($PSCmdlet.ShouldProcess($bin, "Install $($table.Count) host files from commit $($head.Substring(0, 12))")) {
  # Disabled across the swap so the broker task's one-minute trigger cannot start the old broker between the stop and the swap.
  $taskWasEnabled = $false
  $stopSpan = $null
  $stopArgs = $null
  $stopTaskFound = $false
  if ($StopTask) {
    $stopFound = @(Get-ScheduledTask -TaskName $StopTask -ErrorAction SilentlyContinue)
    if ($stopFound.Count -gt 1) { throw "expected one task named $StopTask, found $($stopFound.Count)" }
    if ($stopFound.Count -eq 1) {
      $taskWasEnabled = [bool]$stopFound[0].Settings.Enabled
      . (Join-Path $PSScriptRoot 'task-process.ps1')
      $stopTaskFound = $true
      $stopArgs = (@($stopFound[0].Actions)[0].Arguments)
      $stopSpan = Get-FileArgSpan $stopArgs
      $null = Disable-ScheduledTask -TaskName $StopTask
    }
  }
  try {
    if ($StopTask) {
      Stop-ScheduledTask -TaskName $StopTask -ErrorAction SilentlyContinue
      if ($stopSpan) { Stop-FileArgProcess $stopSpan }
      elseif ($stopTaskFound) { Write-NoSpanWarning $StopTask $stopArgs }
    }

    # A crash mid-swap leaves bin.old and no bin: that is the last good copy, so put it back first.
    if (-not (Test-Path -LiteralPath $bin) -and (Test-Path -LiteralPath $old)) { Move-Item -LiteralPath $old -Destination $bin }
    if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $new -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $new
    foreach ($e in $table) {
      $dst = Join-Path $new $e[1]
      $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)
      Export-Blob "$($head):$($e[0])" $dst
    }

    $lines = @("commit $head", "installed $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))")
    foreach ($e in $table) {
      $p = Join-Path $new $e[1]
      if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "$($e[1]) missing after export" }
      $lines += '{0}  {1}' -f (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant(), $e[1]
    }
    [IO.File]::WriteAllText((Join-Path $new 'MANIFEST'), (($lines -join "`n") + "`n"))

    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force } # a stale backup, bin is intact
    $hadBin = Test-Path -LiteralPath $bin
    try {
      if ($hadBin) { Move-Item -LiteralPath $bin -Destination $old }
      Move-Item -LiteralPath $new -Destination $bin
    } catch {
      if ($hadBin -and -not (Test-Path -LiteralPath $bin) -and (Test-Path -LiteralPath $old)) { Move-Item -LiteralPath $old -Destination $bin }
      throw
    }
    if (Test-Path -LiteralPath $old) {
      try { Remove-Item -LiteralPath $old -Recurse -Force } catch { Write-Warning "could not remove $old ($($_.Exception.Message)); the next run will" }
    }

    $cfg = Join-Path $WowHome 'broker.json'
    $brokerNames = @()
    $ownerDirs = @{}
    # The tokens root, read as broker.ps1 reads it: $WowHome\tokens, or the default home's tokens for a tokens-root file holding default-home.
    $trFile = Join-Path $WowHome 'tokens-root'
    $trItem = Get-Item -LiteralPath $trFile -Force -ErrorAction SilentlyContinue
    $tokensRoot = Join-Path $WowHome 'tokens'
    $trBad = $false
    if ($trItem) {
      $trBad = $true
      try {
        if ((-not $trItem.LinkType -or $trItem.LinkType -eq 'HardLink') -and -not $trItem.PSIsContainer -and $HOME) {
          $dh = Join-Path $HOME '.config/glunk-identity'
          $isDh = Test-IsDefaultHome $WowHome $dh
          $tt = [Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($trFile))
          $okForm = $false # ordinal: -ceq is culture-aware, and under ICU a NUL byte compares as ignorable
          foreach ($w in @('default-home', "default-home`n", "default-home`r`n")) { if ([string]::Equals($tt, $w, [StringComparison]::Ordinal)) { $okForm = $true } }
          if (-not $isDh -and $okForm) {
            $trBad = $false
            $tokensRoot = Join-Path $dh 'tokens'
          }
        }
      } catch { $trBad = $true }
      if ($trBad) { Write-Warning "$trFile must be a regular file holding exactly default-home: no token directory created" }
    }
    if (Test-Path -LiteralPath $cfg -PathType Leaf) {
      try {
        $found = @()
        foreach ($r in @((Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json).repos)) {
          if ($r -isnot [string]) { continue }
          $parts = $r.Split('/')
          if ($parts.Count -gt 2) { continue }
          $halves = @($parts | Where-Object { $_ -cmatch '\A[A-Za-z0-9._-]+\z' -and $_ -cnotmatch '\A[-.]' -and $_ -cnotmatch '\.\z' })
          if ($halves.Count -ne $parts.Count) { continue }
          if ($parts.Count -ne 2) { Write-Warning "broker.json entry $r is a bare name; the broker refuses it, write it as owner/name"; continue }
          if (-not $trBad) {
            $entryDir = Join-Path $tokensRoot "$($parts[0])/$($parts[1])"
            $null = New-Item -ItemType Directory -Force -Path $entryDir
            # a pre-#1608 wow-admin wrote its token here, a directory a dev container mounts; it is only reported, never deleted
            $legacyAdmin = Join-Path $entryDir 'admin-token'
            if (Test-Path -LiteralPath $legacyAdmin) { Write-Warning "$legacyAdmin is a leftover admin token: wow-admin no longer writes there; run: wow-admin $($parts[0])/$($parts[1]) --revoke" }
          }
          $ownerDirs[$parts[0].ToLowerInvariant()] = $true
          $found += $parts[-1]
        }
        $brokerNames = $found
      } catch { Write-Warning "broker.json unreadable ($($_.Exception.Message)); tokens/<owner>/<repo> not created" }
    }

    # Cross-check of the three host repo lists: broker.json (the name half of each entry), review-poll.json (owner/name) and tokens/.
    # It only warns, with fixed text that holds no exception message; the poll comparison ignores the owner half and compares names case-insensitively.
    if ($brokerNames.Count -gt 0) {
      try {
        $okName = { param($n) $n -is [string] -and $n -cmatch '\A[A-Za-z0-9._-]+\z' -and $n -cnotmatch '\A[-.]' -and $n -cnotmatch '\.\z' }
        $brokerSet = [ordered]@{}
        foreach ($n in $brokerNames) { if (-not $brokerSet.Contains($n.ToLowerInvariant())) { $brokerSet[$n.ToLowerInvariant()] = $n } }
        $pollSet = $null
        $pollFile = Join-Path $WowHome 'review-poll.json'
        if (Test-Path -LiteralPath $pollFile -PathType Leaf) {
          $entries = $null
          try {
            $poll = Get-Content -LiteralPath $pollFile -Raw | ConvertFrom-Json -ErrorAction Stop
            $prop = @($poll.PSObject.Properties | Where-Object { $_.Name -ceq 'repos' })
            if ($poll -is [pscustomobject] -and $prop.Count -eq 1 -and $prop[0].Value -is [object[]]) {
              $vals = $prop[0].Value
              if (@($vals | Where-Object { $_ -isnot [string] }).Count -eq 0) { $entries = $vals }
            }
          } catch { $entries = $null }
          if ($null -eq $entries) {
            Write-Warning 'review-poll.json is not readable as a repos list of strings: not compared with broker.json'
          } else {
            $pollSet = [ordered]@{}
            $skipped = 0
            foreach ($e in $entries) {
              $parts = $e.Split('/')
              if ($parts.Count -eq 2 -and (& $okName $parts[0]) -and (& $okName $parts[1])) {
                if (-not $pollSet.Contains($parts[1].ToLowerInvariant())) { $pollSet[$parts[1].ToLowerInvariant()] = $parts[1] }
              } else { $skipped++ }
            }
            if ($skipped -gt 0) { Write-Warning "review-poll.json entries this check cannot read as owner/name: $skipped; they are not compared with broker.json" }
          }
        }
        if ($null -ne $pollSet) {
          foreach ($k in @($pollSet.PSBase.Keys)) {
            if (-not $brokerSet.Contains($k)) { Write-Warning "$($pollSet[$k]) is in review-poll.json but not broker.json: no dev token is minted for it on this host" }
          }
          foreach ($k in @($brokerSet.PSBase.Keys)) {
            if (-not $pollSet.Contains($k)) { Write-Warning "$($brokerSet[$k]) is in broker.json but not review-poll.json: no automatic reviews for it" }
          }
        }
        # In the default home, the owner halves the homes beside it name are not leftovers (#1599). Silent: any failure adds nothing.
        $sibOwners = @{}
        try {
          if (-not $trItem -and $HOME) {
            $dhSib = Join-Path $HOME '.config/glunk-identity'
            if (Test-IsDefaultHome $WowHome $dhSib) {
              foreach ($sh in (Get-SiblingHomes $dhSib)) {
                try {
                  $sc = Join-Path $sh 'broker.json'
                  if (-not (Test-Path -LiteralPath $sc -PathType Leaf)) { continue }
                  foreach ($ok in (Read-HomeOwners $sc).Keys) { if (-not $brokerSet.Contains($ok)) { $sibOwners[$ok] = $true } }
                } catch { }
              }
            }
          }
        } catch { $sibOwners = @{} }
        $tokDir = Join-Path $WowHome 'tokens'
        if (-not $trItem -and (Test-Path -LiteralPath $tokDir -PathType Container)) {
          foreach ($d in @(Get-ChildItem -LiteralPath $tokDir -Directory -Force | Sort-Object Name)) {
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            $dk = $d.Name.ToLowerInvariant()
            if ((& $okName $d.Name) -and -not $ownerDirs.ContainsKey($dk) -and -not $sibOwners.ContainsKey($dk)) { Write-Warning "tokens/$($d.Name) is not the owner directory of any broker.json entry" }
          }
        }
      } catch { Write-Warning 'the cross-check of broker.json, review-poll.json and tokens/ could not run' }
    }
    Write-ProfileBlock $ProfilePath
    "installed commit $head into $bin"
  } finally {
    # A failed enable must not replace the install's own error: warn loudly and let that error through.
    if ($taskWasEnabled) {
      try { $null = Enable-ScheduledTask -TaskName $StopTask }
      catch { Write-Warning "could not enable task $StopTask again ($($_.Exception.Message)); it stays disabled until the register script runs" }
    }
  }
}
