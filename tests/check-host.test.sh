#!/bin/sh
# Fixture tests for scripts/identity/check-host.ps1 (issue #1434), the report-only host check.
#
# Stub pwsh, yq and gh executables sit first on PATH (the script under test is run by the real pwsh's absolute
# path); a scratch source clone with a bare origin and scratch homes carry the bin check; the Task Scheduler
# cmdlets are caller-scope stub functions, so no real task is touched.
#
#   tools        pwsh / yq: current, old, an unreadable version, a valid version with exit 1 (unknown), absent; gh: present, absent
#   bin          a MANIFEST at the base tip (ok), one commit behind (behind 1), off the base (not-on-base), a commit the clone
#                lacks (unknown), malformed or missing (no-manifest), no bin (missing); an unfetchable remote and a PATH with
#                no git (unknown)
#   task         an enabled matching task (ok), a disabled one, two matches (two lines), a path differing in letter case and
#                slash direction, a home with a trailing separator, only a review-poll task or another home's broker (none),
#                an action with no Arguments or no actions, a throw or no cmdlet (unknown)
#   home refusal a home starting with ~ exits 2 with the one message and nothing else; Test-HomeRefused with OnWindows true
#                refuses a home starting with a slash and accepts a Windows-form home; a second bare home after -WowHome is
#                refused by parameter binding
#   exit         0 for all ok lines, 1 for any other; asserted for every non-ok form, each alone (the only non-ok line)
#   static       no copy of the yq minimum (read from Test-YqVersion) and no Register-, Unregister-, Enable-, Disable-,
#                Start- or Stop-ScheduledTask call
#
# Permitted toolset: POSIX sh, its standard utilities, pwsh and git (skipped, loudly, if either is absent; a
# failure instead when WOW_TESTS_REQUIRE_TOOLS is exactly 1, which ci.yml sets).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

for t in pwsh git; do
  if ! command -v "$t" >/dev/null 2>&1; then
    if [ "${WOW_TESTS_REQUIRE_TOOLS:-}" = 1 ]; then
      echo "FAIL - $t not on PATH; check-host fixtures would not run" >&2
      exit 1
    fi
    echo "SKIP - $t not on PATH; check-host fixtures not run" >&2
    exit 0
  fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

wp() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

pwsh_abs="$(command -v pwsh)"
git_abs="$(command -v git)"
script="$root_dir/scripts/identity/check-host.ps1"
common="$root_dir/scripts/identity/wow-launch-common.ps1"

fail=0
ok() { echo "ok - $1"; }
bad() { echo "FAIL - $1" >&2; fail=1; }
check() { l=$1; shift; if "$@"; then ok "$l"; else bad "$l"; fi; }

stubdir="$tmp/stub" gitbin="$tmp/gitbin"
mkdir "$stubdir" "$gitbin"
ln -s "$git_abs" "$gitbin/git"

cat >"$stubdir/pwsh" <<'STUB'
#!/bin/sh
case "$PW_MODE" in
  old) echo "PowerShell 7.1.0" ;;
  garbage) echo "hello" ;;
  exit1) echo "PowerShell 7.4.1"; exit 1 ;;
  *) echo "PowerShell 7.4.1" ;;
esac
STUB
cat >"$stubdir/yq" <<'STUB'
#!/bin/sh
case "$YQ_MODE" in
  old) echo "yq (https://github.com/mikefarah/yq/) version v0.0.1" ;;
  garbage) echo "hello" ;;
  exit1) echo "yq (https://github.com/mikefarah/yq/) version v999.0.0"; exit 1 ;;
  *) echo "yq (https://github.com/mikefarah/yq/) version v999.0.0" ;;
esac
STUB
printf '#!/bin/sh\nexit 0\n' >"$stubdir/gh"
chmod +x "$stubdir/pwsh" "$stubdir/yq" "$stubdir/gh"
PW_MODE=current YQ_MODE=current; export PW_MODE YQ_MODE

# The yq minimum, read from the function the launchers use, with the real pwsh.
yqmin=$("$pwsh_abs" -NoProfile -NonInteractive -Command "\$script:LaunchProg = 't'; \$script:LaunchUsage = 'u'; . '$(wp "$common")'; (Test-YqVersion '').Minimum" 2>&1 | tr -d '\r')
check "the yq minimum reads as a version" sh -c "printf '%s' '$yqmin' | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\$'"

# A source clone with a bare origin: c1 <- c2 <- c3 on main (pushed), side carries one commit off the base.
src="$tmp/src" origin="$tmp/origin.git"
git init -q -b main "$src" && git init -q --bare -b main "$origin"
g() { git -C "$src" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
g remote add origin "$(wp "$origin")"
for n in 1 2 3; do echo "$n" >"$src/f"; g add f; g commit -q -m "c$n"; eval "c$n=$(g rev-parse HEAD)"; done
g push -q origin main
g checkout -q -b side "$c1"; echo side >"$src/s"; g add s; g commit -q -m side; side=$(g rev-parse HEAD)
g checkout -q main
lacks=1111111111111111111111111111111111111111

mkhome() { # mkhome <name> [manifest first line]: a home with bin; no line writes no MANIFEST
  mkdir -p "$tmp/h/$1/bin"
  [ $# -lt 2 ] || printf '%s\ninstalled 2026-01-01T00:00:00Z\n' "$2" >"$tmp/h/$1/bin/MANIFEST"
}
mkhome ok "commit $c3"; mkhome behind "commit $c2"; mkhome off "commit $side"; mkhome lacks "commit $lacks"
mkhome bad "commit ABC"; mkhome none; mkdir -p "$tmp/h/nobin"
hp() { wp "$tmp/h/$1"; }

cat >"$tmp/tasks.ps1" <<'PS1'
# pwsh puts its own directory first on PATH (Linux), which would hide a stub pwsh; take it out again
$env:PATH = ($env:PATH -split [IO.Path]::PathSeparator | Where-Object { $_ -ne $PSHOME }) -join [IO.Path]::PathSeparator
function New-StubTask($Name, $Arguments, $Enabled = $true, [switch]$NoArguments, [switch]$NoActions) {
  $action = if ($NoArguments) { [pscustomobject]@{ Execute = 'conhost.exe' } } else { [pscustomobject]@{ Execute = 'conhost.exe'; Arguments = $Arguments } }
  [pscustomobject]@{ TaskName = $Name; Actions = $(if ($NoActions) { @() } else { @($action) }); Settings = [pscustomobject]@{ Enabled = $Enabled } }
}
function Get-BrokerArgs($Home_) { "--headless `"pwsh`" -NoProfile -File `"$Home_\bin\broker.ps1`" -WowHome `"$Home_`" -Sh `"sh`"" }
if ($env:TASKS) {
  function Get-ScheduledTask {
    $h = $env:T_HOME
    switch ($env:TASKS) {
      'enabled' { New-StubTask 'broker-a' (Get-BrokerArgs $h) }
      'disabled' { New-StubTask 'broker-a' (Get-BrokerArgs $h) $false }
      'two' { New-StubTask 'broker-a' (Get-BrokerArgs $h); New-StubTask 'broker-b' (Get-BrokerArgs $h) $false }
      'caseslash' { New-StubTask 'broker-c' (Get-BrokerArgs $h.ToUpper().Replace('/', '\')) }
      'other' {
        New-StubTask 'poll' "-NoProfile -Command `"& '$h\bin\wow-review-poll'`""
        New-StubTask 'broker-x' (Get-BrokerArgs "$h-other")
      }
      'noargs' { New-StubTask 'broker-n' $null -NoArguments }
      'noactions' { New-StubTask 'broker-n' $null -NoActions }
      'throw' { throw 'access denied' }
    }
  }
}
PS1

# runc <args...>: the script under test with the real pwsh; sets rc and $tmp/out. PATH is the stubs and git only.
runc() {
  rc=0
  PATH="${CH_PATH:-$stubdir:$gitbin}" "$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$script")" -SourceRepo "$(wp "$src")" "$@" >"$tmp/out" 2>&1 || rc=$?
}
# runt <tasks mode> <home name> [args]: the same with the Task Scheduler stubs dot-sourced; T_HOME is the home's path
runt() {
  mode=$1; hn=$2; shift 2
  rc=0
  TASKS=$mode T_HOME="$(hp "$hn")" PATH="${CH_PATH:-$stubdir:$gitbin}" "$pwsh_abs" -NoProfile -NonInteractive -Command \
    ". '$(wp "$tmp/tasks.ps1")'; & '$(wp "$script")' -SourceRepo '$(wp "$src")' -WowHome '$(hp "$hn")' $*; exit \$LASTEXITCODE" >"$tmp/out" 2>&1 || rc=$?
}
has() { grep -Fxq -- "$1" "$tmp/out"; }
lines() { wc -l <"$tmp/out" | tr -d ' '; }
# nonok: how many output lines carry a status word other than ok (the second word of a pwsh, yq or gh line, the third of a
# bin or task line; a home path with a space would shift the third word, which the scratch homes never hold)
nonok() { awk '{ w = ($1 == "bin" || $1 == "task") ? $3 : $2; if (w != "ok") n++ } END { print n + 0 }' "$tmp/out"; }
# only1 <rc 1 expected>: exit 1 and exactly one non-ok line, the form's own
only1() { test "$rc" -eq 1 && test "$(nonok)" -eq 1; }

# --- tools -------------------------------------------------------------------------------------
runt '' ok
check "tools: current pwsh" has "pwsh ok 7.4.1"
check "tools: current yq" has "yq ok 999.0.0"
check "tools: gh present" has "gh ok"
PW_MODE=old runt enabled ok; check "tools: old pwsh" has "pwsh old 7.1.0 7.2"; check "tools: old pwsh exits 1 alone" only1
PW_MODE=garbage runt enabled ok; check "tools: unreadable pwsh" has "pwsh unknown"; check "tools: unreadable pwsh exits 1 alone" only1
PW_MODE=exit1 runt enabled ok; check "tools: pwsh exit 1 is unknown" has "pwsh unknown"; check "tools: pwsh exit 1 exits 1 alone" only1
YQ_MODE=old runt enabled ok; check "tools: old yq names the minimum" has "yq old 0.0.1 $yqmin"; check "tools: old yq exits 1 alone" only1
YQ_MODE=garbage runt enabled ok; check "tools: unreadable yq" has "yq unknown"; check "tools: unreadable yq exits 1 alone" only1
YQ_MODE=exit1 runt enabled ok; check "tools: yq exit 1 is unknown" has "yq unknown"; check "tools: yq exit 1 exits 1 alone" only1
# one tool absent at a time: move its stub aside, run, put it back
for t in pwsh yq gh; do
  mv "$stubdir/$t" "$tmp/$t.aside"
  runt enabled ok
  check "tools: $t absent" has "$t missing"
  check "tools: $t absent exits 1 alone" only1
  mv "$tmp/$t.aside" "$stubdir/$t"
done

# --- bin ---------------------------------------------------------------------------------------
runc -WowHome "$(hp ok)"; check "bin: at the base tip" has "bin $(hp ok) ok $c3"
# every other form runs through runt with the enabled task, so its bin line is the only non-ok line
runt enabled behind; check "bin: one commit behind" has "bin $(hp behind) behind 1 $c2"; check "bin: behind exits 1 alone" only1
runt enabled off; check "bin: a commit off the base" has "bin $(hp off) not-on-base $side"; check "bin: not-on-base exits 1 alone" only1
runt enabled lacks; check "bin: a commit the clone lacks" has "bin $(hp lacks) unknown $lacks"; check "bin: a commit the clone lacks exits 1 alone" only1
runt enabled bad; check "bin: a malformed MANIFEST" has "bin $(hp bad) no-manifest"; check "bin: a malformed MANIFEST exits 1 alone" only1
runt enabled none; check "bin: no MANIFEST" has "bin $(hp none) no-manifest"; check "bin: no MANIFEST exits 1 alone" only1
runt enabled nobin; check "bin: no bin directory" has "bin $(hp nobin) missing"; check "bin: no bin directory exits 1 alone" only1
runt enabled ok -Remote nope; check "bin: an unfetchable remote" has "bin $(hp ok) unknown $c3"; check "bin: an unfetchable remote exits 1 alone" only1
CH_PATH="$stubdir" runt enabled ok; check "bin: no git on PATH" has "bin $(hp ok) unknown $c3"; check "bin: no git on PATH exits 1 alone" only1
runc -WowHome "$(hp ok)" -Base '-x'; check "bin: a base starting with a dash is refused" test "$rc" -eq 2

# --- task --------------------------------------------------------------------------------------
runt enabled ok; check "task: enabled" has "task $(hp ok) ok broker-a"
runt disabled ok; check "task: disabled" has "task $(hp ok) disabled broker-a"; check "task: disabled exits 1 alone" only1
runt two ok; check "task: two matches, two lines" test "$(grep -c '^task ' "$tmp/out")" -eq 2
check "task: the second match is disabled" has "task $(hp ok) disabled broker-b"; check "task: two matches exit 1 with the disabled one alone" only1
runt caseslash ok; check "task: letter case and slash direction are ignored" has "task $(hp ok) ok broker-c"
sep_home="$(hp ok)/"
rc=0
TASKS=enabled T_HOME="$(hp ok)" PATH="$stubdir:$gitbin" "$pwsh_abs" -NoProfile -NonInteractive -Command \
  ". '$(wp "$tmp/tasks.ps1")'; & '$(wp "$script")' -SourceRepo '$(wp "$src")' -WowHome '$sep_home'; exit \$LASTEXITCODE" >"$tmp/out" 2>&1 || rc=$?
check "task: a home with a trailing separator still matches" has "task $sep_home ok broker-a"
runt other ok; check "task: a review-poll task and another home's broker are none" has "task $(hp ok) none"; check "task: a review-poll task and another home's broker are none exits 1 alone" only1
runt noargs ok; check "task: an action with no Arguments is skipped" has "task $(hp ok) none"; check "task: an action with no Arguments is skipped exits 1 alone" only1
runt noactions ok; check "task: a task with no action is skipped" has "task $(hp ok) none"; check "task: a task with no action is skipped exits 1 alone" only1
runt throw ok; check "task: a throw is unknown" has "task $(hp ok) unknown"; check "task: a throw is unknown exits 1 alone" only1
runt '' ok; check "task: no cmdlet is unknown" has "task $(hp ok) unknown"; check "task: no cmdlet exits 1 alone" only1

# --- exit codes --------------------------------------------------------------------------------
runt enabled ok
check "exit: every line ok prints nothing but ok lines" test "$(grep -vc ' ok' "$tmp/out")" -eq 0
check "exit: every line ok exits 0" test "$rc" -eq 0
check "exit: the non-ok counter reads 0 on the all-ok run" test "$(nonok)" -eq 0
runt disabled ok; check "exit: a disabled task exits 1" only1
runt enabled behind; check "exit: a behind bin exits 1" only1

# --- home refusal ------------------------------------------------------------------------------
runc -WowHome '~/x'
check "refusal: ~ exits 2" test "$rc" -eq 2
check "refusal: ~ prints the one message and nothing else" test "$(lines)" -eq 1
check "refusal: the message names the fix" grep -q 'full Windows path' "$tmp/out"
runc -WowHome ''; check "refusal: an empty home exits 2" test "$rc" -eq 2
runc -WowHome "$(hp ok)" extra; check "refusal: a second bare home is refused by parameter binding" test "$rc" -ne 0
check "refusal: parameter binding prints no check line" sh -c "! grep -q '^pwsh ' '$tmp/out'"

cat >"$tmp/refuse.ps1" <<'PS1'
param([string]$Script)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Script, [ref]$null, [ref]$null)
$d = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-HomeRefused' }, $true)
if (@($d).Count -ne 1) { 'missing'; exit 3 }
. ([scriptblock]::Create($d[0].Extent.Text))
"$(Test-HomeRefused '/c/Users/x' $true) $(Test-HomeRefused 'C:\Users\x' $true) $(Test-HomeRefused '/home/x' $false) $(Test-HomeRefused '~x' $false)"
PS1
got=$("$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$tmp/refuse.ps1")" -Script "$(wp "$script")" 2>&1 | tr -d '\r') || true
check "refusal: a slash home is refused on Windows, a Windows-form home accepted, a slash home accepted elsewhere, ~ refused" test "$got" = "True False False True"

# --- static ------------------------------------------------------------------------------------
check "static: no copy of the yq minimum" sh -c "! grep -Fq -- '$yqmin' '$script'"
cat >"$tmp/calls.ps1" <<'PS1'
param([string]$Script)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Script, [ref]$null, [ref]$null)
$c = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
$bad = @($c | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -match '^(Register|Unregister|Enable|Disable|Start|Stop)-ScheduledTask$' })
"count $(@($c).Count) bad $($bad.Count)"
PS1
got=$("$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$tmp/calls.ps1")" -Script "$(wp "$script")" 2>&1 | tr -d '\r') || true
check "static: the script parses and calls no task-changing cmdlet" sh -c "printf '%s' '$got' | grep -Eq '^count [1-9][0-9]* bad 0\$'"

[ "$fail" -eq 0 ] || { echo "check-host: FAILED" >&2; exit 1; }
echo "check-host: all passed"
