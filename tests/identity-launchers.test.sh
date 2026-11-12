#!/bin/sh
# Fixture tests for scripts/identity/wow-driver.ps1, wow-lane.ps1 and wow-launch-common.ps1 (issues #728, #762).
#
# Stub docker, devcontainer and gh record their argv in one calls.log and answer from canned files (gh from the
# scratch origin's real objects, shaped as the compare and git/trees API answers, then reshaped by a ghx.jq.<kind>
# filter or replaced by ghx.raw.<kind> or ghx.exit); all three also log their working directory, in native
# form, to cwd.log (#1346); a recording git wrapper logs its argv and runs the real git. A scratch Reference clone (local bare
# origin, .devcontainer/ and .ai/project.yml committed), a scratch Clone folder holding a copy of
# .devcontainer/, and a scratch WowHome with the three scripts and a MANIFEST in install-host-tools.ps1's
# format are laid out per case. The stub docker answers its Nth `ps` call of each kind (volume, label)
# from ps.<kind>.<N>, else ps.<kind>, else empty.
#
#   not installed   no MANIFEST (a checkout), a wrong hash for either file, a missing row, a bin outside
#                   -WowHome: exit 1 before any stub call; a -WowHome reached through a link passes
#   bad arguments   missing/related/linked/odd-leaf -Clone and -Reference, a .git file, a bad -Remote or
#                   -Base, a -Clone holding -WowHome, a -WowHome that is or sits inside -Reference, & or % in a parent: exit 2, no stub or git call
#   start of day    zero, exited or created container: three gh api calls (the compare, the root tree, the
#                   .devcontainer subtree), up, re-list, record, docker exec -it, the exec's code; gh and up run
#                   with the final -WowHome as their working directory
#   base binding    the launcher started inside the Clone still runs gh and up from -WowHome; a behind compare passes; ahead, diverged, a missing status, another merge-base sha, non-JSON
#                   output and a failing gh each refuse before up; so do a committed tree without
#                   .devcontainer/devcontainer.json, a truncated read of either tree, a root tree with no
#                   .devcontainer entry, and a symlink or submodule entry; the API reason wins over a clone mismatch
#   refusals        .devcontainer/ mismatch, label-only or Reference containers, bad up results, bad re-list
#   attach          record + running container + clean probe: no compare, no gh, no devcontainer, no git on the Clone
#   origin          the Reference's origin repository against the record: start of day, attach,
#                   wow-lane -Issue/-Spec/-SpecSweep refuse another origin; a three-field record is replaced at start and
#                   refused on attach and in the lane; url shapes that refuse without echoing the url
#   attach refuses  mismatched/missing/malformed record, another clone, dirty probe, two containers,
#                   restarting/paused, a failed docker ps, a missing tool
#   yq minimum      the host yq version check: the pure comparison on stubbed version lines, both launchers refuse a
#                   stub yq below v4.54.1 or an unreadable one (the lane through an exit-0 stub printing another yq's form) before any docker or git call, and the number is in neither launcher file
#   -Repo (#1381)   the five-field record (a start of day writes the Reference path; a four-field record still reads and is
#                   replaced), wow-driver and wow-lane -Repo from the record (start of day, attach, -Issue/-Hash, -Spec,
#                   -SpecSweep) making the calls the long form makes, and each -Repo refusal before any external call; -EndDay:
#                   idle (a docker stop of the recorded id), a dirty relay probe, a running claude in a lane leaf
#                   (not a spec- one) or a spec leaf, a driver-like claude outside the lanes directory (idle), a missing
#                   lanes directory, an unsafe one, a failing docker stop, exit 2 combined with another mode (the busy
#                   fixtures are skipped loudly under MSYS); Get-Help on each launcher in the checkout returns the
#                   .SYNOPSIS text, not the syntax line (#1386)
#   model, canary, edit after up, the declared values the docker exec literals match
#   wow-lane        not installed, bad arguments, container and record refusals (the sweep's lanes-directory
#                   refusal too), the lane probe and the
#                   spec prep and cleanup scripts run for real (the stub docker runs a non-interactive
#                   `exec -u app ... /bin/sh -c <script> sh <args>` with the real /bin/sh against a scratch
#                   lanes directory and a scratch container clone), both happy paths, base-moved and kept
#                   worktrees, the busy check (a fake running session: an executable named claude whose
#                   working directory is a spec leaf), the spec record, the -SpecSweep mode (it kills and removes nothing, but fetches in the Reference)
#                   (the busy-check and sweep fixtures are skipped loudly under MSYS), the shared lanes-directory guard
#                   (an owner override in the stub docker makes `test -O` false on the lanes path, a dangling
#                   lanes link and a missing lanes directory are fixtures), and the static shape of the guard, the five scripts and the message
#                   templates (the lane and spec ones in wow-lane.ps1, the driver one in wow-driver.ps1)
#
#
# Concurrency (#937): the sections run at once, each in a subshell with its own scratch world
# (setup_world: its own tmp, stub directory, clones, WowHome and STUB_* exports), so no case reads state
# another section wrote. Each section's output goes to files that are replayed in section order; the
# suite fails if any section reports a FAIL through `check` or exits non-zero.
#
# Permitted toolset: POSIX sh, its standard utilities, pwsh, git, yq and jq (skipped, loudly, if any is absent; a
# failure instead when WOW_TESTS_REQUIRE_TOOLS is exactly 1, which ci.yml sets).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

for t in pwsh git yq jq; do
  if ! command -v "$t" >/dev/null 2>&1; then
    if [ "${WOW_TESTS_REQUIRE_TOOLS:-}" = 1 ]; then
      echo "FAIL - $t not on PATH; identity-launchers fixtures would not run" >&2
      exit 1
    fi
    echo "SKIP - $t not on PATH; identity-launchers fixtures not run" >&2
    exit 0
  fi
done

tmp_root="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp_root"' EXIT

# Native pwsh wants native paths; under MSYS that is cygpath -m, elsewhere the path as is.
wp() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }
norm() { printf '%s' "$1" | tr 'A-Z/\\' 'a-z//' | sed 's,/*$,,'; }

pwsh_abs=$(command -v pwsh)
real_git=$(command -v git)
STUB_SESSION_EXIT=7; export STUB_SESSION_EXIT
REAL_GIT=$real_git; export REAL_GIT

fail=0
ok() { echo "ok - $1"; }
bad() {
  echo "FAIL - $1" >&2; fail=1
  # the last launcher run's exit code and last stderr line, so a failure seen only on a CI runner can be told apart
  [ -z "${tmp:-}" ] || echo "# last run: rc=${rc:-unset}: $(tail -n 1 "$tmp/err" 2>/dev/null | head -c 300)" >&2
}
check() { _cl=$1; shift; if "$@"; then ok "$_cl"; else bad "$_cl"; fi; }

ID1=$(printf '%064d' 0 | tr 0 a)
ID2=$(printf '%064d' 0 | tr 0 b)
ID3=$(printf '%064d' 0 | tr 0 c)

case "$(uname -s)" in MINGW*|MSYS*) msys=1 ;; *) msys= ;; esac
STUB_MSYS=$msys; export STUB_MSYS

# --- stubs -------------------------------------------------------------------------------------
# On MSYS the stubs are .cmd shims that run the sh stubs: they take the same cmd.exe re-parse path as
# the real devcontainer.cmd, so the -Clone character set protects them too.
mkstub() { # mkstub <name> <body-file>
  if [ -n "$msys" ]; then
    cp "$2" "$stubdir/$1.sh"
    printf '@sh "%%~dp0%s.sh" %%*\r\n' "$1" >"$stubdir/$1.cmd"
  else cp "$2" "$stubdir/$1"; chmod +x "$stubdir/$1"; fi
}
# mklink_dir <link> <target>: a directory link, a junction on MSYS (no admin, and MSYS ln -s copies);
# non-zero where a real link cannot be made.
mklink_dir() {
  if [ -n "$msys" ]; then
    "$pwsh_abs" -NoProfile -NonInteractive -Command "New-Item -ItemType Junction -Path '$(wp "$1")' -Target '$(wp "$2")' | Out-Null" >/dev/null 2>&1 &&
      "$pwsh_abs" -NoProfile -NonInteractive -Command "if ((Get-Item -LiteralPath '$(wp "$1")' -Force).LinkType) { exit 0 } else { exit 1 }" >/dev/null 2>&1
  else ln -s "$2" "$1" 2>/dev/null && [ -L "$1" ]; fi
}
skip() { echo "SKIP - $1" >&2; }

# setup_world <name>: a private scratch world for one section, set in the calling shell.
setup_world() {
  tmp="$tmp_root/$1"; mkdir "$tmp"
  stubdir="$tmp/stub" ; mkdir "$stubdir"
  home="$tmp/home" ; mkdir -p "$home/bin"
  STUB_DIR="$stubdir"; export STUB_DIR
cat >"$tmp/docker.body" <<'STUB'
#!/bin/sh
d=$STUB_DIR
echo "docker $*" >>"$d/calls.log"
{ pwd -W 2>/dev/null || pwd -P; } | sed 's/^/docker /' >>"$d/cwd.log"
case "$1" in
  ps)
    kind=vol
    for a in "$@"; do case "$a" in label=*) kind=label ;; esac; done
    n=$(( $(cat "$d/n.$kind" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$d/n.$kind"
    if [ -e "$d/ps.exit" ]; then exit "$(cat "$d/ps.exit")"; fi
    if [ -e "$d/ps.$kind.$n" ]; then cat "$d/ps.$kind.$n"
    elif [ -e "$d/ps.$kind" ]; then cat "$d/ps.$kind"; fi
    exit 0 ;;
  stop) exit "$(cat "$d/stop.exit" 2>/dev/null || echo 0)" ;;
  exec)
    case "$*" in
      *" -it "*)
        [ ! -e "$STUB_RECORD" ] || cp "$STUB_RECORD" "$d/record-at-exec"
        [ -z "${STUB_LANES:-}" ] || ls "$STUB_LANES" >"$d/lanes-at-exec" 2>/dev/null
        [ ! -e "$d/it.hook" ] || sh "$d/it.hook"
        exit "${STUB_SESSION_EXIT:-0}" ;;
      "exec -u app "*)
        # wow-lane.ps1's in-container step: run the script for real, with the container's two literal
        # directories swapped for the scratch ones. MSYS mkdir -m fails (cannot change permissions) under
        # its /tmp, so there the script runs with a plain mkdir; elsewhere it runs as sent.
        shift
        while [ "$1" != /bin/sh ]; do shift; done
        shift 2; script=$1; shift 2
        [ -z "${STUB_MSYS:-}" ] || script=$(printf '%s' "$script" | sed 's/mkdir -m 700/mkdir/g')
        # it.owner: a shell function named test goes in front of the script, false for -O on the scratch
        # lanes path, so the lanes directory reads as not owned by the user without a second user.
        [ ! -e "$d/it.owner" ] || script='test() { case $1:$2 in -O:"$STUB_LANES") return 1;; esac; command test "$@"; }; '"$script"
        n=$#
        while [ "$n" -gt 0 ]; do
          a=$1; shift
          case $a in /tmp/lanes | /srv/wow-lanes) a=$STUB_LANES ;; /workspace) a=$STUB_REPO ;; esac
          set -- "$@" "$a"; n=$((n - 1))
        done
        exec /bin/sh -c "$script" sh "$@" ;;
      *)
        [ ! -e "$d/probe.out" ] || cat "$d/probe.out"
        exit "$(cat "$d/probe.exit" 2>/dev/null || echo 0)" ;;
    esac ;;
esac
exit 0
STUB
cat >"$tmp/devcontainer.body" <<'STUB'
#!/bin/sh
d=$STUB_DIR
echo "devcontainer $*" >>"$d/calls.log"
{ pwd -W 2>/dev/null || pwd -P; } | sed 's/^/devcontainer /' >>"$d/cwd.log"
echo "stub devcontainer: building CANARY-STDERR" >&2
[ ! -e "$d/up.hook" ] || sh "$d/up.hook"
if [ -e "$d/up.out" ]; then cat "$d/up.out"; else
  printf '{"outcome":"success","containerId":"%s","note":"CANARY-UP"}\n' "$UP_ID"; fi
exit "$(cat "$d/up.exit" 2>/dev/null || echo 0)"
STUB
cat >"$tmp/git.body" <<'STUB'
#!/bin/sh
echo "git $*" >>"$STUB_DIR/git.log"
exec "$REAL_GIT" "$@"
STUB
cat >"$tmp/gh.body" <<'STUB'
#!/bin/sh
d=$STUB_DIR
echo "gh $*" >>"$d/calls.log"
{ pwd -W 2>/dev/null || pwd -P; } | sed 's/^/gh /' >>"$d/cwd.log"
[ ! -e "$d/ghx.exit" ] || exit "$(cat "$d/ghx.exit")"
for a in "$@"; do path=$a; done
g() { "$REAL_GIT" -C "$STUB_ORIGIN" "$@"; }
case "$path" in
  repos/acme/widgets/compare/*) kind=compare; c=${path##*...} ;;
  repos/acme/widgets/git/trees/*'?recursive=1') kind=sub; t=${path%'?recursive=1'}; t=${t##*/} ;;
  repos/acme/widgets/git/trees/*) kind=root; t=${path##*/} ;;
  *) exit 1 ;;
esac
if [ -e "$d/ghx.raw.$kind" ]; then cat "$d/ghx.raw.$kind"; exit 0; fi
ents='{truncated:false,tree:[split("\n")[]|select(length>0)|split("[ \t]";null)|{mode:.[0],type:.[1],sha:.[2],path:.[3]}]}'
case $kind in
  compare) out=$(jq -n --arg c "$c" --arg t "$(g rev-parse "$c^{tree}")" '{status:"identical",merge_base_commit:{sha:$c,commit:{tree:{sha:$t}}}}') ;;
  root) out=$(g ls-tree "$t" | jq -R -s "$ents") ;;
  sub) out=$(g ls-tree -r -t "$t" | jq -R -s "$ents") ;;
esac
[ ! -e "$d/ghx.jq.$kind" ] || out=$(printf '%s' "$out" | jq -c -f "$d/ghx.jq.$kind")
printf '%s\n' "$out"
STUB
mkstub docker "$tmp/docker.body"
mkstub devcontainer "$tmp/devcontainer.body"
mkstub gh "$tmp/gh.body"
# On MSYS a .cmd git shim would lose the ^ of ^{commit} to cmd.exe, which the real git.exe never sees, so
# the launcher runs the real git and run_with projects git's own trace2 log into git.log instead.
[ -n "$msys" ] || mkstub git "$tmp/git.body"

# --- a scratch Reference clone, a Clone folder and the installed scripts -----------------------------
seed="$tmp/seed" origin="$tmp/origin.git" ref="$tmp/refs/wb-ref" clone="$tmp/clones/wb-driver"
mkdir -p "$tmp/refs" "$tmp/clones"
G="$real_git -c user.name=t -c user.email=t@t"
$real_git init -q -b main "$seed"; $real_git init -q --bare -b main "$origin"
mkdir -p "$seed/.devcontainer/sub" "$seed/.ai"
printf 'FROM scratch\n# CANARY-DEVC\n' >"$seed/.devcontainer/Dockerfile"
printf '{"remoteUser": "app"}\n' >"$seed/.devcontainer/devcontainer.json"
printf 'echo hi\n' >"$seed/.devcontainer/sub/x.sh"
printf 'models:\n  architect: opus\n  coder: sonnet\ncanary: CANARY-YML\nlanes:\n  dir: /tmp/lanes\n' >"$seed/.ai/project.yml"
$G -C "$seed" add -A; $G -C "$seed" commit -q -m one
c1=$($real_git -C "$seed" rev-parse HEAD)
printf 'FROM scratch\n# CANARY-DEVC\n# second\n' >"$seed/.devcontainer/Dockerfile"
$G -C "$seed" commit -q -am two
$real_git -C "$seed" remote add origin "$(wp "$origin")"; $real_git -C "$seed" push -q origin main
c2=$($real_git -C "$seed" rev-parse HEAD)
t2=$($real_git -C "$seed" rev-parse "$c2^{tree}") dc2=$($real_git -C "$seed" rev-parse "$c2:.devcontainer")
$real_git clone -q "$(wp "$origin")" "$ref"
# The Reference's origin is a github.com url (the launcher records it as lowercase owner/name); its fetch still
# reaches the local bare repo through a scoped insteadOf rewrite, which the launcher's config read never applies.
ref_url='https://github.com/Acme/Widgets.git'
$real_git -C "$ref" config remote.origin.url "$ref_url"
$real_git -C "$ref" config "url.$(wp "$origin").insteadOf" "$ref_url"
# wow-lane's container clone (cloned from the same origin) and a second one whose origin/main is c1.
crepo="$tmp/crepo" crepo2="$tmp/crepo2" origin2="$tmp/origin2.git" lanes="$tmp/lanes"
$real_git clone -q "$(wp "$origin")" "$crepo"
$real_git init -q --bare -b main "$origin2"; $real_git -C "$seed" push -q "$(wp "$origin2")" "$c1:refs/heads/main"
$real_git clone -q "$(wp "$origin2")" "$crepo2"
# On MSYS git prints native paths, so the scripts must be handed the native form of the scratch directories.
STUB_LANES=$(wp "$lanes") STUB_REPO=$(wp "$crepo") STUB_ORIGIN=$(wp "$origin"); export STUB_LANES STUB_REPO STUB_ORIGIN
set_clone() { rm -rf "$clone"; mkdir -p "$clone"; cp -R "$seed/.devcontainer" "$clone/.devcontainer"; }
set_clone

mkdir -p "$tmp/other/bin"
install_to() { # install_to <bin dir>: the three scripts and a MANIFEST in install-host-tools.ps1's format
  b=$1
  cp "$root_dir/scripts/identity/wow-driver.ps1" "$root_dir/scripts/identity/wow-lane.ps1" "$root_dir/scripts/identity/wow-launch-common.ps1" "$b/"
  {
    echo "commit $c2"; echo "installed 2026-01-01T00:00:00Z"
    for f in wow-driver.ps1 wow-lane.ps1 wow-launch-common.ps1; do echo "$(sha256sum <"$b/$f" | cut -d' ' -f1)  $f"; done
  } >"$b/MANIFEST"
}
install_to "$home/bin"; install_to "$tmp/other/bin"
STUB_RECORD="$home/driver/wb-driver.json"; export STUB_RECORD
  # A file symlink for the cases that need one, and the clone paths the sections pass to the launchers.
  echo x >"$tmp/link-target"; ln -s "$tmp/link-target" "$tmp/probe-link" 2>/dev/null || :
C=$(wp "$clone"); R=$(wp "$ref"); H=$(wp "$home")
# The -Clone path as the launcher passes it on: Get-FinalPath's form, backslashes on Windows.
if [ -n "$msys" ]; then CF=$(printf '%s' "$C" | tr / '\\'); else CF=$C; fi
}

# --- running the launcher ------------------------------------------------------------------------
PATH_BASE=$PATH
drv_path() { printf '%s' "$stubdir:$PATH_BASE"; }
# run_drv [args...]: the default arguments are overridden by later duplicates, so cases pass full sets with run_with.
run_with() { # run_with <script> <args...>
  s=$1; shift; rc=0
  rm -f "$tmp/git.trace"
  if [ -n "$msys" ]; then tr2=$(wp "$tmp/git.trace"); else tr2=; fi
  PATH=$(drv_path) UP_ID=$ID1 GIT_TRACE2_EVENT=$tr2 "$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$s")" "$@" >"$tmp/out" 2>"$tmp/err" || rc=$?
  # Top-level git processes only (a child's sid holds a /), as "git <argv>" like the stub's line.
  [ ! -e "$tmp/git.trace" ] || jq -r 'select(.event == "start" and (.sid | contains("/") | not)) | "git " + (.argv[1:] | join(" "))' \
    "$tmp/git.trace" | tr -d '\r' >>"$stubdir/git.log"
  [ -z "${LAUNCH_TEST_VERBOSE:-}" ] || echo "# rc=$rc: $(tail -n 1 "$tmp/err" | head -c 300)" >&2
}
run_drv() { run_with "$home/bin/wow-driver.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$home")" "$@"; }
reset() {
  rm -rf "$stubdir"/calls.log "$stubdir"/cwd.log "$stubdir"/ghx.* "$stubdir"/git.log "$stubdir"/n.* "$stubdir"/ps.* "$stubdir"/up.* "$stubdir"/probe.* "$stubdir"/record-at-exec "$stubdir"/it.* "$stubdir"/stop.* "$stubdir"/lanes-at-exec "$stubdir"/spec-* "$stubdir"/moved-wt
  : >"$stubdir/calls.log"; : >"$stubdir/git.log"
  rm -rf "$home/driver"; set_clone
}
calls() { cat "$stubdir/calls.log" 2>/dev/null || true; }
glog() { cat "$stubdir/git.log" 2>/dev/null || true; }
none_called() { [ ! -s "$stubdir/calls.log" ] && [ ! -s "$stubdir/git.log" ]; }
no_it() { ! calls | grep -q ' -it '; }
no_dc() { ! calls | grep -q '^devcontainer '; }
no_gh() { ! calls | grep -q '^gh '; }
# cwd_all <dir> <lines>: exactly that many docker, gh and devcontainer processes logged, each started in <dir>
cwd_all() {
  want=$(norm "$1"); [ "$(wc -l <"$stubdir/cwd.log" 2>/dev/null | tr -d ' ')" -eq "$2" ] || return 1
  while IFS= read -r l; do [ "$(norm "${l#* }")" = "$want" ] || return 1; done <"$stubdir/cwd.log"
}
gh_line() { printf 'gh api --hostname github.com repos/acme/widgets/%s' "$1"; }
err_has() { grep -q -- "$1" "$tmp/err"; }
out_has() { grep -q -- "$1" "$tmp/out"; }
write_record() { # write_record <id> <commit> <clone> [origin]: the four-field record
  mkdir -p "$home/driver"
  printf '{"id":"%s","commit":"%s","clone":"%s","origin":"%s"}\n' "$1" "$2" "$3" "${4:-acme/widgets}" | sed 's,\\,\\\\,g;' >"$home/driver/wb-driver.json"
}
write_record3() { # write_record3 <id> <commit> <clone>: the old three-field record
  mkdir -p "$home/driver"
  printf '{"id":"%s","commit":"%s","clone":"%s"}\n' "$1" "$2" "$3" | sed 's,\\,\\\\,g;' >"$home/driver/wb-driver.json"
}
json_clone() { printf '%s' "$(wp "$clone")" | sed 's,\\,\\\\,g'; }
rec_ok() { # the record holds exactly id, commit, clone, origin, reference
  f=$home/driver/wb-driver.json
  [ -f "$f" ] && jq -e --arg i "$ID1" --arg c "$c2" 'keys == ["clone","commit","id","origin","reference"] and .id == $i and .commit == $c and .origin == "acme/widgets"' "$f" >/dev/null &&
    [ "$(norm "$(jq -r .clone "$f")")" = "$(norm "$(wp "$clone")")" ] &&
    [ "$(norm "$(jq -r .reference "$f")")" = "$(norm "$(wp "$ref")")" ]
}
# The calls other than docker ps, in order.
non_ps() { calls | grep -v '^docker ps '; }
probe_guarded() { case "$probe_script" in *"-e '[v]scode-remote-containers-server' -e '[v]scode-server'"*) return 0 ;; esac; return 1; }
probe_script=$(sed -n 's/^  "\(\/bin\/ls -d .*\)"$/\1/p' "$root_dir/scripts/identity/wow-launch-common.ps1")
rec_ok_commit() { jq -e --arg c "$c2" '.commit == $c' "$home/driver/wb-driver.json" >/dev/null; }
gh_lines() { # the three API reads of a start of day, in order
  gh_line "compare/refs/heads/main...$c2"; echo; gh_line "git/trees/$t2"; echo; gh_line "git/trees/$dc2?recursive=1"; echo
}
exec_line="docker exec -it -u app -e GIT_TERMINAL_PROMPT=0 -w /workspace $ID1 /usr/local/bin/claude --model opus --effort medium Driver for acme/widgets."

running1() { reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; }

# Helpers more than one section uses.
no_dc_exec() { ! calls | grep -q '^devcontainer exec'; }
no_canary() { ! { calls; glog; } | grep -q CANARY; }
# --- wow-lane.ps1 ------------------------------------------------------------------------------------
run_lane() { run_with "$home/bin/wow-lane.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$home")" "$@"; }
LANE_CONTAINER_STAGE=
LHASH=$ID1   # any 64 lowercase hex digits are a valid -Hash
no_app_exec() { ! calls | grep -q ' -u app '; }
no_secretuser() { ! calls | grep -q SECRETUSER; }
no_banned() { ! calls | grep -q '[&|^%!"]'; }
it_line() { calls | grep ' -it '; }
app_execs() { calls | grep ' -u app ' | grep -v ' -it '; }
# app_execs_pinned <n>: exactly n non-interactive -u app execs, each carrying GIT_NO_REPLACE_OBJECTS=1
app_execs_pinned() { [ "$(app_execs | wc -l | tr -d ' ')" -eq "$1" ] && [ "$(app_execs | grep -c -e '-e GIT_NO_REPLACE_OBJECTS=1')" -eq "$1" ]; }
no_effort() { ! it_line | grep -q -e '--effort'; }
exec_shape() { non_ps | awk '{print $2, $3, $4}' | tr '\n' ,; }
# A fake running spec session (#891): an executable shell script named claude, so the kernel records
# claude as its comm, started per case in the background from a subshell that execs it in the given
# directory, so $! is the fake's own process id. Its sleep is bounded as a backstop. A renamed copy of
# the sleep binary would not do: sleep can be a multicall binary that refuses an unknown name.
mk_fake() {
  mkdir -p "$tmp/fakebin"
  printf '%s\n' '#!/bin/sh' "trap 'kill \$c 2>/dev/null; exit 0' TERM" 'sleep 200 &' 'c=$!' 'wait $c' >"$tmp/fakebin/claude"
  chmod +x "$tmp/fakebin/claude"
}
fake_start() { # fake_start <dir>: sets fake_pid; non-zero if the process never reads as claude
  ( cd "$1" && exec "$tmp/fakebin/claude" ) >/dev/null 2>&1 &
  fake_pid=$!; fake_n=0
  until [ "$(cat "/proc/$fake_pid/comm" 2>/dev/null)" = claude ]; do
    fake_n=$((fake_n + 1)); [ "$fake_n" -lt 100 ] || return 1
    sleep 0.1
  done
}
fake_stop() { kill "$fake_pid" 2>/dev/null || :; wait "$fake_pid" 2>/dev/null || :; }
# lane_setup: one running recorded container, a fresh scratch lanes directory with lane 5 prepared (a linked
# worktree of the container clone, and a prompt file), and the container clone's worktree list pruned.
lane_setup() {
  reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"
  rm -rf "$lanes" "$tmp/otherwt" "$stubdir/moved-wt"; $real_git -C "$crepo" worktree prune
  mkdir "$lanes"; chmod 700 "$lanes" # not mkdir -m: MSYS fails it under its /tmp
  printf '%s exited /elsewhere/CANARY-LABEL\n' "$ID3" >"$stubdir/ps.label"
  $real_git -C "$crepo" worktree add -q --detach "$lanes/5" "$c2"
  printf 'CANARY-PROMPT: do things\n' >"$lanes/5-prompt.md"
  PH=$(sha256sum <"$lanes/5-prompt.md" | cut -d' ' -f1)
  cp "$home/driver/wb-driver.json" "$tmp/rec-snap"
}
lane_refuses() { # lane_refuses <label>: exit 1, a reason, no interactive exec
  check "wow-lane refuses ($1): exit 1" test "$rc" -eq 1
  check "wow-lane refuses ($1): says why on stderr" test -s "$tmp/err"
  check "wow-lane refuses ($1): no -it exec" no_it
  [ -z "${LANE_CONTAINER_STAGE:-}" ] || check "wow-lane refuses ($1): no in-container script ran" no_app_exec
  check "wow-lane refuses ($1): the record is not written" sh -c "[ ! -e '$home/driver/wb-driver.json' ] || cmp -s '$tmp/rec-snap' '$home/driver/wb-driver.json'"
}


# --- section: not installed ---
sec_notinst() {
# --- not installed -----------------------------------------------------------------------------
reset
run_with "$root_dir/scripts/identity/wow-driver.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$home")"
check "not installed: a checkout (no MANIFEST) exits 1" test "$rc" -eq 1
check "not installed: ...naming the installed copy" err_has 'installed copy'
check "not installed: ...before any stub call" none_called
for f in wow-driver.ps1 wow-launch-common.ps1; do
  reset; cp "$home/bin/$f" "$tmp/keep"; printf '# edit\n' >>"$home/bin/$f"
  run_drv
  check "not installed: a wrong hash for $f exits 1 before any call" sh -c "test $rc -eq 1 && ! test -s '$stubdir/calls.log' && ! test -s '$stubdir/git.log'"
  cp "$tmp/keep" "$home/bin/$f"
done
reset; cp "$home/bin/MANIFEST" "$tmp/keep"; grep -v ' wow-launch-common.ps1$' "$tmp/keep" >"$home/bin/MANIFEST"
run_drv
check "not installed: a missing MANIFEST row exits 1 before any call" sh -c "test $rc -eq 1 && ! test -s '$stubdir/calls.log'"
cp "$tmp/keep" "$home/bin/MANIFEST"
reset; run_with "$tmp/other/bin/wow-driver.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$home")"
check "not installed: a bin outside -WowHome exits 1" test "$rc" -eq 1
check "not installed: ...before any stub call" none_called
if mklink_dir "$tmp/homelink" "$home"; then
  reset; echo "$ID1 exited" >"$stubdir/ps.vol.1"; echo "$ID1 running" >"$stubdir/ps.vol.3"
  run_with "$home/bin/wow-driver.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$tmp/homelink")"
  check "not installed: a -WowHome reached through a link passes" test "$rc" -eq 7
  check "not installed: ...and its processes (docker, gh and up) run from the final path, not the link" cwd_all "$(wp "$home")" 11
  reset; run_with "$tmp/homelink/bin/wow-driver.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$home")"
  check "not installed: a script run through the link passes the bin check" test "$rc" -ne 1 -o -s "$stubdir/calls.log"
else skip "a directory link cannot be made here; the -WowHome link fixtures did not run"; fi

  :
}

# --- section: bad arguments ---
sec_badargs() {
# --- bad arguments -----------------------------------------------------------------------------
bad_arg() { # bad_arg <label> <args...>: exit 2, a usage line, no stub or git call
  l=$1; shift; reset
  run_with "$home/bin/wow-driver.ps1" "$@"
  check "bad argument: $l exits 2" test "$rc" -eq 2
  check "bad argument: $l prints usage" err_has 'usage: wow-driver.ps1'
  check "bad argument: $l makes no external call" none_called
}
bad_arg 'a missing -Clone' -Reference "$R" -WowHome "$H"
bad_arg 'a missing -Reference' -Clone "$C" -WowHome "$H"
bad_arg 'a relative -Clone' -Clone wb-driver -Reference "$R" -WowHome "$H"
bad_arg 'a -Clone equal to -Reference' -Clone "$R" -Reference "$R" -WowHome "$H"
mkdir -p "$ref/inner-clone"
bad_arg 'a -Clone inside -Reference' -Clone "$(wp "$ref/inner-clone")" -Reference "$R" -WowHome "$H"
bad_arg 'a -Clone containing -Reference' -Clone "$(wp "$tmp/refs")" -Reference "$R" -WowHome "$H"
mkdir -p "$clone/wowh"
bad_arg 'a -Clone containing -WowHome' -Clone "$C" -Reference "$R" -WowHome "$(wp "$clone/wowh")"
mkdir -p "$tmp/wh-parent/wb-inside"
bad_arg 'a -Clone inside -WowHome' -Clone "$(wp "$tmp/wh-parent/wb-inside")" -Reference "$R" -WowHome "$(wp "$tmp/wh-parent")"
bad_arg 'a missing -WowHome directory' -Clone "$C" -Reference "$R" -WowHome "$(wp "$tmp/nothere")"
mkdir -p "$ref/wow-inside"
bad_arg 'a -WowHome inside -Reference' -Clone "$C" -Reference "$R" -WowHome "$(wp "$ref/wow-inside")"
bad_arg 'a -WowHome equal to -Reference' -Clone "$C" -Reference "$R" -WowHome "$R"
mkdir -p "$tmp/clones/.hidden" "$tmp/clones/_under"
bad_arg 'a leaf starting with a dot' -Clone "$(wp "$tmp/clones/.hidden")" -Reference "$R" -WowHome "$H"
bad_arg 'a leaf starting with an underscore' -Clone "$(wp "$tmp/clones/_under")" -Reference "$R" -WowHome "$H"
if [ -d "$tmp/CLONES/wb-driver" ]; then
  bad_arg 'a leaf or parent whose casing differs on disk' -Clone "$(wp "$tmp/clones/WB-DRIVER")" -Reference "$R" -WowHome "$H"
fi
mkdir -p "$tmp/a&b/wb-amp" "$tmp/a%b/wb-pct"
bad_arg 'an & in a parent of -Clone' -Clone "$(wp "$tmp/a&b/wb-amp")" -Reference "$R" -WowHome "$H"
bad_arg 'a % in a parent of -Clone' -Clone "$(wp "$tmp/a%b/wb-pct")" -Reference "$R" -WowHome "$H"
if mklink_dir "$tmp/clones/wb-link" "$clone" && mklink_dir "$tmp/refs/wb-rlink" "$ref"; then
  bad_arg 'a link as -Clone' -Clone "$(wp "$tmp/clones/wb-link")" -Reference "$R" -WowHome "$H"
  bad_arg 'a link as -Reference' -Clone "$C" -Reference "$(wp "$tmp/refs/wb-rlink")" -WowHome "$H"
else skip "a directory link cannot be made here; the link-argument fixtures did not run"; fi
mkdir -p "$tmp/refs/wb-wt"; echo 'gitdir: /nowhere' >"$tmp/refs/wb-wt/.git"
bad_arg 'a -Reference whose .git is a file' -Clone "$C" -Reference "$(wp "$tmp/refs/wb-wt")" -WowHome "$H"
mkdir -p "$tmp/other-parent/wb-driver/.git"; bad_arg 'a -Reference sharing the clone leaf' -Clone "$C" -Reference "$(wp "$tmp/other-parent/wb-driver")" -WowHome "$H"
check "bad argument: the shared leaf is the stated reason" err_has 'share a folder name'
mkdir -p "$tmp/refs/wb-nogit"
bad_arg 'a -Reference with no .git' -Clone "$C" -Reference "$(wp "$tmp/refs/wb-nogit")" -WowHome "$H"
for v in '-x' 'a..b' '/x' 'x/' 'a//b' 'a b' 'a"b' 'a;b'; do
  bad_arg "a bad -Remote ($v)" -Clone "$C" -Reference "$R" -WowHome "$H" -Remote "$v"
  bad_arg "a bad -Base ($v)" -Clone "$C" -Reference "$R" -WowHome "$H" -Base "$v"
done

  :
}

# --- section: start of day, the record and the .devcontainer/ mismatch ---
sec_start() {
# --- start of day ------------------------------------------------------------------------------
start_ok() { # start_ok <label>: the sequence, the record, the exec, the exit code
  check "$1: exits with the session's code" test "$rc" -eq 7
  check "$1: devcontainer up, then the exec, and nothing else between" test "$(non_ps)" = "$(gh_lines)
devcontainer up --skip-post-attach --remove-existing-container --workspace-folder $CF
$exec_line"
  check "$1: six ps calls, two of them after up" test "$(calls | grep -c '^docker ps ')" -eq 6
  check "$1: the last two ps calls follow up" test "$(calls | sed -n '/^devcontainer up/,$p' | grep -c '^docker ps ')" -eq 2
  check "$1: no argv holds & | ^ % ! or a double quote" no_banned
  check "$1: the record is exactly id, commit, clone, origin and reference" rec_ok
  check "$1: the record existed when the session started" test -f "$stubdir/record-at-exec"
  check "$1: docker, gh and up ran from the final -WowHome" cwd_all "$(wp "$home")" 11
  check "$1: no devcontainer exec" no_dc_exec
  check "$1: nothing from the clone, the listings or up reaches an argv" no_canary
}
printf '%s exited /elsewhere/CANARY-LABEL\n' "$ID3" >"$stubdir/ps.label"
for st in none exited created; do
  reset
  printf '%s exited /elsewhere/CANARY-LABEL\n' "$ID3" >"$stubdir/ps.label"
  [ "$st" = none ] || { echo "$ID1 $st" >"$stubdir/ps.vol.1"; echo "$ID1 $st $(wp "$clone")" >"$stubdir/ps.label.1"; }
  echo "$ID1 running" >"$stubdir/ps.vol.3"
  run_drv
  start_ok "start of day ($st)"
  check "start of day ($st): the record line names the container and commit" out_has "started $ID1 from $c2"
done
check "start of day: git ran only in the Reference" sh -c "! grep -q 'wb-driver' '$stubdir/git.log'"

# the record is replaced, atomically, and driver/ is created when absent
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; write_record "$ID2" "$c1" "$(json_clone)"
run_drv
check "start of day: an old record is replaced" rec_ok
check "start of day: no temp file left" test "$(ls -A "$home/driver" | wc -l | tr -d ' ')" -eq 1

# the base binding: gh answers the compare and the two tree reads from the origin's real objects
gh_start() { reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; }
gh_refuses() { # gh_refuses <label> <gh calls made>: exit 1, nothing after the API reads
  check "base binding ($1): exits 1" test "$rc" -eq 1
  check "base binding ($1): $2 gh call(s), no more" test "$(calls | grep -c '^gh ')" -eq "$2"
  check "base binding ($1): no devcontainer call" no_dc
  check "base binding ($1): no -it exec" no_it
  check "base binding ($1): no record" test ! -e "$home/driver/wb-driver.json"
  check "base binding ($1): nothing from the answers is echoed" sh -c "! grep -q 'CANARY\|NOTJSON' '$tmp/err'"
}
gh_start; echo '.status = "behind"' >"$stubdir/ghx.jq.compare"; run_drv
check "base binding: a behind compare passes" test "$rc" -eq 7
check "base binding: ...with the three gh calls before up" test "$(non_ps | head -3)" = "$(gh_lines)"
for st in ahead diverged; do
  gh_start; echo ".status = \"$st\"" >"$stubdir/ghx.jq.compare"; run_drv
  gh_refuses "status $st" 1; check "base binding ($st): names the status" err_has "$st"
done
gh_start; echo 'del(.status)' >"$stubdir/ghx.jq.compare"; run_drv; gh_refuses 'a missing status' 1
gh_start; echo '.status = 7' >"$stubdir/ghx.jq.compare"; run_drv; gh_refuses 'a non-string status' 1
gh_start; echo '.status = "NOTJSON-STATUS"' >"$stubdir/ghx.jq.compare"; run_drv; gh_refuses 'an odd status' 1
check "base binding (an odd status): says it was unreadable" err_has 'unreadable'
gh_start; echo ".merge_base_commit.sha = \"$c1\"" >"$stubdir/ghx.jq.compare"; run_drv; gh_refuses 'another merge-base sha' 1
gh_start; echo 'del(.merge_base_commit)' >"$stubdir/ghx.jq.compare"; run_drv; gh_refuses 'no merge base' 1
gh_start; echo 'not json CANARY' >"$stubdir/ghx.raw.compare"; run_drv; gh_refuses 'non-JSON output' 1
gh_start; echo '[1]' >"$stubdir/ghx.raw.compare"; run_drv; gh_refuses 'a JSON array' 1
gh_start; echo 1 >"$stubdir/ghx.exit"; run_drv; gh_refuses 'a failing gh' 1
check "base binding (a failing gh): names the exit code" err_has 'exit 1'
gh_start; echo '.merge_base_commit.commit.tree.sha = "xyz"' >"$stubdir/ghx.jq.compare"; run_drv; gh_refuses 'a malformed root tree sha' 1
gh_start; echo '.tree |= map(select(.path != "devcontainer.json"))' >"$stubdir/ghx.jq.sub"; run_drv
gh_refuses 'no devcontainer.json committed' 3; check "base binding (no devcontainer.json): names the file" err_has 'devcontainer.json'
gh_start; echo '.truncated = true' >"$stubdir/ghx.jq.root"; run_drv; gh_refuses 'a truncated root tree' 2
gh_start; echo '.truncated = true' >"$stubdir/ghx.jq.sub"; run_drv; gh_refuses 'a truncated subtree' 3
gh_start; echo 'del(.truncated)' >"$stubdir/ghx.jq.sub"; run_drv; gh_refuses 'a subtree with no truncated field' 3
gh_start; echo '.tree |= map(select(.path != ".devcontainer"))' >"$stubdir/ghx.jq.root"; run_drv; gh_refuses 'no .devcontainer entry' 2
gh_start; echo '.tree += [.tree[] | select(.path == ".devcontainer")]' >"$stubdir/ghx.jq.root"; run_drv; gh_refuses 'two .devcontainer entries' 2
gh_start; echo '.tree |= map(if .path == ".devcontainer" then .type = "blob" else . end)' >"$stubdir/ghx.jq.root"; run_drv; gh_refuses '.devcontainer not a tree' 2
gh_start; echo '.tree += [{mode:"120000",type:"blob",sha:"'"$dc2"'",path:"link"}]' >"$stubdir/ghx.jq.sub"; run_drv; gh_refuses 'a symlink entry' 3
check "base binding (a symlink entry): names it" err_has 'link'
gh_start; echo '.tree += [{mode:"160000",type:"commit",sha:"'"$dc2"'",path:"sm"}]' >"$stubdir/ghx.jq.sub"; run_drv; gh_refuses 'a submodule entry' 3
gh_start; echo '.tree += [{mode:"100644",type:"blob",sha:"'"$dc2"'",path:"a b"}]' >"$stubdir/ghx.jq.sub"; run_drv; gh_refuses 'a path outside the disk-name rule' 3
gh_start; echo '.tree |= map(del(.sha))' >"$stubdir/ghx.jq.sub"; run_drv; gh_refuses 'entries with no sha' 3
# the API reason wins over a clone mismatch
gh_start; echo '.status = "ahead"' >"$stubdir/ghx.jq.compare"; echo x >"$clone/.devcontainer/extra.txt"; run_drv
gh_refuses 'with the clone also mismatched' 1; check "base binding: the API reason is the one named" sh -c "grep -q ahead '$tmp/err' && ! grep -q extra.txt '$tmp/err'"
# started from inside the Clone, every process still runs from the final -WowHome
gh_start; cd "$clone"; run_drv; cd "$tmp"
check "base binding: started inside the Clone, exits with the session's code" test "$rc" -eq 7
check "base binding: ...docker, gh and up ran from -WowHome, not the Clone" cwd_all "$(wp "$home")" 11

# .devcontainer/ mismatch: refuses naming the file, before any devcontainer call
mismatch() { # mismatch <label> <mutation command...>
  l=$1; shift; reset; "$@"
  run_drv
  check "mismatch ($l): exits 1" test "$rc" -eq 1
  check "mismatch ($l): names a .devcontainer/ file" err_has 'Dockerfile\|sub/x.sh\|extra.txt\|devcontainer'
  check "mismatch ($l): no devcontainer call" no_dc
  check "mismatch ($l): no -it exec" no_it
  check "mismatch ($l): no record" test ! -e "$home/driver/wb-driver.json"
}
mismatch 'a changed byte' sh -c "printf 'X' >>'$clone/.devcontainer/sub/x.sh'"
mismatch 'an extra file' sh -c "echo x >'$clone/.devcontainer/extra.txt'"
# A case-insensitive folder (NTFS) cannot hold both names: the cp would fail and the evil byte alone would refuse.
if [ -d "$tmp/CLONES" ]; then skip "a case-insensitive file system; the case-variant fixture did not run"
else mismatch 'a case variant of a committed file' sh -c "cp '$clone/.devcontainer/Dockerfile' '$clone/.devcontainer/dockerfile' && echo evil >>'$clone/.devcontainer/Dockerfile'"; fi
mismatch 'a near-duplicate name (soft hyphen)' sh -c "cp '$clone/.devcontainer/Dockerfile' \"$clone/.devcontainer/Docker\$(printf '\\302\\255')file\"; echo evil >>'$clone/.devcontainer/Dockerfile'"
mismatch 'a missing file' rm "$clone/.devcontainer/sub/x.sh"
mismatch 'a CRLF checkout' sh -c "sed 's/\$/\r/' '$seed/.devcontainer/sub/x.sh' >'$clone/.devcontainer/sub/x.sh'"
if [ -L "$tmp/probe-link" ]; then
  mismatch 'a link under it' sh -c "rm '$clone/.devcontainer/sub/x.sh' && ln -s '$tmp/link-target' '$clone/.devcontainer/sub/x.sh'"
else skip "a file symlink cannot be made here; the link-under-it fixture did not run"; fi
dc_as_link() { mv "$clone/.devcontainer" "$tmp/dc-moved" && mklink_dir "$clone/.devcontainer" "$tmp/dc-moved"; }
if mklink_dir "$tmp/probe-dlink" "$tmp/refs"; then
  mismatch 'a link as the directory' dc_as_link
else skip "a directory link cannot be made here; the link-as-the-directory fixture did not run"; fi
rm -rf "$tmp/dc-moved"

  :
}

# --- section: refusals by label, after up, edit after up ---
sec_startb() {
# containers found only by label, or on the Reference
reset; echo "$ID1 running $(wp "$clone")" >"$stubdir/ps.label.1"
run_drv
check "label only: a running container found only by label refuses (exit 1)" test "$rc" -eq 1
check "label only: ...with no devcontainer call" no_dc
reset; echo "$ID2 running" >"$stubdir/ps.vol.2"
run_drv
check "Reference volume: a container on the Reference's volume refuses" test "$rc" -eq 1
check "Reference volume: ...before devcontainer and before the fetch" sh -c "! grep -q '^devcontainer' '$stubdir/calls.log' && ! grep -q ' fetch ' '$stubdir/git.log'"
reset; echo "$ID2 exited $(wp "$ref")" >"$stubdir/ps.label.2"
run_drv
check "Reference label: a container labelled with the Reference refuses" test "$rc" -eq 1
check "Reference label: ...before devcontainer and before the fetch" sh -c "! grep -q '^devcontainer' '$stubdir/calls.log' && ! grep -q ' fetch ' '$stubdir/git.log'"
# the same, on the attach path
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; echo "$ID2 running" >"$stubdir/ps.vol.2"; write_record "$ID1" "$c2" "$(json_clone)"
run_drv
check "Reference volume: attach refuses too, before the fetch" sh -c "test $rc -eq 1 && ! grep -q ' fetch ' '$stubdir/git.log' && ! grep -q ' -it ' '$stubdir/calls.log'"

# after up
after_up() { # after_up <label> <setup command...>: refuses, no -it exec, record unchanged or absent
  l=$1; shift; reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; "$@"
  run_drv
  check "after up ($l): exits 1" test "$rc" -eq 1
  check "after up ($l): no -it exec" no_it
  if [ -e "$tmp/snap" ]; then check "after up ($l): the old record is byte-identical" cmp -s "$tmp/snap" "$home/driver/wb-driver.json"
  else check "after up ($l): no record" test ! -e "$home/driver/wb-driver.json"; fi
  rm -f "$tmp/snap"
}
keep_record() { write_record "$ID2" "$c1" "$(json_clone)"; cp "$home/driver/wb-driver.json" "$tmp/snap"; }
after_up 'no JSON result' sh -c "echo 'not json' >'$stubdir/up.out'"
after_up 'empty output' sh -c ": >'$stubdir/up.out'"
after_up 'a failed up' sh -c "echo 1 >'$stubdir/up.exit'"
after_up 'a non-success outcome' sh -c "printf '{\"outcome\":\"error\",\"containerId\":\"%s\"}\n' $ID1 >'$stubdir/up.out'"
after_up 'a short id' sh -c "printf '{\"outcome\":\"success\",\"containerId\":\"abc\"}\n' >'$stubdir/up.out'"
after_up 'no id' sh -c "printf '{\"outcome\":\"success\"}\n' >'$stubdir/up.out'"
after_up 'a re-list with another id' sh -c "echo '$ID2 running' >'$stubdir/ps.vol.3'"
after_up 'a re-list not running' sh -c "echo '$ID1 exited' >'$stubdir/ps.vol.3'"
after_up 'a re-list with nothing' sh -c ": >'$stubdir/ps.vol.3'"
# the old record is kept byte-identical when the run refuses
reset; echo bad >"$stubdir/up.out"; keep_record; run_drv
check "after up: an old record is byte-identical after a refusal" cmp -s "$tmp/snap" "$home/driver/wb-driver.json"; rm -f "$tmp/snap"
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; echo "$ID2 running $(wp "$clone")" >"$stubdir/ps.label.3"
run_drv
check "after up: a re-list with two containers (volume and label) refuses" test "$rc" -eq 1
check "after up: ...naming both ids" sh -c "grep -q $ID1 '$tmp/err' && grep -q $ID2 '$tmp/err'"
check "after up: ...with no record and no -it exec" sh -c "test ! -e '$home/driver/wb-driver.json' && ! grep -q ' -it ' '$stubdir/calls.log'"

# edit after up: a byte changed under .devcontainer/ by up changes nothing that reaches argv
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"
printf '#!/bin/sh\necho CANARY-EDIT >>"%s/.devcontainer/Dockerfile"\n' "$clone" >"$stubdir/up.hook"
run_drv
check "edit after up: still only the validated exec" test "$rc" -eq 7 -a "$(non_ps | tail -1)" = "$exec_line"
check "edit after up: nothing from the file in any argv" no_canary

  :
}

# --- section: attach ---
sec_attach() {
# --- attach ------------------------------------------------------------------------------------
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"
run_drv
check "attach: exits with the session's code" test "$rc" -eq 7
check "attach: no devcontainer call" no_dc
check "attach: probe, then the exec, with the recorded id" test "$(non_ps)" = "docker exec -u root $ID1 /bin/sh -c $probe_script
$exec_line"
check "attach: the probe script has none of & | ^ % or a double quote" sh -c "! printf '%s' '$probe_script' | grep -q '[&|^%\"]'"
check "attach: the probe uses the [v] self-match guard on both patterns" probe_guarded
check "attach: prints the record's commit" out_has "attaching to $ID1, created from $c2"
check "attach: no warning for an unchanged .devcontainer/" sh -c "! grep -q 'has changed since' '$tmp/out'"
check "attach: no compare and no git argv names the Clone" sh -c "! grep -q 'wb-driver' '$stubdir/git.log'"
check "attach: no gh call" no_gh
check "attach: no recreate" sh -c "! grep -q 'remove-existing' '$stubdir/calls.log'"
check "attach: the record is untouched" rec_ok_commit
running1; write_record "$ID1" "$c1" "$(json_clone)"
run_drv
check "attach: an older commit with another .devcontainer tree warns" out_has 'has changed since'
check "attach: ...and still execs" test "$rc" -eq 7
e=$(printf '%040d' 0 | tr 0 e)
running1; write_record "$ID1" "$e" "$(json_clone)"
run_drv
check "attach: a record commit the Reference lacks prints unknown" out_has 'unknown'
check "attach: ...still execs and passes the exit code through" test "$rc" -eq 7

attach_refuses() { # attach_refuses <label>: exit 1, no devcontainer, no -it
  check "attach refuses ($1): exit 1" test "$rc" -eq 1
  check "attach refuses ($1): no devcontainer call" no_dc
  check "attach refuses ($1): no -it exec" no_it
  check "attach refuses ($1): says why on stderr" test -s "$tmp/err"
}
running1; write_record "$ID2" "$c2" "$(json_clone)"; run_drv; attach_refuses 'a mismatched record'
running1; run_drv; attach_refuses 'a missing record'
running1; mkdir -p "$home/driver"; echo '{"id":"x"}' >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'a missing field'
running1; mkdir -p "$home/driver"
printf '{"id":"%s","commit":"%s","clone":"%s","origin":"acme/widgets","extra":"1"}\n' "$ID1" "$c2" "$(json_clone)" >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'an extra field'
running1; mkdir -p "$home/driver"
printf '{"id":"abc","commit":"%s","clone":"%s","origin":"acme/widgets"}\n' "$c2" "$(json_clone)" >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'a short id'
running1; mkdir -p "$home/driver"
printf '{"id":"%s","commit":"%s","clone":"%s","origin":"acme/widgets"}\n' "$(echo "$ID1" | tr a A)" "$c2" "$(json_clone)" >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'an uppercase id'
running1; mkdir -p "$home/driver"
printf '{"id":"%s","commit":"%s","clone":"%s","origin":"acme/widgets"}\n' "$ID1" "$(echo "$c2" | cut -c1-12)" "$(json_clone)" >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'a short commit'
running1; mkdir -p "$home/driver"; echo 'not json' >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'not JSON'
running1; mkdir -p "$home/driver"; echo '[1,2]' >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'a JSON array'
running1; mkdir -p "$home/driver"
printf '{"id":1,"commit":"%s","clone":"%s","origin":"acme/widgets"}\n' "$c2" "$(json_clone)" >"$home/driver/wb-driver.json"; run_drv; attach_refuses 'a non-string id'
running1; write_record "$ID1" "$c2" "$(wp "$tmp/clones/elsewhere" | sed 's,\\,\\\\,g')"; run_drv; attach_refuses "another clone's record"
running1; write_record "$ID1" "$c2" "$(json_clone)"; echo "dirty" >"$stubdir/probe.out"; run_drv; attach_refuses 'a probe that prints a line'
check "attach refuses: ...naming the VS Code attach" err_has 'VS Code'
running1; write_record "$ID1" "$c2" "$(json_clone)"; echo 1 >"$stubdir/probe.exit"; run_drv; attach_refuses 'a probe that exits 1'
running1; write_record "$ID1" "$c2" "$(json_clone)"; echo "$ID2 running" >>"$stubdir/ps.vol.1"; run_drv; attach_refuses 'two containers'
check "attach refuses (two containers): ...naming both ids" sh -c "grep -q $ID1 '$tmp/err' && grep -q $ID2 '$tmp/err'"
running1; write_record "$ID1" "$c2" "$(json_clone)"; echo "$ID2 exited" >>"$stubdir/ps.vol.1"; run_drv; attach_refuses 'a running and an exited container'
for st in restarting paused dead removing; do
  reset; echo "$ID1 $st" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"; run_drv; attach_refuses "state $st"
done
running1; write_record "$ID1" "$c2" "$(json_clone)"; echo 1 >"$stubdir/ps.exit"; run_drv; attach_refuses 'a failed docker ps with empty stdout'
reset; echo 1 >"$stubdir/ps.exit"; run_drv
check "failed ps (start of day): exit 1, never read as zero containers" test "$rc" -eq 1 -a "$(calls | grep -c '^devcontainer')" -eq 0
reset; printf 'garbage line\n' >"$stubdir/ps.vol.1"; run_drv
check "unreadable ps line: exit 1 with no devcontainer call" test "$rc" -eq 1 -a "$(calls | grep -c '^devcontainer')" -eq 0
reset; printf '%s running\n\n' "$ID1" >"$stubdir/ps.vol.1"; run_drv
check "blank ps line: exit 1 with no devcontainer call" test "$rc" -eq 1 -a "$(calls | grep -c '^devcontainer')" -eq 0

# missing tool: yq off PATH
nobin="$tmp/nobin"; mkdir "$nobin"
for t in sh cat cp env dirname uname rm mkdir sed grep tr; do p=$(command -v "$t") && ln -s "$p" "$nobin/$t"; done
# On MSYS git has no stub, so its own directory (no yq in it) stands in for the stub.
nopath="$stubdir:$nobin"; [ -z "$msys" ] || nopath="$nopath:$(dirname "$real_git")"
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"
rc=0; PATH="$nopath" "$pwsh_abs" -NoProfile -NonInteractive -File "$(wp "$home/bin/wow-driver.ps1")" -Clone "$C" -Reference "$R" -WowHome "$H" >"$tmp/out" 2>"$tmp/err" || rc=$?
check "missing tool: yq off PATH exits 1" test "$rc" -eq 1
check "missing tool: ...naming yq" err_has 'yq not found'
check "missing tool: ...before any docker call" none_called

  :
}

# --- section: wow-lane: not installed and bad arguments ---
sec_lanea() {
# not installed
reset; rm -f "$tmp/rec-snap"
run_with "$root_dir/scripts/identity/wow-lane.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$home")" -Issue 5 -Hash "$LHASH"
check "wow-lane not installed: a checkout (no MANIFEST) exits 1" test "$rc" -eq 1
check "wow-lane not installed: ...naming the installed copy" err_has 'installed copy'
check "wow-lane not installed: ...before any stub or git call" none_called
for f in wow-lane.ps1 wow-launch-common.ps1; do
  reset; cp "$home/bin/$f" "$tmp/keep"; printf '# edit\n' >>"$home/bin/$f"
  run_lane -Issue 5 -Hash "$LHASH"
  check "wow-lane not installed: a wrong hash for $f exits 1 before any call" sh -c "test $rc -eq 1 && ! test -s '$stubdir/calls.log' && ! test -s '$stubdir/git.log'"
  cp "$tmp/keep" "$home/bin/$f"
done
reset; cp "$home/bin/MANIFEST" "$tmp/keep"; grep -v ' wow-lane.ps1$' "$tmp/keep" >"$home/bin/MANIFEST"
run_lane -Issue 5 -Hash "$LHASH"
check "wow-lane not installed: a missing wow-lane.ps1 row exits 1 before any call" sh -c "test $rc -eq 1 && ! test -s '$stubdir/calls.log' && ! test -s '$stubdir/git.log'"
cp "$tmp/keep" "$home/bin/MANIFEST"
reset; run_with "$tmp/other/bin/wow-lane.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$home")" -Issue 5 -Hash "$LHASH"
check "wow-lane not installed: a bin outside -WowHome exits 1" test "$rc" -eq 1
check "wow-lane not installed: ...before any stub or git call" none_called
reset; run_with "$home/bin/wow-lane.ps1" -Clone "$(wp "$clone")" -Reference "$(wp "$ref")" -WowHome "$(wp "$tmp/nothere")" -Issue 5 -Hash "$LHASH"
check "wow-lane: a bad -WowHome exits 2 before the installed-copy check" test "$rc" -eq 2

# bad arguments
bad_lane() { # bad_lane <label> <args...>: exit 2, a usage line, no stub or git call
  l=$1; shift; reset
  run_with "$home/bin/wow-lane.ps1" "$@"
  check "wow-lane bad argument: $l exits 2" test "$rc" -eq 2
  check "wow-lane bad argument: $l prints usage" err_has 'usage: wow-lane.ps1'
  check "wow-lane bad argument: $l makes no external call" none_called
}
bad_lane 'no mode' -Clone "$C" -Reference "$R" -WowHome "$H"
bad_lane 'both modes' -Clone "$C" -Reference "$R" -WowHome "$H" -Issue 5 -Hash "$LHASH" -Spec 7
bad_lane '-SpecSweep with -Spec' -Clone "$C" -Reference "$R" -WowHome "$H" -SpecSweep -Spec 7
bad_lane '-SpecSweep with -Issue' -Clone "$C" -Reference "$R" -WowHome "$H" -SpecSweep -Issue 5
bad_lane '-SpecSweep with -Hash' -Clone "$C" -Reference "$R" -WowHome "$H" -SpecSweep -Hash "$LHASH"
bad_lane '-SpecSweep with -Issue and -Hash' -Clone "$C" -Reference "$R" -WowHome "$H" -SpecSweep -Issue 5 -Hash "$LHASH"
bad_lane '-Hash alone' -Clone "$C" -Reference "$R" -WowHome "$H" -Hash "$LHASH"
bad_lane '-Issue alone' -Clone "$C" -Reference "$R" -WowHome "$H" -Issue 5
bad_lane '-Spec with -Hash' -Clone "$C" -Reference "$R" -WowHome "$H" -Spec 7 -Hash "$LHASH"
for v in 0 07 1a 1234567890 ' 5'; do
  bad_lane "-Issue '$v'" -Clone "$C" -Reference "$R" -WowHome "$H" -Issue "$v" -Hash "$LHASH"
done
for v in abc "$(echo "$ID1" | cut -c1-63)" "$(echo "$ID1" | tr a A)" "$(echo "$ID1" | tr a g)" "${ID1}a"; do
  bad_lane "-Hash '$v'" -Clone "$C" -Reference "$R" -WowHome "$H" -Issue 5 -Hash "$v"
done
for v in '' '1,,2' ',1' '1,' '1,1' '1,2,3,4,5,6,7,8,9,10,11' '1;2' '1 2' '0' '07,8'; do
  bad_lane "-Spec '$v'" -Clone "$C" -Reference "$R" -WowHome "$H" -Spec "$v"
done
bad_lane 'a missing -Clone' -Reference "$R" -WowHome "$H" -Issue 5 -Hash "$LHASH"
bad_lane 'a -Clone equal to -Reference' -Clone "$R" -Reference "$R" -WowHome "$H" -Spec 7
bad_lane 'a bad -Remote' -Clone "$C" -Reference "$R" -WowHome "$H" -Spec 7 -Remote 'a b'
bad_lane 'a bad -Base' -Clone "$C" -Reference "$R" -WowHome "$H" -Spec 7 -Base 'a"b'

  :
}

# --- section: wow-lane: container, record and probe refusals ---
sec_laneb() {
# container and record refusals: no interactive exec, no in-container script, no record written
LANE_CONTAINER_STAGE=1
lane_setup; : >"$stubdir/ps.vol.1"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'zero containers'; check "wow-lane refuses (zero containers): ...no in-container script ran" no_app_exec
check "wow-lane refuses (zero containers): ...pointing at the driver launcher" err_has 'wow-driver.ps1'
lane_setup; echo "$ID1 exited" >"$stubdir/ps.vol.1"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'one exited container'; check "wow-lane refuses (exited): ...no in-container script ran" no_app_exec
lane_setup; echo "$ID2 running" >>"$stubdir/ps.vol.1"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'two containers'; check "wow-lane refuses (two): ...naming both ids" sh -c "grep -q $ID1 '$tmp/err' && grep -q $ID2 '$tmp/err'"
lane_setup; echo "$ID1 paused" >"$stubdir/ps.vol.1"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'a paused container'
lane_setup; echo "$ID2 running" >"$stubdir/ps.vol.2"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'a container on the Reference'; check "wow-lane refuses (Reference): ...before the fetch" sh -c "! grep -q ' fetch ' '$stubdir/git.log'"
lane_setup; rm -f "$home/driver/wb-driver.json"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'a missing record'; check "wow-lane refuses (no record): ...none written" test ! -e "$home/driver/wb-driver.json"
lane_setup; write_record "$ID2" "$c2" "$(json_clone)"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'a record naming another container'
lane_setup; write_record "$ID1" "$c2" "$(wp "$tmp/clones/elsewhere" | sed 's,\\,\\\\,g')"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'a record naming another clone'
lane_setup; echo dirty >"$stubdir/probe.out"; run_lane -Issue 5 -Hash "$PH"
lane_refuses 'a dirty relay probe'; check "wow-lane refuses (probe): ...naming the VS Code attach" err_has 'VS Code'
check "wow-lane refuses (probe): ...no in-container script ran" no_app_exec

LANE_CONTAINER_STAGE=
# the lane probe, run for real against the scratch lanes directory
probe_refuses() { # probe_refuses <label> <reason text>
  lane_refuses "$1"; check "wow-lane refuses ($1): ...naming its reason" err_has "$2"
}
lane_setup; rm -rf "$lanes"; run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the lanes directory missing' 'in the container is missing, a link'
lane_setup; mv "$lanes" "$tmp/lanes.real"
if mklink_dir "$lanes" "$tmp/lanes.real"; then
  run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the lanes directory a link' 'in the container is missing, a link'
else skip "a directory link cannot be made here; the lanes-directory link fixture did not run"; fi
rm -rf "$lanes" "$tmp/lanes.real"; $real_git -C "$crepo" worktree prune
lane_setup; rm -rf "$lanes"; $real_git -C "$crepo" worktree prune
# The probe maps both lw=unsafe and lw=missing to unsafe-dir, so this fixture cannot tell the guard's link
# branch from its missing branch. The sweep dangling-link fixture (sec_laned, not run under MSYS) and the
# static guard_order check are what pin test -L before test -e.
if mklink_dir "$lanes" "$tmp/lanes.gone"; then
  run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the lanes directory a link to a missing target' 'in the container is missing, a link'
else skip "a directory link to a missing target cannot be made here (on MSYS, New-Item may refuse a junction whose target does not exist); the probe dangling-link fixture did not run"; fi
rm -rf "$lanes"; $real_git -C "$crepo" worktree prune
lane_setup; : >"$stubdir/it.owner"; run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the lanes directory not owned by the user' 'in the container is missing, a link'
rm -f "$stubdir/it.owner"
lane_setup; $real_git -C "$crepo" worktree remove --force "$lanes/5"; run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the worktree missing' 'is not a worktree'
lane_setup; rm "$lanes/5/.git"; run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the worktree with no .git file' 'is not a worktree'
lane_setup; rm -rf "$lanes/5/.git"; mkdir "$lanes/5/.git"; run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the worktree .git a directory' 'is not a worktree'
lane_setup; rm -f "$lanes/5-prompt.md"; run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the prompt missing' 'is not a regular file'
if [ -L "$tmp/probe-link" ]; then
  lane_setup; mv "$lanes/5-prompt.md" "$tmp/prompt-real"; ln -s "$tmp/prompt-real" "$lanes/5-prompt.md"
  run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the prompt a link' 'is not a regular file'
  lane_setup; mv "$lanes/5" "$tmp/wt-real"; ln -s "$tmp/wt-real" "$lanes/5"
  run_lane -Issue 5 -Hash "$PH"; probe_refuses 'the worktree a link' 'is not a worktree'
  rm -rf "$lanes/5" "$tmp/wt-real"; $real_git -C "$crepo" worktree prune
else skip "a file symlink cannot be made here; the prompt-link and worktree-link fixtures did not run"; fi
lane_setup; run_lane -Issue 5 -Hash "$(echo "$PH" | tr 0-9a-f 1-9a-f0)"; probe_refuses 'a hash mismatch' 'does not hash'

  :
}

# --- section: wow-lane: happy paths, kept worktrees and static shape ---
sec_lanec() {
# lane happy path
lane_setup; run_lane -Issue 5 -Hash "$PH"
lane_msg="Lane: #5 in acme/widgets. In one Bash call, run: T=\$(mktemp -d); cp /tmp/lanes/5-prompt.md \$T/p.md; sha256sum \$T/p.md; echo \$T/p.md. Stop unless that call printed the hash $PH. If it did, read only that copy and follow it."
check "wow-lane lane: exits with the session's code" test "$rc" -eq 7
check "wow-lane lane: the interactive argv is exactly the declared one" test "$(non_ps | tail -1)" = "docker exec -it -u app -e GIT_TERMINAL_PROMPT=0 -w /tmp/lanes/5 $ID1 /usr/local/bin/claude --model sonnet $lane_msg"
check "wow-lane lane: relay probe, in-container probe, then the session, and nothing else" test "$(exec_shape)" = "exec -u root,exec -u app,exec -it -u,"
check "wow-lane lane: the one in-container exec carries GIT_NO_REPLACE_OBJECTS=1" app_execs_pinned 1
check "wow-lane lane: no --effort" no_effort
check "wow-lane lane: no devcontainer call" no_dc
check "wow-lane lane: no argv holds & | ^ % ! or a double quote" no_banned
check "wow-lane lane: nothing from the prompt file or the listings reaches an argv" no_canary
check "wow-lane lane: the record is byte-identical afterwards" cmp -s "$tmp/rec-snap" "$home/driver/wb-driver.json"
check "wow-lane lane: no devcontainer exec" no_dc_exec

# spec happy path: a hook looks at the lanes directory while the session runs
spec_setup() { lane_setup; rm -rf "$lanes/5" "$lanes/5-prompt.md"; $real_git -C "$crepo" worktree prune; }
spec_left() { ls "$lanes" | grep -q '^spec-'; }
not_spec_left() { ! spec_left; }
cat >"$tmp/hook.ok" <<'HOOK'
for w in "$STUB_LANES"/spec-*; do
  git -C "$w" rev-parse HEAD >"$STUB_DIR/spec-head"
  git -C "$w" symbolic-ref -q HEAD >"$STUB_DIR/spec-symref" 2>/dev/null || echo detached >"$STUB_DIR/spec-symref"
  basename "$w" >"$STUB_DIR/spec-leaf"
  cp "$STUB_LANES/record-$(basename "$w")" "$STUB_DIR/spec-record" 2>/dev/null || :
done
HOOK
spec_setup; cp "$tmp/hook.ok" "$stubdir/it.hook"; run_lane -Spec 12,7,30
spec_line="docker exec -it -u app -e GIT_TERMINAL_PROMPT=0 -w /tmp/lanes/spec-[a-z0-9]{6} $ID1 /usr/local/bin/claude --model opus --effort high Spec: #12, #7, #30 in acme/widgets. Run /way-of-working:spec-task for each of these issues, one at a time, in this order: 12, 7, 30. Build nothing, and start no build for any of them.\$"
check "wow-lane spec: exits with the session's code" test "$rc" -eq 7
spec_it_ok() { it_line | grep -E -q -e "^$spec_line"; }
spec_seen() { # the hook saw a detached worktree at the Reference's commit, under the leaf the argv names
  l=$(cat "$stubdir/spec-leaf" 2>/dev/null) || return 1
  [ "$(cat "$stubdir/spec-head")" = "$c2" ] && [ "$(cat "$stubdir/spec-symref")" = detached ] &&
    printf '%s\n' "$l" | grep -q -x -E 'spec-[a-z0-9]{6}' && grep -q -x "$l" "$stubdir/lanes-at-exec" &&
    it_line | grep -q -e "-w /tmp/lanes/$l "
}
check "wow-lane spec: the interactive argv is the declared one, issues in the given order" spec_it_ok
check "wow-lane spec: a detached worktree at the Reference's commit existed under the leaf the argv names" spec_seen
check "wow-lane spec: both non-interactive execs carry GIT_NO_REPLACE_OBJECTS=1" app_execs_pinned 2
check "wow-lane spec: the worktree is gone afterwards" not_spec_left
check "wow-lane spec: ...and no worktree of the container clone is left but its own" test "$($real_git -C "$crepo" worktree list | wc -l | tr -d ' ')" -eq 1
check "wow-lane spec: no argv holds & | ^ % ! or a double quote" no_banned
check "wow-lane spec: the record is byte-identical afterwards" cmp -s "$tmp/rec-snap" "$home/driver/wb-driver.json"
spec_record_ok() { # the spec record seen while the session ran: the list, a space, whole seconds near now
  r=$(cat "$stubdir/spec-record" 2>/dev/null) || return 1
  case $r in "12,7,30 "*) ;; *) return 1 ;; esac
  s=${r#12,7,30 }; case $s in ''|*[!0-9]*) return 1 ;; esac
  now=$(date +%s); [ "$s" -le "$now" ] && [ $((now - s)) -lt 600 ]
}
check "wow-lane spec: the record held the list and the launch seconds while the session ran" spec_record_ok
no_record_left() { ! ls "$lanes" | grep -q '^record-'; }
check "wow-lane spec: the record is gone after a clean exit" no_record_left
spec_setup; cp "$tmp/hook.ok" "$stubdir/it.hook"; run_lane -Spec 9
one_issue() { it_line | grep -q -e 'in this order: 9\. Build nothing'; }
check "wow-lane spec: a single issue is named alone" one_issue

# spec refusals
spec_setup; STUB_REPO=$(wp "$crepo2"); run_lane -Spec 7; STUB_REPO=$(wp "$crepo")
lane_refuses 'the container clone origin/main at another commit (base-moved)'
check "wow-lane refuses (base-moved): ...naming the base" err_has 'origin/main'
check "wow-lane refuses (base-moved): ...no worktree or leaf directory left" not_spec_left
check "wow-lane refuses (base-moved): ...no registered worktree" test "$($real_git -C "$crepo2" worktree list | wc -l | tr -d ' ')" -eq 1
# kept worktrees: exit 1, the path named, and the worktree is not forced away
kept_check() { # kept_check <label>
  check "wow-lane kept ($1): exits 1 although the session exited 7" test "$rc" -eq 1
  check "wow-lane kept ($1): the kept path is named" err_has '/tmp/lanes/spec-'
  check "wow-lane kept ($1): ...with the hand removal" err_has 'worktree remove --force'
}
spec_setup
printf '%s\n' 'for w in "$STUB_LANES"/spec-*; do echo x >"$w/untracked"; done' >"$stubdir/it.hook"
run_lane -Spec 7; kept_check 'an untracked file'
untracked_kept() { ls "$lanes"/spec-*/untracked >/dev/null 2>&1; }
check "wow-lane kept (untracked): the worktree and the file are still there" untracked_kept
record_kept() { ls "$lanes"/record-spec-* >/dev/null 2>&1; }
check "wow-lane kept (untracked): the record is still there" record_kept
check "wow-lane kept (untracked): ...with its own removal line" err_has 'rm /tmp/lanes/record-spec-'
spec_setup; $real_git -C "$crepo" worktree add -q --detach "$tmp/otherwt" "$c2"
if [ -L "$tmp/probe-link" ]; then
  printf '%s\n' 'for w in "$STUB_LANES"/spec-*; do mv "$w" "$STUB_DIR/moved-wt"; ln -s "$STUB_OTHER" "$w"; done' >"$stubdir/it.hook"
  STUB_OTHER=$tmp/otherwt; export STUB_OTHER; run_lane -Spec 7; kept_check 'the worktree replaced by a link'
  check "wow-lane kept (link): the other worktree is still present" test -f "$tmp/otherwt/.git"
  for w in "$lanes"/spec-*; do rm -f "$w"; done
else skip "a file symlink cannot be made here; the replaced-by-a-link fixture did not run"; fi
$real_git -C "$crepo" worktree remove --force "$tmp/otherwt" || true
spec_setup
printf '%s\n' "for w in \"\$STUB_LANES\"/spec-*; do git -C \"\$w\" checkout -q --detach $c1; done" >"$stubdir/it.hook"
run_lane -Spec 7; kept_check 'HEAD moved to another commit'
check "wow-lane kept (HEAD moved): the worktree is still there" spec_left
# the shared lanes-directory guard in the prep and the cleanup: not owned by the user, and missing
spec_setup; : >"$stubdir/it.owner"; run_lane -Spec 7
lane_refuses 'the lanes directory not owned by the user (spec prep)'
check "wow-lane refuses (spec prep, not owned): ...naming its reason" err_has 'not owned by the container user, or cannot be made'
check "wow-lane refuses (spec prep, not owned): ...no spec leaf made" not_spec_left
rm -f "$stubdir/it.owner"
spec_setup; printf '%s\n' ': >"$STUB_DIR/it.owner"' >"$stubdir/it.hook"
run_lane -Spec 7; kept_check 'the lanes directory not owned by the user'
rm -f "$stubdir/it.owner"; for w in "$lanes"/spec-*; do $real_git -C "$crepo" worktree remove --force "$w"; done
spec_setup; rm -rf "$lanes"; cp "$tmp/hook.ok" "$stubdir/it.hook"; run_lane -Spec 7
check "wow-lane spec (the lanes directory missing): the prep makes it and the session runs" test "$rc" -eq 7
check "wow-lane spec (the lanes directory missing): a detached worktree existed during the session" spec_seen
rm -rf "$lanes"; $real_git -C "$crepo" worktree prune

# static shape of the five scripts and the three message templates
lane_fn() { sed -n "/^function $1 /,/^}/p" "$root_dir/scripts/identity/wow-lane.ps1"; }
lane_line() { lane_fn "$1" | sed -n 2p; }
clean_line() { # no & | ^ % ! or double quote, and no single quote between the outer pair
  ! printf '%s\n' "$1" | grep -q '[&|^%!"]' && ! printf '%s\n' "$1" | sed "s/^  '//; s/'\$//" | grep -q "'"
}
one_quoted() { lane_line "$1" | grep -q "^  '.*'\$"; }
# the shared lanes-directory guard: one single-quoted line every script starts with
guard_line() { grep -E "^[\$]script:LanesGuard = '.*'\$" "$root_dir/scripts/identity/wow-lane.ps1" | sed "s/^[^']*'//; s/'\$//"; }
starts_set_f() { guard_line | grep -q "^set -f; "; }
check "static: the shared lanes-directory guard exists as one single-quoted line" test "$(guard_line | wc -l | tr -d ' ')" -eq 1
check "static: the guard holds none of & | ^ % ! or a double quote, nor an inner single quote" clean_line "$(guard_line)"
check "static: the guard starts with set -f" starts_set_f
guard_order() { # test -L $L comes before test -e $L
  g=$(guard_line); a=${g%%test -L \$L*}; b=${g%%test -e \$L*}
  [ "${#a}" -lt "${#g}" ] && [ "${#b}" -lt "${#g}" ] && [ "${#a}" -lt "${#b}" ]
}
check "static: the guard tests -L before -e" guard_order
# the string a function concatenates after the guard
lane_rest() { lane_line "$1" | sed "s/^  [\$]script:LanesGuard + '//; s/'\$//"; }
guard_first() { lane_line "$1" | grep -q "^  [\$]script:LanesGuard + '.*'\$"; }
# a test or [ command, any one-letter flag, then $L or ${L} with optional slashes or dots. The check is
# lexical: it does not catch the lanes path re-tested through another name ($1, or a copy such as M=$L), an
# option terminator before the operand (test -d -- $L), or binary forms such as -ef, -nt and -ot (with the
# lanes variable on either side), and other spellings. It over-catches a trailing /.. (test -d $L/.., which
# tests the parent), which is harmless.
dir_test_re='(test|\[)[[:space:]]+-[A-Za-z][[:space:]]+\$(L|[{]L[}])[/.]*([^A-Za-z0-9_$/.]|$)'
dir_test_in() { printf '%s\n' "$1" | grep -Eq "$dir_test_re"; }
not_dir_test_in() { ! dir_test_in "$1"; }
no_dir_test() { # no lanes-directory test of its own in the remainder
  ! lane_rest "$1" | grep -Eq "$dir_test_re"
}
for fn in Get-LaneProbeScript Get-SpecPrepScript Get-SpecCleanupScript Get-SpecSweepScript Get-EndDayScript; do
  check "static: $fn is a function of exactly one line" test "$(lane_fn $fn | wc -l | tr -d ' ')" -eq 3
  check "static: $fn returns the guard followed by one single-quoted string" guard_first $fn
  check "static: $fn's own string holds none of & | ^ % ! or a double quote, nor an inner single quote" clean_line "  '$(lane_rest $fn)'"
  check "static: $fn spells no lanes-directory test of its own" no_dir_test $fn
done
for t in '[ -e $L ]' 'test -O ${L};' 'test -d $L/;' 'test -x $L;' 'if test -h $L; then' 'test -d $L ;' 'test -L $L'; do
  check "static: the lanes-directory test pattern catches: $t" dir_test_in "$t"
done
for t in 'test -d $L/$N;' 'test -e $L/record-$F;' 'test $lw = ok;'; do
  check "static: the lanes-directory test pattern passes: $t" not_dir_test_in "$t"
done
sweep_pure() { ! { guard_line; lane_rest Get-SpecSweepScript; } | grep -q -w -e kill -e rm -e mkdir -e git; }
check "static: the guard and Get-SpecSweepScript hold none of kill, rm, mkdir or git as a whole word" sweep_pure
endday_pure() { ! { guard_line; lane_rest Get-EndDayScript; } | grep -q -w -e kill -e rm -e mkdir -e git; }
check "static: the guard and Get-EndDayScript hold none of kill, rm, mkdir or git as a whole word" endday_pure
tpl_line() { grep -E "^[\$]script:$1 = '" "$root_dir/scripts/identity/$2" | sed "s/^[^']*'//; s/'\$//"; }
for tplf in LaneMessage:wow-lane.ps1 SpecMessage:wow-lane.ps1 DriverMessage:wow-driver.ps1; do
  tpl=${tplf%%:*}; tplfile=${tplf#*:}
  check "static: the $tpl template exists" test -n "$(tpl_line $tpl $tplfile)"
  check "static: the $tpl template holds none of & | ^ % ! or a double quote" clean_line "$(tpl_line $tpl $tplfile)"
  check "static: the $tpl template holds @ORIGIN@ exactly once" test "$(tpl_line $tpl $tplfile | grep -o '@ORIGIN@' | wc -l)" -eq 1
done

  :
}

# --- section: wow-lane: the busy check, the spec record and -SpecSweep (#891) ---
sec_laned() {
spec_setup() { lane_setup; rm -rf "$lanes/5" "$lanes/5-prompt.md"; $real_git -C "$crepo" worktree prune; }
leaves() { ls -1A "$lanes" | tr '\n' ' '; }
# rerun <args>: run_lane again in the same world; the stub's ps counters and the call logs start over
rerun() { rm -f "$stubdir"/n.*; : >"$stubdir/calls.log"; : >"$stubdir/git.log"; run_lane "$@"; }
wt_count() { $real_git -C "$crepo" worktree list | wc -l | tr -d ' '; }
if [ -n "$msys" ]; then
  skip "the fake running session needs /proc; the busy check and sweep fixtures did not run under MSYS"
else
  mk_fake
  busy_refuses() { # busy_refuses <label> <issues word>: before = the lanes listing before the run
    check "wow-lane busy ($1): exit 1" test "$rc" -eq 1
    check "wow-lane busy ($1): no -it exec" no_it
    check "wow-lane busy ($1): names the worktree" err_has '/tmp/lanes/spec-aaa111'
    check "wow-lane busy ($1): names the process id" err_has "process $fake_pid"
    check "wow-lane busy ($1): names the issues" err_has "issues $2"
    check "wow-lane busy ($1): says the maintainer stops it" err_has 'maintainer stops that session'
    check "wow-lane busy ($1): no fetch of the base" sh -c "! grep -q -e 'fetch -q origin +refs/heads/' '$stubdir/git.log'"
    check "wow-lane busy ($1): no directory, worktree or record made" test "$(leaves)" = "$before"
    check "wow-lane busy ($1): no registered worktree made" test "$(wt_count)" -eq 1
  }
  busy_case() { # busy_case <label> <record text, or - for none> <-Spec list> <issues word>
    rm -f "$lanes/record-spec-aaa111"
    if [ "$2" != - ]; then printf '%s\n' "$2" >"$lanes/record-spec-aaa111"; fi
    before=$(leaves); rerun -Spec "$3"; busy_refuses "$1" "$4"
  }
  spec_setup; mkdir "$lanes/spec-aaa111"
  if fake_start "$lanes/spec-aaa111"; then
    busy_case 'a record that overlaps' '7,9 1700000000' 7 7,9
    busy_case 'a record that overlaps, in a list' '7,9 1700000000' 12,9,30 7,9
    busy_case 'no record' - 8 unknown
    busy_case 'a record of one word' 'zz' 8 unknown
    busy_case 'a record with a non-number' '7 abc' 8 unknown
    busy_case 'a record with a third field' '7 1700000000 9' 8 unknown
    busy_case 'a record whose list ends in a comma' '7, 1700000000' 8 unknown
    busy_case 'a record with a doubled comma' '7,,8 1700000000' 8 unknown
    busy_case 'a record with a leading zero' '07 1700000000' 8 unknown
    busy_case 'a record with an over-long number' '1234567890,5 1700000000' 8 unknown
    busy_case 'a record whose seconds field holds spaces' '7 a a' 8 unknown
    busy_case 'a record with over-long seconds' '7 12345678901' 8 unknown
    busy_case 'a record of two lines' '7 1700000000
7 1700000000' 8 unknown
    if [ -L "$tmp/probe-link" ]; then
      printf '7 1700000000\n' >"$tmp/record-real"; rm -f "$lanes/record-spec-aaa111"; ln -s "$tmp/record-real" "$lanes/record-spec-aaa111"
      before=$(leaves); rerun -Spec 8; busy_refuses 'a record that is a link' unknown
    else skip "a file symlink cannot be made here; the record-link fixture did not run"; fi
    # a record that lists only other issues: the run starts, and leaves the other session alone
    rm -f "$lanes/record-spec-aaa111"; printf '%s\n' '7,9 1700000000' >"$lanes/record-spec-aaa111"
    before=$(leaves); rerun -Spec 8
    check "wow-lane busy (no overlap): starts, exiting with the session's code" test "$rc" -eq 7
    check "wow-lane busy (no overlap): ...the other session's directory and record are untouched" test "$(leaves)" = "$before"
    check "wow-lane busy (no overlap): ...the interactive session ran" sh -c "grep -q ' -it ' '$stubdir/calls.log'"
    fake_stop
  else bad "the fake running session never read as claude"; fake_stop; fi
  # a running session whose directory was removed still counts
  spec_setup; mkdir "$lanes/spec-aaa111"; printf '%s\n' '7 1700000000' >"$lanes/record-spec-aaa111"
  if fake_start "$lanes/spec-aaa111"; then
    rm -rf "$lanes/spec-aaa111"
    before=$(leaves); rerun -Spec 7; busy_refuses 'the leaf directory removed under the session' 7
    rerun -SpecSweep
    check "wow-lane sweep (leaf removed under the session): exits 0" test "$rc" -eq 0
    check "wow-lane sweep (leaf removed under the session): lists it gone, with its process and issues" out_has "^/tmp/lanes/spec-aaa111 (gone); process $fake_pid; issues 7; started 2023-11-1"
    rm -f "$lanes/record-spec-aaa111"
    before=$(leaves); rerun -Spec 7; busy_refuses 'the leaf directory and the record removed' unknown
    fake_stop
  else bad "the fake running session never read as claude"; fake_stop; fi

  # -SpecSweep: kills and removes nothing, one non-interactive exec, no session
  spec_setup; mkdir "$lanes/spec-aaa111" "$lanes/spec-bbb222" "$lanes/spec-ddd444" "$lanes/spec-xyz" "$lanes/spec-ABC123" "$lanes/spec-eee55"
  printf '%s\n' '7,9 1700000000' >"$lanes/record-spec-aaa111"
  printf '%s\n' '5 1700000100' >"$lanes/record-spec-ccc333"
  printf '%s\n' 'zz' >"$lanes/record-spec-ddd444"
  : >"$lanes/notes.txt"; : >"$lanes/record-foo"
  if fake_start "$lanes/spec-aaa111"; then
    before=$(leaves); wt_before=$($real_git -C "$crepo" worktree list)
    rerun -SpecSweep
    check "wow-lane sweep: exits 0" test "$rc" -eq 0
    check "wow-lane sweep: lists the running session with its issues and start time" out_has "^/tmp/lanes/spec-aaa111; process $fake_pid; issues 7,9; started 2023-11-1"
    check "wow-lane sweep: lists a kept directory with no process" out_has '^/tmp/lanes/spec-bbb222; no process; issues unknown; started unknown$'
    check "wow-lane sweep: lists an orphan record, marked gone" out_has '^/tmp/lanes/spec-ccc333 (gone); no process; issues 5; started 2023-11-1'
    check "wow-lane sweep: shows a malformed record as unknown" out_has '^/tmp/lanes/spec-ddd444; no process; issues unknown; started unknown$'
    check "wow-lane sweep: skips names of another shape" sh -c "! grep -q -e spec-xyz -e ABC123 -e eee55 -e notes -e record-foo '$tmp/out'"
    check "wow-lane sweep: one line per entry, four entries" test "$(wc -l <"$tmp/out" | tr -d ' ')" -eq 4
    check "wow-lane sweep: relay probe, then one in-container exec, and nothing else" test "$(exec_shape)" = "exec -u root,exec -u app,"
    check "wow-lane sweep: the one in-container exec carries GIT_NO_REPLACE_OBJECTS=1" app_execs_pinned 1
    check "wow-lane sweep: no -it exec" no_it
    check "wow-lane sweep: no argv holds & | ^ % ! or a double quote" no_banned
    check "wow-lane sweep: the lanes directory is unchanged" test "$(leaves)" = "$before"
    check "wow-lane sweep: the registered worktrees are unchanged" test "$($real_git -C "$crepo" worktree list)" = "$wt_before"
    check "wow-lane sweep: the session is still running" kill -0 "$fake_pid"
    check "wow-lane sweep: the record is not written" sh -c "[ ! -e '$home/driver/wb-driver.json' ] || cmp -s '$tmp/rec-snap' '$home/driver/wb-driver.json'"
    fake_stop
  else bad "the fake running session never read as claude"; fake_stop; fi
  spec_setup; rerun -SpecSweep
  check "wow-lane sweep (empty lanes directory): exits 0" test "$rc" -eq 0
  check "wow-lane sweep (empty lanes directory): reports no spec sessions" test "$(cat "$tmp/out")" = 'no spec sessions'
  rm -rf "$lanes"; rerun -SpecSweep
  check "wow-lane sweep (no lanes directory): exits 0" test "$rc" -eq 0
  check "wow-lane sweep (no lanes directory): reports no spec sessions" test "$(cat "$tmp/out")" = 'no spec sessions'
  check "wow-lane sweep (no lanes directory): no lanes directory made" test ! -e "$lanes"
  # a lanes directory that is a link or a regular file: refused, nothing listed
  sweep_unsafe() { # sweep_unsafe <label>
    check "wow-lane sweep ($1): exits 1" test "$rc" -eq 1
    check "wow-lane sweep ($1): says why" err_has 'is a link, not a directory, or not owned by the container user'
    check "wow-lane sweep ($1): lists no spec line" sh -c "! grep -q 'spec-' '$tmp/out'"
    check "wow-lane sweep ($1): no -it exec" no_it
  }
  spec_setup; mkdir "$lanes/spec-aaa111"; printf '%s\n' '7 1700000000' >"$lanes/record-spec-aaa111"
  mv "$lanes" "$tmp/lanes.real"
  if mklink_dir "$lanes" "$tmp/lanes.real"; then
    target_before=$(ls -1A "$tmp/lanes.real" | tr '\n' ' ')
    rerun -SpecSweep; sweep_unsafe 'the lanes directory a link'
    check "wow-lane sweep (the lanes directory a link): relay probe, then one in-container exec" test "$(exec_shape)" = "exec -u root,exec -u app,"
    check "wow-lane sweep (the lanes directory a link): the link target is unchanged" test "$(ls -1A "$tmp/lanes.real" | tr '\n' ' ')" = "$target_before"
  else skip "a directory link cannot be made here; the sweep lanes-directory link fixture did not run"; fi
  rm -rf "$lanes" "$tmp/lanes.real"
  : >"$lanes"; rerun -SpecSweep; sweep_unsafe 'the lanes path a regular file'
  rm -f "$lanes"
  # a lanes directory that exists but is not owned by the user (the stub's test function says -O is false)
  spec_setup; mkdir "$lanes/spec-aaa111"; printf '%s\n' '7 1700000000' >"$lanes/record-spec-aaa111"
  : >"$stubdir/it.owner"; rerun -SpecSweep; sweep_unsafe 'the lanes directory not owned by the user'
  rm -f "$stubdir/it.owner"
  # a link to a missing target: refused, which pins test -L running before test -e
  rm -rf "$lanes" "$tmp/lanes.gone"
  if mklink_dir "$lanes" "$tmp/lanes.gone"; then
    rerun -SpecSweep; sweep_unsafe 'the lanes directory a link to a missing target'
    check "wow-lane sweep (the lanes directory a dangling link): relay probe, then one in-container exec" test "$(exec_shape)" = "exec -u root,exec -u app,"
  else skip "a directory link cannot be made here; the sweep dangling-link fixture did not run"; fi
  rm -f "$lanes"
fi
  :
}

# --- section: model, declared values and the helper ---
sec_misc() {
# --- model -------------------------------------------------------------------------------------
push_yml() { # push_yml <architect value>
  printf 'models:\n  architect: %s\n  coder: sonnet\ncanary: CANARY-YML\nlanes:\n  dir: /tmp/lanes\n' "$1" >"$seed/.ai/project.yml"
  $G -C "$seed" commit -q -am "model $1"; $real_git -C "$seed" push -q origin main
  c2=$($real_git -C "$seed" rev-parse HEAD)
}
push_yml gpt
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "model: a value outside the four names refuses" test "$rc" -eq 1
check "model: ...with no -it exec" no_it
push_yml 'fable'
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "model: a valid value reaches argv as the script's literal" test "$(non_ps | tail -1)" = "docker exec -it -u app -e GIT_TERMINAL_PROMPT=0 -w /workspace $ID1 /usr/local/bin/claude --model fable --effort medium Driver for acme/widgets."
push_yml 'opus; rm -rf'
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "model: an injected value refuses and reaches no argv" test "$rc" -eq 1 -a "$(calls | grep -c 'rm -rf')" -eq 0
printf 'models:\n  coder: sonnet\nlanes:\n  dir: /tmp/lanes\n' >"$seed/.ai/project.yml"; $G -C "$seed" commit -q -am nomodel; $real_git -C "$seed" push -q origin main
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "model: a missing models.architect refuses" test "$rc" -eq 1

# --- the declared values the docker exec literals match ---------------------------------------------
dc="$root_dir/.devcontainer/devcontainer.json"
check "declared: devcontainer.json still carries remoteUser app" grep -q '"remoteUser": "app"' "$dc"
for f in wow-driver.ps1 wow-lane.ps1; do
  check "declared: $f's docker exec carries the same user and the image's GIT_TERMINAL_PROMPT literal" sh -c "grep -q \"'-u', 'app'\" '$root_dir/scripts/identity/$f' && grep -q \"'GIT_TERMINAL_PROMPT=0'\" '$root_dir/scripts/identity/$f'"
done

# --- the helper defines functions only -----------------------------------------------------------
rc=0; out=$("$pwsh_abs" -NoProfile -NonInteractive -Command "
  \$ast = [System.Management.Automation.Language.Parser]::ParseFile('$(wp "$root_dir/scripts/identity/wow-launch-common.ps1")', [ref]\$null, [ref]\$null)
  \$other = \$ast.EndBlock.Statements | Where-Object { \$_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] }
  if (\$ast.BeginBlock -or \$ast.ProcessBlock -or \$other) { 'top-level statement' } else { 'functions only' }" 2>&1) || rc=$?
check "helper: wow-launch-common.ps1 has functions only" test "$out" = 'functions only'
if mklink_dir "$tmp/clones-link" "$tmp/clones"; then
  out=$("$pwsh_abs" -NoProfile -NonInteractive -Command ". '$(wp "$root_dir/scripts/identity/wow-launch-common.ps1")'; Get-FinalPath '$(wp "$tmp/clones-link/wb-driver")'" 2>&1) || true
  check "helper: Get-FinalPath follows a link in a parent" test "$(norm "$out")" = "$(norm "$(wp "$clone")")"
else skip "a directory link cannot be made here; the Get-FinalPath link fixture did not run"; fi

  :
}

# --- section: ConvertFrom-MsysDrivePath ---
sec_msys() {
# --- ConvertFrom-MsysDrivePath (#789, #842): the platform flag is passed, so these run on any host -------
# A stub sh in its own directory logs its arguments and answers from sh.out and sh.code. It is written directly,
# not with mkstub: on MSYS mkstub's .cmd shim runs `sh` by name, so a shim named sh would run itself. There the
# stub is an sh.cmd running the real sh (by its Windows path, taken before PATH changes) on sh.sh.
shdir="$tmp/shstub" ; mkdir "$shdir"
noshdir="$tmp/nosh" ; mkdir "$noshdir"
# The stub uses only shell builtins: pwsh runs it with a PATH that holds no dirname or cat.
cat >"$tmp/sh.body" <<'STUB'
d=${0%/*}; d=${d%\\*}
echo "argc $#" >>"$d/sh.log"
for a in "$@"; do echo "arg $a" >>"$d/sh.log"; done
if [ -r "$d/sh.out" ]; then while IFS= read -r l || [ -n "$l" ]; do printf '%s\n' "$l"; done <"$d/sh.out"; fi
c=0; if [ -r "$d/sh.code" ]; then read -r c <"$d/sh.code"; fi
exit "$c"
STUB
if [ -n "$msys" ]; then
  real_sh_win=$(cygpath -w "$(command -v sh)")
  cp "$tmp/sh.body" "$shdir/sh.sh"
  printf '@"%s" "%%~dp0sh.sh" %%*\r\n' "$real_sh_win" >"$shdir/sh.cmd"
else
  { echo '#!/bin/sh'; cat "$tmp/sh.body"; } >"$shdir/sh"; chmod +x "$shdir/sh"
fi
sh_reset() { rm -f "$shdir/sh.log" "$shdir/sh.out" "$shdir/sh.code"; }
# msys_conv <path> <is-windows> [<path-dir>]: output in $out, exit code in $rc. The path reaches pwsh through an
# environment variable behind one leading letter (Git Bash rewrites a /-leading value on its way to a native
# program), never inside the -Command string. <path-dir> is the whole PATH pwsh runs with (default: the stub sh's).
msys_conv() {
  rc=0; out=$(MSYS_CONV_PATH="v$1" PATH="${3:-$shdir}" "$pwsh_abs" -NoProfile -NonInteractive -Command "\$script:LaunchProg = 't'; \$script:LaunchUsage = 'u'; . '$(wp "$root_dir/scripts/identity/wow-launch-common.ps1")'; ConvertFrom-MsysDrivePath '-WowHome' \$env:MSYS_CONV_PATH.Substring(1) \$$2" 2>&1) || rc=$?
  out=$(printf '%s' "$out" | tr -d '\r')
}

# With the stub sh on PATH: the conversion is whatever cygpath -w through sh printed.
sh_reset; printf 'D:\\conv\\y\n' >"$shdir/sh.out"
msys_conv '/c/x/y' true
check "msys: an sh conversion returns exactly what the stub printed" test "$rc" -eq 0 -a "$out" = 'D:\conv\y'
check "msys: the stub saw the value" grep -qxF 'arg /c/x/y' "$shdir/sh.log"
check "msys: the stub saw -c" grep -qxF 'arg -c' "$shdir/sh.log"
check "msys: the stub saw sh as \$0" grep -qxF 'arg sh' "$shdir/sh.log"
if [ -z "$msys" ]; then
  check "msys: the stub saw the cygpath script" grep -qxF 'arg cygpath -w "$1"' "$shdir/sh.log"
  check "msys: the stub saw four arguments" grep -qxF 'argc 4' "$shdir/sh.log"
fi
sh_reset; printf 'D:\\mnt\\x\n' >"$shdir/sh.out"
msys_conv '/mnt/c/x' true
check "msys: a non-default prefix returns what the stub printed" test "$rc" -eq 0 -a "$out" = 'D:\mnt\x'
sh_reset; echo 3 >"$shdir/sh.code"
msys_conv '/c/x' true
check "msys: a nonzero sh exit exits 2" test "$rc" -eq 2
case "$out" in
  *'-WowHome'*'cygpath -w conversion through sh failed (exit 3)'*'give its Windows form'*) ok "msys: a nonzero sh exit names the argument, the cause and the fix" ;;
  *) bad "msys: a nonzero sh exit names the argument, the cause and the fix" ;;
esac
sh_reset
msys_conv '/c/x' true
check "msys: empty sh output exits 2" test "$rc" -eq 2
case "$out" in
  *'-WowHome'*'printed nothing'*'give its Windows form'*) ok "msys: empty sh output names the argument, the cause and the fix" ;;
  *) bad "msys: empty sh output names the argument, the cause and the fix" ;;
esac
for refused in '//server/share/x' '/c/a&b' '/c/a>b' "/c/it's"; do
  sh_reset
  msys_conv "$refused" true
  check "msys: $refused exits 2 without running sh" test "$rc" -eq 2
  check "msys: $refused leaves no stub call" test ! -e "$shdir/sh.log"
done
msys_conv "/c/it's" true
case "$out" in
  *'one of & | ^ %'*) ok "msys: a single-quote path reaches the function and names the refused characters" ;;
  *) bad "msys: a single-quote path reaches the function and names the refused characters" ;;
esac

# With no sh on PATH: the fixed drive-prefix conversion.
for pair in '/c|C:/' '/c/|C:/' '/C/|C:/' '/c/x/y|C:/x/y'; do
  msys_conv "${pair%%|*}" true "$noshdir"
  check "msys: no sh, ${pair%%|*} converts to ${pair#*|}" test "$rc" -eq 0 -a "$out" = "${pair#*|}"
done
for badp in /cc/x /tmp/x /1/x; do
  msys_conv "$badp" true "$noshdir"
  check "msys: no sh, $badp exits 2" test "$rc" -eq 2
  case "$out" in
    *'-WowHome is in MSYS form'*'no sh was found on PATH'*'give its Windows form'*) ok "msys: no sh, $badp names the argument, the cause and the fix" ;;
    *) bad "msys: no sh, $badp names the argument, the cause and the fix" ;;
  esac
done
msys_conv '//server/share/x' true "$noshdir"
check "msys: no sh, a // value exits 2" test "$rc" -eq 2
msys_conv 'C:/x/y' true
check "msys: a drive-form path is unchanged" test "$rc" -eq 0 -a "$out" = 'C:/x/y'
msys_conv 'x/y' true
check "msys: a relative path is unchanged" test "$rc" -eq 0 -a "$out" = 'x/y'
msys_conv '/c/x' false
check "msys: flag false leaves /c/x unchanged" test "$rc" -eq 0 -a "$out" = '/c/x'
for f in wow-driver.ps1 wow-lane.ps1; do
  check "msys: $f converts -WowHome before resolving it" grep -qF "Resolve-LaunchDir '-WowHome' (ConvertFrom-MsysDrivePath '-WowHome' \$WowHome) -Plain" "$root_dir/scripts/identity/$f"
done
  :
}

# --- section: the Reference's origin repository (#1164, WB-D42) ---
sec_origin() {
set_url() { $real_git -C "$ref" config --replace-all remote.origin.url "$1"; }
no_fetch() { ! grep -q ' fetch ' "$stubdir/git.log"; }
attach_refuses() { # attach_refuses <label>: exit 1, no devcontainer, no -it, a reason
  check "attach refuses ($1): exit 1" test "$rc" -eq 1
  check "attach refuses ($1): no devcontainer call" no_dc
  check "attach refuses ($1): no -it exec" no_it
  check "attach refuses ($1): says why on stderr" test -s "$tmp/err"
}
refuses_early() { # refuses_early <label>: exit 1, a reason, no fetch, no devcontainer, no -it exec
  check "$1: exit 1" test "$rc" -eq 1
  check "$1: says why on stderr" test -s "$tmp/err"
  check "$1: before the fetch" no_fetch
  check "$1: no devcontainer call" no_dc
  check "$1: no -it exec" no_it
}

# start of day: a record naming this clone and another origin refuses and is left alone
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; write_record "$ID2" "$c1" "$(json_clone)" other/repo; cp "$home/driver/wb-driver.json" "$tmp/snap"
run_drv
refuses_early 'start of day, another origin'
check "start of day, another origin: names both repositories" sh -c "grep -q other/repo '$tmp/err' && grep -q acme/widgets '$tmp/err'"
check "start of day, another origin: the record is unchanged" cmp -s "$tmp/snap" "$home/driver/wb-driver.json"
# a record naming another clone does not bind this one
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; write_record "$ID2" "$c1" "$(wp "$tmp/clones/elsewhere" | sed 's,\\,\\\\,g')" other/repo
run_drv
start_ok_origin() { check "$1: exits with the session's code" test "$rc" -eq 7; check "$1: writes a five-field record" rec_ok; }
start_ok_origin 'start of day, a record of another clone'
# no record, a three-field record and an unreadable record each write five fields
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; run_drv
start_ok_origin 'start of day, no record'
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; write_record3 "$ID2" "$c1" "$(json_clone)"; run_drv
start_ok_origin 'start of day, a three-field record'
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; mkdir -p "$home/driver"; echo '{not json' >"$home/driver/wb-driver.json"; run_drv
start_ok_origin 'start of day, an unreadable record'
check "start of day: the Reference's mixed-case url is recorded as lowercase" test "$(jq -r .origin "$home/driver/wb-driver.json")" = acme/widgets

# attach: a different origin, a three-field record
running1; write_record "$ID1" "$c2" "$(json_clone)" other/repo; run_drv
attach_refuses 'another origin'; check "attach refuses (another origin): before the fetch" no_fetch
running1; write_record3 "$ID1" "$c2" "$(json_clone)"; run_drv
attach_refuses 'a three-field record'; check "attach refuses (a three-field record): before the fetch" no_fetch
check "attach refuses (a three-field record): says to rerun at start of day" err_has 'start of day'
running1; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "attach with the same origin still attaches" test "$rc" -eq 7

# wow-lane: -Issue, -Spec and -SpecSweep refuse another origin and a three-field record
LANE_CONTAINER_STAGE=1
sweep_url_free() { check "$1: no url in the output" sh -c "! grep -q -e github.com -e Widgets '$tmp/err' '$tmp/out'"; }
for mode in issue spec sweep; do
  lane_setup; write_record "$ID1" "$c2" "$(json_clone)" other/repo; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"
  case $mode in issue) run_lane -Issue 5 -Hash "$PH" ;; spec) run_lane -Spec 7 ;; sweep) run_lane -SpecSweep ;; esac
  lane_refuses "$mode, another origin"; check "wow-lane refuses ($mode, another origin): before the fetch" no_fetch
  [ "$mode" != sweep ] || sweep_url_free "wow-lane refuses (sweep, another origin)"
  lane_setup; write_record3 "$ID1" "$c2" "$(json_clone)"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"
  case $mode in issue) run_lane -Issue 5 -Hash "$PH" ;; spec) run_lane -Spec 7 ;; sweep) run_lane -SpecSweep ;; esac
  lane_refuses "$mode, a three-field record"; check "wow-lane refuses ($mode, a three-field record): before the fetch" no_fetch
  [ "$mode" != sweep ] || sweep_url_free "wow-lane refuses (sweep, a three-field record)"
done
if [ -z "$msys" ]; then
  lane_setup; run_lane -SpecSweep
  check "wow-lane -SpecSweep still lists with a valid four-field record" test "$rc" -eq 0
  check "wow-lane -SpecSweep with a four-field record: says there are no spec sessions" test "$(cat "$tmp/out")" = 'no spec sessions'
fi

# the lanes directory comes from the Reference's lanes.dir at the base commit
push_lanes() { # push_lanes <lanes text, or - for none>
  { printf 'models:\n  architect: opus\n  coder: sonnet\ncanary: CANARY-YML\n'; [ "$1" = - ] || printf '%s\n' "$1"; } >"$seed/.ai/project.yml"
  $G -C "$seed" commit -q -am lanes; $real_git -C "$seed" push -q origin main
}
c2_before_lanes=$c2
for mode in issue spec sweep; do
  for v in '-' 'lanes: null' 'lanes: x' 'lanes: { dir: 5 }' 'lanes: { dir: rel/x }' 'lanes: { dir: /a//b }' 'lanes: { dir: /a/ }' 'lanes: { dir: /a/../b }' 'lanes: { dir: /a/./b }' 'lanes: { dir: /a b }' 'lanes: { dir: / }'; do
    push_lanes "$v"; lane_setup
    case $mode in issue) run_lane -Issue 5 -Hash "$PH" ;; spec) run_lane -Spec 7 ;; sweep) run_lane -SpecSweep ;; esac
    lane_refuses "$mode, lanes [$v]"
    check "wow-lane refuses ($mode, lanes [$v]): names lanes.dir" err_has 'lanes.dir'
    check "wow-lane refuses ($mode, lanes [$v]): no spec worktree prep ran" sh -c "! ls '$lanes' | grep -q '^spec-'"
  done
done
if [ -z "$msys" ]; then
  push_lanes 'lanes: { dir: /srv/wow-lanes }'
  lane_setup; run_lane -Issue 5 -Hash "$PH"
  check "wow-lane lanes.dir (lane): exits with the session's code" test "$rc" -eq 7
  check "wow-lane lanes.dir (lane): -w and the message name the Reference's directory" sh -c "it_line() { grep ' -it ' '$stubdir/calls.log'; }; it_line | grep -q -e '-w /srv/wow-lanes/5 ' && it_line | grep -q -e 'cp /srv/wow-lanes/5-prompt.md'"
  check "wow-lane lanes.dir (lane): /tmp/lanes is in no argv" sh -c "! grep -q '/tmp/lanes' '$stubdir/calls.log'"
  lane_setup; rm -rf "$lanes/5" "$lanes/5-prompt.md"; $real_git -C "$crepo" worktree prune; run_lane -Spec 7
  check "wow-lane lanes.dir (spec): the session's -w is a spec leaf under the Reference's directory" sh -c "grep ' -it ' '$stubdir/calls.log' | grep -q -e '-w /srv/wow-lanes/spec-'"
  lane_setup; mkdir "$lanes/spec-bbb222"; run_lane -SpecSweep
  check "wow-lane lanes.dir (sweep): exits 0" test "$rc" -eq 0
  check "wow-lane lanes.dir (sweep): lists the leaf under the Reference's directory" out_has '^/srv/wow-lanes/spec-bbb222; no process; issues unknown; started unknown$'
fi
# put the Reference's base back where it was, for the checks that follow
$real_git -C "$seed" reset -q --hard "$c2_before_lanes"; $real_git -C "$seed" push -q -f origin main
LANE_CONTAINER_STAGE=

# the Reference's url: shapes that refuse without echoing it, and one with a user name that is accepted
bad_url() { # bad_url <label> <url> <secret word>
  set_url "$2"; reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; run_drv
  refuses_early "a Reference url ($1)"
  check "a Reference url ($1): the url is not echoed" sh -c "! grep -q -e '$3' '$tmp/err' '$tmp/out'"
}
bad_url 'a password part on https' 'https://u:SECRETPW@github.com/acme/widgets' SECRETPW
bad_url 'another host' 'https://example.com/SECRETHOST/widgets' SECRETHOST
bad_url 'a local path' "$(wp "$origin")" origin.git
set_url 'https://github.com/Acme/Widgets.git'; $real_git -C "$ref" config --add remote.origin.url 'https://github.com/SECRETTWO/two.git'
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; run_drv
refuses_early 'a Reference with two url values'
check "a Reference with two url values: the urls are not echoed" sh -c "! grep -q -e SECRETTWO '$tmp/err' '$tmp/out'"
set_url 'https://SECRETUSER@github.com/Acme/Widgets.git'
$real_git -C "$ref" config "url.$(wp "$origin").insteadOf" 'https://SECRETUSER@github.com/Acme/Widgets.git'
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; run_drv
start_ok_origin 'a Reference url with only a user name'
check "a Reference url with only a user name: the name does not reach the session argv" no_secretuser
check "a Reference url with only a user name: the name is in neither the record nor the output" sh -c "! grep -q SECRETUSER '$home/driver/wb-driver.json' '$tmp/out' '$tmp/err'"
check "start of day: git ran only in the Reference (origin read included)" sh -c "! grep -q 'wb-driver' '$stubdir/git.log'"
}

# --- section: the host yq minimum version (#1256) ---
sec_yqver() {
common=$(wp "$root_dir/scripts/identity/wow-launch-common.ps1")
yq_line() { printf 'yq (https://github.com/mikefarah/yq/) version %s' "$1"; }
yq_status() { # yq_status <text>: the pure function's Status and Found in $out
  out=$(YQ_TEXT="$1" "$pwsh_abs" -NoProfile -NonInteractive -Command "\$script:LaunchProg = 't'; \$script:LaunchUsage = 'u'; . '$common'; \$v = Test-YqVersion \$env:YQ_TEXT; \"\$(\$v.Status) \$(\$v.Found) \$(\$v.Minimum)\"" 2>&1 | tr -d '\r') || out="error $out"
}
for v in v4.53.6 v4.6.0 v3.99.99; do
  yq_status "$(yq_line "$v")"; check "yq version: $v is older" test "$out" = "older ${v#v} 4.54.1"
done
for v in v4.54.1 v4.54.2 v4.55.0 v4.100.0 v5.0.0; do
  yq_status "$(yq_line "$v")"; check "yq version: $v passes" test "$out" = "ok ${v#v} 4.54.1"
done
yq_status "$(yq_line v4.54.1)
"; check "yq version: a trailing newline passes" test "$out" = "ok 4.54.1 4.54.1"
yq_status ''; check "yq version: empty output is unparseable" test "$out" = "unparseable  4.54.1"
yq_status 'yq 3.4.1'; check "yq version: another yq's form is unparseable" test "$out" = "unparseable  4.54.1"
yq_status "$(yq_line v4.54)"; check "yq version: two components are unparseable" test "$out" = "unparseable  4.54.1"
yq_status "$(yq_line v4.54.1-rc1)"; check "yq version: a pre-release suffix is unparseable" test "$out" = "unparseable  4.54.1"
yq_status "$(yq_line v4.54.1)
second line"; check "yq version: a second line is unparseable" test "$out" = "unparseable  4.54.1"

# end to end: a stub yq ahead of the real one that only prints and exits
yq_stub() { # yq_stub <text> <exit code>
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\nexit %s\n' "$1" "$2" >"$tmp/yq.body"; mkstub yq "$tmp/yq.body"
}
yq_stub "$(yq_line v4.53.6)" 0
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "yq version: wow-driver refuses v4.53.6 with exit 1" test "$rc" -eq 1
check "yq version: wow-driver names v4.53.6 and v4.54.1" sh -c "grep -q 'v4.53.6' '$tmp/err' && grep -q 'v4.54.1' '$tmp/err'"
check "yq version: wow-driver refuses before any docker or git call" none_called
reset; run_lane -Spec 7
check "yq version: wow-lane refuses v4.53.6 with exit 1" test "$rc" -eq 1
check "yq version: wow-lane names v4.53.6 and v4.54.1" sh -c "grep -q 'v4.53.6' '$tmp/err' && grep -q 'v4.54.1' '$tmp/err'"
check "yq version: wow-lane refuses before any docker or git call" none_called
yq_stub "$(yq_line v4.55.0)" 1
reset; echo "$ID1 running" >"$stubdir/ps.vol.1"; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "yq version: a failing yq --version exits 1" test "$rc" -eq 1
check "yq version: ...with the unparseable message" err_has 'no yq version could be read'
check "yq version: ...before any docker or git call" none_called
yq_stub 'yq 3.4.1' 0
reset; run_lane -Spec 7
check "yq version: wow-lane refuses an exit-0 other-form yq with exit 1" test "$rc" -eq 1
check "yq version: wow-lane, other-form yq, with the unparseable message" err_has 'no yq version could be read'
check "yq version: wow-lane, other-form yq, before any docker or git call" none_called

# static: the minimum is written once, in the shared code
check "yq version: 4.54.1 is in wow-launch-common.ps1" grep -qF '4.54.1' "$root_dir/scripts/identity/wow-launch-common.ps1"
for f in wow-driver.ps1 wow-lane.ps1; do
  check "yq version: 4.54.1 is not in $f" sh -c "! grep -qF '4.54.1' '$root_dir/scripts/identity/$f'"
done
}

# --- section: -Repo, the five-field record, -EndDay and Get-Help (#1381, #1386) ---
sec_repo() {
json_ref() { printf '%s' "$(wp "$ref")" | sed 's,\\,\\\\,g'; }
write_record5() { # write_record5 <id> <commit> <clone> <reference> [origin] [file leaf]: the five-field record
  mkdir -p "$home/driver"
  printf '{"id":"%s","commit":"%s","clone":"%s","origin":"%s","reference":"%s"}\n' "$1" "$2" "$3" "${5:-acme/widgets}" "$4" | sed 's,\\,\\\\,g;' >"$home/driver/${6:-wb-driver}.json"
}
run_repo_drv() { run_with "$home/bin/wow-driver.ps1" -WowHome "$(wp "$home")" "$@"; }
run_repo_lane() { run_with "$home/bin/wow-lane.ps1" -WowHome "$(wp "$home")" "$@"; }

# a start of day from the record: the same calls the explicit-path form makes (the record is rewritten with the new container)
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; run_drv
long_calls=$(non_ps)
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; write_record5 "$ID2" "$c1" "$(json_clone)" "$(json_ref)"
run_repo_drv -Repo Acme/Widgets
check "-Repo driver start of day: exits with the session's code" test "$rc" -eq 7
check "-Repo driver start of day: makes the calls the long form makes" test "$(non_ps)" = "$long_calls"
check "-Repo driver start of day: writes the five-field record" rec_ok
check "-Repo driver start of day: every process ran from the final -WowHome" cwd_all "$(wp "$home")" 11
# a hidden file in driver/ (the write's temp file) is skipped; an unrelated record is read and ignored
reset; echo "$ID1 running" >"$stubdir/ps.vol.3"; write_record5 "$ID2" "$c1" "$(json_clone)" "$(json_ref)"
echo '{' >"$home/driver/.junk.json"; write_record5 "$ID3" "$c1" "$(wp "$tmp/clones/elsewhere" | sed 's,\\,\\\\,g')" "$(wp "$tmp/refs/else" | sed 's,\\,\\\\,g')" other/repo other
run_repo_drv -Repo acme/widgets
check "-Repo: a hidden file and a record of another repository do not stop a start of day" test "$rc" -eq 7

# attach from the record
running1; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; run_drv; long_calls=$(non_ps)
running1; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; cp "$home/driver/wb-driver.json" "$tmp/snap"
run_repo_drv -Repo acme/widgets
check "-Repo driver attach: exits with the session's code" test "$rc" -eq 7
check "-Repo driver attach: makes the calls the long form makes" test "$(non_ps)" = "$long_calls"
check "-Repo driver attach: no gh and no devcontainer" sh -c "! grep -q '^gh \|^devcontainer ' '$stubdir/calls.log'"
check "-Repo driver attach: the record is untouched" cmp -s "$tmp/snap" "$home/driver/wb-driver.json"
check "-Repo driver attach: the session line is the long form's" test "$(it_line)" = "$exec_line"

# refusals: exit 2 before any external call
repo_bad() { # repo_bad <label> <args...>
  l=$1; shift; reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"
  run_repo_drv "$@"
  check "-Repo driver ($l): exit 2 with a usage line" sh -c "test $rc -eq 2 && grep -q 'usage: wow-driver.ps1' '$tmp/err'"
  check "-Repo driver ($l): no external call" none_called
}
repo_bad 'no slash' -Repo acme
repo_bad 'three parts' -Repo a/b/c
repo_bad 'a space' -Repo 'a b/c'
repo_bad 'an empty half' -Repo acme/
repo_bad 'with -Clone' -Repo acme/widgets -Clone "$C"
repo_bad 'with -Reference' -Repo acme/widgets -Reference "$R"
# refusals: exit 1 before any docker call
repo_refuses() { # repo_refuses <label> <message part>
  check "-Repo driver ($1): exit 1" test "$rc" -eq 1
  check "-Repo driver ($1): says why" err_has "$2"
  check "-Repo driver ($1): no external call" none_called
}
reset; run_repo_drv -Repo acme/widgets; repo_refuses 'no driver directory' 'no driver record names acme/widgets'
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)" other/repo; run_repo_drv -Repo acme/widgets; repo_refuses 'no record names it' 'no driver record names acme/widgets'
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; write_record5 "$ID2" "$c2" "$(json_clone)" "$(json_ref)" acme/widgets second
run_repo_drv -Repo acme/widgets; repo_refuses 'two records' 'more than one driver record'
check "-Repo driver (two records): names both file names" sh -c "grep -q 'second.json' '$tmp/err' && grep -q 'wb-driver.json' '$tmp/err'"
reset; write_record "$ID1" "$c2" "$(json_clone)"; run_repo_drv -Repo acme/widgets; repo_refuses 'a four-field record' 'no Reference path'
check "-Repo driver (a four-field record): says the next start of day writes it" err_has 'next start of day'
reset; write_record3 "$ID1" "$c2" "$(json_clone)"; run_repo_drv -Repo acme/widgets; repo_refuses 'a three-field record' 'no driver record names'
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; echo '{' >"$home/driver/broken.json"; run_repo_drv -Repo acme/widgets
repo_refuses 'an unreadable record file' 'broken.json'
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; printf '{"id":"%s","commit":"%s","clone":"x","origin":"acme/widgets","reference":""}\n' "$ID1" "$c2" >"$home/driver/wb-driver.json"
run_repo_drv -Repo acme/widgets; repo_refuses 'an empty reference' 'reference is empty'
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "relative/path"; run_repo_drv -Repo acme/widgets
check "-Repo driver (a recorded relative Reference): the argument checks refuse it, exit 2" test "$rc" -eq 2
check "-Repo driver (a recorded relative Reference): no external call" none_called
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(wp "$tmp/refs/gone" | sed 's,\\,\\\\,g')"; run_repo_drv -Repo acme/widgets
check "-Repo driver (a recorded Reference that is gone): exit 2" test "$rc" -eq 2
# five-field strict read: an extra field and a non-string reference
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; sed 's/}$/,"x":"y"}/' "$home/driver/wb-driver.json" >"$tmp/six"; cp "$tmp/six" "$home/driver/wb-driver.json"
run_repo_drv -Repo acme/widgets; repo_refuses 'a six-field record' 'exactly id, commit, clone, origin and reference'
reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; sed 's/"reference":"[^"]*"/"reference":7/' "$home/driver/wb-driver.json" >"$tmp/num"; cp "$tmp/num" "$home/driver/wb-driver.json"
run_repo_drv -Repo acme/widgets; repo_refuses 'a numeric reference' 'reference is not a string'
# a four-field record still reads: attach with it works through the long form
running1; write_record "$ID1" "$c2" "$(json_clone)"; run_drv
check "a four-field record still reads: attach through the long form" test "$rc" -eq 7

# wow-lane -Repo
lane_setup; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"
run_lane -Issue 5 -Hash "$PH"; long_calls=$(non_ps)
lane_setup; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"
run_repo_lane -Repo acme/widgets -Issue 5 -Hash "$PH"
check "-Repo lane -Issue/-Hash: exits with the session's code" test "$rc" -eq 7
check "-Repo lane -Issue/-Hash: makes the calls the long form makes" test "$(non_ps)" = "$long_calls"
check "-Repo lane -Issue/-Hash: the record is byte-identical afterwards" cmp -s "$tmp/rec-snap" "$home/driver/wb-driver.json"
lane_setup; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"
rm -rf "$lanes/5" "$lanes/5-prompt.md"; $real_git -C "$crepo" worktree prune
run_repo_lane -Repo acme/widgets -Spec 12,7
check "-Repo lane -Spec: exits with the session's code" test "$rc" -eq 7
check "-Repo lane -Spec: the session leads with the issues in order, then names the repository" sh -c "grep -q 'claude --model opus --effort high Spec: #12, #7 in acme/widgets. Run /way-of-working:spec-task for each of these issues, one at a time, in this order: 12, 7\\.' '$stubdir/calls.log'"
lane_setup; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"
run_repo_lane -Repo acme/widgets -SpecSweep
check "-Repo lane -SpecSweep: lists, exit 0" sh -c "test $rc -eq 0 && grep -q 'no spec sessions' '$tmp/out'"
lane_bad() { # lane_bad <label> <args...>: exit 2, usage, no external call
  l=$1; shift; reset; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"
  run_repo_lane "$@"
  check "-Repo lane ($l): exit 2 with a usage line" sh -c "test $rc -eq 2 && grep -q 'usage: wow-lane.ps1' '$tmp/err'"
  check "-Repo lane ($l): no external call" none_called
}
lane_bad 'a bad shape' -Repo acme -SpecSweep
lane_bad 'with -Clone' -Repo acme/widgets -Clone "$C" -SpecSweep
lane_bad 'with -Reference' -Repo acme/widgets -Reference "$R" -SpecSweep
reset; run_repo_lane -Repo acme/widgets -SpecSweep
check "-Repo lane (no record): exit 1 before any external call" sh -c "test $rc -eq 1 && grep -q 'no driver record names acme/widgets' '$tmp/err'"
check "-Repo lane (no record): no external call" none_called

# -EndDay
end_setup() { lane_setup; write_record5 "$ID1" "$c2" "$(json_clone)" "$(json_ref)"; cp "$home/driver/wb-driver.json" "$tmp/rec-snap"; }
stop_calls() { calls | grep -c '^docker stop '; }
stopped_once() { [ "$(stop_calls)" -eq 1 ] && calls | grep -q -x "docker stop $ID1"; }
no_stop() { [ "$(stop_calls)" -eq 0 ]; }
end_refuses() { # end_refuses <label> <message part>
  check "-EndDay ($1): exit 1" test "$rc" -eq 1
  check "-EndDay ($1): says why" err_has "$2"
  check "-EndDay ($1): no docker stop" no_stop
  check "-EndDay ($1): no interactive exec" no_it
}
end_setup; run_repo_lane -Repo acme/widgets -EndDay
check "-EndDay idle: exit 0" test "$rc" -eq 0
check "-EndDay idle: one docker stop of the recorded id" stopped_once
check "-EndDay idle: prints stopped <id>" sh -c "test \"\$(cat '$tmp/out')\" = 'stopped $ID1'"
check "-EndDay idle: relay probe, one pinned in-container check, then the stop, and nothing else" test "$(exec_shape)" = "exec -u root,exec -u app,stop $ID1 ,"
check "-EndDay idle: one in-container exec, GIT_NO_REPLACE_OBJECTS=1" app_execs_pinned 1
check "-EndDay idle: no model read, no interactive exec" no_it
check "-EndDay idle: the record is byte-identical afterwards" cmp -s "$tmp/rec-snap" "$home/driver/wb-driver.json"
check "-EndDay idle: no argv holds & | ^ % ! or a double quote" no_banned
end_setup; run_lane -EndDay
check "-EndDay through the long form: stops the recorded container" sh -c "test $rc -eq 0 && grep -q -x 'docker stop $ID1' '$stubdir/calls.log'"
end_setup; rm -rf "$lanes"; run_repo_lane -Repo acme/widgets -EndDay
check "-EndDay (no lanes directory): idle, stops" sh -c "test $rc -eq 0 && grep -q -x 'docker stop $ID1' '$stubdir/calls.log'"
end_setup; echo dirty >"$stubdir/probe.out"; run_repo_lane -Repo acme/widgets -EndDay
end_refuses 'a dirty relay probe' 'VS Code attach'
check "-EndDay (a dirty relay probe): no in-container check ran" no_app_exec
end_setup; : >"$stubdir/it.owner"; run_repo_lane -Repo acme/widgets -EndDay
end_refuses 'a lanes directory not owned by the user' 'link, not a directory'
end_setup; echo 3 >"$stubdir/stop.exit"; run_repo_lane -Repo acme/widgets -EndDay
check "-EndDay (docker stop fails): exit 1 naming the stop" sh -c "test $rc -eq 1 && grep -q 'docker stop failed' '$tmp/err'"
check "-EndDay (docker stop fails): does not print stopped" sh -c "! grep -q stopped '$tmp/out'"
end_setup; rm -rf "$lanes"; ln -s "$tmp/nowhere" "$lanes" 2>/dev/null && { run_repo_lane -Repo acme/widgets -EndDay; end_refuses 'a dangling lanes link' 'link, not a directory'; rm -f "$lanes"; }
end_bad() { # end_bad <label> <args...>
  l=$1; shift; end_setup
  run_repo_lane -Repo acme/widgets "$@"
  check "-EndDay ($l): exit 2 with a usage line" sh -c "test $rc -eq 2 && grep -q 'usage: wow-lane.ps1' '$tmp/err'"
  check "-EndDay ($l): no external call" none_called
}
end_bad 'with -Issue and -Hash' -EndDay -Issue 5 -Hash "$PH"
end_bad 'with -Spec' -EndDay -Spec 5
end_bad 'with -SpecSweep' -EndDay -SpecSweep
end_bad 'with -Hash alone' -EndDay -Hash "$PH"

if [ -n "$msys" ]; then
  skip "the fake running session needs /proc; the -EndDay busy fixtures did not run under MSYS"
else
  mk_fake
  end_busy() { # end_busy <label> <dir>: a running claude in <dir> refuses -EndDay
    end_setup
    if fake_start "$2"; then
      run_repo_lane -Repo acme/widgets -EndDay
      end_refuses "$1" 'still running'
      check "-EndDay ($1): the in-container check ran once" app_execs_pinned 1
      fake_stop
    else bad "the fake running session never read as claude"; fake_stop; fi
  }
  end_busy 'a lane session in a numbered lane leaf' "$lanes/5"
  end_setup; mkdir "$lanes/spec-aaa111"
  if fake_start "$lanes/spec-aaa111"; then
    run_repo_lane -Repo acme/widgets -EndDay
    end_refuses 'a spec session' 'still running'
    rm -rf "$lanes/spec-aaa111"
    rerun_end() { rm -f "$stubdir"/n.*; : >"$stubdir/calls.log"; run_repo_lane -Repo acme/widgets -EndDay; }
    rerun_end
    end_refuses 'a spec session whose leaf was removed under it' 'still running'
    fake_stop
  else bad "the fake running session never read as claude"; fake_stop; fi
  # the driver session runs in /workspace: it does not count as busy
  end_setup
  if fake_start "$crepo"; then
    run_repo_lane -Repo acme/widgets -EndDay
    check "-EndDay (a claude in the container clone, the driver's place): not busy, stops" sh -c "test $rc -eq 0 && grep -q -x 'docker stop $ID1' '$stubdir/calls.log'"
    fake_stop
  else bad "the fake running session never read as claude"; fake_stop; fi
  # a process named claude that is not under the lanes directory but under a sibling with the same prefix
  end_setup; mkdir "$lanes-other"
  if fake_start "$lanes-other"; then
    run_repo_lane -Repo acme/widgets -EndDay
    check "-EndDay (a claude under a sibling directory with the lanes name as a prefix): not busy" sh -c "test $rc -eq 0 && grep -q -x 'docker stop $ID1' '$stubdir/calls.log'"
    fake_stop
  else bad "the fake running session never read as claude"; fake_stop; fi
  rm -rf "$lanes-other"
fi

# the end-of-day script, run for real, reads an empty /proc as unreadable, never idle
endday_unreadable() {
  script=$(sed -n '/^function Get-EndDayScript/,/^}/p' "$root_dir/scripts/identity/wow-lane.ps1" | sed -n 2p | sed "s/^  [\$]script:LanesGuard + '//; s/'\$//")
  g=$(grep -E "^[\$]script:LanesGuard = '.*'\$" "$root_dir/scripts/identity/wow-lane.ps1" | sed "s/^[^']*'//; s/'\$//")
  [ -n "$g" ] || return 1
  # a stand-in for ls that prints nothing: the walk sees no process id, its own included
  mkdir -p "$tmp/emptybin"; printf '#!/bin/sh\nexit 0\n' >"$tmp/emptybin/ls"; chmod +x "$tmp/emptybin/ls"
  mkdir -p "$tmp/el"; chmod 700 "$tmp/el"
  w=$(PATH="$tmp/emptybin:$PATH" /bin/sh -c "$g$script" sh "$tmp/el")
  [ "$w" = unreadable ]
}
if [ -n "$msys" ]; then skip "the end-of-day script runs against /proc; the unreadable fixture did not run under MSYS"; else
  check "-EndDay script: a walk that sees no process, its own included, answers unreadable and not idle" endday_unreadable
fi

# Get-Help on each launcher in the checkout (the script is not run) returns the .SYNOPSIS text, not the syntax line (#1386)
help_synopsis() { "$pwsh_abs" -NoProfile -NonInteractive -Command "(Get-Help -Name '$(wp "$root_dir/scripts/identity/$1")' -ErrorAction Stop).Synopsis" 2>/dev/null | tr -d '\r'; }
help_starts() { # help_starts <script> <text>
  out=$(help_synopsis "$1"); case "$out" in "$2"*) return 0 ;; esac; return 1
}
check "Get-Help wow-driver.ps1: the Synopsis begins with the .SYNOPSIS text" help_starts wow-driver.ps1 'Start the driver session'
check "Get-Help wow-lane.ps1: the Synopsis begins with the .SYNOPSIS text" help_starts wow-lane.ps1 'Start a coder lane'
help_names_home() { out=$(help_synopsis "$1"); case "$out" in *"the -WowHome identity home serves"*) return 0 ;; esac; return 1; }
check "wow-driver.ps1's .SYNOPSIS names the identity home the org is read from" help_names_home wow-driver.ps1
check "wow-lane.ps1's .SYNOPSIS names the identity home the org is read from" help_names_home wow-lane.ps1
no_bare_any_repo() { ! grep -q 'Any repository of the org works' "$root_dir/scripts/identity/wow-driver.ps1" "$root_dir/scripts/identity/wow-lane.ps1"; }
check "neither launcher says \"Any repository of the org works\"" no_bare_any_repo

  :
}

# Run every section at once; replay each one's output in order.
sections="notinst badargs start startb attach lanea laneb lanec laned misc msys origin yqver repo"
pids=
# An interrupt stops the section subshells and removes the scratch tree (a signal skips the EXIT trap);
# a pwsh run already in flight ends on its own, as test-all.sh's header allows.
stop_sections() { kill $pids 2>/dev/null || :; rm -rf "$tmp_root" || :; exit "$1"; }
trap 'stop_sections 129' HUP; trap 'stop_sections 130' INT; trap 'stop_sections 143' TERM
for n in $sections; do
  ( setup_world "$n"; "sec_$n"; [ "$fail" -eq 0 ] ) >"$tmp_root/$n.out" 2>"$tmp_root/$n.err" &
  eval "pid_$n=$!"; pids="$pids $!"
done
all_ok=1
for n in $sections; do
  eval "p=\$pid_$n"; src=0; wait "$p" || src=$?
  cat "$tmp_root/$n.out"; cat "$tmp_root/$n.err" >&2
  [ "$src" -eq 0 ] || { echo "FAIL - section $n exited $src" >&2; all_ok=0; }
done

[ "$all_ok" -eq 1 ] || { echo "identity-launchers: FAILED" >&2; exit 1; }
echo "identity-launchers: all passed"
