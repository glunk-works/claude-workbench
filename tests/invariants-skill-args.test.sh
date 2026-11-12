#!/bin/sh
# Fixture tests for scripts/invariants-check.sh's check 29: no SKILL.md holds a bare `$<digit>`,
# which the skill loader rewrites with the invocation argument (#1470).
#
# Each case mutates a COPY of the real tree and asserts the check fires (or stays silent), so
# a check that only passes on the real tree cannot hide. Only check 29's own message is
# asserted, never the script's overall exit.
#
# Every case but the first control runs just check 29 (`--only 29`); that control runs the full checker.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/invariants-check.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# One read of the checkout per run: every fixture copies from this, never from the root.
pristine="$tmp/.pristine"
mkdir -p "$pristine"
cp -R "$root_dir/plugins" "$pristine/plugins"

fail=0
MSG='holds a bare $<digit>'

tree() {
  d="$tmp/$1"
  mkdir -p "$d"
  cp -R "$pristine/plugins" "$d/plugins"
  echo "$d"
}

sel="--only 29"

run() { ( cd "$1" || exit 1; rc=0; bash "$script" $sel 2>&1 >/dev/null || rc=$?; [ "$rc" -ne 2 ] || : >"$tmp/usage-exit" ) || true; }

assert_fires() { # <desc> <dir>
  if run "$2" | grep -qF -- "$MSG"; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected check 29 to fire" >&2
    fail=1
  fi
}

assert_silent() { # <desc> <dir>
  if run "$2" | grep -qF -- "$MSG"; then
    echo "FAIL - $1: check 29 fired" >&2
    fail=1
  else
    echo "ok - $1"
  fi
}

skill() { ls "$1"/plugins/*/skills/handoff/SKILL.md; }

# Control: the real tree is clean, under the full checker.
sel=
d="$(tree control)"
assert_silent "real tree passes" "$d"
sel="--only 29"

d="$(tree bare0)"
printf '%s\n' 'awk '"'"'{ print $0 }'"'"' f' >>"$(skill "$d")"
assert_fires 'a bare $0 fires' "$d"

d="$(tree bare12)"
printf '%s\n' 'echo $12' >>"$(skill "$d")"
assert_fires 'a bare $12 fires' "$d"

d="$(tree safe)"
printf '%s\n' 'awk '"'"'{ print $(0) $(1) }'"'"' f; echo "${1}"' >>"$(skill "$d")"
assert_silent 'the $(N) and ${N} forms stay silent' "$d"

d="$(tree prose)"
printf '%s\n' 'Prose naming $1 outside any fence.' >>"$(skill "$d")"
assert_fires 'a $1 in prose fires' "$d"

d="$(tree nofile)"
rm -f "$d"/plugins/*/skills/*/SKILL.md
assert_fires 'a tree with no SKILL.md fires' "$d"

[ ! -e "$tmp/usage-exit" ] || { echo "FAIL - the checker exited 2 (usage) in at least one case" >&2; fail=1; }

[ "$fail" -eq 0 ]
