#!/bin/sh
# Fixture tests for scripts/invariants-check.sh's check 27: every plugins/*/skills/*/ directory is
# named as /PLUGIN:SKILL in both manifest descriptions of its plugin (#1249).
#
# Each case mutates a COPY of the real tree and asserts the check fires (or stays silent), so
# a check that only passes on the real tree cannot hide. Only check 27's own message is
# asserted, never the script's overall exit; a usage exit (2) fails the suite.
#
# Every case but the first control runs just check 27 (`--only 27`); that control runs the full checker.
#
# Permitted toolset: POSIX sh, sed, grep and jq (several fixtures edit a manifest with it; the checker
# needs it too, so this test skips, loudly, without it). No yq, no python.
set -eu

command -v jq >/dev/null 2>&1 || { echo "SKIP - jq is not on PATH; check 27 cannot run" >&2; exit 0; }

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/invariants-check.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# One read of the checkout per run: every fixture copies from this, never from the root.
pristine="$tmp/.pristine"
mkdir -p "$pristine"
cp -R "$root_dir/plugins" "$pristine/plugins"
cp -R "$root_dir/.claude-plugin" "$pristine/.claude-plugin"

fail=0
MSG='a skill is missing from a manifest description (#1249)'

tree() {
  d="$tmp/$1"
  mkdir -p "$d"
  cp -R "$pristine/plugins" "$d/plugins"
  cp -R "$pristine/.claude-plugin" "$d/.claude-plugin"
  echo "$d"
}

sel="--only 27"

run() { ( cd "$1" || exit 1; rc=0; bash "$script" $sel 2>&1 >/dev/null || rc=$?; [ "$rc" -ne 2 ] || : >"$tmp/usage-exit" ) || true; }

assert_fires() { # <desc> <dir>
  if run "$2" | grep -qF -- "$MSG"; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected check 27 to fire" >&2
    fail=1
  fi
}

assert_silent() { # <desc> <dir>
  if run "$2" | grep -qF -- "$MSG"; then
    echo "FAIL - $1: check 27 fired" >&2
    fail=1
  else
    echo "ok - $1"
  fi
}

plugin_json() { ls "$1"/plugins/way-of-working/.claude-plugin/plugin.json; }
market() { echo "$1/.claude-plugin/marketplace.json"; }
newskill() { # <dir>: a new skill directory zzqskill with a SKILL.md
  mkdir -p "$1/plugins/way-of-working/skills/zzqskill"
  printf -- '---\nname: zzqskill\ndescription: x\n---\nbody\n' >"$1/plugins/way-of-working/skills/zzqskill/SKILL.md"
}
# Name a skill after "/way-of-working:resume" in a manifest's description (the one place both hold it).
addname() { # <file> <text>
  sed "s|/way-of-working:resume|/way-of-working:resume, $2|" "$1" >"$1.new" && mv "$1.new" "$1"
}
jqedit() { # <file> <program>
  jq "$2" "$1" >"$1.new" && mv "$1.new" "$1"
}
replace() { # <file> <sed-expr>
  sed "$2" "$1" >"$1.new" && mv "$1.new" "$1"
}

# Control: the real tree is clean, under the full checker.
sel=
d="$(tree control)"
assert_silent "real tree passes" "$d"
sel="--only 27"

d="$(tree neither)"
newskill "$d"
assert_fires "a new skill named in neither description fires" "$d"

d="$(tree empty)"
mkdir -p "$d/plugins/way-of-working/skills/zzqskill"
assert_fires "an empty skill directory named in neither description fires" "$d"

d="$(tree nested)"
mkdir -p "$d/plugins/way-of-working/skills/resume/zzqnested"
assert_silent "a nested directory under a skill is not a skill, so it is silent" "$d"

d="$(tree pluginonly)"
newskill "$d"
addname "$(plugin_json "$d")" /way-of-working:zzqskill
assert_fires "a new skill named only in plugin.json fires" "$d"

d="$(tree marketonly)"
newskill "$d"
addname "$(market "$d")" /way-of-working:zzqskill
assert_fires "a new skill named only in marketplace.json fires" "$d"

d="$(tree both)"
newskill "$d"
addname "$(plugin_json "$d")" /way-of-working:zzqskill
addname "$(market "$d")" /way-of-working:zzqskill
assert_silent "a new skill named in both descriptions is silent" "$d"

d="$(tree bare)"
newskill "$d"
addname "$(plugin_json "$d")" zzqskill
addname "$(market "$d")" zzqskill
assert_fires "a new skill named only bare, without /way-of-working:, fires" "$d"

d="$(tree noslash)"
newskill "$d"
addname "$(plugin_json "$d")" way-of-working:zzqskill
addname "$(market "$d")" way-of-working:zzqskill
assert_fires "a skill named as way-of-working:NAME without the leading slash fires" "$d"

d="$(tree trailing)"
replace "$(market "$d")" 's|/way-of-working:retro,|/way-of-working:retros,|'
grep -qF ':retros' "$(market "$d")" || { echo "FAIL - trailing fixture edit did not apply" >&2; fail=1; }
assert_fires "/way-of-working:retro rewritten to retros in one manifest fires" "$d"

d="$(tree metaskill)"
mv "$d/plugins/way-of-working/skills/retro" "$d/plugins/way-of-working/skills/ret.o"
assert_fires "a skill directory name holding a regex metacharacter fires" "$d"

d="$(tree metaplugin)"
replace "$(plugin_json "$d")" 's|"name": "way-of-working"|"name": "way.of.working"|'
replace "$(market "$d")" 's|"name": "way-of-working"|"name": "way.of.working"|'
assert_fires "a plugin.json name holding a regex metacharacter fires" "$d"

d="$(tree noskills)"
rm -rf "$d"/plugins/*/skills
assert_fires "a tree with no skill directories fires" "$d"

d="$(tree nomarket)"
rm -f "$(market "$d")"
assert_fires "a missing marketplace.json fires" "$d"

d="$(tree badmp)"
printf '{"plugins": [' >"$(market "$d")"
assert_fires "a marketplace.json that is not valid JSON fires" "$d"

d="$(tree noentry)"
replace "$(market "$d")" 's/"name": "way-of-working"/"name": "other-plugin"/'
assert_fires "no marketplace entry for the plugin fires" "$d"

d="$(tree dupentry)"
jqedit "$(market "$d")" '.plugins += [.plugins[] | select(.name == "way-of-working")]'
assert_fires "two marketplace entries for the plugin fire" "$d"

d="$(tree nopj)"
rm -f "$(plugin_json "$d")"
assert_fires "a missing plugin.json fires" "$d"

d="$(tree badpj)"
printf '{"name": "way-of-working", "description": ' >"$(plugin_json "$d")"
assert_fires "a plugin.json that is not valid JSON fires" "$d"

d="$(tree pjarr)"
jqedit "$(plugin_json "$d")" '.description = [.description]'
assert_fires "a non-string plugin.json description fires" "$d"

d="$(tree pjempty)"
jqedit "$(plugin_json "$d")" '.description = ""'
assert_fires "an empty plugin.json description fires" "$d"

d="$(tree mparr)"
jqedit "$(market "$d")" '(.plugins[] | select(.name == "way-of-working") | .description) |= [.]'
assert_fires "a non-string marketplace entry description fires" "$d"

d="$(tree mpempty)"
jqedit "$(market "$d")" '(.plugins[] | select(.name == "way-of-working") | .description) = ""'
assert_fires "an empty marketplace entry description fires" "$d"

# jq missing: bash by absolute path, PATH one empty directory (the checker then exits 127 after
# its message, as cat is not there either; only the message is asserted).
d="$(tree nojq)"
bash_bin="$(command -v bash)"
mkdir -p "$tmp/emptybin"
nojq_out="$( ( cd "$d" || exit 1; rc=0; PATH="$tmp/emptybin" "$bash_bin" "$script" --only 27 2>&1 >/dev/null || rc=$?; [ "$rc" -ne 2 ] || : >"$tmp/usage-exit" ) || true )"
if printf '%s\n' "$nojq_out" | grep -qF -- "$MSG" && printf '%s\n' "$nojq_out" | grep -qF -- 'jq not found on PATH'; then
  echo "ok - check 27 fires when jq is not on PATH"
else
  echo "FAIL - check 27 fires when jq is not on PATH: expected it to fire" >&2
  fail=1
fi

[ ! -e "$tmp/usage-exit" ] || { echo "FAIL - the checker exited 2 (usage) in at least one case" >&2; fail=1; }

[ "$fail" -eq 0 ]
