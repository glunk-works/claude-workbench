#!/bin/sh
# Fixture tests for plugins/way-of-working/hooks/ai-cursor-banner.sh.
#
# Each fixture is a throwaway project directory the hook is run FROM (it reads
# .ai/state.json relative to cwd), and the assertions read the emitted
# additionalContext back out of the hook's JSON. The behaviour under test is
# the `Parked:` line added for /way-of-working:park-sprint (issue #88): present
# with the ids when .ai/parked/*-state.json files exist, absent otherwise, and
# derived from the directory rather than from any cursor field. Also under test:
# every interpolated value, the Parked id list included, is capped at 200
# characters (issue #246).
#
# Permitted toolset: POSIX sh, plus the hook's own dependencies (bash, jq). The
# hook no-ops without jq, so without jq these assertions could only ever pass
# vacuously -- skip, loudly, instead.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root_dir/plugins/way-of-working/hooks/ai-cursor-banner.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "skip - ai-cursor-banner fixtures: no jq on PATH (the hook itself no-ops without it)"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

# A project dir with a minimal cursor; the hook is run from inside it.
new_project() {
  proj="$tmp/$1"
  mkdir -p "$proj/.ai"
  cd "$proj"
  printf '%s\n' '{"assigned_persona":"architect","assigned_model":"opus","current_sprint_id":"s15","sprint_status":"implementing","next_action":"do the thing. then more"}' >.ai/state.json
}

# The banner's context text, or the empty string when the hook emitted nothing.
# A crashing hook is NOT "emitted nothing": it prints a marker that no assertion
# expects, so the four assertions expecting "" cannot pass vacuously on a crash.
banner() {
  out="$(bash "$hook")" || { echo "HOOK-EXIT-$?"; return 0; }
  [ -n "$out" ] || return 0
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext'
}

parked_line() {
  banner | grep '^Parked:' || true
}

# --- no parked dir: no Parked line, banner otherwise intact -----------------
new_project none
assert_eq "none: no Parked line without .ai/parked/" "" "$(parked_line)"
assert_eq "none: the banner still opens with the cursor" \
  "[.ai cursor] Assigned: architect/opus for s15 (sprint_status: implementing)." \
  "$(banner | sed -n 1p)"

# --- empty parked dir: still no Parked line ----------------------------------
new_project empty
mkdir .ai/parked
assert_eq "empty: an empty .ai/parked/ adds nothing" "" "$(parked_line)"

# --- two parked sprints: both ids, in directory order ------------------------
new_project two
mkdir .ai/parked
echo '{}' >.ai/parked/s13-state.json
echo '{}' >.ai/parked/s14-state.json
echo x >.ai/parked/s13-next-steps.md
assert_eq "two: ids derived from *-state.json, next-steps files ignored" \
  "Parked: s13, s14 (restore with /way-of-working:unpark-sprint <id>)." \
  "$(parked_line)"

# --- a stray file that is not a snapshot: ignored ----------------------------
new_project stray
mkdir .ai/parked
echo x >.ai/parked/README.md
assert_eq "stray: a non-snapshot file under .ai/parked/ adds nothing" "" "$(parked_line)"

# --- no cursor at all: the hook stays silent even with parked files ----------
new_project nocursor
rm .ai/state.json
mkdir .ai/parked
echo '{}' >.ai/parked/s13-state.json
assert_eq "nocursor: no state.json means no banner, parked or not" "" "$(banner)"

# --- over-long fields: each interpolated field is capped at 200 characters ----
new_project long
long="$(jq -rn '"x" * 300')"
jq --arg l "$long" '.assigned_persona = $l | .assigned_model = $l | .current_sprint_id = $l | .sprint_status = $l | .next_action = $l' \
  .ai/state.json >.ai/state.tmp && mv .ai/state.tmp .ai/state.json
cap200="$(jq -rn '"x" * 200')"
assert_eq "long: every field is truncated to 200 characters" \
  "[.ai cursor] Assigned: $cap200/$cap200 for $cap200 (sprint_status: $cap200)." \
  "$(banner | sed -n 1p)"
assert_eq "long: next_action is truncated to 200 characters" \
  "Next action: $cap200." \
  "$(banner | sed -n 2p)"
assert_eq "long: assigned_model is truncated in both places of the wrong-session line" \
  "If THIS session is not running $cap200, it is the wrong session for planning/review/architecture work: /way-of-working:handoff -> new session -> /model $cap200 -> /way-of-working:resume (\`models\` in .ai/project.yml). Mechanical/coder tasks are fine on any model." \
  "$(banner | sed -n 3p)"

# --- many long parked ids: the joined Parked list is capped too ---------------
new_project longparked
mkdir .ai/parked
for n in 1 2 3; do echo '{}' >".ai/parked/$(jq -rn '"p" * 150')$n-state.json"; done
assert_eq "longparked: the Parked ids are capped at 200 characters" \
  "Parked: $(jq -rn '"p" * 150')1, $(jq -rn '"p" * 47') (restore with /way-of-working:unpark-sprint <id>)." \
  "$(parked_line)"

exit "$fail"
