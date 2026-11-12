#!/bin/sh
# Fixture tests for scripts/invariants-check.sh's check 28: spec-task prints the answer word
# (`ANSWER=`) in its Fetch and check call before it drafts (#1416, tightened by #1454 and #1456).
#
# Each case mutates a COPY of the real spec-task skill and asserts check 28 fires; the real tree
# is a control that must stay silent. Only check 28's own message is asserted, never the script's
# overall exit: every case runs just that check (`--only 28`).
#
# Permitted toolset: POSIX sh, awk, sed. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/invariants-check.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pristine="$tmp/.pristine"
mkdir -p "$pristine"
cp -R "$root_dir/plugins" "$pristine/plugins"

fail=0
MSG="spec-task does not print the answer word before it drafts (#1416)"

tree() {
  d="$tmp/$1"
  mkdir -p "$d"
  cp -R "$pristine/plugins" "$d/plugins"
  echo "$d"
}

skill_in() { ls "$1"/plugins/*/skills/spec-task/SKILL.md; }

run() { ( cd "$1" || exit 1; bash "$script" --only 28 2>&1 >/dev/null || true ); }

assert_fires() {
  if run "$2" | grep -qF -- "$MSG"; then echo "ok - $1"
  else echo "FAIL - $1: expected check 28 to report" >&2; fail=1; fi
}

assert_silent() {
  if run "$2" | grep -qF -- "$MSG"; then echo "FAIL - $1: unexpected check 28 report" >&2; fail=1
  else echo "ok - $1"; fi
}

# mutate <dir> <step-name-prefix> <scope> <awk-body>
# Runs <awk-body> on each line of the named step; scope "block" limits it to the step's first
# fenced block, "step" to the whole step. The body may `next` to drop the line, and may use
# `closing` (true on the block's closing fence line) to append before it.
mutate() {
  f="$(skill_in "$1")"
  awk -v name="$2" -v scope="$3" '
    /^[0-9]+[a-z]?\. \*\*/ { cur = (index($0, "**" name) > 0) ? 1 : 0; print; next }
    {
      closing = 0; inb = 0
      if (cur && /^ *```/) { if (open && !done) { done = 1; closing = 1 } else if (!open) open = 1 }
      if (cur && (scope == "step" || (open && !done) || closing)) inb = 1
      if (inb) { '"$4"' }
      print
    }' "$f" >"$f.new" && mv "$f.new" "$f"
  if cmp -s "$f" "$pristine/${f#"$1"/}"; then echo "FAIL - fixture premise: the mutation changed nothing" >&2; fail=1; fi
}

assert_changed() {
  if cmp -s "$(skill_in "$1")" "$(skill_in "$pristine")"; then echo "FAIL - fixture premise: the mutation changed nothing" >&2; fail=1; fi
}

d="$(tree real)"
assert_silent "real tree: check 28 is silent" "$d"

d="$(tree nofind)"
mutate "$d" "Fetch and check" block 'if (index($0, "$(spec-find.sh answer")) next'
assert_fires "the spec-find.sh answer line deleted" "$d"

d="$(tree moved)"
# Hold the finder line back and print it just before the closing fence, below the ANSWER= print.
mutate "$d" "Fetch and check" block 'if (index($0, "$(spec-find.sh answer")) { held = $0; next } if (closing && held != "") { print held }'
assert_fires "the finder line moved below the ANSWER= print" "$d"

d="$(tree finderfirst)"
# Rename the real fetch line so only a fetch line placed after the finder remains.
mutate "$d" "Fetch and check" block 'if (index($0, "L=$(spec-issue.sh fetch")) { sub(/L=\$\(spec-issue.sh fetch/, "L=$(spec-issue-x.sh fetch"); } if (closing) print "   L=$(spec-issue.sh fetch \"$N\" \"$T\") &&"'
assert_fires "the fetch line placed after the finder line" "$d"

d="$(tree noprint)"
mutate "$d" "Fetch and check" block 'gsub(/ANSWER=/, "ANS=")'
assert_fires "ANSWER= removed from the block" "$d"

d="$(tree nodraft)"
mutate "$d" "Draft against the base" step 'gsub(/ANSWERCHECK=ok/, "ANSCHK=ok")'
assert_fires "ANSWERCHECK=ok removed from the Draft step" "$d"

d="$(tree renamed)"
f="$(skill_in "$d")"
sed 's/\*\*Fetch and check/**Fetch and verify/' "$f" >"$f.new" && mv "$f.new" "$f"
assert_fires "the Fetch and check step renamed" "$d"

d="$(tree gaterev)"
f="$(skill_in "$d")"
awk '/^[0-9]+[a-z]?\. \*\*Answer branch/ { c = 1; print; next } c == 1 { sub(/`ANSWER=` word/, "`VERDICT` word"); c = 2 } { print }' "$f" >"$f.new" && mv "$f.new" "$f"
assert_changed "$d"
assert_fires "the Answer branch gate reverted to VERDICT" "$d"

d="$(tree anrenamed)"
f="$(skill_in "$d")"
sed 's/\*\*Answer branch/**Reply branch/' "$f" >"$f.new" && mv "$f.new" "$f"
assert_changed "$d"
assert_fires "the Answer branch step renamed" "$d"

d="$(tree printcomment)"
mutate "$d" "Fetch and check" block 'if (index($0, "printf") && index($0, "ANSWER=")) gsub(/ANSWER=/, "ANS="); if (closing) print "   # ANSWER=$W"'
assert_fires "ANSWER= only in a comment line, not a printf" "$d"

d="$(tree draftweak)"
mutate "$d" "Draft against the base" step 'gsub(/printed an `ANSWER=` word/, "printed a word")'
assert_fires "the Draft sentence weakened" "$d"

d="$(tree gone)"
rm -f "$(skill_in "$d")"
assert_fires "no spec-task SKILL.md" "$d"

exit "$fail"
