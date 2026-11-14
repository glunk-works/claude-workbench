#!/bin/sh
# Fixture tests for scripts/invariants-check.sh's check 30: under an identities map, diff-mode
# critics judge only against the approved spec, so critic-gate's SKILL.md and the three critic
# agents carry their lead-ins and name no `--json body` or `--json comments` (#1423, WB-D50).
#
# Each case mutates a COPY of the real tree and asserts the check fires (or stays silent), so
# a check that only passes on the real tree cannot hide. Only check 30's own message is
# asserted, never the script's overall exit.
#
# Every case but the first control runs just check 30 (`--only 30`); that control runs the full checker.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/invariants-check.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pristine="$tmp/.pristine"
mkdir -p "$pristine"
cp -R "$root_dir/plugins" "$pristine/plugins"

fail=0
MSG="a diff-mode critic may judge against the task issue's body or comments under an identities map"
GATE_LEAD='**Under an identities map, the critics judge against the approved spec only.**'
AGENT_LEAD='**Under an identities map, you judge against the approved spec only.**'

tree() {
  d="$tmp/$1"
  mkdir -p "$d"
  cp -R "$pristine/plugins" "$d/plugins"
  echo "$d"
}

sel="--only 30"

run() { ( cd "$1" || exit 1; rc=0; bash "$script" $sel 2>&1 >/dev/null || rc=$?; [ "$rc" -ne 2 ] || : >"$tmp/usage-exit" ) || true; }

assert_fires() { # <desc> <dir>
  if run "$2" | grep -qF -- "$MSG"; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected check 30 to fire" >&2
    fail=1
  fi
}

assert_silent() { # <desc> <dir>
  if run "$2" | grep -qF -- "$MSG"; then
    echo "FAIL - $1: check 30 fired" >&2
    fail=1
  else
    echo "ok - $1"
  fi
}

# Control: the real tree is clean, under the full checker.
sel=
d="$(tree control)"
assert_silent "real tree passes" "$d"
sel="--only 30"

# Removing the critic-gate lead-in fires.
d="$(tree nogate)"
f="$(ls "$d"/plugins/*/skills/critic-gate/SKILL.md)"
grep -vF -- "$GATE_LEAD" "$f" >"$f.new" && mv "$f.new" "$f"
assert_fires "critic-gate without its lead-in fires" "$d"

# Removing the agent lead-in from each one of the three agents fires.
for a in architect security-critic docs-consistency; do
  d="$(tree "no-$a")"
  f="$(ls "$d"/plugins/*/agents/$a.md)"
  sed 's/Under an identities map, you judge/Under a map, you judge/' "$f" >"$f.new" && mv "$f.new" "$f"
  assert_fires "$a without its lead-in fires" "$d"
done

# A forbidden read appended to an agent, and to critic-gate, fires.
d="$(tree bodyagent)"
f="$(ls "$d"/plugins/*/agents/architect.md)"
printf '%s\n' 'Run gh issue view 1 --json body,comments to read the task.' >>"$f"
assert_fires "an agent naming --json body,comments fires" "$d"

d="$(tree bodygate)"
f="$(ls "$d"/plugins/*/skills/critic-gate/SKILL.md)"
printf '%s\n' 'Run gh issue view 1 --json comments to read the task.' >>"$f"
assert_fires "critic-gate naming --json comments fires" "$d"

# A missing file is a hit: a check that cannot look must not pass.
d="$(tree noagentfile)"
rm "$d"/plugins/*/agents/security-critic.md
assert_fires "a missing agent file fires" "$d"

d="$(tree nogatefile)"
rm "$d"/plugins/*/skills/critic-gate/SKILL.md
assert_fires "a missing critic-gate SKILL.md fires" "$d"

[ ! -e "$tmp/usage-exit" ] || { echo "FAIL - the checker exited 2 (usage) in at least one case" >&2; fail=1; }

[ "$fail" -eq 0 ]
