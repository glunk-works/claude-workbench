#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/driver-lock.sh.
#
# #233 (sprint-orchestrator plan v9 § 7.5): resume must not auto-start while the
# driver's lock exists, and an unreadable location or lock reads as not-absent.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/driver-lock.sh"

tmp="$(mktemp -d)"
trap 'chmod -R u+rwx "$tmp" 2>/dev/null || true; rm -rf "$tmp"' EXIT

fail=0

assert_eq() {
  desc="$1"
  expected="$2"
  actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$expected], got [$actual]" >&2
    fail=1
  fi
}

# Run the script with a controlled environment: only what the case names.
run() {
  env -i PATH="$PATH" "$@" sh "$script"
}

# -- declared location ($WOW_DRIVER_DIR) --------------------------------------
d="$tmp/declared"
mkdir "$d"
assert_eq "declared dir, no lock: absent" absent "$(run WOW_DRIVER_DIR="$d")"

: >"$d/lock"
assert_eq "declared dir, lock file: present" present "$(run WOW_DRIVER_DIR="$d")"

rm "$d/lock"
mkdir "$d/lock"
assert_eq "declared dir, lock is a directory: present" present "$(run WOW_DRIVER_DIR="$d")"
rmdir "$d/lock"

ln -s "$tmp/nowhere" "$d/lock" 2>/dev/null && {
  assert_eq "declared dir, broken-symlink lock: present" present "$(run WOW_DRIVER_DIR="$d")"
  rm "$d/lock"
} || echo "skip - symlinks unavailable on this host"

: >"$d/lock.bak"
: >"$d/other"
assert_eq "declared dir, only look-alike names: absent" absent "$(run WOW_DRIVER_DIR="$d")"

assert_eq "declared dir missing: unreadable, never absent" unreadable \
  "$(run WOW_DRIVER_DIR="$tmp/typo")"

: >"$tmp/a-file"
assert_eq "declared path is a file: unreadable" unreadable \
  "$(run WOW_DRIVER_DIR="$tmp/a-file")"

# A declared location beats the default: a lock at the default is not seen.
mkdir -p "$tmp/home1/.config/way-of-working/driver"
: >"$tmp/home1/.config/way-of-working/driver/lock"
assert_eq "declared dir wins over the default's lock" absent \
  "$(run WOW_DRIVER_DIR="$d" HOME="$tmp/home1")"

# -- default location ---------------------------------------------------------
assert_eq "default: lock under \$HOME/.config" present "$(run HOME="$tmp/home1")"

mkdir -p "$tmp/home2/.config/way-of-working/driver"
assert_eq "default: dir exists, no lock: absent" absent "$(run HOME="$tmp/home2")"

mkdir -p "$tmp/home3"
assert_eq "default: nothing installed: absent" absent "$(run HOME="$tmp/home3")"

mkdir -p "$tmp/xdg/way-of-working/driver"
: >"$tmp/xdg/way-of-working/driver/lock"
assert_eq "default: \$XDG_CONFIG_HOME is honoured over \$HOME" present \
  "$(run XDG_CONFIG_HOME="$tmp/xdg" HOME="$tmp/home3")"

assert_eq "default: neither HOME nor a declaration: unreadable" unreadable "$(run)"

assert_eq "empty WOW_DRIVER_DIR is not a declaration: falls to the default" present \
  "$(run WOW_DRIVER_DIR= HOME="$tmp/home1")"

mkdir -p "$tmp/home4/.config/way-of-working"
: >"$tmp/home4/.config/way-of-working/driver"
assert_eq "default path exists but is a file: unreadable" unreadable \
  "$(run HOME="$tmp/home4")"

# -- relative paths never resolve against the caller's clone --------------------
mkdir -p "$tmp/clone/emptydir"
assert_eq "relative WOW_DRIVER_DIR: unreadable, not resolved against cwd" unreadable \
  "$(cd "$tmp/clone" && run WOW_DRIVER_DIR=emptydir)"
assert_eq "relative WOW_DRIVER_DIR '.': unreadable" unreadable \
  "$(cd "$tmp/clone" && run WOW_DRIVER_DIR=.)"
assert_eq "relative XDG_CONFIG_HOME is ignored: the \$HOME default's lock still shows" present \
  "$(cd "$tmp/clone" && run XDG_CONFIG_HOME=. HOME="$tmp/home1")"
assert_eq "relative HOME: unreadable" unreadable "$(cd "$tmp/clone" && run HOME=emptydir)"

mkdir -p "$tmp/home5"
: >"$tmp/home5/.config"
assert_eq "default: an ancestor is a file: unreadable, not absent" unreadable \
  "$(run HOME="$tmp/home5")"

# -- permissions (skipped where chmod does not bite: root, or a no-mode fs) ----
p="$tmp/locked-dir"
mkdir "$p"
: >"$p/lock"
chmod 000 "$p"
if [ ! -r "$p" ] && [ ! -x "$p" ]; then
  assert_eq "unsearchable dir holding a lock: unreadable, never absent" unreadable \
    "$(run WOW_DRIVER_DIR="$p")"
else
  echo "skip - chmod 000 does not restrict this user/filesystem"
fi
chmod 755 "$p"

# A directory searchable but not listable (mode 311 -- owner-unlistable, unlike
# 0711) still answers `-e dir/lock`.
q="$tmp/unlistable"
mkdir "$q"
: >"$q/lock"
chmod 311 "$q"
if [ ! -r "$q" ] && [ -x "$q" ]; then
  assert_eq "searchable-but-unlistable dir holding a lock: present" present \
    "$(run WOW_DRIVER_DIR="$q")"
else
  echo "skip - chmod 311 does not restrict this user/filesystem"
fi
chmod 755 "$q"

# An unsearchable ANCESTOR of the default location: stat below it fails like
# "not there", which must not read as a driverless host.
mkdir -p "$tmp/home6/.config/way-of-working/driver"
: >"$tmp/home6/.config/way-of-working/driver/lock"
chmod 000 "$tmp/home6/.config/way-of-working"
if [ ! -x "$tmp/home6/.config/way-of-working" ] && [ ! -e "$tmp/home6/.config/way-of-working/driver" ]; then
  assert_eq "default: unsearchable ancestor over a real lock: unreadable, never absent" unreadable \
    "$(run HOME="$tmp/home6")"
else
  echo "skip - chmod 000 does not restrict this user/filesystem"
fi
chmod 755 "$tmp/home6/.config/way-of-working"

# -- usage --------------------------------------------------------------------
if sh "$script" extra >/dev/null 2>&1; then
  echo "FAIL - an argument should be a usage error" >&2
  fail=1
else
  echo "ok - an argument is a usage error"
fi

exit "$fail"
