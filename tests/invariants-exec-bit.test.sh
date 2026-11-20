#!/bin/sh
# Fixture tests for scripts/invariants-check.sh's check 9: every executed hook, bin script and
# scripts/identity host command is stored executable (#214, #1492).
#
# Each case builds a throwaway git repository holding a tracked, 100755 plugin bin script and, in all
# but the last case, a scripts/identity tree, and runs only check 9 (`--only 9`) from it. The host commands are the
# extensionless `wow-*` names: wow-common.sh is sourced and a `.ps1` runs under pwsh, so a 100644
# for either is not a finding. The control case has every host command 100755 and fires nothing.
#
# The two cases that expect a message assert only that message. The control and no-identity cases, which
# expect silence, also assert the run's exit is 0: a crash before check 9's messages (an empty host-command
# array on a bash older than 4.4) prints neither of them, so silence alone would pass it.
#
# Permitted toolset: POSIX sh and git; the suite skips, loudly, without git.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/invariants-check.sh"

if ! command -v git >/dev/null 2>&1; then
  echo "skip - invariants-exec-bit fixtures: no git on PATH" >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
MODE_MSG="a hook, bin script or host command is stored without the executable bit"
DONE_MSG="the executable-bit check could not be completed"

# repo <name> [identity]: a repository with one 100755 plugin bin script; with `identity`, a scripts/identity tree
# whose host commands wow-x and wow-y are 100755, plus wow-common.sh and wow-y.ps1 stored 100644.
repo() {
  d="$tmp/$1"
  mkdir -p "$d/plugins/p/bin"
  (
    cd "$d"
    git init -q .
    git config user.email t@example.invalid
    git config user.name t
    printf '#!/bin/sh\n' >plugins/p/bin/a.sh
    chmod 755 plugins/p/bin/a.sh
    git add plugins/p/bin/a.sh
    git update-index --chmod=+x plugins/p/bin/a.sh
    if [ "${2:-}" = identity ]; then
      mkdir -p scripts/identity
      for f in wow-x wow-y; do printf '#!/bin/sh\n' >"scripts/identity/$f"; chmod 755 "scripts/identity/$f"; done
      printf '# sourced\n' >scripts/identity/wow-common.sh
      printf '# pwsh\n' >scripts/identity/wow-y.ps1
      chmod 644 scripts/identity/wow-common.sh scripts/identity/wow-y.ps1
      git add scripts/identity
      git update-index --chmod=+x scripts/identity/wow-x scripts/identity/wow-y
    fi
  )
  echo "$d"
}

run() { # run <dir> -> check 9's stderr on stdout
  ( cd "$1" && bash "$script" --only 9 2>&1 >/dev/null || true )
}

run_status() { # run_status <dir> -> the run's exit status
  ( cd "$1" && bash "$script" --only 9 >/dev/null 2>&1 ) && echo 0 || echo $?
}

assert_fires() { # assert_fires <desc> <dir> <message> [<also>]
  out=$(run "$2")
  if printf '%s\n' "$out" | grep -qF -- "$3" && { [ -z "${4:-}" ] || printf '%s\n' "$out" | grep -qF -- "$4"; }; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$3] ${4:+and [$4] }in the check's output" >&2
    fail=1
  fi
}

assert_silent() { # assert_silent <desc> <dir>: neither message, and the run completed (exit 0)
  out=$(run "$2")
  status=$(run_status "$2")
  if printf '%s\n' "$out" | grep -qF -e "$MODE_MSG" -e "$DONE_MSG"; then
    echo "FAIL - $1: check 9 spoke: $out" >&2
    fail=1
  elif [ "$status" != 0 ]; then
    echo "FAIL - $1: the run exited $status: $out" >&2
    fail=1
  else
    echo "ok - $1"
  fi
}

d=$(repo control identity)
assert_silent "every host command 100755, wow-common.sh and a .ps1 100644: nothing fires" "$d"

d=$(repo mode644 identity)
( cd "$d" && git update-index --chmod=-x scripts/identity/wow-x )
assert_fires "a wow-x stored 100644 fires the mode message and names the path" "$d" "$MODE_MSG" "scripts/identity/wow-x (mode 100644)"

d=$(repo untracked identity)
printf '#!/bin/sh\n' >"$d/scripts/identity/wow-z"; chmod 755 "$d/scripts/identity/wow-z"
assert_fires "an untracked wow-z fires the could-not-be-completed message" "$d" "$DONE_MSG"

d=$(repo noidentity)
assert_silent "a tree with no scripts/identity reports nothing" "$d"

exit "$fail"
