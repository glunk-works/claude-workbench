#!/bin/sh
# Fixture tests for spec-task's Fetch and check block: a failed default-branch read stops as
# `answer no project file`, a failed or silent finder as `answer no word` (#1454).
#
# The block is extracted the way tests/spec-issue.test.sh does (the first indented bash fence,
# N=<digits> replaced by N=611) and run under sh with stub spec-issue.sh, gh, git and spec-find.sh
# at the front of PATH and TMPDIR pointed at an empty scratch directory.
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

awk '/^   ```bash/ { on = 1; next } /^   ```/ { if (on) exit } on { sub(/^   /, ""); print }' "$skill" |
  sed 's/^N=<digits>/N=611/' >"$tmp/snippet.sh"
[ -s "$tmp/snippet.sh" ] || { echo "FAIL - no snippet extracted" >&2; exit 1; }

bin="$tmp/bin"
mkdir -p "$bin"
printf '#!/bin/sh\necho "ok B=b BASE=main VERDICT=reacted ASSOC=NONE"\n' >"$bin/spec-issue.sh"
# gh, git and the finder are driven by GHRC, SHOWRC, FINDRC (exit code) and FINDOUT (output).
printf '#!/bin/sh\n[ "${GHRC:-0}" -eq 0 ] && echo main; exit "${GHRC:-0}"\n' >"$bin/gh"
cat >"$bin/git" <<'G'
#!/bin/sh
case "$*" in
  *rev-parse*) echo /nowhere ;;
  *" show "*) echo "repo: x"; exit "${SHOWRC:-0}" ;;
  *" remote get-url "*) echo origin-url ;;
esac
exit 0
G
cat >"$bin/spec-find.sh" <<'G'
#!/bin/sh
[ "${FINDRC:-0}" -eq 0 ] || exit "$FINDRC"
printf '%s' "${FINDOUT-}"
[ -z "${FINDOUT-}" ] || echo
G
chmod +x "$bin"/*

run() { # <name> -> sets OUT ERR RC, scratch dir S
  S="$tmp/s-$1"; mkdir -p "$S"
  RC=0
  env PATH="$bin:$PATH" TMPDIR="$S" sh "$tmp/snippet.sh" >"$tmp/out" 2>"$tmp/err" || RC=$?
  OUT=$(cat "$tmp/out"); ERR=$(cat "$tmp/err")
}

GHRC=1 run ghfail
assert_eq "gh repo view fails: the project-file word" "stopped: answer no project file" "$ERR"
[ "$RC" -ne 0 ] && echo "ok - gh fail: non-zero exit" || { echo "FAIL - gh fail exit" >&2; fail=1; }
assert_eq "gh fail: TMPDIR empty" "" "$(ls -A "$S")"

SHOWRC=1 run showfail
assert_eq "git show fails: the project-file word" "stopped: answer no project file" "$ERR"
assert_eq "git show fail: TMPDIR empty" "" "$(ls -A "$S")"

FINDOUT= run silent
assert_eq "finder prints nothing: the finder word" "stopped: answer no word" "$ERR"
assert_eq "silent finder: TMPDIR empty" "" "$(ls -A "$S")"

FINDRC=3 run findfail
assert_eq "finder exits non-zero: the finder word" "stopped: answer no word" "$ERR"
assert_eq "failing finder: TMPDIR empty" "" "$(ls -A "$S")"

FINDOUT=none run okcase
assert_eq "finder prints none: exit 0" "0" "$RC"
case "$OUT" in *" ANSWER=none") echo "ok - the line ends with ANSWER=none" ;; *) echo "FAIL - line: [$OUT]" >&2; fail=1 ;; esac
assert_eq "success: one line" "1" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
assert_eq "success: only the issue directory remains" "1" "$(ls -A "$S" | wc -l | tr -d ' ')"

exit "$fail"
