#!/usr/bin/env bash
# SessionStart hook: surface the .ai/ dev-workflow cursor at the top of every
# session so the ASSIGNED model/persona for the next action can't be missed.
# Automates the manual "you're on the wrong model for this" reminder — the
# role->model routing lives in the `models` key of the consuming repo's
# .ai/project.yml, and this plugin's reference/workflow.md explains the
# role split the cursor's fields carry.
#
# Reads .ai/state.json (relative to the session cwd = project root). Emits a
# SessionStart additionalContext block. No-ops silently outside the repo root
# or if jq/the cursor file is missing — a hook that errors is worse than none.
#
# Every interpolated value (the cursor fields and the Parked id list) is capped
# at 200 characters each (`cap` in the jq program), and next_action is also
# trimmed to its first sentence: in a cloned untrusted repo this text becomes
# model context at session start, so it must not be unbounded. `cap` cuts to 200
# characters first (jq's gsub is superlinear in the match count, and the hook
# has a 10s timeout), then replaces each line-breaking or control character
# (newline, carriage return, tab, the C0/C1 ranges, DEL, U+2028/U+2029) with a
# space, so a field cannot start a forged banner line of its own; the banner's
# line count is fixed. next_action goes through `cap` before the first-sentence
# split, so a non-string value cannot kill the banner either.
set -euo pipefail

state=".ai/state.json"
[ -f "$state" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Parked sprints (/way-of-working:park-sprint) live as tracked snapshots in
# .ai/parked/<id>-state.json. Derive the id list from the directory, never from
# a field: the directory is the authority. Empty when there are none; the
# `-e` test is what keeps an unmatched glob from echoing its own pattern.
parked=""
for f in .ai/parked/*-state.json; do
  [ -e "$f" ] || continue
  id="${f##*/}"
  id="${id%-state.json}"
  parked="${parked:+$parked, }$id"
done

jq --arg parked "$parked" '
def cap: tostring | .[0:200] | gsub("[\u0000-\u001f\u007f-\u009f\u2028\u2029]"; " ");
{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: (
      "[.ai cursor] Assigned: \(.assigned_persona | cap)/\(.assigned_model | cap) for \(.current_sprint_id | cap) (sprint_status: \(.sprint_status | cap)).\n"
      + "Next action: \((.next_action // "unset") | cap | split(". ")[0]).\n"
      + (if $parked == "" then "" else "Parked: \($parked | cap) (restore with /way-of-working:unpark-sprint <id>).\n" end)
      + "If THIS session is not running \(.assigned_model | cap), it is the wrong session for planning/review/architecture work: /way-of-working:handoff -> new session -> /model \(.assigned_model | cap) -> /way-of-working:resume (`models` in .ai/project.yml). Mechanical/coder tasks are fine on any model."
    )
  }
}' "$state" 2>/dev/null || exit 0
