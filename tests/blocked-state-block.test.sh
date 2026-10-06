#!/bin/sh
# Fixture tests for the shell block around blocked-state.sh in
# plugins/way-of-working/skills/pr-checks/SKILL.md (block (b), "ask the predicate").
#
# Issue #244: tests/blocked-state.test.sh covers the predicate; this covers the chain that
# feeds it. A failed gh must never reach the predicate and never print `lag`, and a branch
# name is untrusted text that must stop the chain before any gh api call. The block is
# extracted from the skill itself (not copied here), its placeholders filled in, and run
# against a stub gh on PATH. Three mutants then prove the assertions can fail.
#
# Permitted toolset: POSIX sh and its standard utilities. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root_dir/plugins/way-of-working/skills/pr-checks/SKILL.md"
predicate="$root_dir/plugins/way-of-working/bin/blocked-state.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 1' INT TERM
stub="$work/stub"
sandbox="$work/sandbox"
mkdir -p "$stub" "$sandbox"

fail=0

assert_eq() {
  desc="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$expected], got [$actual]" >&2
    fail=1
  fi
}

# --- extract block (b) from the skill ----------------------------------------
# From the marker comment line to the closing fence, then fill the three placeholders.
awk '/^ *# \(b\) ask the predicate/ { p = 1 } p && /^ *```/ { exit } p' "$skill" |
  sed -e 's/^ *//' -e 's/<N>/7/g' -e 's/{repo}/o\/r/g' -e 's/<green>/1/g' >"$work/block.sh"
if grep -Eq '(^|[^$])[<{][A-Za-z0-9_.-]+[>}]' "$work/block.sh"; then
  echo "FAIL - block (b) still has an unfilled placeholder; teach the fixture to fill it" >&2
  exit 1
fi
if [ ! -s "$work/block.sh" ] || ! grep -q 'blocked-state.sh' "$work/block.sh"; then
  echo "FAIL - could not extract block (b) from $skill" >&2
  exit 1
fi

# --- stubs --------------------------------------------------------------------
# gh: logs every call; STUB_PR_RC / STUB_API_RC make that call fail; STUB_BASE is the
# base branch name; STUB_RULES is the already-projected rule list the real --jq would print.
cat >"$stub/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_LOG"
case "$1 $2" in
  "pr view")
    [ "${STUB_PR_RC:-0}" = 0 ] || exit 1
    printf '%s\n' "$STUB_BASE" ;;
  "api --paginate")
    [ "${STUB_API_RC:-0}" = 0 ] || { echo "stub gh: api failed" >&2; exit 1; }
    [ -z "${STUB_RULES-}" ] || printf '%s\n' "$STUB_RULES" ;;
  *) exit 99 ;;
esac
EOF
# blocked-state.sh by bare name, as the skill calls it; logs that it ran, then defers to the
# real script (via sh, so no exec bit is needed).
cat >"$stub/blocked-state.sh" <<EOF
#!/bin/sh
printf 'PRED\n' >>"\$STUB_LOG"
exec sh "$predicate" "\$@"
EOF
chmod +x "$stub/gh" "$stub/blocked-state.sh"

# The skill ships the block as a bash block; run it under bash where there is one.
if command -v bash >/dev/null 2>&1; then block_shell=bash; else block_shell=sh; fi

# run_block <block-file> -> "<stdout>|<rc>"; STUB_* come from the caller's environment.
run_block() {
  : >"$work/log"
  out="$(cd "$sandbox" && STUB_LOG="$work/log" PATH="$stub:$PATH" "$block_shell" "$1" 2>/dev/null)" && rc=0 || rc=$?
  printf '%s|%s' "$out" "$rc"
}
calls() { grep -c "$1" "$work/log" || true; }

pr0='pull_request approvals=0 threads=false codeowner=false reviewers=0'
rsc0='required_status_checks app_pinned=0'
export STUB_BASE=main STUB_PR_RC=0 STUB_API_RC=0
STUB_RULES="$(printf 'deletion\nnon_fast_forward\n%s\n%s' "$pr0" "$rsc0")"
export STUB_RULES

# --- answers ------------------------------------------------------------------
assert_eq "empty rule list -> lag" "lag|0" "$(STUB_RULES= run_block "$work/block.sh")"
assert_eq "no update rule -> lag" "lag|0" "$(run_block "$work/block.sh")"
with_update="$(printf '%s\nupdate' "$STUB_RULES")"
assert_eq "update rule -> admin-merge-ready" "admin-merge-ready|0" \
  "$(STUB_RULES="$with_update" run_block "$work/block.sh")"

# --- a failed gh never reaches the predicate ----------------------------------
assert_eq "failing gh api -> no word, non-zero" "|1" "$(STUB_API_RC=1 run_block "$work/block.sh")"
assert_eq "failing gh api -> predicate never ran" "0" "$(calls PRED)"
assert_eq "failing gh pr view -> no word, non-zero" "|1" "$(STUB_PR_RC=1 run_block "$work/block.sh")"
assert_eq "failing gh pr view -> no gh api call" "0" "$(calls '^api')"

# --- an untrusted branch name stops the chain before any gh api call -----------
for b in 'x$(touch PWN)' 'a;b' 'a b' 'a|b' 'a&b' '' 'a`b`' 'caf'"$(printf '\303\251')"; do
  res="$(STUB_BASE="$b" run_block "$work/block.sh")"
  assert_eq "branch [$b] -> no word, non-zero" "|1" "$res"
  assert_eq "branch [$b] -> no gh api call" "0" "$(calls '^api')"
done
assert_eq "slashes, dots, dashes in a branch are allowed" "lag|0" \
  "$(STUB_BASE='feat/v1.2_x-y' run_block "$work/block.sh")"

# --- mutants: the assertions above must be able to fail ------------------------
# (1) T=$(gh api ...) no longer chained to what follows (the && after it dropped).
sed -e '/^T=\$(/ s/ &&$//' "$work/block.sh" >"$work/mut1.sh"
# (2) the branch check no longer chained to the gh api call.
sed -e '/^case "\$B"/ s/ &&$//' "$work/block.sh" >"$work/mut2.sh"
# (3) gh piped straight into the predicate, no capture.
awk '/^T=\$\(/ { sub(/^T=\$\(/, ""); sub(/\) &&$/, " |"); print; getline; sub(/^.*\| /, ""); print; next } { print }' \
  "$work/block.sh" >"$work/mut3.sh"
for m in 1 2 3; do
  if cmp -s "$work/block.sh" "$work/mut$m.sh"; then
    echo "FAIL - mutant $m did not change the block (the mutation no longer applies)" >&2
    fail=1
  fi
done
# Each mutant must fail open exactly the way it models (lag, exit 0), not merely differ,
# so a mutant broken into a syntax error cannot count as caught.
assert_eq "mutant 1 (T= not chained) fails open on a failing gh api" "lag|0" \
  "$(STUB_API_RC=1 run_block "$work/mut1.sh")"
assert_eq "mutant 2 (branch check not chained) fails open on a;b" "lag|0" \
  "$(STUB_BASE='a;b' run_block "$work/mut2.sh")"
assert_eq "mutant 2 made the gh api call" "1" "$(calls '^api')"
assert_eq "mutant 3 (gh piped straight in) fails open on a failing gh api" "lag|0" \
  "$(STUB_API_RC=1 run_block "$work/mut3.sh")"

if [ "$fail" -ne 0 ]; then
  echo "blocked-state-block.test.sh: FAILED" >&2
  exit 1
fi
echo "blocked-state-block.test.sh: all passed"
