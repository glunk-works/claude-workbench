#!/bin/sh
# Fixture tests for scripts/claude-pin-check.sh and .github/workflows/claude-pin-check.yml (#1677).
#
# The check must never read an unreadable feed as current: every malformed or unreadable feed
# or pin fails closed with nothing on stdout, the script holds no network call or token, and
# the only workflow job that can write holds no checkout and runs no repo file. The workflow's
# two `run: |` blocks are extracted and run under stub `curl` and `gh`, so the suite makes no
# network call.
#
# Permitted toolset: POSIX sh plus awk, grep and jq. A missing jq fails the suite, never skips it.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/claude-pin-check.sh"
wf="$root_dir/.github/workflows/claude-pin-check.yml"
lswf="$root_dir/.github/workflows/label-sync.yml"
realdf="$root_dir/scripts/identity/review/Dockerfile"

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL - jq is required and is missing" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
n=0

ok() { echo "ok - $1"; }
bad() { echo "FAIL - $1" >&2; fail=1; }

printf 'FROM scratch\nARG CLAUDE_VERSION=2.1.316\nRUN true\n' >"$tmp/df"

# run_script FEED DF: sets rc, out
run_script() {
  n=$((n + 1))
  rc=0
  ( cd "$root_dir" && bash "$script" "$@" ) >"$tmp/out.$n" 2>"$tmp/err.$n" || rc=$?
  out="$(cat "$tmp/out.$n")"
}

# feedcase DESC FEED-BYTES WANT: a printf format for the feed; WANT is the stdout line
feedcase() {
  printf "$2" >"$tmp/feed"
  run_script "$tmp/feed" "$tmp/df"
  if [ "$rc" = 0 ] && [ "$out" = "$3" ]; then ok "$1"; else bad "$1: rc=$rc out=[$out] want [$3]"; fi
}

# failfeed DESC FEED-BYTES
failfeed() {
  printf "$2" >"$tmp/feed"
  run_script "$tmp/feed" "$tmp/df"
  if [ "$rc" = 1 ] && [ -z "$out" ]; then ok "$1"; else bad "$1: rc=$rc out=[$out]"; fi
}

# pincase DESC DOCKERFILE-BYTES WANT ("fail" for exit 1)
pincase() {
  printf "$2" >"$tmp/df2"
  printf '2.1.328\n' >"$tmp/feed"
  run_script "$tmp/feed" "$tmp/df2"
  if [ "$3" = fail ]; then
    if [ "$rc" = 1 ] && [ -z "$out" ]; then ok "$1"; else bad "$1: rc=$rc out=[$out]"; fi
  elif [ "$rc" = 0 ] && [ "$out" = "$3" ]; then ok "$1"; else bad "$1: rc=$rc out=[$out] want [$3]"; fi
}

# --- decision ---------------------------------------------------------------
feedcase "behind: 2.1.328 over 2.1.316" '2.1.328\n' "behind 2.1.316 2.1.328"
feedcase "equal reads current" '2.1.316\n' "current 2.1.316 2.1.316"
feedcase "pin ahead of the feed reads current" '2.1.300\n' "current 2.1.316 2.1.300"
feedcase "a feed with no trailing newline" '2.1.328' "behind 2.1.316 2.1.328"
feedcase "a feed with CR and newline" '2.1.328\r\n' "behind 2.1.316 2.1.328"
feedcase "a component of nine digits" '2.1.999999999\n' "behind 2.1.316 2.1.999999999"

numcase() { # PIN FEED WANT-STATE
  printf 'ARG CLAUDE_VERSION=%s\n' "$1" >"$tmp/df3"
  printf '%s\n' "$2" >"$tmp/feed"
  run_script "$tmp/feed" "$tmp/df3"
  if [ "$rc" = 0 ] && [ "$out" = "$3 $1 $2" ]; then ok "numeric: $2 against pin $1 is $3"; else bad "numeric: $2 against $1 rc=$rc out=[$out]"; fi
}
numcase 2.1.99 2.1.100 behind
numcase 2.1.100 2.1.99 current
numcase 2.9.9 2.10.0 behind
numcase 2.10.0 2.9.9 current
numcase 1.99.99 2.0.0 behind
numcase 3.0.0 2.99.99 current

pincase "a pin line ending in CR and newline is read plain" 'ARG CLAUDE_VERSION=2.1.316\r\n' "behind 2.1.316 2.1.328"

# --- fail closed --------------------------------------------------------------
failfeed "empty feed" ''
failfeed "two-line feed" '2.1.328\n2.1.329\n'
failfeed "a version and two newlines" '2.1.328\n\n'
failfeed "leading v" 'v2.1.328\n'
failfeed "surrounding spaces" ' 2.1.328 \n'
failfeed "an HTML body" '<html><body>503</body></html>\n'
failfeed "a lone trailing CR" '2.1.328\r'
failfeed "a leading-zero component" '2.01.328\n'
failfeed "a ten-digit component" '2.1.1000000000\n'
failfeed "two components" '2.1\n'
failfeed "four components" '2.1.328.1\n'
failfeed "a suffix" '2.1.328-beta\n'
failfeed "a non-digit component" '2.x.1\n'
failfeed "two CRs before the newline" '2.1.328\r\r\n'

pincase "a pin line ending in two CRs" 'ARG CLAUDE_VERSION=2.1.316\r\r\n' fail
pincase "a Dockerfile with no pin line" 'FROM scratch\n' fail
pincase "a Dockerfile with two pin lines" 'ARG CLAUDE_VERSION=2.1.316\nARG CLAUDE_VERSION=2.1.316\n' fail
pincase "a pin value that is not a version" 'ARG CLAUDE_VERSION=latest\n' fail
pincase "an indented pin line is not a pin line" ' ARG CLAUDE_VERSION=2.1.316\n' fail

printf '2.1.328\n' >"$tmp/feed"
run_script "$tmp/nope" "$tmp/df"
[ "$rc" = 1 ] && [ -z "$out" ] && ok "a missing feed file fails closed" || bad "missing feed rc=$rc"
run_script "$tmp/feed" "$tmp/nope"
[ "$rc" = 1 ] && [ -z "$out" ] && ok "a missing Dockerfile fails closed" || bad "missing Dockerfile rc=$rc"

run_script "$tmp/feed"
[ "$rc" = 2 ] && [ -z "$out" ] && grep -q '^usage:' "$tmp/err.$n" && ok "one argument exits 2 with a usage line" || bad "one argument rc=$rc"
run_script "$tmp/feed" "$tmp/df" extra
[ "$rc" = 2 ] && [ -z "$out" ] && ok "three arguments exit 2" || bad "three arguments rc=$rc"

# no echo of the feed or the pin
printf '::set-output name=x::y\n' >"$tmp/feed"
run_script "$tmp/feed" "$tmp/df"
if [ "$rc" = 1 ] && [ -z "$out" ] && ! grep -q '::' "$tmp/err.$n"; then ok "a workflow-command feed fails and is not echoed"; else bad "workflow-command feed rc=$rc"; fi
printf 'ARG CLAUDE_VERSION=SECRETPIN\n' >"$tmp/df2"
printf '2.1.328\n' >"$tmp/feed"
run_script "$tmp/feed" "$tmp/df2"
if [ "$rc" = 1 ] && ! grep -q 'SECRETPIN' "$tmp/err.$n"; then ok "a bad pin value is not echoed"; else bad "bad pin echoed or rc=$rc"; fi

# real tree
real_pin="$(sed -n 's/^ARG CLAUDE_VERSION=//p' "$realdf")"
printf '%s\n' "$real_pin" >"$tmp/feed"
run_script "$tmp/feed" "$realdf"
if [ "$rc" = 0 ] && [ "$out" = "current $real_pin $real_pin" ]; then ok "real Dockerfile with an equal feed prints current"; else bad "real Dockerfile rc=$rc out=[$out]"; fi

# --- workflow steps -----------------------------------------------------------
if [ ! -f "$wf" ]; then
  bad "workflow: .github/workflows/claude-pin-check.yml is absent"
else
  # extract_run ID: the lines of the `run: |` block of the step with `id: ID`
  extract_run() {
    awk -v id="$1" '
      function indent(s) { match(s, /^ */); return RLENGTH }
      state == 0 && $0 ~ ("^ *id: " id "$") { state = 1; next }
      state == 1 && $0 ~ /^ *run: \|$/ { ri = indent($0); state = 2; next }
      state == 2 {
        if ($0 ~ /^ *$/) { print ""; next }
        if (indent($0) <= ri) exit
        print substr($0, ri + 3)
      }
    ' "$wf"
  }
  extract_run check >"$tmp/check-step.sh"
  extract_run file >"$tmp/file-step.sh"
  [ -s "$tmp/check-step.sh" ] && ok "workflow: check step extracted" || bad "workflow: check step not found"
  [ -s "$tmp/file-step.sh" ] && ok "workflow: file step extracted" || bad "workflow: file step not found"

  stubdir="$tmp/stub"; mkdir -p "$stubdir"
  cat >"$stubdir/curl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_LOG"
[ -z "${STUB_CURL_FAIL:-}" ] || exit 22
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output ]; then out="$2"; fi
  shift
done
cp "$STUB_FEED" "$out"
STUB
  cat >"$stubdir/gh" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_LOG"
if [ "${1:-}" = api ]; then
  [ -z "${STUB_FAIL:-}" ] || exit 1
  cat "$STUB_LIST"
fi
exit 0
STUB
  chmod +x "$stubdir/curl" "$stubdir/gh"

  # run_step SCRIPT DIR [env...]: sets rc; resets the logs
  run_step() {
    s="$1"; d="$2"; shift 2
    : >"$tmp/log"; : >"$tmp/gh-out"
    rc=0
    ( cd "$d" && env PATH="$stubdir:$PATH" STUB_LOG="$tmp/log" REPO=o/r GH_TOKEN=t \
        RUNNER_TEMP="$tmp/rt" GITHUB_OUTPUT="$tmp/gh-out" "$@" \
        bash "$s" ) >"$tmp/step.out" 2>"$tmp/step.err" || rc=$?
  }
  mkdir -p "$tmp/rt"

  # the check block, run from a tree holding the script and a fixture Dockerfile
  px="$tmp/px"; mkdir -p "$px/scripts/identity/review"
  cp "$script" "$px/scripts/claude-pin-check.sh"
  cp "$tmp/df" "$px/scripts/identity/review/Dockerfile"

  printf '2.1.328\n' >"$tmp/feed-new"
  run_step "$tmp/check-step.sh" "$px" STUB_FEED="$tmp/feed-new"
  if [ "$rc" = 0 ] && grep -qx 'state=behind' "$tmp/gh-out" && grep -qx 'pin=2.1.316' "$tmp/gh-out" && grep -qx 'latest=2.1.328' "$tmp/gh-out"; then
    ok "check step: a newer feed writes state=behind with the pin and latest"
  else bad "check step: newer feed rc=$rc out=[$(cat "$tmp/gh-out")]"; fi
  allflags=1
  for flag in --fail --location --retry --max-time "--proto =https" "--proto-redir =https" https://downloads.claude.ai/claude-code-releases/latest; do
    grep -q -- "$flag" "$tmp/log" || { allflags=0; bad "check step: curl call lacks [$flag]"; }
  done
  [ "$allflags" = 1 ] && ok "check step: curl is called with the feed URL and the six flags"

  printf '2.1.316\n' >"$tmp/feed-eq"
  run_step "$tmp/check-step.sh" "$px" STUB_FEED="$tmp/feed-eq"
  if [ "$rc" = 0 ] && grep -qx 'state=current' "$tmp/gh-out"; then ok "check step: an equal feed writes state=current"; else bad "check step: equal feed rc=$rc"; fi

  run_step "$tmp/check-step.sh" "$px" STUB_FEED="$tmp/feed-new" STUB_CURL_FAIL=1
  if [ "$rc" != 0 ] && ! grep -q '^state' "$tmp/gh-out"; then ok "check step: a failed download fails with no state output"; else bad "check step: curl failure rc=$rc"; fi

  printf '<html>oops</html>\n' >"$tmp/feed-html"
  run_step "$tmp/check-step.sh" "$px" STUB_FEED="$tmp/feed-html"
  if [ "$rc" != 0 ] && ! grep -q '^state' "$tmp/gh-out"; then ok "check step: an HTML feed fails with no state output"; else bad "check step: HTML feed rc=$rc"; fi

  # the file block
  PIN=2.1.316; LATEST=2.1.328
  mklist() { # FILE then "LOGIN|TITLE|pr?" entries
    f="$1"; shift
    printf '[' >"$f"; sep=''
    for e in "$@"; do
      login="${e%%|*}"; rest="${e#*|}"; title="${rest%%|*}"; pr="${rest#*|}"
      if [ "$pr" = pr ]; then extra=',"pull_request":{}'; else extra=''; fi
      printf '%s{"title":"%s","user":{"login":"%s"}%s}' "$sep" "$title" "$login" "$extra" >>"$f"; sep=','
    done
    printf ']\n' >>"$f"
  }
  fs() { run_step "$tmp/file-step.sh" "$tmp" PIN="$PIN" LATEST="$LATEST" "$@"; }
  creates() { grep -c '^issue create' "$tmp/log" || true; }
  T='Bump the pinned Claude Code from 2.1.316 to'
  bot='github-actions[bot]'

  mklist "$tmp/l-none" "someone|Unrelated issue|x"
  fs STUB_LIST="$tmp/l-none"
  if [ "$rc" = 0 ] && [ "$(creates)" = 1 ] && grep -q -- "--title Bump the pinned Claude Code from 2.1.316 to 2.1.328" "$tmp/log" \
     && grep -q -- '--label area/devcontainer' "$tmp/log" && grep -q -- '--label type/chore' "$tmp/log" \
     && grep -q 'repos/o/r/issues' "$tmp/log" && grep -q -- '--paginate' "$tmp/log"; then
    ok "file step: no matching notice creates exactly one issue with the title and both labels"
  else bad "file step: no notice rc=$rc log=[$(cat "$tmp/log")]"; fi
  grep -q '2.1.316' "$tmp/log" && grep -q '2.1.328' "$tmp/log" && ok "file step: the issue names both versions" || bad "file step: versions missing"

  mklist "$tmp/l-match" "$bot|$T 2.1.328|x"
  fs STUB_LIST="$tmp/l-match"
  if [ "$rc" = 0 ] && [ "$(creates)" = 0 ] && [ "$(cat "$tmp/step.out")" = "claude-pin-check: an open notice for 2.1.328 exists" ]; then
    ok "file step: an open bot notice for LATEST creates none and prints the fixed line"
  else bad "file step: matching notice rc=$rc creates=$(creates) out=[$(cat "$tmp/step.out")]"; fi
  grep -q 'Bump the pinned' "$tmp/step.out" "$tmp/step.err" && bad "file step: a title was printed" || ok "file step: a matching title is never printed"

  mklist "$tmp/l-other" "someone|$T 2.1.328|x"
  fs STUB_LIST="$tmp/l-other"
  [ "$rc" = 0 ] && [ "$(creates)" = 1 ] && ok "file step: a matching title by another author still creates one" || bad "file step: other author rc=$rc"

  mklist "$tmp/l-old" "$bot|$T 2.1.320|x"
  fs STUB_LIST="$tmp/l-old"
  [ "$rc" = 0 ] && [ "$(creates)" = 1 ] && ok "file step: a notice ending in an older version still creates one" || bad "file step: older notice rc=$rc"

  mklist "$tmp/l-12" "$bot|$T 12.1.328|x"
  fs STUB_LIST="$tmp/l-12"
  [ "$rc" = 0 ] && [ "$(creates)" = 1 ] && ok "file step: a notice ending in 12.1.328 still creates one" || bad "file step: 12.1.328 rc=$rc"

  mklist "$tmp/l-prefix" "$bot|Something else to 2.1.328|x"
  fs STUB_LIST="$tmp/l-prefix"
  [ "$rc" = 0 ] && [ "$(creates)" = 1 ] && ok "file step: the right ending with another prefix still creates one" || bad "file step: other prefix rc=$rc"

  mklist "$tmp/l-pr" "$bot|$T 2.1.328|pr"
  fs STUB_LIST="$tmp/l-pr"
  [ "$rc" = 0 ] && [ "$(creates)" = 1 ] && ok "file step: a bot pull request with the matching title still creates one" || bad "file step: pull request rc=$rc"

  fs STUB_LIST="$tmp/l-none" STUB_FAIL=1
  [ "$rc" != 0 ] && [ "$(creates)" = 0 ] && ok "file step: a failing list call fails with no create call" || bad "file step: list failure rc=$rc"

  for bv in '2.1' 'v2.1.328' '2.01.328' ''; do
    PIN="$bv"; LATEST=2.1.328
    fs STUB_LIST="$tmp/l-none"
    [ "$rc" != 0 ] && [ ! -s "$tmp/log" ] && ok "file step: a pin of [$bv] fails before any gh call" || bad "file step: pin [$bv] rc=$rc"
  done
  PIN=2.1.316
  for bv in '2.1.328-beta' '2.1.328 x' ''; do
    LATEST="$bv"
    fs STUB_LIST="$tmp/l-none"
    [ "$rc" != 0 ] && [ ! -s "$tmp/log" ] && ok "file step: a latest of [$bv] fails before any gh call" || bad "file step: latest [$bv] rc=$rc"
  done

  # --- static checks -------------------------------------------------------------
  if grep -nEv '^[[:space:]]*#' "$script" | grep -Ew 'gh|curl|wget|GH_TOKEN|GITHUB_TOKEN' >/dev/null; then
    bad "static: claude-pin-check.sh names gh, curl, wget or a token outside comments"
  else ok "static: claude-pin-check.sh has no gh, curl, wget or token name outside comments"; fi

  code="$(grep -v '^[[:space:]]*#' "$wf")"
  trig="$(awk '/^on:/{on=1;next} on&&/^[^ ]/{exit} on&&/^  [a-z_]+:/{print $1}' "$wf" | tr '\n' ' ')"
  [ "$trig" = "schedule: workflow_dispatch: " ] && ok "static: the triggers are schedule and workflow_dispatch only" || bad "static: triggers [$trig]"
  grep -q '^permissions: {}$' "$wf" && ok "static: top-level permissions are {}" || bad "static: top-level permissions"
  grep -q '^  group: claude-pin-check$' "$wf" && grep -q '^  cancel-in-progress: false$' "$wf" && ok "static: the fixed concurrency group" || bad "static: concurrency"
  for pat in 'git push' 'gh pr' 'git checkout -b' 'git branch' 'gh api -X' 'write-all'; do
    if printf '%s\n' "$code" | grep -q -- "$pat"; then bad "static: workflow contains [$pat]"; else ok "static: workflow lacks [$pat]"; fi
  done

  awk -v dir="$tmp" '
    /^jobs:/ { injobs = 1; next }
    injobs && /^  [a-z][a-z-]*:$/ { name = $1; sub(/:$/, "", name); f = dir "/job." name; next }
    injobs && f != "" { print >> f }
  ' "$wf"
  [ -f "$tmp/job.check" ] && [ -f "$tmp/job.file" ] && [ "$(ls "$tmp"/job.* | wc -l | tr -d ' ')" = 2 ] && ok "static: exactly the jobs check and file" || bad "static: job blocks"
  for j in check file; do
    grep -q 'refs/heads/main' "$tmp/job.$j" && ok "static: $j carries the main-ref condition" || bad "static: $j lacks the main-ref condition"
    grep -q 'timeout-minutes:' "$tmp/job.$j" && ok "static: $j has a timeout" || bad "static: $j has no timeout"
  done
  perms() { awk '/^    permissions:/{on=1;next} on&&/^      [a-z-]+:/{print $1 $2;next} on{exit}' "$tmp/job.$1" | tr '\n' ' '; }
  [ "$(perms check)" = "contents:read " ] && ok "static: check holds only contents: read" || bad "static: check permissions [$(perms check)]"
  [ "$(perms file)" = "issues:write " ] && ok "static: file holds only issues: write" || bad "static: file permissions [$(perms file)]"
  grep -q 'persist-credentials: false' "$tmp/job.check" && ok "static: the check checkout does not persist credentials" || bad "static: persist-credentials"
  pin_of() { sed -n 's/.*uses: \(actions\/checkout@.*\)$/\1/p' "$1" | head -1; }
  [ -n "$(pin_of "$wf")" ] && [ "$(pin_of "$wf")" = "$(pin_of "$lswf")" ] && ok "static: the checkout pin equals label-sync.yml's" || bad "static: checkout pin differs from label-sync.yml's"
  if grep -q 'actions/checkout' "$tmp/job.file" || grep -q 'bash scripts/' "$tmp/job.file"; then bad "static: the file job checks out or runs a repo script"; else ok "static: the file job has no checkout and runs no repo script"; fi
  grep -q '^    needs: check$' "$tmp/job.file" && grep -q "needs.check.outputs.state == 'behind'" "$tmp/job.file" && ok "static: file needs check and tests its state for behind" || bad "static: file needs or if"
  grep -q 'repos/\$REPO/issues' "$tmp/job.file" && grep -q 'github-actions\[bot\]' "$tmp/job.file" && ok "static: the list call and the Actions bot match are present" || bad "static: list call or bot match"
  if grep 'gh api' "$tmp/job.file" | grep -Eq -- '--jq|[[:space:]]-q([[:space:]]|$)'; then bad "static: the list call carries --jq or -q"; else ok "static: the list call carries neither --jq nor -q"; fi
fi

exit "$fail"
