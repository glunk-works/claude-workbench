#!/bin/sh
# Fixture tests for plugins/way-of-working/hooks/reach-gate.sh and its hooks.json registration
# (WB-D42).
#
# Runs the REAL hook from a scratch project directory holding .ai/project.yml, inside a scratch
# checkout with an origin remote, against a stub gh that logs every call. Each case has its own
# session id and its own TMPDIR where it writes a pass. Cases that run the hook assert an empty stdout.
#
# Permitted toolset: POSIX sh, git, jq, timeout. Skips loudly without any of them.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root_dir/plugins/way-of-working/hooks/reach-gate.sh"
hooks_json="$root_dir/plugins/way-of-working/hooks/hooks.json"

for t in git jq timeout; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "skip - reach-gate.sh fixtures: no $t on PATH" >&2
    exit 0
  fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

# A stub gh. $STUB_USER set: `api user` prints it; unset: it fails (an installation token).
# STUB_MODE: ok (prints $STUB_REPOS), fail (exit 1), partial (prints a page, exit 1), hang.
stubbin="$tmp/bin"
mkdir -p "$stubbin"
cat >"$stubbin/gh" <<'STUB'
#!/bin/sh
echo "$*" >>"$STUB_LOG"
case "$*" in
  *"api user"*)
    [ -n "${STUB_USER:-}" ] || exit 1
    echo "$STUB_USER"; exit 0 ;;
esac
case "${STUB_MODE:-ok}" in
  ok) printf '%s\n' $STUB_REPOS ;;
  fail) exit 1 ;;
  partial) echo acme/widgets; exit 1 ;;
  hang) exec sleep 30 ;;
esac
STUB
chmod +x "$stubbin/gh"

git_q() { git -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false "$@"; }

proj="$tmp/proj"
mkdir -p "$proj/.ai"
git_q -C "$proj" init -q
echo "repo: acme/widgets" >"$proj/.ai/project.yml"
set_origin() { git -C "$proj" remote remove origin 2>/dev/null || true; [ -z "$1" ] || git -C "$proj" remote add origin "$1"; }

n=0
# run <session-id> [dir] -- sets rc, out, err, log; env knobs come from the caller's variables.
run() {
  n=$((n + 1))
  sid="$1"; d="${2:-$proj}"
  T="$tmp/t$n"; mkdir -p "$T"
  STUB_LOG="$T/log"; : >"$STUB_LOG"
  export STUB_LOG
  printf '{"session_id":"%s"}' "$sid" |
    (cd "$d" && TMPDIR="${RG_TMPDIR:-$T}" PATH="$stubbin:$PATH" "$hook" >"$T/out" 2>"$T/err") && rc=0 || rc=$?
  out=$(cat "$T/out"); err=$(cat "$T/err"); calls=$(wc -l <"$STUB_LOG" | tr -d ' ')
}
reset() { unset STUB_USER STUB_MODE RG_TMPDIR 2>/dev/null || true; STUB_REPOS="acme/widgets other/thing"; export STUB_REPOS; }
reset

set_origin "https://github.com/acme/widgets.git"

# --- no project file: silent, no gh call ---
mkdir -p "$tmp/bare"
run s1 "$tmp/bare"
assert_eq "no .ai/project.yml is silent with no gh call" "0||0" "$rc|$out|$calls"

# --- reached, remembered ---
reset; export TMPDIR_SHARED="$tmp/shared"; mkdir -p "$TMPDIR_SHARED"; RG_TMPDIR="$TMPDIR_SHARED"
run s2
assert_eq "reached passes" "0|" "$rc|$out"
first_calls=$calls
run s2
assert_eq "a second prompt in the same session makes no gh call" "0||0" "$rc|$out|$calls"
[ "$first_calls" -gt 0 ] || { echo "FAIL - first prompt made no gh call" >&2; fail=1; }

# --- unreached: exit 2, one stderr line, probes again ---
reset
STUB_REPOS="other/thing"; export STUB_REPOS
run s3
assert_eq "unreached exits 2 with empty stdout" "2|" "$rc|$out"
assert_eq "unreached stderr is one line naming the repo" "1|yes" \
  "$(printf '%s\n' "$err" | wc -l | tr -d ' ')|$(case $err in *acme/widgets*) echo yes ;; *) echo no ;; esac)"
RG_TMPDIR="$tmp/shared2"; mkdir -p "$RG_TMPDIR"
run s3b; c1=$calls
run s3b
assert_eq "unreached is not remembered: the next prompt probes and refuses again" "2|yes" \
  "$rc|$([ "$calls" -gt 0 ] && echo yes || echo no)"
: "$c1"

# --- a user token passes and is remembered ---
reset; RG_TMPDIR="$tmp/shared3"; mkdir -p "$RG_TMPDIR"
STUB_USER="octocat"; export STUB_USER
run s4
assert_eq "a user token passes" "0|" "$rc|$out"
run s4
assert_eq "a user token is remembered" "0||0" "$rc|$out|$calls"
unset STUB_USER

# --- https origin with only a user name is probed like a bare one; the user name is not echoed ---
reset
set_origin "https://alice-1@github.com/acme/widgets"
run s5
assert_eq "an https origin with a user name is probed and reached" "0||yes" \
  "$rc|$out|$([ "$calls" -gt 1 ] && echo yes || echo no)"
STUB_REPOS="other/thing"; export STUB_REPOS
run s5b
assert_eq "unreached with a user name refuses" "2|" "$rc|$out"
assert_eq "the user name stays out of the stderr line" "no" "$(case $err in *alice*) echo yes ;; *) echo no ;; esac)"
set_origin "git@github.com:acme/widgets.git"
run s5c
assert_eq "an scp-style origin is probed" "2|" "$rc|$out"
set_origin "ssh://git@github.com/acme/widgets"
run s5d
assert_eq "an ssh:// origin is probed" "2|" "$rc|$out"
set_origin "https://github.com/acme/widgets.git"

# --- failures pass and are not remembered ---
for mode in fail partial; do
  reset; RG_TMPDIR="$tmp/shared-$mode"; mkdir -p "$RG_TMPDIR"
  STUB_MODE=$mode; export STUB_MODE
  run f1
  assert_eq "a $mode installation call passes" "0|" "$rc|$out"
  run f1
  assert_eq "a $mode installation call is not remembered" "yes" "$([ "$calls" -gt 0 ] && echo yes || echo no)"
done
reset; RG_TMPDIR="$tmp/shared-hang"; mkdir -p "$RG_TMPDIR"
STUB_MODE=hang; export STUB_MODE
run h1
assert_eq "a hung gh passes" "0|" "$rc|$out"
run h1
assert_eq "a hung gh is not remembered" "yes" "$([ "$calls" -gt 0 ] && echo yes || echo no)"

reset; RG_TMPDIR="$tmp/shared-noorigin"; mkdir -p "$RG_TMPDIR"
set_origin ""
run o1
assert_eq "a missing origin passes" "0|" "$rc|$out"
run o1
assert_eq "a missing origin is not remembered" "yes" "$([ "$calls" -gt 0 ] && echo yes || echo no)"
for u in "https://u:pw@github.com/acme/widgets" "https://a@evil.com/@github.com/acme/widgets" "https://u@x:pw@github.com/acme/widgets" "https://example.com/acme/widgets" "git@host-alias:acme/widgets"; do
  RG_TMPDIR="$tmp/shared-badurl"; mkdir -p "$RG_TMPDIR"
  set_origin "$u"
  STUB_REPOS="other/thing"; export STUB_REPOS
  run u1
  assert_eq "an origin not in the three forms passes ($u)" "0|" "$rc|$out"
  assert_eq "an origin not in the three forms is not echoed" "no" "$(case $err in *pw*|*alias*) echo yes ;; *) echo no ;; esac)"
  run u1
  assert_eq "an origin not in the three forms is not remembered ($u)" "yes" "$([ "$calls" -gt 0 ] && echo yes || echo no)"
done
set_origin "https://github.com/acme/widgets.git"

# --- remembering off: the probe still refuses, nothing is written ---
reset
STUB_REPOS="other/thing"; export STUB_REPOS
for sid in "a/b" "a.b"; do
  RG_TMPDIR="$tmp/off-sid"; mkdir -p "$RG_TMPDIR"
  run "$sid"
  assert_eq "session id [$sid] still refuses" "2|" "$rc|$out"
  assert_eq "session id [$sid] leaves nothing written" "" "$(find "$RG_TMPDIR" -type f | head -1)"
done

# a missing jq: PATH holds only the stub gh and the tools the hook needs, not jq
nojq="$tmp/nojq"; mkdir -p "$nojq"
cp "$stubbin/gh" "$nojq/gh"   # before the loop, whose -e check then skips the runner's own gh
for d in /usr/bin /bin; do
  for f in "$d"/*; do
    b=${f##*/}
    [ "$b" = jq ] || [ -e "$nojq/$b" ] || ln -s "$f" "$nojq/$b" 2>/dev/null || true
  done
done
n=$((n + 1)); T="$tmp/t$n"; mkdir -p "$T"; STUB_LOG="$T/log"; : >"$STUB_LOG"; export STUB_LOG
RG_TMPDIR="$tmp/off-jq"; mkdir -p "$RG_TMPDIR"
printf '{"session_id":"nojq"}' | (cd "$proj" && TMPDIR="$RG_TMPDIR" PATH="$nojq" "$hook" >"$T/out" 2>"$T/err") && rc=0 || rc=$?
assert_eq "a missing jq still refuses" "2|" "$rc|$(cat "$T/out")"
assert_eq "a missing jq leaves nothing written" "" "$(find "$RG_TMPDIR" -type f | head -1)"

# a remember dir that is a link, or group-writable, already holding a pass: still refuses
uid=$(id -u)
RG_TMPDIR="$tmp/off-link"; mkdir -p "$RG_TMPDIR/real"
touch "$RG_TMPDIR/real/sidlink"
ln -s "$RG_TMPDIR/real" "$RG_TMPDIR/wow-reach-gate-$uid"
run sidlink
assert_eq "a linked remember dir is not trusted" "2|" "$rc|$out"
RG_TMPDIR="$tmp/off-perm"; mkdir -p "$RG_TMPDIR/wow-reach-gate-$uid"
chmod 770 "$RG_TMPDIR/wow-reach-gate-$uid"
touch "$RG_TMPDIR/wow-reach-gate-$uid/sidperm"
run sidperm
assert_eq "a group-writable remember dir is not trusted" "2|" "$rc|$out"
assert_eq "a group-writable remember dir gets nothing written" "1" \
  "$(find "$RG_TMPDIR/wow-reach-gate-$uid" -type f | wc -l | tr -d ' ')"

# --- registration ---
assert_eq "hooks.json registers reach-gate.sh under UserPromptSubmit with a 10-second timeout" \
  "\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/reach-gate.sh|10|null" \
  "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0] | "\(.command)|\(.timeout)|\(.matcher)"' "$hooks_json")"

exit "$fail"
