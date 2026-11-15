#!/bin/sh
# Fixture tests for spec-task's step 7 project file re-copy block (#1316): a successful re-read
# replaces a stale project.yml and prints RECOPY=ok; each failure path stops
# `stopped: no project file`, keeps the old copy and leaves no other file in the draft directory.
#
# The block is the fenced bash block that contains the line printing RECOPY=ok (not the first
# fence), extracted with DD='<printed draft dir>' replaced by a scratch directory, and run under
# sh with stub gh and git at the front of PATH, driven by GHRC, FETCHRC, SHOWRC (exit codes),
# SHOWOUT (git show output) and DEFNAME (the default branch name gh prints).
# Permitted toolset: POSIX sh, awk, sed.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root_dir/plugins/way-of-working/skills/spec-task/SKILL.md"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
assert_eq() {
  if [ "$2" = "$3" ]; then echo "ok - $1"
  else echo "FAIL - $1: expected [$2], got [$3]" >&2; fail=1; fi
}

awk '
  /^   ```bash/ { on = 1; buf = ""; hit = 0; next }
  /^   ```/ { if (on && hit) { printf "%s", buf; exit } on = 0; next }
  on { sub(/^   /, ""); buf = buf $0 "\n"; if (index($0, "RECOPY=ok")) hit = 1 }
' "$skill" >"$tmp/raw.sh"
[ -s "$tmp/raw.sh" ] || { echo "FAIL - no block containing RECOPY=ok found in the skill" >&2; exit 1; }
grep -q "^DD='<printed draft dir>'" "$tmp/raw.sh" ||
  { echo "FAIL - the block does not start with the DD placeholder" >&2; exit 1; }

bin="$tmp/bin"
mkdir -p "$bin"
cat >"$bin/gh" <<'G'
#!/bin/sh
[ "${GHRC:-0}" -eq 0 ] || exit "$GHRC"
echo "${DEFNAME-main}"
G
cat >"$bin/git" <<'G'
#!/bin/sh
case "$*" in
  *rev-parse*) echo /nowhere ;;
  *" remote get-url "*) echo origin-url ;;
  *" fetch "*) exit "${FETCHRC:-0}" ;;
  *" show "*) [ -z "${SHOWOUT-}" ] || printf '%s\n' "$SHOWOUT"; exit "${SHOWRC:-0}" ;;
esac
exit 0
G
chmod +x "$bin"/*

run() { # <name> -> sets OUT ERR RC, draft dir DD with a stale project.yml
  DD="$tmp/dd-$1"; mkdir -p "$DD"
  printf 'old\n' >"$DD/project.yml"
  sed "s|^DD='<printed draft dir>'|DD='$DD'|" "$tmp/raw.sh" >"$tmp/snippet.sh"
  RC=0
  env PATH="$bin:$PATH" sh "$tmp/snippet.sh" >"$tmp/out" 2>"$tmp/err" || RC=$?
  OUT=$(cat "$tmp/out"); ERR=$(cat "$tmp/err")
}

kept_old() { # <label> : failure path keeps the old copy and nothing else
  assert_eq "$1: stop word" "stopped: no project file" "$ERR"
  [ "$RC" -ne 0 ] && echo "ok - $1: non-zero exit" || { echo "FAIL - $1: exit 0" >&2; fail=1; }
  assert_eq "$1: project.yml unchanged" "old" "$(cat "$DD/project.yml")"
  assert_eq "$1: only project.yml remains" "project.yml" "$(ls -A "$DD")"
}

SHOWOUT='new: 1' run ok
assert_eq "success: exit 0" "0" "$RC"
assert_eq "success: RECOPY=ok" "RECOPY=ok" "$OUT"
assert_eq "success: project.yml holds the new content" "new: 1" "$(cat "$DD/project.yml")"
assert_eq "success: only project.yml remains" "project.yml" "$(ls -A "$DD")"

GHRC=1 SHOWOUT='new: 1' run ghfail;   kept_old "gh repo view fails"
FETCHRC=1 SHOWOUT='new: 1' run fetchfail; kept_old "git fetch fails"
SHOWRC=1 SHOWOUT='new: 1' run showfail; kept_old "git show fails"
SHOWOUT= run emptyshow;               kept_old "git show prints nothing"
DEFNAME='bad name;x' SHOWOUT='new: 1' run badname; kept_old "branch name outside the allowlist"
DEFNAME='-evil' SHOWOUT='new: 1' run dashname;  kept_old "branch name with a leading dash"
DEFNAME= SHOWOUT='new: 1' run emptyname;       kept_old "empty branch name"

exit "$fail"
