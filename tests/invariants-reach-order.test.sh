#!/bin/sh
# Fixture tests for scripts/invariants-check.sh's check 3: the reach check precedes the
# ruleset call in /resume.
#
# The ruleset call is the line whose first word is `ruleset-drift.sh` (the script holds the
# `gh api` reads; #1211). Its earlier anchor, a `gh api ... rules/branches` pattern, never
# matched for its first life (#162), so a wrong ordering could not fail. A test that only feeds
# the real tree is a control that yields the same answer with or without the check, so each
# case here mutates a COPY of the real /resume skill into a wrong order (or removes the call)
# and asserts the check fires. The real-tree case is a deliberate control.
#
# Only check 3's own messages are asserted, never the script's overall exit: every case but
# the control runs just that check (`--only 3`), and the control runs them all.
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

ORDER_MSG="/resume checks the ruleset before establishing reach"
MISSING_MSG="/resume's ruleset call could not be found"
REACH_LINE='gh api repos/{repo} --jq .permissions'

# Fresh copy of the real plugins/ tree, cwd for one run of the script.
tree() {
  d="$tmp/$1"
  mkdir -p "$d"
  cp -R "$pristine/plugins" "$d/plugins"
  echo "$d"
}

resume_in() { ls "$1"/plugins/*/skills/resume/SKILL.md; }

sel="--only 3"

run() { # run <dir> -> stderr on stdout; a usage exit (2) leaves a marker
  ( cd "$1" || exit 1; rc=0; bash "$script" $sel 2>&1 >/dev/null || rc=$?; [ "$rc" -ne 2 ] || : >"$tmp/usage-exit" ) || true
}

assert_fires() { # assert_fires <desc> <dir> <message>
  if run "$2" | grep -qF -- "$3"; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$3] in the check's output" >&2
    fail=1
  fi
}

assert_silent() { # assert_silent <desc> <dir> <message>
  if run "$2" | grep -qF -- "$3"; then
    echo "FAIL - $1: unexpected [$3] in the check's output" >&2
    fail=1
  else
    echo "ok - $1"
  fi
}

# Move the reach call after everything else: rename the original occurrence, append a
# fresh one at end of file. Leaves the ruleset call untouched, so reach > ruleset.
reorder() { # reorder <resume-file>
  sed "s|$REACH_LINE|gh api repos/{repo} --jq .PERM|" "$1" >"$1.new"
  printf '\n%s\n' "$REACH_LINE" >>"$1.new"
  mv "$1.new" "$1"
}

# --- control: the real skill is in the right order ---------------------------
sel=
d="$(tree real)"
assert_silent "real tree: reach precedes the ruleset call" "$d" "$ORDER_MSG"
assert_silent "real tree: the ruleset call is found" "$d" "$MISSING_MSG"
sel="--only 3"

CALL_RE='^ *ruleset-drift\.sh '

# --- wrong order: the script call above the reach call -------------------------
d="$(tree order)"
grep -qE "$CALL_RE" "$(resume_in "$d")" || {
  echo "FAIL - fixture premise: the real /resume no longer calls ruleset-drift.sh on its own line" >&2
  fail=1
}
reorder "$(resume_in "$d")"
assert_fires "wrong order fires against the real script call" "$d" "$ORDER_MSG"

# --- the call reworded or removed must be loud, not silent -----------------------
d="$(tree reworded)"
r="$(resume_in "$d")"
sed 's|^\( *\)ruleset-drift\.sh |\1ruleset-drift-x.sh |' "$r" >"$d/r.new" && mv "$d/r.new" "$r"
grep -qE "$CALL_RE" "$r" && { echo "FAIL - fixture premise: the rewording did not apply" >&2; fail=1; }
assert_fires "a reworded script call is reported, not silently passed" "$d" "$MISSING_MSG"

d="$(tree removed)"
r="$(resume_in "$d")"
grep -vE "$CALL_RE" "$r" >"$d/r.new" && mv "$d/r.new" "$r"
assert_fires "a removed script call is reported, not silently passed" "$d" "$MISSING_MSG"

# --- a backtick mention of the script in prose is not the call --------------------
d="$(tree prose)"
r="$(resume_in "$d")"
grep -vE "$CALL_RE" "$r" >"$d/r.new" && mv "$d/r.new" "$r"
printf '\n`ruleset-drift.sh` is mentioned in prose here.\n' >>"$r"
assert_fires "a prose mention naming the script is not mistaken for the call" "$d" "$MISSING_MSG"

[ ! -e "$tmp/usage-exit" ] || { echo "FAIL - the checker exited 2 (usage) in at least one case" >&2; fail=1; }

exit "$fail"
