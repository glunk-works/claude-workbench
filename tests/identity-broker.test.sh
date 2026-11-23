#!/bin/sh
# Fixture tests for scripts/identity/broker.ps1 (issue #392).
#
# Stub mint.sh stands in for the real minter (its own suite covers it): it records its argv and writes a
# canned token. A throwaway $WOW_HOME is laid out like the real one (apps.json with a "dev" entry,
# broker.json). The broker runs with -Once, one pass per case.
#
#   mint         no token -> minted for the dev installation, one repo, the dev permissions, written to
#                tokens/<owner>/<repo>/dev-token (entries are owner/name, #1340); the staging file is gone
#   current      a token with more than 30 minutes left is left alone (mint never called)
#   rotation     a token with 10 minutes left, then an expired one, are replaced by the new token
#   failure      a failed mint, or one that yields a non-token or already-expired file, exits 1 and
#                keeps the old token untouched; no token text reaches stdout, stderr or broker.log
#   survival     a repo whose token cannot be published (a directory in the way) is logged and exits 1;
#                the other repo is still minted
#   token shape  a CRLF token file, or one with a blank line, is not "current" and is replaced
#   expiry       a reviewer-token file older than the TTL is removed for any repo, a recent one kept
#   sweep        review-sessions/<id> older than the session age is removed and a recent one kept; a session
#                directory that is, or holds, a junction is left and its target never touched; review-logs
#                files older than the log age are removed and recent ones kept (#634)
#   install      install-host-tools.ps1 exports committed files only into bin with a MANIFEST (commit, hashes),
#                the review image's build context into bin/review/ from the table in the script,
#                refuses an uncommitted change (in any source directory) or a HEAD not on origin/main, and
#                creates tokens/<owner>/<repo> only, and warns once, without deleting, about an admin-token file already in one (#1608); warns, without failing, when broker.json and review-poll.json name different repos, or a top-level tokens/ directory is no entry's owner, and
#                gives poll entries it cannot read as owner/name one warning holding only their count;
#                register-broker-task.ps1 -WhatIf points the task at bin, runs pwsh through conhost --headless and installs nothing (skipped, loudly,
#                where New-ScheduledTaskAction is not available)
#   task process task-process.ps1 (dot-sourced): Get-FileArgSpan finds the -File span of the broker task's conhost action
#                and none in the poll task's -Command form; Test-FileArgMatch matches the broker pwsh and conhost command
#                lines (any letter case), quoted or bare as the Store app-alias pwsh reports it, and not another home, a bin.old
#                path, a longer path or an empty line; an empty -File "" is no span;
#                Stop-FileArgProcess under strict mode with stubbed cmdlets (no match, one, two, a survivor throws, a bare and a quoted match); the install's
#                -StopTask handling run for real against stubbed Task Scheduler and process cmdlets (#1028), asserting the call log line for line: an
#                enabled task is disabled, stopped, its process ended and re-enabled in that order; a task disabled before is never re-enabled; a throw
#                past the disable (Get-FileHash stubbed to throw) still re-enables an enabled task and creates no bin; a throw from the disable itself
#                stops before the stop and the re-enable; Write-NoSpanWarning warns once, naming the task, for a broker action with an unquoted -File path
#                (any letter case) and is silent for a quoted span, the poll task's -Command action, an empty string and $null, and the install prints it for an
#                unquoted action (nothing ended) and stays silent for a missing task (#1029); a task with no actions or an action without an Arguments property completes the install, and register-broker-task.ps1 -Unregister, with no error text, no process ended and no warning (#1658); static checks that the
#                broker trigger repeats every minute with no RestartCount, both stop paths call Stop-FileArgProcess and Write-NoSpanWarning, and
#                no identity script passes Disable-, Enable-, Start- or Stop-ScheduledTask -Confirm or -WhatIf
#   junction     Test-IsDefaultHome from broker.ps1 and install-host-tools.ps1 (their Resolve-RealPath and Test-IsDefaultHome definitions taken through the parser) is true for a
#                junction to the default home and for a home reached through a junction in a parent component, and false for another directory (#1598; skipped, loudly, where no junction can be made)
#   guard        register-broker-task.ps1 reads the task registered under -TaskName before it calls the installer, and refuses (also
#                under -WhatIf) one whose -WowHome names another home or none it can read, unless -ReplaceOtherHome is given (#1594; stubbed
#                Get-ScheduledTask, skipped, loudly, where [Environment]::SystemDirectory is set, and a failure instead when that holds off Windows
#                with WOW_TESTS_REQUIRE_TOOLS exactly 1, since a real pwsh reads it empty there: guard_verdict decides run, skip or fail): no task, the same home, the same home in
#                another letter case with backslashes, a different home, a different home with the switch, no -WowHome, no actions, no Arguments property
#   no tool on PATH  with PATH holding only an empty directory and no -Sh, register-broker-task, broker
#                and install-host-tools each reach their own "no POSIX sh found" / "git not found" message,
#                never a null .Source error; broker never calls mint.sh and install creates no bin
#   owner/name   a broker.json entry "acme/alpha" mints once (--repos alpha) and writes only tokens/acme/alpha with no staged file
#                left; a stale or missing owner copy re-mints, and a stale or missing old-layout tokens/alpha alone never
#                does; a publish blocked for the owner copy is logged, exits 1, leaves no staged file and the other entry is
#                still minted; bad shapes (a/b/c, /alpha, acme/, a half starting with . or -, a non-ASCII half, an owner
#                equal to another entry's name in any case, two entries with one name half, a non-string entry) exit 2 before
#                any mint; acme/acme is accepted; a bare-name entry exits 2 before any mint (#1340); the sweeps leave a
#                non-ASCII directory; the install creates only owner directories, warns once by name for a bare entry,
#                skips an entry failing the rule, and its cross-check names a top-level directory that is not an owner half
#   tokens root  a tokens-root file holding default-home (#1568) moves the dev-token to the default home's tokens/ (HOME is a
#                fixture; skipped, loudly, under MSYS where pwsh's HOME is the user profile): the owner half must equal the dev
#                installation's account (mint.sh --print-account, any letter case) or nothing is minted and the pass exits 1; default-home with
#                no newline, one LF and CRLF are accepted, two LFs, other content, an empty file, a link, a directory, an empty
#                HOME and the file in the default home itself (also through a link, a parent-component link, a link whose target runs through a link or through link/.., or another letter case) exit 2 with a setup: line; a missing default home is created; absent file:
#                no account read; the install creates <owner>/<repo> under the root and warns once, creating nothing, for a refused file
#   profile      the install writes the wowd, wowl and wowend shortcuts into a marked block of the PowerShell profile (#1595; HOME is a fixture,
#                skipped, loudly, under MSYS like the tokens-root cases): a new directory and file, an append with and without a final
#                line break, a second run that leaves the bytes identical, an update after a map change that keeps every byte outside the
#                markers (a UTF-8 byte order mark before the start marker with CRLF; one invalid UTF-8 byte before the block with LF),
#                malformed marker forms and a UTF-16 profile left untouched with one profile: line and exit 0, the default profile path,
#                a directory, a link, a dangling link and a path under a regular file left alone, the owner-to-home map (default home,
#                sibling with a valid tokens-root, without, with a refused one, through a link, a broker.json that is not JSON, an owner in
#                two homes, one owner in two letter cases), an install from a sibling home, no .config folder, a quoted folder name, the
#                echo of wowd, wowl and wowend (a half with a dot, an underscore and a hyphen included), the throws (a half outside letters, digits and . _ - included, with the usage pattern held byte-equal to Assert-RepoArgument's), a mode-600 profile keeping its mode on an update and an append, a hard-linked profile staying linked and equal, a mode-444 profile left byte-identical with one not-written line (#1658), and -WhatIf writing no profile. Under MSYS those fixture-HOME cases (the owner-to-home map,
#                the sibling homes, the default profile path, the empty HOME, the sibling-owner cross-check) do not run, and a smaller set does,
#                with -ProfilePath a scratch file and HOME untouched: a first install into a missing directory writes one marker pair with CRLF
#                throughout and a final CRLF, a second leaves the bytes identical, an LF profile gets the block with LF only and its first lines
#                unchanged, and dot-sourcing the CRLF file defines wowd, wowl and wowend (the owner map is not asserted)
#   sibling owners  the default home's cross-check accepts the owner directories named by the broker.json of each home beside it with a valid tokens-root
#                (#1599; HOME is a fixture, skipped under MSYS like the profile cases): an owner in another letter case, no tokens-root or other
#                content, a sibling whose broker.json is not JSON or is absent beside a readable one, an owner equal to a name half of the default
#                home's broker.json, an install from another home, entries that are not two halves passing the name rule, and an empty HOME
#   config       a bad repo name (or a trailing dot) or a missing broker.json exits 2 before anything
#                is minted
#
# Permitted toolset: POSIX sh, its standard utilities and pwsh (skipped, loudly, if absent; a failure instead when
# WOW_TESTS_REQUIRE_TOOLS is exactly 1, which ci.yml sets, as tests/identity-launchers.test.sh words it).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  if [ "${WOW_TESTS_REQUIRE_TOOLS:-}" = 1 ]; then
    echo "FAIL - pwsh not on PATH; identity-broker fixtures would not run" >&2
    exit 1
  fi
  echo "SKIP - pwsh not on PATH; identity-broker fixtures not run" >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Native pwsh wants native paths; under MSYS that is cygpath -m, elsewhere the path as is.
wp() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

scripts="$tmp/scripts" home="$tmp/home" stubdir="$tmp/stub"
mkdir "$scripts" "$home" "$stubdir"
cat >"$scripts/mint.sh" <<'STUB'
#!/bin/sh
for a in "$@"; do
  if [ "$a" = --print-account ]; then
    echo called >>"$STUB_DIR/print-calls"
    [ -z "${STUB_ACCT_FAIL:-}" ] || { echo "mint.sh: could not read the account" >&2; exit 1; }
    printf '%s\n' "${STUB_ACCOUNT:-acme}"; exit 0
  fi
done
printf '%s\n' "$@" >"$STUB_DIR/mint-argv"
echo called >>"$STUB_DIR/mint-calls"
while [ $# -gt 0 ]; do [ "$1" = --out ] && out=$2; shift; done
[ -z "${STUB_FAIL:-}" ] || { echo "mint.sh: GitHub answered HTTP 401: Bad credentials" >&2; exit 1; }
printf '%s\n%s\n' "$STUB_TOKEN" "$STUB_EXPIRES" >"$out"
STUB
cat >"$home/apps.json" <<'CONF'
{"dev": {"client_id": "Iv1devclient", "installation_id": "4242", "key": "dev.pem"}}
CONF
echo pem >"$home/dev.pem"
repos_ok='{"repos": ["acme/alpha", "acme/beta"]}'
echo "$repos_ok" >"$home/broker.json"

sh_path=$(wp "$(command -v sh)")
fresh=ghs_FRESHfreshFRESHfreshFRESHfreshFRESH0001
old=ghs_OLDoldOLDoldOLDoldOLDoldOLDoldOLDold00001
STUB_DIR=$stubdir; export STUB_DIR
STUB_TOKEN=$fresh; export STUB_TOKEN

stamp() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }
live=$(stamp '+60 minutes')
STUB_EXPIRES=$live; export STUB_EXPIRES

fail=0
ok() { echo "ok - $1"; }
bad() { echo "FAIL - $1" >&2; fail=1; }
check() { # check <label> <command...>
  l=$1; shift
  if "$@"; then ok "$l"; else bad "$l"; fi
}

run_broker() { # leaves the exit code in $rc, output in $tmp/out
  rc=0
  pwsh -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/broker.ps1")" \
    -WowHome "$(wp "$home")" -Sh "$sh_path" -ScriptsDir "$(wp "$scripts")" -Once >"$tmp/out" 2>&1 || rc=$?
}
reset() { rm -f "$stubdir"/*; rm -rf "$home/tokens" "$home/staging" "$home/broker.log" "$home/review-sessions" "$home/review-logs"; echo "$repos_ok" >"$home/broker.json"; }
set_repos() { printf '{"repos": [%s]}\n' "$1" >"$home/broker.json"; }
calls() { if [ -f "$stubdir/$1" ]; then wc -l <"$stubdir/$1" | tr -d ' '; else echo 0; fi; }
# tpath <repo>: a bare name means the fixtures' owner, acme; owner/name and paths with a slash are kept
tpath() { case "$1" in */*) printf '%s' "$1" ;; *) printf 'acme/%s' "$1" ;; esac; }
write_token() { # write_token <repo> <token> <expires>
  d="$home/tokens/$(tpath "$1")"; mkdir -p "$d"; printf '%s\n%s\n' "$2" "$3" >"$d/dev-token"
}
tokfile() { cat "$home/tokens/$(tpath "$1")/dev-token" 2>/dev/null || true; }
expect_fresh() { printf '%s\n%s' "$fresh" "$live"; }

# --- mint ------------------------------------------------------------------------------------
reset; run_broker
check "mint: exits 0" test "$rc" -eq 0
check "mint: one mint per repo" test "$(calls mint-calls)" -eq 2
check "mint: alpha token and expiry written" test "$(tokfile alpha)" = "$(expect_fresh)"
check "mint: beta token and expiry written" test "$(tokfile beta)" = "$(expect_fresh)"
check "mint: staging file gone" test ! -e "$home/staging/alpha/dev-token"
argv=$(tr '\n' ' ' <"$stubdir/mint-argv")
case "$argv" in
  *"--client-id Iv1devclient"*"--installation-id 4242"*"--repos beta --perms contents=write,pull_requests=write,issues=write,checks=read,actions=read,statuses=read"*)
    ok "mint: dev App, one repo, dev permissions" ;;
  *) bad "mint: argv was $argv" ;;
esac
case "$argv" in *administration*) bad "mint: asked for administration" ;; *) ok "mint: no administration permission" ;; esac

# --- current ---------------------------------------------------------------------------------
reset
soon=$(stamp '+45 minutes')
write_token alpha "$old" "$soon"; write_token beta "$old" "$soon"
run_broker
check "current: exits 0" test "$rc" -eq 0
check "current: mint never called" test "$(calls mint-calls)" -eq 0
check "current: token untouched" test "$(tokfile alpha)" = "$old
$soon"

# --- rotation --------------------------------------------------------------------------------
reset
write_token alpha "$old" "$(stamp '+10 minutes')"; write_token beta "$old" "$(stamp '-5 minutes')"
run_broker
check "rotation: exits 0" test "$rc" -eq 0
check "rotation: expiring token replaced" test "$(tokfile alpha)" = "$(expect_fresh)"
check "rotation: expired token replaced" test "$(tokfile beta)" = "$(expect_fresh)"
check "rotation: both minted" test "$(calls mint-calls)" -eq 2

# --- failure ---------------------------------------------------------------------------------
reset
write_token alpha "$old" "$(stamp '+10 minutes')"; write_token beta "$old" "$(stamp '+10 minutes')"
before=$(tokfile alpha)
STUB_FAIL=1; export STUB_FAIL; run_broker; unset STUB_FAIL
check "failure: exits 1" test "$rc" -eq 1
check "failure: old token kept" test "$(tokfile alpha)" = "$before"
check "failure: error in the log" grep -q 'mint failed' "$home/broker.log"
for bad_token in notatoken ghs_short; do
  reset; write_token alpha "$old" "$(stamp '+10 minutes')"; before=$(tokfile alpha)
  STUB_TOKEN=$bad_token; run_broker; STUB_TOKEN=$fresh
  check "failure: $bad_token not published" test "$(tokfile alpha)" = "$before"
  check "failure: $bad_token exits 1" test "$rc" -eq 1
done
reset; write_token alpha "$old" "$(stamp '+10 minutes')"; before=$(tokfile alpha)
STUB_EXPIRES=$(stamp '-1 minutes'); run_broker; STUB_EXPIRES=$live
check "failure: already-expired mint not published" test "$(tokfile alpha)" = "$before"
for f in "$tmp/out" "$home/broker.log"; do
  if grep -q "$fresh\|$old" "$f"; then bad "secrecy: token text in $(basename "$f")"; else ok "secrecy: no token text in $(basename "$f")"; fi
done

# --- survival --------------------------------------------------------------------------------
reset
mkdir -p "$home/tokens/acme/alpha/dev-token"   # unpublishable: a directory where the token file goes
run_broker
check "survival: failed repo exits 1" test "$rc" -eq 1
check "survival: the other repo is still minted" test "$(tokfile beta)" = "$(expect_fresh)"
check "survival: failure is logged" grep -q 'dev acme/alpha' "$home/broker.log"

# --- token shape -----------------------------------------------------------------------------
reset
mkdir -p "$home/tokens/acme/alpha" "$home/tokens/acme/beta"
printf '%s\r\n%s\r\n' "$old" "$(stamp '+55 minutes')" >"$home/tokens/acme/alpha/dev-token"
printf '%s\n\n%s\n' "$old" "$(stamp '+55 minutes')" >"$home/tokens/acme/beta/dev-token"
run_broker
check "shape: CRLF token is replaced" test "$(tokfile alpha)" = "$(expect_fresh)"
check "shape: token with a blank line is replaced" test "$(tokfile beta)" = "$(expect_fresh)"

reset
mkdir -p "$home/review-tokens/gone-repo" "$home/review-tokens/alpha"
echo t >"$home/review-tokens/gone-repo/reviewer-token"; touch -d '-20 minutes' "$home/review-tokens/gone-repo/reviewer-token"
echo t >"$home/review-tokens/alpha/reviewer-token"   # recent
write_token alpha "$old" "$soon"; write_token beta "$old" "$soon"
run_broker
check "expiry: an old file is removed for a repo not in broker.json" test ! -e "$home/review-tokens/gone-repo/reviewer-token"
check "expiry: a recent file is kept" test -e "$home/review-tokens/alpha/reviewer-token"

# --- sweep (#634) ----------------------------------------------------------------------------
# mkjunction <path> <target>: a junction via pwsh (no admin on Windows); non-zero where one cannot be made.
mkjunction() {
  pwsh -NoProfile -NonInteractive -Command "New-Item -ItemType Junction -Path '$(wp "$1")' -Target '$(wp "$2")' | Out-Null" >/dev/null 2>&1 &&
    pwsh -NoProfile -NonInteractive -Command "if ((Get-Item -LiteralPath '$(wp "$1")' -Force).LinkType) { exit 0 } else { exit 1 }" >/dev/null 2>&1
}
reset
write_token alpha "$old" "$soon"; write_token beta "$old" "$soon"
mkdir -p "$home/review-sessions/old-sess" "$home/review-sessions/new-sess" "$home/review-sessions/.bad name"
echo t >"$home/review-sessions/old-sess/session-token"; touch -d '-200 minutes' "$home/review-sessions/old-sess/session-token"
echo t >"$home/review-sessions/new-sess/session-token"
mkdir -p "$home/review-sessions/nofile-old" "$home/review-sessions/nofile-new"
touch -d '-200 minutes' "$home/review-sessions/nofile-old"
mkdir -p "$home/review-logs/sub"
echo l >"$home/review-logs/old.log"; touch -d '-10 days' "$home/review-logs/old.log"
echo l >"$home/review-logs/recent.log"
echo l >"$home/review-logs/sub/old-nested.log"; touch -d '-10 days' "$home/review-logs/sub/old-nested.log"
run_broker
check "sweep: exits 0" test "$rc" -eq 0
check "sweep: an old review session is removed" test ! -e "$home/review-sessions/old-sess"
check "sweep: a recent review session is kept" test -e "$home/review-sessions/new-sess/session-token"
check "sweep: a session with no token is aged by its directory" test ! -e "$home/review-sessions/nofile-old" -a -d "$home/review-sessions/nofile-new"
check "sweep: a badly named directory is left" test -d "$home/review-sessions/.bad name"
check "sweep: an old log is removed" test ! -e "$home/review-logs/old.log"
check "sweep: a recent log is kept" test -e "$home/review-logs/recent.log"
check "sweep: logs are swept at the top level only" test -e "$home/review-logs/sub/old-nested.log"

reset
write_token alpha "$old" "$soon"; write_token beta "$old" "$soon"
mkdir -p "$tmp/jt/inner" "$tmp/jt2" "$home/review-sessions/nest-sess"
echo secret >"$tmp/jt/session-token"; touch -d '-200 minutes' "$tmp/jt/session-token"
echo keep >"$tmp/jt2/keep.txt"
echo t >"$home/review-sessions/nest-sess/session-token"; touch -d '-200 minutes' "$home/review-sessions/nest-sess/session-token"
if mkjunction "$home/review-sessions/junc-sess" "$tmp/jt" && mkjunction "$home/review-sessions/nest-sess/inner" "$tmp/jt2"; then
  run_broker
  check "sweep: a junction session directory is left" test -d "$home/review-sessions/junc-sess"
  check "sweep: a session holding a junction is left" test -d "$home/review-sessions/nest-sess" -a -e "$home/review-sessions/nest-sess/session-token"
  check "sweep: a junction's target is never touched" test -f "$tmp/jt/session-token" -a -f "$tmp/jt2/keep.txt"
  check "sweep: the left session is logged" grep -q 'nest-sess.*link or junction' "$home/broker.log"
  check "sweep: ...logged once in a pass, not once per repo (the once-per-process cache is not exercised: -Once is one pass)" test "$(grep -c 'nest-sess.*link or junction' "$home/broker.log")" -eq 1
else
  echo "SKIP - a junction cannot be made here; the junction sweep fixtures did not run" >&2
fi
# Whatever happened, take the junctions off without following them before the temp tree is removed.
for j in "$home/review-sessions/junc-sess" "$home/review-sessions/nest-sess/inner"; do
  [ ! -e "$j" ] || pwsh -NoProfile -NonInteractive -Command "(Get-Item -LiteralPath '$(wp "$j")' -Force).Delete()" >/dev/null 2>&1 || true
done

# --- default-home junctions (#1598) ------------------------------------------------------------
# Resolve-RealPath's junction branch, at function level: both scripts' Resolve-RealPath and Test-IsDefaultHome definitions are
# taken through the PowerShell parser and run alone. Outside the tokens-root case that skips under MSYS, since a junction needs Windows.
mkdir -p "$tmp/jd/default" "$tmp/jd/other" "$tmp/jd2"
if mkjunction "$tmp/jd/jlink" "$tmp/jd/default" && mkjunction "$tmp/jd2/p" "$tmp/jd"; then
  cat >"$tmp/jfix.ps1" <<'PS'
param([string]$Script, [string]$Home1, [string]$Home2, [string]$Home3, [string]$Default)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Script, [ref]$null, [ref]$null)
$defs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in 'Resolve-RealPath', 'Test-IsDefaultHome' }, $true)
if (@($defs).Count -ne 2) { 'missing'; exit 3 }
foreach ($d in $defs) { . ([scriptblock]::Create($d.Extent.Text)) }
# the runner's temp dir comes as an 8.3 short name, which a path through a junction loses; give every input its long form
if ([Environment]::OSVersion.Platform -eq 'Win32NT') {
  Add-Type -MemberDefinition '[DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint GetLongPathName(string s, System.Text.StringBuilder b, uint n);' -Name Lp -Namespace Wow
  function Get-LongPath([string]$p) { $b = New-Object System.Text.StringBuilder 1024; if ([Wow.Lp]::GetLongPathName($p, $b, 1024) -gt 0) { $b.ToString() } else { $p } }
  $Home1 = Get-LongPath $Home1; $Home2 = Get-LongPath $Home2; $Home3 = Get-LongPath $Home3; $Default = Get-LongPath $Default
}
"$(Test-IsDefaultHome $Home1 $Default) $(Test-IsDefaultHome $Home2 $Default) $(Test-IsDefaultHome $Home3 $Default)"
foreach ($x in $Home1, $Home2, $Home3, $Default) { try { "resolved: $x -> $(Resolve-RealPath $x)" } catch { "resolved: $x -> THROW $_" } }
PS
  for f in broker.ps1 install-host-tools.ps1; do
    got=$(pwsh -NoProfile -NonInteractive -File "$(wp "$tmp/jfix.ps1")" -Script "$(wp "$root_dir/scripts/identity/$f")" \
      -Home1 "$(wp "$tmp/jd/jlink")" -Home2 "$(wp "$tmp/jd2/p/default")" -Home3 "$(wp "$tmp/jd/other")" -Default "$(wp "$tmp/jd/default")" 2>&1) || true
    first=$(printf '%s\n' "$got" | head -n 1)
    [ "$first" = "True True False" ] || printf 'junction: %s printed: %s\n' "$f" "$got" >&2
    check "junction: $f Test-IsDefaultHome is true for a junction to the default home, true through a parent junction, false for another directory" test "$first" = "True True False"
  done
else
  echo "SKIP - a junction cannot be made here; the default-home junction fixtures did not run" >&2
fi
for j in "$tmp/jd/jlink" "$tmp/jd2/p"; do
  [ ! -e "$j" ] || pwsh -NoProfile -NonInteractive -Command "(Get-Item -LiteralPath '$(wp "$j")' -Force).Delete()" >/dev/null 2>&1 || true
done

# --- install-host-tools / register -----------------------------------------------------------
# A throwaway source repo with the host scripts committed on main, and a bare origin it is pushed to.
src="$tmp/src" origin="$tmp/origin.git"
git init -q -b main "$src" && git init -q --bare -b main "$origin"
mkdir -p "$src/scripts/identity"
for f in broker.ps1 mint.sh wow-common.sh wow-review-mint wow-admin register-broker-task.ps1 install-host-tools.ps1 task-process.ps1; do
  cp "$root_dir/scripts/identity/$f" "$src/scripts/identity/$f"
done
# The install table, read from the script itself: one `,@('<source>', '<destination>')` line per entry.
table=$tmp/table
sed -n "s/^  ,@('\([^']*\)', '\([^']*\)')\$/\1 \2/p" "$root_dir/scripts/identity/install-host-tools.ps1" >"$table"
entries=$(wc -l <"$table" | tr -d ' ')
review_entries=$(grep -c ' review/' "$table" || true)
check "install setup: the table has review-context rows" test "$review_entries" -gt 0
# Every table source, at its own repo path (the host scripts as well as the review-context files).
while read -r srcpath dstpath; do
  mkdir -p "$src/$(dirname "$srcpath")"; cp "$root_dir/$srcpath" "$src/$srcpath"
done <"$table"
git -C "$src" -c user.name=t -c user.email=t@t add -A
git -C "$src" -c user.name=t -c user.email=t@t commit -q -m seed
git -C "$src" remote add origin "$(wp "$origin")"
git -C "$src" push -q origin main
head=$(git -C "$src" rev-parse HEAD)
# profile_path: the profile every install writes, a scratch file under $tmp so no case writes a real or fixture-HOME profile;
# the one case for the default path sets it to - and passes none.
profile_path="$tmp/scratch-profile.ps1"
run_install() { rc=0
  if [ "$profile_path" = - ]; then
    pwsh -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/install-host-tools.ps1")" \
      -WowHome "$(wp "$home")" -SourceRepo "$(wp "$src")" "$@" >"$tmp/out" 2>&1 || rc=$?
  else
    pwsh -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/install-host-tools.ps1")" \
      -WowHome "$(wp "$home")" -SourceRepo "$(wp "$src")" -ProfilePath "$(wp "$profile_path")" "$@" >"$tmp/out" 2>&1 || rc=$?
  fi
}
has_cr() { [ "$(tr -cd '\015' <"$1" | wc -c | tr -d ' ')" -gt 0 ]; }
not_cr() { for p in "$@"; do ! has_cr "$p" || return 1; done; }
# A CRLF working tree (autocrlf) that git still reports clean: only a blob export keeps the install LF.
git -C "$src" config core.autocrlf true
for f in $(git -C "$src" ls-files scripts/identity); do rm -f "$src/$f"; done; git -C "$src" checkout -q -- scripts/identity
check "install setup: the source working tree really is CRLF" has_cr "$src/scripts/identity/mint.sh"
reset; rm -rf "$home/bin"
run_install
check "install: exits 0" test "$rc" -eq 0
check "install: broker and mint.sh land in bin" test -f "$home/bin/broker.ps1" -a -f "$home/bin/mint.sh"
check "install: MANIFEST records the commit" grep -q "^commit $head\$" "$home/bin/MANIFEST"
check "install: MANIFEST has one hash per table entry" test "$(grep -c '^[0-9a-f]\{64\}  ' "$home/bin/MANIFEST")" -eq "$entries"
ok_hash=1
while read -r srcpath dstpath; do
  want=$(git -C "$src" cat-file blob "HEAD:$srcpath" | sha256sum | cut -d' ' -f1)
  grep -q "^$want  $dstpath\$" "$home/bin/MANIFEST" || ok_hash=
  [ "$(sha256sum <"$home/bin/$dstpath" | cut -d' ' -f1)" = "$want" ] || ok_hash=
done <"$table"
check "install: every installed file is the committed blob, at its destination path" test -n "$ok_hash"
review_ok=1
while read -r srcpath dstpath; do
  case $dstpath in review/*) [ -f "$home/bin/$dstpath" ] || review_ok= ;; esac
done <"$table"
check "install: every review-context file lands under bin/review" test -n "$review_ok"
check "install: bin/review holds only table entries" test "$(find "$home/bin/review" -type f | wc -l | tr -d ' ')" -eq "$review_entries"
in_bin_with_manifest() { test -f "$home/bin/$1" && grep -qE "^[0-9a-f]{64}  $1\$" "$home/bin/MANIFEST"; }
for f in wow-review review-gate-state.sh token-check.sh gh-identity.sh wow-driver.ps1 wow-launch-common.ps1 wow-lane.ps1; do
  check "install: $f lands in bin with a MANIFEST line" in_bin_with_manifest "$f"
done
check "install: files are LF" not_cr "$home/bin/mint.sh" "$home/bin/wow-admin" "$home/bin/broker.ps1"
check "install: no staging left" test ! -e "$home/bin.new" -a ! -e "$home/bin.old"
check "install: tokens/<owner>/<repo> created for each repo" test -d "$home/tokens/acme/alpha" -a -d "$home/tokens/acme/beta"
check "install: no bare tokens/<repo> directory created" test ! -e "$home/tokens/alpha" -a ! -e "$home/tokens/beta"
# cross-check of broker.json, review-poll.json and tokens/ (#1161): warns only, never changes the exit code
xc_warns() { grep -c 'WARNING: ' "$tmp/out"; }
xc_has() { grep -q -F -e "WARNING: $1" "$tmp/out"; }
reset; echo '{"repos": ["acme/alpha", "acme/gamma"]}' >"$home/review-poll.json"; mkdir -p "$home/tokens/delta"
run_install
check "cross-check: a mismatch still exits 0" test "$rc" -eq 0
check "cross-check: a poll name not in broker.json is named" xc_has "gamma is in review-poll.json but not broker.json: no dev token is minted for it on this host"
check "cross-check: a broker.json name with no poll entry is named" xc_has "beta is in broker.json but not review-poll.json: no automatic reviews for it"
check "cross-check: a tokens directory with no broker.json entry is named" xc_has "tokens/delta is not the owner directory of any broker.json entry"
check "cross-check: exactly three warnings" test "$(xc_warns)" -eq 3
reset; echo '{"repos": ["acme/alpha", "other/beta"]}' >"$home/review-poll.json"
run_install
check "cross-check: matching sets give no warning" test "$(xc_warns)" -eq 0
reset; rm -f "$home/review-poll.json"; mkdir -p "$home/tokens/delta"
run_install
check "cross-check: no poll file gives no poll warning" test "$(grep -c 'review-poll.json' "$tmp/out")" -eq 0
check "cross-check: no poll file still reports the extra tokens directory" xc_has "tokens/delta is not the owner directory of any broker.json entry"
reset; echo 'POLLSECRET not json' >"$home/review-poll.json"
run_install
check "cross-check: a poll file that is not JSON: one warning, exit 0" test "$rc" -eq 0 -a "$(xc_warns)" -eq 1
check "cross-check: a poll file that is not JSON: the file content is not echoed" sh -c "! grep -q POLLSECRET '$tmp/out'"
reset; echo '{"repos": ["acme/alpha", 7, "POLLSECRET/x"]}' >"$home/review-poll.json"
run_install
check "cross-check: a poll file with a non-string entry: one warning, exit 0" test "$rc" -eq 0 -a "$(xc_warns)" -eq 1
check "cross-check: a poll file with a non-string entry: the content is not echoed" sh -c "! grep -q POLLSECRET '$tmp/out'"
reset; echo '{"repos": ["Acme/Alpha"]}' >"$home/broker.json"; echo '{"repos": ["acme/alpha"]}' >"$home/review-poll.json"
run_install
check "cross-check: names compare case-insensitively" test "$rc" -eq 0 -a "$(xc_warns)" -eq 0
reset; echo '{"repos": ["acme/keys", "acme/alpha"]}' >"$home/broker.json"; echo '{"repos": ["acme/keys", "acme/gamma"]}' >"$home/review-poll.json"
run_install
check "cross-check: a repo named keys does not hide other broker.json names" xc_has "alpha is in broker.json but not review-poll.json: no automatic reviews for it"
check "cross-check: a repo named keys does not hide other poll names" xc_has "gamma is in review-poll.json but not broker.json: no dev token is minted for it on this host"
reset; echo '{"repos": ["acme/alpha"]}' >"$home/broker.json"; echo '{"repos": ["acmealpha"]}' >"$home/review-poll.json"
run_install
check "cross-check: an unreadable poll entry: exit 0" test "$rc" -eq 0
check "cross-check: an unreadable poll entry is counted" xc_has "review-poll.json entries this check cannot read as owner/name: 1; they are not compared with broker.json"
check "cross-check: an unreadable poll entry: the broker-only name is still named" xc_has "alpha is in broker.json but not review-poll.json: no automatic reviews for it"
check "cross-check: an unreadable poll entry: exactly two warnings" test "$(xc_warns)" -eq 2
reset; echo '{"repos": ["acme/alpha", "other/beta", "POLLSECRET", "acme/POLLSECRET/x", "acme/POLLSECRET x"]}' >"$home/review-poll.json"
run_install
check "cross-check: mixed poll entries: exit 0" test "$rc" -eq 0
check "cross-check: mixed poll entries: the skipped ones are counted" xc_has "review-poll.json entries this check cannot read as owner/name: 3; they are not compared with broker.json"
check "cross-check: mixed poll entries: exactly one warning" test "$(xc_warns)" -eq 1
check "cross-check: mixed poll entries: the entry text is not echoed" sh -c "! grep -q POLLSECRET '$tmp/out'"
reset; set_repos '"acme/alpha", "beta"'; echo '{"repos": ["acme/alpha"]}' >"$home/review-poll.json"
run_install
check "install: an owner/name entry creates its owner directory" test -d "$home/tokens/acme/alpha"
check "install: a bare entry creates nothing, not even tokens/<name>" test ! -e "$home/tokens/beta" -a ! -e "$home/tokens/acme/beta" -a "$(find "$home/tokens" -mindepth 1 | wc -l | tr -d ' ')" -eq 2
check "install: a bare entry gets one fixed warning naming it" xc_has "broker.json entry beta is a bare name; the broker refuses it, write it as owner/name"
check "install: ...and nothing else is warned about, the exit stays 0" test "$rc" -eq 0 -a "$(xc_warns)" -eq 1
reset; set_repos '"acme/alpha", "a/b/c", "acme/", "acKme/zeta"'; rm -f "$home/review-poll.json"
run_install
check "install: entries failing the per-half rule create nothing" test ! -e "$home/tokens/b" -a ! -e "$home/tokens/a" -a ! -e "$home/tokens/zeta" -a ! -e "$home/tokens/c" -a -d "$home/tokens/acme/alpha"
check "install: ...and the install still exits 0" test "$rc" -eq 0
# a pre-#1608 admin-token in a broker entry's tokens directory is warned about once, with the revoke command, and left in place
reset; set_repos '"acme/alpha", "acme/beta"'; echo '{"repos": ["acme/alpha", "acme/beta"]}' >"$home/review-poll.json"
mkdir -p "$home/tokens/acme/alpha"; printf 'ghs_leftover\n2099-01-01T00:00:00Z\n' >"$home/tokens/acme/alpha/admin-token"
run_install
check "install: a legacy admin-token gets one warning naming its path and the revoke" test "$(tr '\\' '/' <"$tmp/out" | grep -c -F "$(wp "$home")/tokens/acme/alpha/admin-token is a leftover admin token: wow-admin no longer writes there; run: wow-admin acme/alpha --revoke")" -eq 1
check "install: ...and no other warning, the exit stays 0" test "$rc" -eq 0 -a "$(xc_warns)" -eq 1
check "install: ...and the file is left in place" test -f "$home/tokens/acme/alpha/admin-token"
reset; set_repos '"acme/alpha", "acme/beta"'; echo '{"repos": ["acme/alpha", "acme/beta"]}' >"$home/review-poll.json"
run_install
check "install: with no admin-token there is no such warning" test "$(grep -c 'leftover admin token' "$tmp/out")" -eq 0
reset; set_repos '"acme/alpha"'; echo '{"repos": ["acme/alpha"]}' >"$home/review-poll.json"; mkdir -p "$home/tokens/other"
run_install
check "cross-check: a tokens directory that is not an owner half is named" xc_has "tokens/other is not the owner directory of any broker.json entry"
check "cross-check: ...and the owner directory is not" test "$(grep -c 'tokens/acme' "$tmp/out")" -eq 0
reset; rm -f "$home/review-poll.json"
manifest=$(cat "$home/bin/MANIFEST")

echo '# dirty' >>"$src/scripts/identity/mint.sh"
run_install
check "install: an uncommitted change is refused" test "$rc" -ne 0
check "install: ...for that reason" grep -q 'uncommitted changes' "$tmp/out"
check "install: ...and bin is untouched" test "$(cat "$home/bin/MANIFEST")" = "$manifest"
git -C "$src" checkout -q -- scripts/identity/mint.sh

# An uncommitted change in any other source directory is refused too, before anything under $home changes.
for dirty in scripts/loop/inject.py scripts/identity/review/Dockerfile plugins/way-of-working/bin/token-check.sh; do
  echo '# dirty' >>"$src/$dirty"
  run_install
  check "install: an uncommitted change in $dirty is refused" test "$rc" -ne 0
  check "install: ...for that reason ($dirty)" grep -q 'uncommitted changes' "$tmp/out"
  check "install: ...and bin is untouched ($dirty)" test "$(cat "$home/bin/MANIFEST")" = "$manifest" -a ! -e "$home/bin.new"
  git -C "$src" checkout -q -- "$dirty"
done

git -C "$src" -c user.name=t -c user.email=t@t commit -q --allow-empty -m unpushed
run_install
check "install: a HEAD not on origin/main is refused" test "$rc" -ne 0
check "install: ...for that reason" grep -q 'is not on origin/main' "$tmp/out"
check "install: ...and bin is untouched (unmerged)" test "$(cat "$home/bin/MANIFEST")" = "$manifest"
git -C "$src" branch origin/main   # a local branch named like the remote ref must not satisfy the check
run_install
check "install: a local branch named origin/main does not bypass it" test "$rc" -ne 0
check "install: ...still for that reason" grep -q 'is not on origin/main' "$tmp/out"
git -C "$src" branch -q -D origin/main
git -C "$src" reset -q --hard "$head"


rm -rf "$home/bin"
# The -WhatIf run needs the Task Scheduler cmdlets, which pwsh off Windows lacks.
if pwsh -NoProfile -NonInteractive -Command 'if (Get-Command New-ScheduledTaskAction -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }' >/dev/null 2>&1; then
  reg=$(pwsh -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/register-broker-task.ps1")" \
    -WowHome "$(wp "$home")\\" -Sh "$sh_path" -SourceRepo "$(wp "$src")" -TaskName "wow-broker-test-$$" -WhatIf 2>&1) || reg="failed: $reg"
  case "$reg" in
    *'-File "'*'bin\broker.ps1" -WowHome "'*'\home" -Sh'*) ok "register: runs the installed copy, trailing backslash trimmed" ;;
    *) bad "register: command line was $reg" ;;
  esac
  case "$reg" in
    *'conhost.exe --headless "'*'" -NoProfile -NonInteractive -WindowStyle Hidden -File "'*) ok "register: task runs pwsh through conhost --headless" ;;
    *) bad "register: no conhost --headless form in $reg" ;;
  esac
  case "$reg" in *WindowsApps\\Microsoft.PowerShell_*) bad "register: version-pinned Store pwsh path recorded" ;; *) ok "register: no version-pinned Store pwsh path" ;; esac
  check "register: -WhatIf installs nothing" test ! -e "$home/bin"
else
  echo "SKIP - New-ScheduledTaskAction not available; the register -WhatIf case (command line, Store pwsh path, installs nothing) did not run" >&2
fi

# --- an MSYS-form WowHome (#789) -------------------------------------------------------------
# Windows only: Git Bash rewrites a /-leading argument into Windows form when it starts pwsh, so
# MSYS2_ARG_CONV_EXCL='*' keeps the value as typed. bin goes first, as in the install cases above.
case "$(uname -s)" in
  MINGW*|MSYS*)
    reset; rm -rf "$home/bin"; rc=0
    MSYS2_ARG_CONV_EXCL='*' pwsh -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/install-host-tools.ps1")" \
      -WowHome "$(cygpath -u "$home")" -SourceRepo "$(wp "$src")" -ProfilePath "$(wp "$tmp/msys-profile.ps1")" >"$tmp/out" 2>&1 || rc=$?
    check "msys: install refuses an MSYS-form WowHome" test "$rc" -ne 0
    check "msys: ...naming the fix" grep -q 'is in MSYS form; pass -WowHome in Windows form' "$tmp/out"
    check "msys: ...and creates no bin" test ! -e "$home/bin" ;;
  *) echo "SKIP - not Git Bash on Windows; the MSYS-form install case did not run" >&2 ;;
esac

# --- no tool on PATH -------------------------------------------------------------------------
# PATH holds only an empty directory, pwsh is run by the absolute path resolved before that, and no -Sh is
# given: each script's own "not found" message must be reached, not a null .Source lookup.
pwsh_abs=$(command -v pwsh)
emptydir="$tmp/empty"; mkdir "$emptydir"
no_source_err() { ! cat "$tmp/out" "$home/broker.log" 2>/dev/null | grep -q "'Source' cannot be found"; }
broker_says_no_sh() { cat "$tmp/out" "$home/broker.log" 2>/dev/null | grep -q 'no POSIX sh found'; }
reset; rm -rf "$home/bin"; rc=0
PATH="$emptydir" "$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/register-broker-task.ps1")" \
  -WowHome "$(wp "$home")" -SourceRepo "$(wp "$src")" -TaskName "wow-broker-test-nopath-$$" -WhatIf >"$tmp/out" 2>&1 || rc=$?
check "no tool: register exits non-zero" test "$rc" -ne 0
check "no tool: register reports the missing sh" grep -q 'no POSIX sh found: pass -Sh' "$tmp/out"
check "no tool: register has no null .Source error" no_source_err
reset; rc=0
PATH="$emptydir" "$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/broker.ps1")" \
  -WowHome "$(wp "$home")" -ScriptsDir "$(wp "$scripts")" -Once >"$tmp/out" 2>&1 || rc=$?
check "no tool: broker exits 2" test "$rc" -eq 2
check "no tool: broker reports the missing sh" broker_says_no_sh
check "no tool: broker has no null .Source error" no_source_err
check "no tool: broker never calls mint.sh" test "$(calls mint-calls)" -eq 0
reset; rm -rf "$home/bin"; rc=0
PATH="$emptydir" "$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$root_dir/scripts/identity/install-host-tools.ps1")" \
  -WowHome "$(wp "$home")" -SourceRepo "$(wp "$src")" -ProfilePath "$(wp "$tmp/notool-profile.ps1")" >"$tmp/out" 2>&1 || rc=$?
check "no tool: install exits non-zero" test "$rc" -ne 0
check "no tool: install reports the missing git" grep -q 'git not found on PATH' "$tmp/out"
check "no tool: install has no null .Source error" no_source_err
check "no tool: install creates no bin" test ! -e "$home/bin"

# --- task process (#1016) ---------------------------------------------------------------------
tp="$root_dir/scripts/identity/task-process.ps1"
reg_ps="$root_dir/scripts/identity/register-broker-task.ps1"
inst_ps="$root_dir/scripts/identity/install-host-tools.ps1"
tpcase() { # tpcase <label> <expected> <powershell expression using the dot-sourced functions>
  l=$1 want=$2 expr=$3
  got=$(pwsh -NoProfile -NonInteractive -Command ". '$(wp "$tp")'; $expr" 2>&1) || got="failed: $got"
  if [ "$got" = "$want" ]; then ok "task process: $l"; else bad "task process: $l (got: $got)"; fi
}
span='-File "C:\Users\a\.config\glunk-identity\bin\broker.ps1"'
tail_args='-WowHome "C:\Users\a\.config\glunk-identity" -Sh "C:\Program Files\Git\bin\sh.exe"'
con_args="--headless \"C:\\pwsh\\pwsh.exe\" -NoProfile -NonInteractive -WindowStyle Hidden $span $tail_args"
tpcase "span from the conhost action" "$span" "Get-FileArgSpan '$con_args'"
tpcase "no span in the poll task's -Command action" "NULL" "if (\$null -eq (Get-FileArgSpan '-NoProfile -Command \"& x\"')) { 'NULL' } else { 'span' }"
tpcase "no span in an empty argument string" "NULL" "if (\$null -eq (Get-FileArgSpan '')) { 'NULL' } else { 'span' }"
pwsh_line="\"C:\\pwsh\\pwsh.exe\" -NoProfile -NonInteractive -WindowStyle Hidden $span $tail_args"
tpcase "pwsh command line matches" "True" "Test-FileArgMatch '$pwsh_line' '$span'"
tpcase "conhost command line matches" "True" "Test-FileArgMatch '$con_args' '$span'"
tpcase "another letter case matches" "True" "Test-FileArgMatch ('$pwsh_line').ToUpper() '$span'"
tpcase "another home does not match" "False" "Test-FileArgMatch ('$pwsh_line').Replace('\\a\\', '\\b\\') '$span'"
tpcase "a bin.old path does not match" "False" "Test-FileArgMatch ('$pwsh_line').Replace('\\bin\\', '\\bin.old\\') '$span'"
tpcase "a longer path does not match" "False" "Test-FileArgMatch ('$pwsh_line').Replace('broker.ps1', 'broker.ps1x') '$span'"
tpcase "an empty command line does not match" "False" "Test-FileArgMatch '' '$span'"
tpcase "an empty span does not match" "False" "Test-FileArgMatch '$pwsh_line' ''"
# The Store app-alias pwsh.exe reports a rebuilt command line, quoting only paths that hold a space (seen on the host, #1016).
alias_line='C:\Users\a\AppData\Local\Microsoft\WindowsApps\pwsh.exe -NoProfile -NonInteractive -WindowStyle Hidden -File C:\Users\a\.config\glunk-identity\bin\broker.ps1 -WowHome C:\Users\a\.config\glunk-identity -Sh "C:\Program Files\Git\bin\sh.exe"'
tpcase "the alias pwsh's unquoted -File path matches" "True" "Test-FileArgMatch '$alias_line' '$span'"
tpcase "an unquoted path at the end of the line matches" "True" "Test-FileArgMatch 'pwsh -File C:\Users\a\.config\glunk-identity\bin\broker.ps1' '$span'"
tpcase "an unquoted longer path does not match" "False" "Test-FileArgMatch ('$alias_line').Replace('broker.ps1', 'broker.ps1x') '$span'"
tpcase "an unquoted bin.old path does not match" "False" "Test-FileArgMatch ('$alias_line').Replace('\\bin\\', '\\bin.old\\') '$span'"
tpcase "an unquoted path in a -WowHome argument does not match" "False" "Test-FileArgMatch 'pwsh -File C:\\x.ps1 -WowHome C:\\Users\\a\\.config\\glunk-identity\\bin\\broker.ps1' '$span'"
tpcase "a path opened by a quote and not closed does not match" "False" "Test-FileArgMatch ('$alias_line').Replace('-File C:', '-File \"C:') '$span'"
tpcase "-File glued to a preceding character does not match" "False" "Test-FileArgMatch ('$alias_line').Replace(' -File ', ' x-File ') '$span'"
tpcase "a path with its dot replaced does not match" "False" "Test-FileArgMatch ('$alias_line').Replace('broker.ps1', 'brokerXps1') '$span'"
sp_span='-File "C:\Users\a b\.config\glunk-identity\bin\broker.ps1"'
tpcase "a quoted path with a space matches" "True" "Test-FileArgMatch 'C:\\p\\pwsh.exe -NoProfile $sp_span -WowHome x' '$sp_span'"
# Stop-FileArgProcess under strict mode with the process cmdlets stubbed (a fake process table of the matching ids in $env:TP_MATCH,
# ids in $env:TP_IMMORTAL surviving a kill, ids in $env:TP_QUOTED reporting the quoted command-line form).
sfa_run() { # sfa_run <label> <expected> <matching ids, space separated> <ids that survive a kill, space separated> [<matching ids with a quoted command line>]
  l=$1 want=$2 quoted=${5:-}
  cat >"$tmp/sfa.ps1" <<'PS1'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $env:TP_FILE
$script:procs = [System.Collections.ArrayList]@($env:TP_MATCH -split ' ' | Where-Object { $_ } | ForEach-Object { [int]$_ })
$script:immortal = @($env:TP_IMMORTAL -split ' ' | Where-Object { $_ } | ForEach-Object { [int]$_ })
$script:quoted = @($env:TP_QUOTED -split ' ' | Where-Object { $_ } | ForEach-Object { [int]$_ })
$script:killed = [System.Collections.ArrayList]@()
function Get-CimInstance { param($ClassName)
  $script:procs | ForEach-Object { [pscustomobject]@{ ProcessId = $_; CommandLine = $(if ($script:quoted -contains $_) { '"p" -File "C:\h\bin\broker.ps1" -x' } else { 'p -File C:\h\bin\broker.ps1 -x' }) } }
  [pscustomobject]@{ ProcessId = $PID; CommandLine = '-File "C:\h\bin\broker.ps1"' }
  [pscustomobject]@{ ProcessId = 1; CommandLine = 'unrelated' } }
function Stop-Process { param($Id, [switch]$Force)
  [void]$script:killed.Add($Id)
  if ($script:immortal -notcontains $Id) { $script:procs.Remove($Id) } }
try { Stop-FileArgProcess '-File "C:\h\bin\broker.ps1"' 1; "ok killed=$($script:killed -join ',')" } catch { "threw: $($_.Exception.Message)" }
PS1
  got=$(TP_FILE="$(wp "$tp")" TP_MATCH="$3" TP_IMMORTAL="$4" TP_QUOTED="$quoted" pwsh -NoProfile -NonInteractive -File "$(wp "$tmp/sfa.ps1")" 2>&1) || got="failed: $got"
  if [ "$got" = "$want" ]; then ok "task process: $l"; else bad "task process: $l (got: $got)"; fi
}
sfa_run "Stop-FileArgProcess with no match returns quietly" "ok killed=" "" ""
sfa_run "Stop-FileArgProcess ends one match, never itself" "ok killed=11" "11" ""
sfa_run "Stop-FileArgProcess ends two matches" "ok killed=11,12" "11 12" ""
sfa_run "Stop-FileArgProcess throws naming a survivor" "threw: still running after 1 s: process id 12" "11 12" "12"
sfa_run "Stop-FileArgProcess ends a bare and a quoted match" "ok killed=11,12" "11 12" "" "12"
# Write-NoSpanWarning under strict mode; the warning stream is merged into the output so the assertion reads the text (#1029).
nsw() { # nsw <label> <expected> <arguments expression>
  tpcase "$1" "$2" "Set-StrictMode -Version Latest; Write-NoSpanWarning 'wow-t' $3 3>&1 | ForEach-Object { \"[\$_]\" }"
}
nsw "no-span warning: an unquoted broker -File path warns, naming the task" "[task wow-t has no quoted -File path in its action, so the broker pwsh it started may still be running; end it by hand]" "'--headless p -File C:\\h\\bin\\broker.ps1 -x'"
nsw "no-span warning: the same in upper case warns once" "[task wow-t has no quoted -File path in its action, so the broker pwsh it started may still be running; end it by hand]" "'--HEADLESS P -FILE C:\\H\\BIN\\BROKER.PS1 -X'"
nsw "no-span warning: a quoted broker span is silent" "" "'$con_args'"
nsw "no-span warning: the poll task's -Command action is silent" "" "'-NoProfile -Command \"& x\"'"
nsw "no-span warning: an empty string is silent" "" "''"
nsw "no-span warning: \$null is silent" "" "\$null"
tpcase "an empty -File \"\" has no span" "NULL" "if (\$null -eq (Get-FileArgSpan '-File \"\" x')) { 'NULL' } else { 'span' }"
check "register: the repeating trigger is one minute" grep -q 'RepetitionInterval (New-TimeSpan -Minutes 1)' "$reg_ps"
check "register: no RestartCount" test "$(grep -c 'RestartCount' "$reg_ps")" -eq 0
check "register: dot-sources task-process.ps1 and calls Stop-FileArgProcess" sh -c 'grep -q "task-process.ps1" "$1" && grep -q "Stop-FileArgProcess" "$1"' sh "$reg_ps"
check "install: dot-sources task-process.ps1 and calls Stop-FileArgProcess" sh -c 'grep -q "task-process.ps1" "$1" && grep -q "Stop-FileArgProcess" "$1"' sh "$inst_ps"
check "register: calls Write-NoSpanWarning" grep -q 'Write-NoSpanWarning' "$reg_ps"
check "install: calls Write-NoSpanWarning" grep -q 'Write-NoSpanWarning' "$inst_ps"
# The install's task handling, run for real against stubbed Task Scheduler and process cmdlets (#1028): caller-scope functions shadow
# the cmdlets inside the script, and supply them where pwsh lacks them. SWAP_ENABLED, SWAP_HASHFAIL, SWAP_DISABLEFAIL, SWAP_UNQUOTED and SWAP_NOTASK set per case
# what the stubs report and throw; every stub that matters appends its cmdlet name to $SWAP_LOG, and no real task or process is touched.
swap_log="$tmp/swap.log"
cat >"$tmp/swap-stubs.ps1" <<'PS1'
$global:procs = [System.Collections.ArrayList]@(11)
function Get-ScheduledTask { param($TaskName, $ErrorAction)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Get-ScheduledTask' -WhatIf:$false
  if ($env:SWAP_NOTASK -eq '1') { return }
  $acts = switch ($env:SWAP_ACTSHAPE) {
    'none' { @() }
    'noargs' { @([pscustomobject]@{ Execute = 'x' }) }
    default { @([pscustomobject]@{ Arguments = $(if ($env:SWAP_UNQUOTED -eq '1') { '--headless p -File C:\h\bin\broker.ps1 -x' } else { '--headless p -File "C:\h\bin\broker.ps1" -x' }) }) } }
  [pscustomobject]@{ Settings = [pscustomobject]@{ Enabled = ($env:SWAP_ENABLED -eq '1') }; Actions = $acts } }
function Disable-ScheduledTask { param($TaskName, $ErrorAction)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Disable-ScheduledTask' -WhatIf:$false
  if ($env:SWAP_DISABLEFAIL -eq '1') { throw 'DISABLEBOOM' } }
function Stop-ScheduledTask { param($TaskName, $ErrorAction)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Stop-ScheduledTask' -WhatIf:$false }
function Enable-ScheduledTask { param($TaskName, $ErrorAction)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Enable-ScheduledTask' -WhatIf:$false }
function Get-CimInstance { param($ClassName)
  $global:procs | ForEach-Object { [pscustomobject]@{ ProcessId = $_; CommandLine = 'p -File C:\h\bin\broker.ps1 -x' } }
  [pscustomobject]@{ ProcessId = 1; CommandLine = 'unrelated' } }
function Stop-Process { param($Id, [switch]$Force, $ErrorAction)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Stop-Process' -WhatIf:$false
  $global:procs.Remove($Id) }
if ($env:SWAP_HASHFAIL -eq '1') { function Get-FileHash { param($LiteralPath, $Algorithm) throw 'HASHBOOM' } }
PS1
swap_run() { # swap_run <task enabled 1|0> <Get-FileHash throws 1|0> <Disable-ScheduledTask throws 1|0> [<action -File path unquoted 1|0> [<no task found 1|0> [<action shape: none = no actions, noargs = an action without Arguments>]]]]; leaves the exit code in $rc, the output in $tmp/out, the call log in $swap_log
  reset; rm -rf "$home/bin" "$home/bin.new" "$home/bin.old"; rm -f "$swap_log"; : >"$swap_log"; rc=0
  SWAP_LOG="$(wp "$swap_log")" SWAP_ENABLED=$1 SWAP_HASHFAIL=$2 SWAP_DISABLEFAIL=$3 SWAP_UNQUOTED=${4:-0} SWAP_NOTASK=${5:-0} SWAP_ACTSHAPE=${6:-} \
    pwsh -NoProfile -NonInteractive -Command ". '$(wp "$tmp/swap-stubs.ps1")'; & '$(wp "$inst_ps")' -WowHome '$(wp "$home")' -SourceRepo '$(wp "$src")' -ProfilePath '$(wp "$profile_path")' -StopTask 'wow-swap-test-$$'" >"$tmp/out" 2>&1 || rc=$?
}
swap_log_is() { # swap_log_is <cmdlet>... : the call log holds exactly these lines, in this order (Add-Content ends a line with CRLF on Windows, so CR is stripped)
  printf '%s\n' "$@" >"$tmp/swap.want"; [ "$#" -gt 0 ] || : >"$tmp/swap.want"
  tr -d '\r' <"$swap_log" | cmp -s "$tmp/swap.want" - || { echo "swap call log was: $(tr -d '\r' <"$swap_log" | tr '\n' ' ')" >&2; return 1; }
}
swap_run 1 0 0
check "install task: an enabled task is disabled, stopped, its process ended and re-enabled, in that order" swap_log_is Get-ScheduledTask Disable-ScheduledTask Stop-ScheduledTask Stop-Process Enable-ScheduledTask
check "install task: an enabled task, success exits 0" test "$rc" -eq 0
check "install task: an enabled task, success writes bin/MANIFEST" test -f "$home/bin/MANIFEST"
swap_run 0 0 0
check "install task: a task disabled before is never re-enabled" swap_log_is Get-ScheduledTask Disable-ScheduledTask Stop-ScheduledTask Stop-Process
check "install task: a task disabled before, success exits 0" test "$rc" -eq 0
swap_run 1 1 0
check "install task: an enabled task is re-enabled after a throw past the disable" swap_log_is Get-ScheduledTask Disable-ScheduledTask Stop-ScheduledTask Stop-Process Enable-ScheduledTask
check "install task: an enabled task, a throw past the disable exits non-zero" test "$rc" -ne 0
check "install task: an enabled task, a throw past the disable reports the error" grep -q 'HASHBOOM' "$tmp/out"
check "install task: an enabled task, a throw past the disable creates no bin" test ! -e "$home/bin"
swap_run 0 1 0
check "install task: a task disabled before is not re-enabled after a throw" swap_log_is Get-ScheduledTask Disable-ScheduledTask Stop-ScheduledTask Stop-Process
check "install task: a task disabled before, a throw past the disable exits non-zero" test "$rc" -ne 0
swap_run 1 0 1
check "install task: a throw from the disable itself stops before the stop and the re-enable" swap_log_is Get-ScheduledTask Disable-ScheduledTask
check "install task: a throw from the disable itself exits non-zero" test "$rc" -ne 0
check "install task: a throw from the disable itself creates no bin" test ! -e "$home/bin"
swap_run 1 0 0 1 0
check "install task: an unquoted action is disabled, stopped and re-enabled in that order, no process ended" swap_log_is Get-ScheduledTask Disable-ScheduledTask Stop-ScheduledTask Enable-ScheduledTask
check "install task: an unquoted action prints the warning naming the task" grep -q "WARNING: task wow-swap-test-$$ has no quoted -File path" "$tmp/out"
check "install task: an unquoted action exits 0" test "$rc" -eq 0
check "install task: an unquoted action writes bin/MANIFEST" test -f "$home/bin/MANIFEST"
swap_run 1 0 0 0 1
check "install task: a missing task is looked up and stopped only" swap_log_is Get-ScheduledTask Stop-ScheduledTask
check "install task: a missing task prints no warning naming the task" test "$(grep -c "wow-swap-test-$$" "$tmp/out")" -eq 0
check "install task: a missing task exits 0" test "$rc" -eq 0
check "install task: a missing task writes bin/MANIFEST" test -f "$home/bin/MANIFEST"
# A task with no actions, or whose first action has no Arguments property (a COM-handler action), is read defensively under StrictMode: the
# install completes, ends no process and prints neither a StrictMode error nor the no-span warning.
for shape in none noargs; do
  swap_run 1 0 0 0 0 "$shape"
  check "install task [$shape]: the lookup, the disable, the stop and the enable only, no process ended" swap_log_is Get-ScheduledTask Disable-ScheduledTask Stop-ScheduledTask Enable-ScheduledTask
  check "install task [$shape]: exits 0" test "$rc" -eq 0
  check "install task [$shape]: writes bin/MANIFEST" test -f "$home/bin/MANIFEST"
  check "install task [$shape]: no StrictMode error text" test "$(grep -c -e 'cannot be found on this object' -e 'outside the bounds' "$tmp/out")" -eq 0
  check "install task [$shape]: no warning naming the task" test "$(grep -c "wow-swap-test-$$" "$tmp/out")" -eq 0
done
# register-broker-task.ps1 -Unregister against the same two task shapes, stubbed Task Scheduler and process cmdlets (the path returns before any other lookup).
cat >"$tmp/unreg-stubs.ps1" <<'PS1'
function Get-ScheduledTask { param($TaskName, $ErrorAction)
  $acts = if ($env:UNREG_SHAPE -eq 'none') { @() } else { @([pscustomobject]@{ Execute = 'x' }) }
  [pscustomobject]@{ Actions = $acts } }
function Stop-ScheduledTask { param($TaskName, $ErrorAction)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Stop-ScheduledTask' -WhatIf:$false }
function Unregister-ScheduledTask { param($TaskName, $Confirm)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Unregister-ScheduledTask' -WhatIf:$false }
function Get-CimInstance { param($ClassName)
  [pscustomobject]@{ ProcessId = 11; CommandLine = 'p -File C:\h\bin\broker.ps1 -x' } }
function Stop-Process { param($Id, [switch]$Force, $ErrorAction)
  Add-Content -LiteralPath $env:SWAP_LOG -Value 'Stop-Process' -WhatIf:$false }
PS1
for shape in none noargs; do
  rm -f "$swap_log"; : >"$swap_log"; rc=0
  SWAP_LOG="$(wp "$swap_log")" UNREG_SHAPE=$shape \
    pwsh -NoProfile -NonInteractive -Command ". '$(wp "$tmp/unreg-stubs.ps1")'; & '$(wp "$reg_ps")' -Unregister -TaskName 'wow-unreg-test-$$'" >"$tmp/out" 2>&1 || rc=$?
  check "register -Unregister [$shape]: exits 0" test "$rc" -eq 0
  check "register -Unregister [$shape]: the stop and the unregister only, no process ended" swap_log_is Stop-ScheduledTask Unregister-ScheduledTask
  check "register -Unregister [$shape]: no StrictMode error text" test "$(grep -c -e 'cannot be found on this object' -e 'outside the bounds' "$tmp/out")" -eq 0
  check "register -Unregister [$shape]: no warning naming the task" test "$(grep -c "wow-unreg-test-$$" "$tmp/out")" -eq 0
done
# Disable-, Enable-, Start- and Stop-ScheduledTask take no -Confirm or -WhatIf (they do not support ShouldProcess); passing one fails the
# install on the host. Read through the parser, so a continuation, an abbreviation, a splat or a module-qualified call counts and a comment does not.
cat >"$tmp/noconfirm.ps1" <<'PS1'
# A file it cannot read or parse, or no file at all, is exit 2: ParseFile reports those as parse errors, never a throw.
if (-not $args) { [Console]::Error.WriteLine('no files given'); exit 2 }
$bad = foreach ($p in $args) {
  $errs = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errs)
  if ($errs) { [Console]::Error.WriteLine("${p}: $($errs[0].Message)"); exit 2 }
  $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -match '(^|\\)((Dis|En)able|Start|Stop)-ScheduledTask$' }, $true) |
    Where-Object { $_.CommandElements | Where-Object {
      ($_ -is [System.Management.Automation.Language.CommandParameterAst] -and
        ('confirm'.StartsWith($_.ParameterName, 'OrdinalIgnoreCase') -or 'whatif'.StartsWith($_.ParameterName, 'OrdinalIgnoreCase') -or $_.ParameterName -in 'cf', 'wi')) -or
      ($_ -is [System.Management.Automation.Language.VariableExpressionAst] -and $_.Splatted) } } |
    ForEach-Object { '{0}:{1}' -f $p, $_.Extent.StartLineNumber }
}
if ($bad) { $bad; exit 1 }
PS1
noconfirm() { pwsh -NoProfile -NonInteractive -File "$(wp "$tmp/noconfirm.ps1")" "$@"; }
noconfirm_fails() { # fails with a file:line finding, not just any non-zero exit
  if out=$(noconfirm "$@"); then return 1; fi
  case $out in *.ps1:[0-9]*) ;; *) return 1 ;; esac
}
noconfirm_identity() { # every scripts/identity/*.ps1, as native paths
  set --; for f in "$root_dir"/scripts/identity/*.ps1; do set -- "$@" "$(wp "$f")"; done
  noconfirm "$@"
}
printf '%s\n' '# Disable-ScheduledTask takes no -Confirm' 'Disable-ScheduledTask -TaskName x' >"$tmp/nc-ok.ps1"
printf '%s\n' 'Enable-ScheduledTask -TaskName x `' '  -Confirm:$false' >"$tmp/nc-cont.ps1"
printf '%s\n' '$a = @{ Confirm = $false }' 'Disable-ScheduledTask -TaskName x @a' >"$tmp/nc-splat.ps1"
printf '%s\n' 'Disable-ScheduledTask -TaskName x -wi' >"$tmp/nc-abbr.ps1"
printf '%s\n' 'ScheduledTasks\Disable-ScheduledTask -TaskName x -Confirm:$false' >"$tmp/nc-mq-bad.ps1"
printf '%s\n' 'ScheduledTasks\Enable-ScheduledTask -TaskName x' >"$tmp/nc-mq-ok.ps1"
printf '%s\n' 'Stop-ScheduledTask -TaskName x -Confirm:$false' >"$tmp/nc-stop-bad.ps1"
printf '%s\n' 'Start-ScheduledTask -TaskName x -wh' >"$tmp/nc-start-abbr.ps1"
printf '%s\n' 'ScheduledTasks\Stop-ScheduledTask -TaskName x -Confirm:$false' >"$tmp/nc-mq-stop-bad.ps1"
printf '%s\n' 'Start-ScheduledTask -TaskName x' 'Stop-ScheduledTask -TaskName x -ErrorAction SilentlyContinue' >"$tmp/nc-ss-ok.ps1"
printf '%s\n' 'Unregister-ScheduledTask -TaskName x -Confirm:$false' >"$tmp/nc-unreg-ok.ps1"
check "no-confirm check: a comment and a plain call pass" noconfirm "$(wp "$tmp/nc-ok.ps1")"
check "no-confirm check: a continued -Confirm fails" noconfirm_fails "$(wp "$tmp/nc-cont.ps1")"
check "no-confirm check: a splat fails" noconfirm_fails "$(wp "$tmp/nc-splat.ps1")"
check "no-confirm check: an abbreviated -WhatIf fails" noconfirm_fails "$(wp "$tmp/nc-abbr.ps1")"
check "no-confirm check: a module-qualified -Confirm fails" noconfirm_fails "$(wp "$tmp/nc-mq-bad.ps1")"
check "no-confirm check: a module-qualified plain call passes" noconfirm "$(wp "$tmp/nc-mq-ok.ps1")"
check "no-confirm check: a Stop-ScheduledTask -Confirm fails" noconfirm_fails "$(wp "$tmp/nc-stop-bad.ps1")"
check "no-confirm check: a Start-ScheduledTask abbreviated -WhatIf fails" noconfirm_fails "$(wp "$tmp/nc-start-abbr.ps1")"
check "no-confirm check: a module-qualified Stop-ScheduledTask -Confirm fails" noconfirm_fails "$(wp "$tmp/nc-mq-stop-bad.ps1")"
check "no-confirm check: plain Start- and Stop-ScheduledTask calls pass" noconfirm "$(wp "$tmp/nc-ss-ok.ps1")"
check "no-confirm check: Unregister-ScheduledTask -Confirm passes (outside the guard)" noconfirm "$(wp "$tmp/nc-unreg-ok.ps1")"
check "no-confirm check: an unreadable path fails" sh -c '! "$@" 2>/dev/null' sh pwsh -NoProfile -NonInteractive -File "$(wp "$tmp/noconfirm.ps1")" "$(wp "$tmp/nc-missing.ps1")"
check "no-confirm check: no file fails" sh -c '! "$@" 2>/dev/null' sh pwsh -NoProfile -NonInteractive -File "$(wp "$tmp/noconfirm.ps1")"
check "identity scripts: no -Confirm or -WhatIf on Disable-, Enable-, Start- or Stop-ScheduledTask" noconfirm_identity

# --- other-home guard (#1594) -----------------------------------------------------------------
# A run that passes the guard ends at the conhost lookup, where [Environment]::SystemDirectory is empty off Windows
# (the error text "Cannot bind argument to parameter 'Path'"); a refusal ends before it.
check "register: reads the existing task before it calls the installer" test \
  "$(grep -n -F "Get-ScheduledTask -TaskName \$TaskName -TaskPath '\\'" "$reg_ps" | head -1 | cut -d: -f1)" -lt \
  "$(grep -n -F "Join-Path \$PSScriptRoot 'install-host-tools.ps1'" "$reg_ps" | head -1 | cut -d: -f1)"
# guard_verdict <system directory read> <uname -s> <WOW_TESTS_REQUIRE_TOOLS>: run when the read is empty; otherwise fail when the
# variable is exactly 1 and the host is not Windows (a real pwsh reads it empty there), else skip.
guard_verdict() {
  if [ -z "$1" ]; then echo run; return 0; fi
  case "$2" in MINGW* | MSYS* | CYGWIN*) echo skip; return 0 ;; esac
  if [ "$3" = 1 ]; then echo fail; else echo skip; fi
}
check "guard verdict: a non-empty read on Linux with the variable 1 fails" test "$(guard_verdict x Linux 1)" = fail
check "guard verdict: a non-empty read on Linux with the variable unset skips" test "$(guard_verdict x Linux '')" = skip
check "guard verdict: a non-empty read on Linux with the variable 0 skips" test "$(guard_verdict x Linux 0)" = skip
check "guard verdict: a non-empty read on MINGW with the variable 1 skips" test "$(guard_verdict x MINGW64_NT-10.0 1)" = skip
check "guard verdict: an empty read runs whatever the other two are" test "$(guard_verdict '' Linux 1)$(guard_verdict '' MINGW64_NT-10.0 '')$(guard_verdict '' Linux 0)" = runrunrun
guard_read=$(pwsh -NoProfile -NonInteractive -Command '[Environment]::SystemDirectory' </dev/null 2>/dev/null)
guard_do=$(guard_verdict "$guard_read" "$(uname -s)" "${WOW_TESTS_REQUIRE_TOOLS:-}")
if [ "$guard_do" = fail ]; then
  bad "guard: [Environment]::SystemDirectory is set off Windows; register-broker-task.ps1 guard cases would not run"
elif [ "$guard_do" = skip ]; then
  echo "SKIP - [Environment]::SystemDirectory is set; register-broker-task.ps1 guard cases not run" >&2
else
  esc=$(printf '\033')
  has() { grep -q -F -- "$2" "$1"; }
  nothas() { ! grep -q -F -- "$2" "$1"; }
  lines() { if [ -f "$1" ]; then wc -l <"$1" | tr -d ' '; else echo 0; fi; }
  ghome="$tmp/guard-home"
  mkdir "$ghome"
  gcalls="$tmp/guard.calls"
  gt() { # gt <out> <stub mode: none|home|nohome|noactions|noargs> <stub home> [script args]
    o=$1; sm=$2; sh_=$3; shift 3
    : >"$gcalls"
    grc=0
    STUB_MODE=$sm STUB_HOME=$sh_ STUB_CALLS=$gcalls G_REG=$reg_ps G_HOME=$ghome \
      pwsh -NoProfile -NonInteractive -Command '
        function Get-ScheduledTask {
          param($TaskName, $TaskPath, $ErrorAction)
          Add-Content -LiteralPath $env:STUB_CALLS -Value "$TaskName $TaskPath" -WhatIf:$false
          switch ($env:STUB_MODE) {
            "none" { return }
            "noactions" { return [pscustomobject]@{ Actions = @() } }
            "noargs" { return [pscustomobject]@{ Actions = @([pscustomobject]@{ Execute = "x" }) } }
            "nohome" { $a = "--headless pwsh -NoProfile -File x.ps1 -Sh y" }
            default { $a = "--headless pwsh -NoProfile -NonInteractive -WindowStyle Hidden -File `"b.ps1`" -WowHome `"$($env:STUB_HOME)`" -Sh `"s`"" }
          }
          [pscustomobject]@{ Actions = @([pscustomobject]@{ Arguments = $a }) }
        }
        & $env:G_REG -TaskName guard-test -WhatIf -WowHome $env:G_HOME -Sh /bin/sh @args' "$@" >"$o" 2>&1 </dev/null || grc=$?
    sed "s/$esc\\[[0-9;]*[A-Za-z]//g" "$o" | tr '\n' ' ' | sed 's/ | / /g; s/  */ /g' >"$o.plain"
  }
  g_passes() { # g_passes <label> <out>
    check "$1: stub called once" test "$(lines "$gcalls")" -eq 1
    check "$1: no refusal" nothas "$2.plain" "Pass -ReplaceOtherHome"
    check "$1: runs on to the conhost lookup" has "$2.plain" "Cannot bind argument to parameter 'Path'"
  }
  g_refuses() { # g_refuses <label> <out>
    check "$1: stub called once" test "$(lines "$gcalls")" -eq 1
    check "$1: names -ReplaceOtherHome" has "$2.plain" "Pass -ReplaceOtherHome"
    check "$1: names the requested home" has "$2.plain" "this run would register home $ghome"
    check "$1: stops before the conhost lookup" nothas "$2.plain" "Cannot bind argument to parameter 'Path'"
    check "$1: no StrictMode property error" nothas "$2.plain" "cannot be found on this object"
    check "$1: non-zero exit" test "$grc" -ne 0
  }
  gup=$(printf '%s' "$ghome" | tr 'a-z/' 'A-Z\\')

  gt "$tmp/g.none" none ""
  g_passes "guard, no existing task" "$tmp/g.none"
  gt "$tmp/g.same" home "$ghome"
  g_passes "guard, same home" "$tmp/g.same"
  gt "$tmp/g.case" home "$gup"
  g_passes "guard, same home in other case with backslashes" "$tmp/g.case"
  gt "$tmp/g.diff" home "/other/home"
  g_refuses "guard, different home" "$tmp/g.diff"
  check "guard, different home: names the existing home" has "$tmp/g.diff.plain" "registered with home /other/home"
  gt "$tmp/g.repl" home "/other/home" -ReplaceOtherHome
  g_passes "guard, different home with -ReplaceOtherHome" "$tmp/g.repl"
  gt "$tmp/g.nohome" nohome ""
  g_refuses "guard, action with no -WowHome" "$tmp/g.nohome"
  check "guard, action with no -WowHome: says so" has "$tmp/g.nohome.plain" "no -WowHome the script can read"
  gt "$tmp/g.noact" noactions ""
  g_refuses "guard, no actions" "$tmp/g.noact"
  check "guard, no actions: says so" has "$tmp/g.noact.plain" "no -WowHome the script can read"
  gt "$tmp/g.noargs" noargs ""
  g_refuses "guard, action with no Arguments property" "$tmp/g.noargs"
  check "guard, action with no Arguments property: says so" has "$tmp/g.noargs.plain" "no -WowHome the script can read"
fi

# --- owner/name entries (#1276, #1340) ---------------------------------------------------------
staged() { find "$home/staging" -type f 2>/dev/null | wc -l | tr -d ' '; }
reset; set_repos '"acme/alpha"'
run_broker
check "owner/name: exits 0" test "$rc" -eq 0
check "owner/name: one mint" test "$(calls mint-calls)" -eq 1
check "owner/name: --repos carries the bare name" grep -qx 'alpha' "$stubdir/mint-argv"
check "owner/name: no owner/ in the mint argv" sh -c "! grep -q 'acme' '$stubdir/mint-argv'"
check "owner/name: owner-qualified layout written" test "$(tokfile acme/alpha)" = "$(expect_fresh)"
check "owner/name: nothing written under tokens/<repo>" test ! -e "$home/tokens/alpha"
check "owner/name: tokens/ holds only the owner directory" test "$(ls -A "$home/tokens")" = acme
check "owner/name: no staged file left" test "$(staged)" -eq 0
check "owner/name: tokens/<owner> holds no token itself" test ! -e "$home/tokens/acme/dev-token"
for f in "$tmp/out" "$home/broker.log"; do
  if grep -q "$fresh" "$f"; then bad "owner/name: token text in $(basename "$f")"; else ok "owner/name: no token text in $(basename "$f")"; fi
done

reset; set_repos '"acme/alpha"'
write_token acme/alpha "$old" "$(stamp '+10 minutes')"
run_broker
check "owner/name: an expiring owner copy triggers a mint" test "$(calls mint-calls)" -eq 1 -a "$(tokfile acme/alpha)" = "$(expect_fresh)"
reset; set_repos '"acme/alpha"'
write_token acme/alpha "$old" "$soon"
run_broker
check "owner/name: a current owner copy: no mint" test "$(calls mint-calls)" -eq 0
# an old-layout file is never read: stale, expired or missing, it triggers no mint and is left alone
reset; set_repos '"acme/alpha"'
write_token acme/alpha "$old" "$soon"; mkdir -p "$home/tokens/alpha"; past=$(stamp '-5 minutes'); printf '%s\n%s\n' "$old" "$past" >"$home/tokens/alpha/dev-token"
run_broker
check "owner/name: a stale old-layout file alone triggers no mint" test "$(calls mint-calls)" -eq 0 -a "$rc" -eq 0
check "owner/name: ...and is left as it was" test "$(cat "$home/tokens/alpha/dev-token")" = "$old
$past"
reset; set_repos '"acme/alpha"'
write_token acme/alpha "$old" "$(stamp '+10 minutes')"; mkdir -p "$home/tokens/alpha"
run_broker
check "owner/name: a mint writes no old-layout file" test "$(calls mint-calls)" -eq 1 -a ! -e "$home/tokens/alpha/dev-token"

reset; set_repos '"acme/alpha", "acme/beta"'
mkdir -p "$home/tokens/acme/alpha/dev-token"   # unpublishable owner copy
run_broker
check "owner/name: a blocked publish exits 1" test "$rc" -eq 1
check "owner/name: ...and is logged" grep -q 'dev acme/alpha' "$home/broker.log"
check "owner/name: ...no staged file is left" test "$(staged)" -eq 0
check "owner/name: ...the other entry is still minted" test "$(tokfile acme/beta)" = "$(expect_fresh)"

reset; set_repos '"alpha"'
run_broker
check "bare: a bare entry exits 2" test "$rc" -eq 2
check "bare: ...before any mint" test "$(calls mint-calls)" -eq 0
check "bare: ...with the reason" grep -q 'bare name, which is no longer accepted' "$tmp/out"
check "bare: ...and nothing written under tokens/" test ! -e "$home/tokens"
reset; set_repos '"acme/alpha", "beta"'
run_broker
check "bare: a bare entry beside an owner/name entry mints for neither" test "$rc" -eq 2 -a "$(calls mint-calls)" -eq 0

bad_shape() { # bad_shape <broker.json repos list> <label>
  reset; set_repos "$1"; run_broker
  check "owner/name config: $2 exits 2" test "$rc" -eq 2
  check "owner/name config: $2 mints nothing" test "$(calls mint-calls)" -eq 0
}
bad_shape '"a/b/c"' 'three parts'
bad_shape '"/alpha"' 'empty owner'
bad_shape '"acme/"' 'empty name'
bad_shape '".acme/alpha"' 'owner starting with a dot'
bad_shape '"-acme/alpha"' 'owner starting with a hyphen'
bad_shape '"acme/.alpha"' 'name starting with a dot'
bad_shape '"acKme/alpha"' 'owner with U+212A'
bad_shape '"acme/alİpha"' 'name with U+0130'
bad_shape '"acme", "acme/alpha"' 'owner equal to a bare entry'
bad_shape '"ACME", "acme/alpha"' 'owner equal to a bare entry in another case'
bad_shape '"beta/acme", "acme/alpha"' 'owner equal to another owner/name entry'"'"'s name'
bad_shape '"Beta/acme", "acme/alpha"' 'owner equal to the name half in another case'
bad_shape '7' 'a non-string entry'
bad_shape '"acme/alpha", "beta/alpha"' 'two entries with the same name half'
bad_shape '"acme/alpha", "alpha"' 'an owner/name entry and a bare entry with the same name'
bad_shape '"acme/alpha", "beta/ALPHA"' 'the same name half in another case'
bad_shape '"alpha", "alpha"' 'a repeated entry'
reset; set_repos '"acme/acme"'; run_broker
check "owner/name config: an owner equal to its own entry's name is accepted" test "$rc" -eq 0 -a "$(tokfile acme/acme)" = "$(expect_fresh)"

# the sweeps leave a directory whose name has a non-ASCII letter
reset; set_repos '"acme/alpha"'
mkdir -p "$home/review-sessions/ac$(printf '\342\204\252')" "$home/review-tokens/ac$(printf '\342\204\252')"
touch -d '-200 minutes' "$home/review-sessions/ac$(printf '\342\204\252')"
echo t >"$home/review-tokens/ac$(printf '\342\204\252')/reviewer-token"; touch -d '-20 minutes' "$home/review-tokens/ac$(printf '\342\204\252')/reviewer-token"
run_broker
check "sweep: a session directory with a non-ASCII letter is left" test -d "$home/review-sessions/ac$(printf '\342\204\252')"
check "sweep: a reviewer token under a non-ASCII directory is left" test -e "$home/review-tokens/ac$(printf '\342\204\252')/reviewer-token"

# --- config ----------------------------------------------------------------------------------
reset
echo '{"repos": ["alpha."]}' >"$home/broker.json"
run_broker
check "config: trailing-dot name exits 2" test "$rc" -eq 2
echo "$repos_ok" >"$home/broker.json"
echo '{"repos": ["alpha", "../evil"]}' >"$home/broker.json"
run_broker
check "config: bad repo name exits 2" test "$rc" -eq 2
check "config: nothing minted" test "$(calls mint-calls)" -eq 0
rm "$home/broker.json"; run_broker
check "config: missing broker.json exits 2" test "$rc" -eq 2

# --- tokens root (#1568) ---------------------------------------------------------------------
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) echo "SKIP - tokens root: pwsh's HOME is the Windows user profile here, not HOME; the tokens-root fixtures did not run" >&2 ;;
  *)
real_home=${HOME:-}; trn=0
# newfh: a fresh fixture HOME with no default home in it
newfh() { trn=$((trn + 1)); fh="$tmp/fh$trn"; mkdir "$fh"; dh="$fh/.config/glunk-identity"; HOME="$fh"; export HOME; }
tr_reset() { reset; rm -rf "$home/tokens-root"; newfh; set_repos '"acme/alpha"'; }
dtok() { cat "$dh/tokens/$1/dev-token" 2>/dev/null || true; }
log_has() { grep -q -F -e "$1" "$home/broker.log"; }

tr_reset; printf 'default-home\n' >"$home/tokens-root"
run_broker
check "tokens root: exits 0" test "$rc" -eq 0
check "tokens root: one mint" test "$(calls mint-calls)" -eq 1
check "tokens root: the dev-token lands under the default home, creating it" test "$(dtok acme/alpha)" = "$(expect_fresh)"
check "tokens root: the second home has no tokens directory" test ! -e "$home/tokens"
check "tokens root: no staged file left" test "$(staged)" -eq 0
check "tokens root: one account read" test "$(calls print-calls)" -eq 1
check "tokens root: nothing else under the default home but tokens" test "$(ls -A "$dh")" = tokens

tr_reset; printf 'default-home\n' >"$home/tokens-root"; STUB_ACCOUNT=ACME; export STUB_ACCOUNT
run_broker; unset STUB_ACCOUNT
check "tokens root: the account in another letter case mints" test "$rc" -eq 0 -a "$(dtok acme/alpha)" = "$(expect_fresh)"

tr_reset; printf 'default-home\n' >"$home/tokens-root"; STUB_ACCOUNT=other; export STUB_ACCOUNT
run_broker; unset STUB_ACCOUNT
check "tokens root: a different account exits 1" test "$rc" -eq 1
check "tokens root: a different account: no mint call" test "$(calls mint-calls)" -eq 0
check "tokens root: a different account: no dev-token" test -z "$(dtok acme/alpha)"
check "tokens root: a different account: the log names the entry" log_has "dev acme/alpha"
tr_reset; printf 'default-home\n' >"$home/tokens-root"; STUB_ACCT_FAIL=1; export STUB_ACCT_FAIL
run_broker; unset STUB_ACCT_FAIL
check "tokens root: a failed account read exits 1" test "$rc" -eq 1
check "tokens root: a failed account read: no mint call" test "$(calls mint-calls)" -eq 0
check "tokens root: a failed account read: no dev-token" test -z "$(dtok acme/alpha)"
check "tokens root: a failed account read: the log names the entry" log_has "dev acme/alpha"

for pair in 'no-newline:default-home' 'LF:default-home\n' 'CRLF:default-home\r\n'; do
  tr_reset; printf "${pair#*:}" >"$home/tokens-root"
  run_broker
  check "tokens root accepted [${pair%%:*}]" test "$rc" -eq 0 -a "$(dtok acme/alpha)" = "$(expect_fresh)"
done
refused() { # refused <label>: exit 2, a setup: line naming the file, nothing minted
  check "tokens root $1: exit 2" test "$rc" -eq 2
  check "tokens root $1: a setup: line in broker.log" log_has "setup: "
  check "tokens root $1: the line names the file and the word" log_has "tokens-root must be a regular file holding exactly default-home"
  check "tokens root $1: mint.sh and the account read never called" test "$(calls mint-calls)" -eq 0 -a "$(calls print-calls)" -eq 0
  check "tokens root $1: the default home is not created" test ! -e "$fh/.config"
}
for pair in 'nul-inside:default-\000home\n' 'nul-after:default-home\000' 'nul-before-LF:default-home\000\n' 'two-LF:default-home\n\n' 'two-CRLF:default-home\r\n\r\n' 'other-content:elsewhere\n' 'empty:' 'trailing-text:default-home x'; do
  tr_reset; printf "${pair#*:}" >"$home/tokens-root"
  run_broker
  refused "${pair%%:*}"
done
tr_reset; printf 'default-home\n' >"$tmp/trtarget"; ln -s "$tmp/trtarget" "$home/tokens-root"
run_broker; refused "link"
tr_reset; mkdir "$home/tokens-root"
run_broker; refused "directory"
tr_reset; printf 'default-home\n' >"$home/tokens-root"; HOME=; export HOME
run_broker; refused "with HOME empty"
# the file in the default home itself
tr_reset; mkdir -p "$dh"; cp "$home/apps.json" "$home/dev.pem" "$home/broker.json" "$dh/"; printf 'default-home\n' >"$dh/tokens-root"
saved_home=$home; home=$dh
run_broker; home=$saved_home
check "tokens root in the default home: exit 2" test "$rc" -eq 2
check "tokens root in the default home: a setup: line" grep -q "setup: " "$dh/broker.log"
check "tokens root in the default home: nothing minted" test "$(calls mint-calls)" -eq 0 -a ! -e "$dh/tokens"
# the default home itself reached through a link (last component, then a parent component), or written in another letter case (#1571)
for how in link parent chain dotdot case; do
  tr_reset; saved_home=$home
  case "$how" in
    link) mkdir -p "$dh"; hv="$tmp/trlink$trn"; ln -s "$dh" "$hv" ;;
    parent) mkdir -p "$dh"; ln -s "$fh" "$tmp/trparent$trn"; hv="$tmp/trparent$trn/.config/glunk-identity" ;;
    chain) mkdir -p "$dh"; ln -s "$fh" "$tmp/trchainfh$trn"; hv="$tmp/trchain$trn"; ln -s "$tmp/trchainfh$trn/.config/glunk-identity" "$hv" ;;
    dotdot) mkdir -p "$dh" "$fh/.config/sub"; ln -s "$fh/.config/sub" "$tmp/trdd$trn"; hv="$tmp/trddh$trn"; ln -s "$tmp/trdd$trn/../glunk-identity" "$hv" ;;
    case) hv="$fh/.config/GLUNK-identity"; mkdir -p "$hv" ;;
  esac
  cp "$home/apps.json" "$home/dev.pem" "$hv/"; echo '{"repos": ["acme/alpha"]}' >"$hv/broker.json"; printf 'default-home\n' >"$hv/tokens-root"
  home=$hv; run_broker; rc_b=$rc
  check "tokens root default home [$how]: broker exit 2" test "$rc_b" -eq 2
  check "tokens root default home [$how]: a setup: line" grep -q "setup: " "$hv/broker.log"
  check "tokens root default home [$how]: nothing minted, no account read" test "$(calls mint-calls)" -eq 0 -a "$(calls print-calls)" -eq 0 -a ! -e "$dh/tokens"
  run_install
  check "tokens root default home [$how] install: exits 0" test "$rc" -eq 0
  check "tokens root default home [$how] install: one warning" test "$(xc_warns)" -eq 1
  check "tokens root default home [$how] install: the warning names the file" xc_has "$(wp "$hv")/tokens-root must be a regular file holding exactly default-home: no token directory created"
  check "tokens root default home [$how] install: no token directory created" test ! -e "$hv/tokens/acme" -a ! -e "$dh/tokens"
  home=$saved_home
done

# absent file: no account read
tr_reset
run_broker
check "tokens root absent: mints under the home as before" test "$rc" -eq 0 -a "$(tokfile acme/alpha)" = "$(expect_fresh)"
check "tokens root absent: no account read" test "$(calls print-calls)" -eq 0

# the install
tr_reset; echo '{"repos": ["acme/alpha", "other/beta"]}' >"$home/broker.json"; rm -f "$home/review-poll.json"
printf 'default-home\n' >"$home/tokens-root"; mkdir -p "$dh/tokens/theirs"
run_install
check "tokens root install: exits 0" test "$rc" -eq 0
check "tokens root install: <owner>/<repo> created under the root" test -d "$dh/tokens/acme/alpha" -a -d "$dh/tokens/other/beta"
check "tokens root install: none under the second home" test ! -e "$home/tokens"
check "tokens root install: no warning for another owner's directory in the root" test "$(xc_warns)" -eq 0
tr_reset; echo '{"repos": ["acme/alpha"]}' >"$home/broker.json"; rm -f "$home/review-poll.json"
printf 'default-home' >"$home/tokens-root"
run_install
check "tokens root install: no newline accepted" test -d "$dh/tokens/acme/alpha"
for how in content link; do
  tr_reset; echo '{"repos": ["acme/alpha"]}' >"$home/broker.json"; rm -f "$home/review-poll.json"
  if [ "$how" = content ]; then printf 'elsewhere\n' >"$home/tokens-root"; else printf 'default-home\n' >"$tmp/trtarget"; ln -s "$tmp/trtarget" "$home/tokens-root"; fi
  run_install
  check "tokens root install [$how]: exits 0" test "$rc" -eq 0
  check "tokens root install [$how]: one warning" test "$(xc_warns)" -eq 1
  check "tokens root install [$how]: the warning names the file" xc_has "$(wp "$home")/tokens-root must be a regular file holding exactly default-home: no token directory created"
  check "tokens root install [$how]: no token directory created" test ! -e "$home/tokens/acme" -a ! -e "$fh/.config"
done
# a refused file still leaves the broker.json and review-poll.json comparison running
tr_reset; echo '{"repos": ["acme/alpha"]}' >"$home/broker.json"; echo '{"repos": ["acme/gamma"]}' >"$home/review-poll.json"
printf 'elsewhere\n' >"$home/tokens-root"
run_install
check "tokens root install [refused]: the poll comparison still warns" xc_has "gamma is in review-poll.json but not broker.json: no dev token is minted for it on this host"
rm -f "$home/tokens-root"
HOME=$real_home; export HOME
;;
esac

# --- profile block (#1595) -------------------------------------------------------------------
START='# >>> way-of-working launchers >>>'; END='# <<< way-of-working launchers <<<'
pl() { grep -c '^profile:' "$tmp/out" || true; }
pout() { grep -q -F -e "$1" "$tmp/out"; }
pf_has() { grep -q -F -e "$1" "$profile_path"; }
pf_lacks() { ! grep -q -F -e "$1" "$profile_path"; }
nmark() { grep -c -F -x -e "$1" "$profile_path" || true; }
pcmp() { cmp -s "$profile_path" "$tmp/before"; }
dotrun() { # dotrun <command text>: dot-source the written profile, then run the text
  pwsh -NoProfile -NonInteractive -Command ". '$(wp "$profile_path")'; $1" 2>&1
}
# the written block holds the three functions and the map
pbhold() { pf_has 'function wowd {' && pf_has 'function wowl {' && pf_has 'function wowend {' && pf_has '$WowHomes = @{'; }
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
echo "SKIP - profile: pwsh's HOME is the Windows user profile here and cannot be pointed at a fixture; the owner-to-home map, sibling-home, default-profile-path (it would write the real user profile), empty-HOME and sibling-owner fixtures did not run" >&2
# Windows profile cases (the install prints the path in backslash form, so only the line prefix is matched): -ProfilePath is a scratch file, HOME is never set, the owner map is not asserted.
wmark() { tr -d '\r' <"$profile_path" | grep -c -F -x -e "$1" || true; }
ncr() { tr -cd '\r' <"$1" | wc -c | tr -d ' '; }
nlf() { tr -cd '\n' <"$1" | wc -c | tr -d ' '; }
reset; set_repos '"acme/alpha"'
profile_path="$tmp/winprof/dir/profile.ps1"
run_install
check "Windows profile new: exits 0" test "$rc" -eq 0
check "Windows profile new: added line" pout "profile block added in "
check "Windows profile new: one start and one end marker line" test "$(wmark "$START")" -eq 1 -a "$(wmark "$END")" -eq 1
check "Windows profile new: every line break is CRLF" test "$(ncr "$profile_path")" -eq "$(nlf "$profile_path")" -a "$(nlf "$profile_path")" -gt 0
check "Windows profile new: the file ends with one CRLF" test "$(tail -c 2 "$profile_path" | od -An -tx1 | tr -d ' \n')" = 0d0a -a "$(tail -c 4 "$profile_path" | od -An -tx1 | tr -d ' \n')" != 0d0a0d0a
check "Windows profile new: the three functions and the map" pbhold
cp "$profile_path" "$tmp/before"
run_install
check "Windows profile again: exits 0" test "$rc" -eq 0
check "Windows profile again: unchanged line" pout "profile block unchanged in "
check "Windows profile again: byte-identical" pcmp
check "Windows profile dot-source: wowd, wowl and wowend are defined" test "$(dotrun '(Get-Command wowd, wowl, wowend -CommandType Function).Count')" = 3
profile_path="$tmp/winprof/lf.ps1"
printf 'line1\nline2\n' >"$profile_path"
run_install
check "Windows profile append to LF: added" pout "profile block added in "
check "Windows profile append to LF: the block uses LF only" test "$(ncr "$profile_path")" -eq 0
check "Windows profile append to LF: the first two lines are unchanged" test "$(head -c 12 "$profile_path" | od -An -tx1 | tr -d ' \n')" = 6c696e65310a6c696e65320a
check "Windows profile append to LF: one marker pair" test "$(wmark "$START")" -eq 1 -a "$(wmark "$END")" -eq 1
profile_path="$tmp/scratch-profile.ps1"
;;
  *)
echo "SKIP - Windows profile: not Git Bash on Windows; the CRLF profile fixtures did not run" >&2
prof_home=${HOME:-}
pnew() { reset; newfh; set_repos '"acme/alpha"'; mkdir -p "$dh"; profile_path="$tmp/prof$trn/dir/profile.ps1"; }
# mkh <dir> <repos list>: a home holding only a broker.json
mkh() { mkdir -p "$1"; printf '{"repos": [%s]}\n' "$2" >"$1/broker.json"; }
sibling() { mkh "$fh/.config/$1" "$2"; printf 'default-home\n' >"$fh/.config/$1/tokens-root"; }

# first write into a directory that does not exist yet
pnew; mkh "$dh" '"my-org/a", "acme/alpha"'; sibling two '"beta/x"'
run_install
check "profile new: exits 0" test "$rc" -eq 0
check "profile new: added line" pout "profile block added in $(wp "$profile_path")"
check "profile new: no profile: line" test "$(pl)" -eq 0
check "profile new: one start and one end marker" test "$(nmark "$START")" -eq 1 -a "$(nmark "$END")" -eq 1
check "profile new: the three functions and the map" pbhold
check "profile new: a hyphenated owner is mapped to the default home" pf_has "'my-org' = '$(wp "$dh")'"
check "profile new: the map is ordered by owner" test "$(grep -o "^  '[^']*'" "$profile_path" | tr -d ' ' | tr '\n' ' ')" = "'acme' 'beta' 'my-org' "
# a second run changes nothing, from the other home too
cp "$profile_path" "$tmp/before"
run_install
check "profile again: exits 0" test "$rc" -eq 0
check "profile again: unchanged line" pout "profile block unchanged in $(wp "$profile_path")"
check "profile again: byte-identical" pcmp
saved_home=$home; home=$fh/.config/two
run_install; home=$saved_home
check "profile from a sibling home: unchanged" pout "profile block unchanged in $(wp "$profile_path")"
check "profile from a sibling home: byte-identical, owner set unchanged" pcmp

# append to an existing profile, with and without a final line break
for end in with without; do
  pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
  if [ "$end" = with ]; then printf 'line1\nline2\n' >"$profile_path"; else printf 'line1\nline2' >"$profile_path"; fi
  run_install
  check "profile append [$end a final line break]: added" pout "profile block added in $(wp "$profile_path")"
  check "profile append [$end a final line break]: the earlier lines are kept" test "$(sed -n 1,2p "$profile_path")" = "line1
line2"
  check "profile append [$end a final line break]: the block starts on line 3" test "$(sed -n 3p "$profile_path")" = "$START"
  check "profile append [$end a final line break]: one marker pair" test "$(nmark "$START")" -eq 1 -a "$(nmark "$END")" -eq 1
  if [ "$end" = with ]; then
    check "profile append [with a final line break]: the earlier bytes are unchanged" test "$(head -c 12 "$profile_path" | od -An -c | tr -d ' ')" = 'l i n e 1 \n l i n e 2 \n' -o "$(head -c 12 "$profile_path" | od -An -tx1 | tr -d ' \n')" = 6c696e65310a6c696e65320a
  else
    check "profile append [without a final line break]: the earlier bytes are unchanged" test "$(head -c 11 "$profile_path" | od -An -tx1 | tr -d ' \n')" = 6c696e65310a6c696e6532
  fi
done

# update after a map change: bytes outside the markers kept (BOM + CRLF; an invalid UTF-8 byte + LF)
for how in bom-crlf invalid-lf; do
  pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
  if [ "$how" = bom-crlf ]; then
    printf '\357\273\277%s\r\n%s\r\ntail one\r\n\r\ntail two' "$START" "$END" >"$profile_path"
    printf '%s\r\ntail one\r\n\r\ntail two' "$END" >"$tmp/after"; printf '\357\273\277' >"$tmp/pre"
  else
    printf 'before \377 x\n%s\nold\n%s\nafter\n' "$START" "$END" >"$profile_path"
    printf '%s\nafter\n' "$END" >"$tmp/after"; printf 'before \377 x\n' >"$tmp/pre"
  fi
  run_install
  check "profile update [$how] setup: first write updates" pout "profile block updated in $(wp "$profile_path")"
  sibling two '"beta/x"'
  run_install
  check "profile update [$how]: updated line" pout "profile block updated in $(wp "$profile_path")"
  check "profile update [$how]: the new owner is in the block" pf_has "'beta' = "
  n=$(wc -c <"$tmp/pre"); head -c "$n" "$profile_path" >"$tmp/gotpre"
  check "profile update [$how]: the bytes before the start marker are unchanged" cmp -s "$tmp/gotpre" "$tmp/pre"
  n=$(wc -c <"$tmp/after"); tail -c "$n" "$profile_path" >"$tmp/gotafter"
  check "profile update [$how]: the bytes from the end marker on are unchanged" cmp -s "$tmp/gotafter" "$tmp/after"
  check "profile update [$how]: one marker pair" test "$(nmark "$START")" -eq 1 -o "$how" = bom-crlf
  if [ "$how" = bom-crlf ]; then
    check "profile update [bom-crlf]: the block uses CRLF throughout" test "$(tr -cd '\r' <"$profile_path" | wc -c | tr -d ' ')" -eq "$(tr -cd '\n' <"$profile_path" | wc -c | tr -d ' ')"
  else
    check "profile update [invalid-lf]: the block uses LF" test "$(tr -cd '\r' <"$profile_path" | wc -c | tr -d ' ')" -eq 0
  fi
  cp "$profile_path" "$tmp/before"; run_install
  check "profile update [$how]: a third run leaves it byte-identical" pcmp
done

# the block is written through the existing profile file: its mode and hard links are kept (#1658)
mode_of() { ls -l "$1" | cut -c1-10; }
links_of() { ls -l "$1" | awk '{ print $2 }'; }
pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
printf 'before\n%s\nold\n%s\nafter\n' "$START" "$END" >"$profile_path"; chmod 600 "$profile_path"
sibling two '"beta/x"'
run_install
check "profile mode 600 update: updated line" pout "profile block updated in $(wp "$profile_path")"
check "profile mode 600 update: the new owner is in the block" pf_has "'beta' = "
check "profile mode 600 update: still -rw-------" test "$(mode_of "$profile_path")" = -rw-------
pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
printf 'line1\nline2\n' >"$profile_path"; chmod 600 "$profile_path"
run_install
check "profile mode 600 append: added line" pout "profile block added in $(wp "$profile_path")"
check "profile mode 600 append: still -rw-------" test "$(mode_of "$profile_path")" = -rw-------
pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
printf 'before\n%s\nold\n%s\nafter\n' "$START" "$END" >"$profile_path"; ln "$profile_path" "$profile_path.link"
sibling two '"beta/x"'
run_install
check "profile hard link update: updated line" pout "profile block updated in $(wp "$profile_path")"
check "profile hard link update: the link count is still 2" test "$(links_of "$profile_path")" = 2
check "profile hard link update: the other name holds the same bytes" cmp -s "$profile_path" "$profile_path.link"
pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
printf 'before\n%s\nold\n%s\nafter\n' "$START" "$END" >"$profile_path"; chmod 444 "$profile_path"; cp "$profile_path" "$tmp/before"
sibling two '"beta/x"'
run_install
if [ "$(id -u)" = 0 ]; then
  echo "SKIP - profile mode 444: running as root, which writes a read-only file; the not-written fixture did not run" >&2
else
  check "profile mode 444: exits 0" test "$rc" -eq 0
  check "profile mode 444: exactly one not-written line" test "$(grep -c '^profile: not written (' "$tmp/out" || true)" -eq 1
  check "profile mode 444: byte-identical" pcmp
  check "profile mode 444: the mode is unchanged" test "$(mode_of "$profile_path")" = -r--r--r--
fi
chmod 644 "$profile_path"

# malformed marker forms and a UTF-16 profile are left untouched
for form in start-only end-only end-first two-starts utf16le utf16be; do
  pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
  case "$form" in
    start-only) printf 'a\n%s\nb\n' "$START" ;;
    end-only) printf 'a\n%s\nb\n' "$END" ;;
    end-first) printf '%s\nb\n%s\n' "$END" "$START" ;;
    two-starts) printf '%s\nb\n%s\n%s\n' "$START" "$START" "$END" ;;
    utf16le) printf '\377\376#\000 \000x\000\n\000' ;;
    utf16be) printf '\376\377\000#\000 \000x\000\n' ;;
  esac >"$profile_path"
  cp "$profile_path" "$tmp/before"
  run_install
  check "profile malformed [$form]: exits 0" test "$rc" -eq 0
  check "profile malformed [$form]: byte-identical" pcmp
  check "profile malformed [$form]: one profile: line" test "$(pl)" -eq 1
  check "profile malformed [$form]: no added or updated line" test "$(grep -c '^profile block' "$tmp/out" || true)" -eq 0
  case "$form" in
    two-starts) check "profile malformed [two-starts]: the line counts the markers" pout "has 2 start and 1 end marker lines in a form the install cannot update; fix the block by hand" ;;
    utf16*) check "profile malformed [$form]: the line names the byte order mark" pout 'starts with a UTF-16 byte order mark' ;;
  esac
done

# the default profile path, under a fixture HOME with XDG_CONFIG_HOME unset
pnew; mkh "$dh" '"acme/alpha"'; profile_path=-
saved_xdg=${XDG_CONFIG_HOME-}; unset XDG_CONFIG_HOME
run_install
[ -z "$saved_xdg" ] || XDG_CONFIG_HOME=$saved_xdg
profile_path="$fh/.config/powershell/profile.ps1"
check "profile default path: exits 0" test "$rc" -eq 0
check "profile default path: added" pout "profile block added in $(wp "$profile_path")"
check "profile default path: the block is in .config/powershell/profile.ps1 under HOME" pbhold

# a directory, a link, a dangling link and a path under a regular file are left alone
for how in directory link dangling under-file; do
  pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$(dirname "$profile_path")"
  case "$how" in
    directory) mkdir "$profile_path" ;;
    link) printf 'target\n' >"$tmp/ptarget$trn"; ln -s "$tmp/ptarget$trn" "$profile_path" ;;
    dangling) ln -s "$tmp/pnowhere$trn" "$profile_path" ;;
    under-file) printf 'x' >"$tmp/pfile$trn"; profile_path="$tmp/pfile$trn/profile.ps1" ;;
  esac
  run_install
  check "profile $how: exits 0" test "$rc" -eq 0
  check "profile $how: one profile: line" test "$(pl)" -eq 1
  check "profile $how: no added or updated line" test "$(grep -c '^profile block' "$tmp/out" || true)" -eq 0
  case "$how" in
    link) check "profile link: still a link, target untouched" test -L "$profile_path" -a "$(cat "$tmp/ptarget$trn")" = target ;;
    dangling) check "profile dangling: still a link, nothing written through it" test -L "$profile_path" -a ! -e "$tmp/pnowhere$trn" ;;
    directory) check "profile directory: still a directory" test -d "$profile_path" ;;
    under-file) check "profile under-file: the line says not written" pout 'profile: not written (' ;;
  esac
done

# the owner-to-home map
pnew; mkh "$dh" '"my-org/a", "Case/a", "case/b", "dup/x"'
sibling two '"beta/x"'
mkh "$fh/.config/three" '"gamma/x"'
mkh "$fh/.config/four" '"delta/x"'; printf 'elsewhere\n' >"$fh/.config/four/tokens-root"
mkdir -p "$tmp/realfive$trn"; mkh "$tmp/realfive$trn" '"epsilon/x"'; printf 'default-home\n' >"$tmp/realfive$trn/tokens-root"; ln -s "$tmp/realfive$trn" "$fh/.config/five"
sibling six '"zeta/x"'; printf 'not json {' >"$fh/.config/six/broker.json"
sibling seven '"dup/y"'
run_install
check "profile map: exits 0" test "$rc" -eq 0
check "profile map: the default home's owners, a hyphenated one included" pf_has "'my-org' = '$(wp "$dh")'"
check "profile map: a sibling with a valid tokens-root" pf_has "'beta' = '$(wp "$fh/.config/two")'"
check "profile map: one owner in two letter cases maps once, in its first spelling" test "$(grep -c -i "^  'case' = " "$profile_path")" -eq 1 -a "$(grep -c "^  'Case' = " "$profile_path")" -eq 1
check "profile map: a sibling without tokens-root contributes nothing" pf_lacks "'gamma'"
check "profile map: a sibling with a refused tokens-root contributes nothing" pf_lacks "'delta'"
check "profile map: a sibling reached through a link contributes nothing" pf_lacks "'epsilon'"
check "profile map: a sibling whose broker.json is not JSON contributes nothing" pf_lacks "'zeta'"
check "profile map: ...with its one profile: line" pout "profile: $(wp "$fh/.config/six")/broker.json unreadable, its owners are not mapped"
check "profile map: an owner two homes name is absent" pf_lacks "'dup'"
check "profile map: ...with its one profile: line naming both homes" pout "owner dup is named by $(wp "$dh") and $(wp "$fh/.config/seven")"
check "profile map: exactly the two profile: lines" test "$(pl)" -eq 2

# an install from a sibling home, the default home holding only tokens/
pnew; rmdir "$dh"; mkdir -p "$dh/tokens"; sibling two '"beta/x", "acme/alpha"'
saved_home=$home; home=$fh/.config/two
run_install; home=$saved_home
check "profile from a sibling: exits 0" test "$rc" -eq 0
check "profile from a sibling: no profile: line" test "$(pl)" -eq 0
check "profile from a sibling: the added line" pout "profile block added in $(wp "$profile_path")"
check "profile from a sibling: the block maps the sibling's owner beta" pf_has "'beta' = '$(wp "$fh/.config/two")'"
check "profile from a sibling: the block maps the sibling's owner acme" pf_has "'acme' = '$(wp "$fh/.config/two")'"

# a fixture HOME with no .config folder, -WowHome outside it with no tokens-root
pnew; rm -rf "$fh/.config"
run_install
check "profile no .config: exits 0" test "$rc" -eq 0
check "profile no .config: no profile: line" test "$(pl)" -eq 0
check "profile no .config: the added line" pout "profile block added in $(wp "$profile_path")"
check "profile no .config: nothing was created under HOME" test ! -e "$fh/.config"
check "profile no .config: the three functions and the map are written" pbhold

# an empty HOME
pnew; HOME=; export HOME
run_install
HOME=$fh; export HOME
check "profile empty HOME: exits 0, one not-written line, no file" test "$rc" -eq 0 -a "$(pl)" -eq 1 -a ! -e "$profile_path"
check "profile empty HOME: the line says HOME is empty" pout 'profile: not written (HOME is empty'

# a folder name holding an ASCII quote and a U+2019 quote
pnew; qd="$fh/.config/q'uote’s"; mkh "$qd" '"qq/x"'; printf 'default-home\n' >"$qd/tokens-root"; mkh "$dh" '"acme/alpha"'
run_install
check "profile quoted folder: added" pout "profile block added in $(wp "$profile_path")"
check "profile quoted folder: dot-sourcing parses and runs only the definitions" test "$(dotrun '$WowHomes.Count')" = 2
check "profile quoted folder: the home value is the folder's real name" test "$(dotrun '[IO.Path]::GetFileName($WowHomes["qq"])')" = "q'uote’s"

# the shortcuts, echoed
pnew; mkh "$dh" '"acme/alpha"'; run_install
WOW_PROFILE_ECHO=1; export WOW_PROFILE_ECHO
b="$(wp "$dh")/bin"
check "profile echo: wowd with a further argument" test "$(dotrun 'wowd acme/alpha -Base dev')" = "pwsh -NoProfile -File $b/wow-driver.ps1 -Repo acme/alpha -Base dev"
check "profile echo: wowl with a comma list after -Spec" test "$(dotrun 'wowl acme/alpha -Spec 7,8')" = "pwsh -NoProfile -File $b/wow-lane.ps1 -Repo acme/alpha -Spec 7,8"
check "profile echo: wowl with -Issue and -Hash" test "$(dotrun 'wowl acme/alpha -Issue 5 -Hash abc')" = "pwsh -NoProfile -File $b/wow-lane.ps1 -Repo acme/alpha -Issue 5 -Hash abc"
check "profile echo: wowend is wowl with -EndDay" test "$(dotrun 'wowend acme/alpha')" = "pwsh -NoProfile -File $b/wow-lane.ps1 -Repo acme/alpha -EndDay"
check "profile echo: wowend passes further arguments after -EndDay" test "$(dotrun 'wowend acme/alpha -Base dev')" = "pwsh -NoProfile -File $b/wow-lane.ps1 -Repo acme/alpha -EndDay -Base dev"
check "profile echo: an owner in another letter case is found" test "$(dotrun 'wowd ACME/alpha')" = "pwsh -NoProfile -File $b/wow-driver.ps1 -Repo ACME/alpha"
check "profile echo: a half holding a dot, an underscore and a hyphen is accepted" test "$(dotrun 'wowd acme/a.b_c-d')" = "pwsh -NoProfile -File $b/wow-driver.ps1 -Repo acme/a.b_c-d"
tpl_pat=$(sed -n "s/.*-cnotmatch '\(.*\)') { throw 'usage.*/\1/p" "$inst_ps")
arg_pat=$(sed -n "/^function Assert-RepoArgument/{n;s/.*-cnotmatch '\(.*\)') { Stop-BadArgument.*/\1/p;}" "$root_dir/scripts/identity/wow-launch-common.ps1")
check "profile throw: the template's usage pattern is Assert-RepoArgument's, byte for byte" test -n "$tpl_pat" -a "$tpl_pat" = "$arg_pat"
dotrun 'wowd nobody/x' >"$tmp/o1" || true
check "profile throw: an unknown owner is named" grep -q 'wowd: no identity home for owner nobody' "$tmp/o1"
for bad in 'wowd' 'wowd acme' 'wowl acme/' 'wowl /alpha' 'wowend a/b/c' 'wowd acme/al+pha' 'wowl ac~me/x'; do
  dotrun "$bad" >"$tmp/o1" || true
  check "profile throw [$bad]: a usage message" grep -q 'usage: ' "$tmp/o1"
done
unset WOW_PROFILE_ECHO

# -WhatIf writes no profile
pnew; mkh "$dh" '"acme/alpha"'
run_install -WhatIf
check "profile -WhatIf: exits 0" test "$rc" -eq 0
check "profile -WhatIf: no profile and no directory" test ! -e "$profile_path" -a ! -e "$(dirname "$profile_path")"

# the default home's step-5 loop accepts the owner directories of the homes beside it (#1599)
nowarn() { ! xc_has "tokens/$1 is not the owner directory of any broker.json entry"; }
warned() { xc_has "tokens/$1 is not the owner directory of any broker.json entry"; }
all_warned() { for n; do warned "$n" || return 1; done; }
nocouldnot() { ! grep -q 'could not run' "$tmp/out"; }
# (a) a sibling with a valid tokens-root, its owner in another letter case than its directory
pnew; mkh "$dh" '"acme/alpha"'; sibling two '"Beta/x"'; mkdir -p "$dh/tokens/beta" "$dh/tokens/leftover"
saved_home=$home; home=$dh; run_install; home=$saved_home
check "sibling owners (a): exits 0" test "$rc" -eq 0
check "sibling owners (a): no warning for the sibling's owner directory" nowarn beta
check "sibling owners (a): exactly one warning, the leftover's" test "$(xc_warns)" -eq 1
check "sibling owners (a): the leftover is named" warned leftover
# (b) no tokens-root file
pnew; mkh "$dh" '"acme/alpha"'; mkh "$fh/.config/two" '"Beta/x"'; mkdir -p "$dh/tokens/beta"
saved_home=$home; home=$dh; run_install; home=$saved_home
check "sibling owners (b): no tokens-root, the warning is printed" warned beta
# (c) other tokens-root content
pnew; mkh "$dh" '"acme/alpha"'; mkh "$fh/.config/two" '"Beta/x"'; printf 'elsewhere\n' >"$fh/.config/two/tokens-root"; mkdir -p "$dh/tokens/beta"
saved_home=$home; home=$dh; run_install; home=$saved_home
check "sibling owners (c): other tokens-root content, the warning is printed" warned beta
# (d) one unreadable sibling, one readable, one with no broker.json
pnew; mkh "$dh" '"acme/alpha"'
sibling one '"x/x"'; printf 'not json' >"$fh/.config/one/broker.json"
sibling two '"gamma/x"'
mkdir -p "$fh/.config/three"; printf 'default-home\n' >"$fh/.config/three/tokens-root"
mkdir -p "$dh/tokens/ghost" "$dh/tokens/gamma" "$dh/tokens/nobrk" "$dh/tokens/leftover"
saved_home=$home; home=$dh; run_install; home=$saved_home
check "sibling owners (d): exits 0" test "$rc" -eq 0
check "sibling owners (d): no could-not-run line" nocouldnot
check "sibling owners (d): exactly three warnings" test "$(xc_warns)" -eq 3
check "sibling owners (d): the leftover, the unreadable and the no-broker.json sibling's directories are named" all_warned leftover ghost nobrk
check "sibling owners (d): none for the readable sibling's directory" nowarn gamma
# (e) a sibling owner equal to a name half of the default home's broker.json
pnew; mkh "$dh" '"acme/alpha"'; sibling two '"ALPHA/x"'; mkdir -p "$dh/tokens/alpha"
saved_home=$home; home=$dh; run_install; home=$saved_home
check "sibling owners (e): a collision with a name half keeps the warning" warned alpha
# (f) an install from a home that is not the default home
pnew; mkh "$dh" '"acme/alpha"'; sibling two '"beta/x"'; mkh "$fh/.config/other" '"acme/alpha"'; mkdir -p "$fh/.config/other/tokens/beta"
saved_home=$home; home=$fh/.config/other; run_install; home=$saved_home
check "sibling owners (f): not the default home, the warning is printed" warned beta
# (g) entries that are not two halves each passing the name rule
pnew; mkh "$dh" '"acme/alpha"'; sibling two '"bare1", "tp/x/y", "ow/-bad"'; mkdir -p "$dh/tokens/bare1" "$dh/tokens/tp" "$dh/tokens/ow"
saved_home=$home; home=$dh; run_install; home=$saved_home
check "sibling owners (g): a bare, a three-part and a bad-half entry each keep the warning" all_warned bare1 tp ow
# (h) an empty HOME
pnew; mkh "$dh" '"acme/alpha"'; mkdir -p "$dh/tokens/leftover"; HOME=; export HOME
saved_home=$home; home=$dh; run_install; home=$saved_home
HOME=$fh; export HOME
check "sibling owners (h): empty HOME, exits 0" test "$rc" -eq 0
check "sibling owners (h): the leftover is warned about" warned leftover
check "sibling owners (h): no could-not-run line" nocouldnot

profile_path="$tmp/scratch-profile.ps1"
HOME=$prof_home; export HOME
;;
esac

[ "$fail" -eq 0 ] || exit 1
echo "all identity-broker fixtures passed"
