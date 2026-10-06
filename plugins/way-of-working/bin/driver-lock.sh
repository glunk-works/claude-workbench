#!/bin/sh
# Is an orchestrator driver running in this host's driver directory?
#
# The sprint-orchestrator driver (docs/proposals/sprint-orchestrator-plan-v9.md
# § 7.5) holds a lock file in its own driver directory while it works, and
# /way-of-working:resume must not auto-start a task while that lock exists --
# two writers on one clone. This is the deterministic predicate resume calls,
# mirroring cursor-drift.sh's shape: prose already gets "is that path readable?"
# wrong in both directions, so it is a tested script, not a check in SKILL.md.
#
# Where the driver directory is found -- decided here (#233), and it is the
# DRIVER'S config, never a repo value (plan § 8.4d, D3): not a key in any
# .ai/project.yml, so no repo's project file can claim or redirect it. It is
# read from the process environment, which a repo's committed project
# `.claude/settings.json` `env` block can ALSO set -- a stated residual (the
# same repo can already add hooks). Accepting absolute paths only stops a value
# from resolving against the clone by accident; it does NOT stop a repo setting
# one on purpose (`WOW_DRIVER_DIR=/` reads `absent`). One host fact, resolved in
# this order:
#   1. $WOW_DRIVER_DIR, when set and non-empty -- an explicit declaration,
#      which must be an absolute path (a relative one reads `unreadable`).
#   2. otherwise `<base>/way-of-working/driver`, where <base> is
#      $XDG_CONFIG_HOME when that is an absolute path (a relative value is
#      ignored, as the XDG Base Directory spec requires) and `$HOME/.config`
#      otherwise -- the default the driver creates. A fixed, plugin-defined
#      host path rather than "no variable, no guard": a guard that only works
#      when the human's interactive shell happens to export the driver's
#      variable would fail open on exactly the host where it matters.
# The lock is the entry named `lock` directly inside that directory.
#
# Contract the DRIVER must keep, or this guard silently reads `absent` while it
# runs: it runs as the same OS user as the interactive session, and it either
# keeps its directory at the default location or exports $WOW_DRIVER_DIR into
# the login environment the human's Claude Code sessions inherit -- not only
# into its own process or service unit.
#
# Usage: driver-lock.sh        (reads WOW_DRIVER_DIR, XDG_CONFIG_HOME, HOME)
# Prints exactly one of, to stdout, and exits 0 (the caller decides policy; only a usage error exits 2, with nothing on stdout):
#   present    -- the lock entry exists (a file, a directory, or a symlink --
#                 even a broken one: the driver put *something* there)
#   absent     -- the directory is searchable and holds no lock, OR the default
#                 location does not exist and every ancestor of it that does
#                 exist is a searchable directory (no driver was ever installed
#                 on this host -- the ordinary case for every repo that does
#                 not use the orchestrator)
#   unreadable -- anything that leaves "is there a lock?" unanswerable: the
#                 location cannot be resolved (no absolute $XDG_CONFIG_HOME, no usable $HOME and nothing
#                 declared), a DECLARED $WOW_DRIVER_DIR that is relative, or is
#                 not a searchable directory, a default location that exists
#                 but is not a directory, or an ancestor that exists but cannot
#                 be searched (stat on everything below it fails with EACCES,
#                 which looks exactly like "not there"). A declared location
#                 that is missing reads unreadable, not absent: a typo in the
#                 declaration must not read as "no driver".
# resume waits on `present` and `unreadable` alike and proceeds only on
# `absent` ("an unreadable location or lock reads as present", #233).
#
# Limits, stated rather than implied: the lock is host-wide, not scoped to a
# clone or a task (plan § 7.4 defers that choice), so it blocks resume in every
# repo on the host while the driver runs; narrowing it is a later change to
# this predicate, not to resume's policy. And this is a read, not mutual
# exclusion: a driver that starts after resume read `absent` is not stopped.
#
# Permitted toolset: POSIX sh, test(1), dirname(1), uname(1). No jq, no yq, no python.
set -eu

if [ "$#" -ne 0 ]; then
  echo "usage: driver-lock.sh" >&2
  exit 2
fi

# An absolute path: POSIX `/...`, or -- only on an MSYS/MinGW/Cygwin host, where
# it is one -- a Windows drive path (`C:/...`, `C:\...`); on any other host that
# form is relative.
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*) drive_paths=1 ;;
  *) drive_paths=0 ;;
esac
is_abs() {
  case "$1" in
    /*) return 0 ;;
    [A-Za-z]:[/\\]*) [ "$drive_paths" -eq 1 ] ;;
    *) return 1 ;;
  esac
}

declared=0
if [ -n "${WOW_DRIVER_DIR:-}" ]; then
  dir="$WOW_DRIVER_DIR"
  declared=1
  if ! is_abs "$dir"; then
    echo unreadable
    exit 0
  fi
else
  base="${XDG_CONFIG_HOME:-}"
  if [ -n "$base" ] && ! is_abs "$base"; then
    base=
  fi
  if [ -z "$base" ]; then
    if [ -z "${HOME:-}" ] || ! is_abs "$HOME"; then
      echo unreadable
      exit 0
    fi
    base="$HOME/.config"
  fi
  base="${base%/}"   # one trailing slash off, so a bare `/` XDG value joins as `/way-of-working/...`, not a `//` (UNC-shaped on MSYS) path
  dir="$base/way-of-working/driver"
fi

if [ ! -d "$dir" ]; then
  # `-d` is false both for "not there" and for "there but not a directory" and
  # for "an ancestor cannot be searched". Only a default location with nothing
  # but searchable directories above it is a driverless host.
  if [ "$declared" -eq 0 ] && [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
    anc="$dir"
    while :; do
      parent="$(dirname "$anc")"
      if [ "$parent" = "$anc" ]; then
        break
      fi
      anc="$parent"
      if [ -e "$anc" ] || [ -L "$anc" ]; then
        break
      fi
    done
    if [ -d "$anc" ] && [ -x "$anc" ]; then
      echo absent
    else
      echo unreadable
    fi
  else
    echo unreadable
  fi
  exit 0
fi

# Without search permission `-e` on an entry inside answers false for a lock
# that is really there, so absence is only believable with it. (Read permission
# is not needed to stat a named entry, so a 0711 directory is fine.)
if [ ! -x "$dir" ]; then
  echo unreadable
  exit 0
fi

if [ -e "$dir/lock" ] || [ -L "$dir/lock" ]; then
  echo present
else
  echo absent
fi
