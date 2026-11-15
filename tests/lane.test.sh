#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/lane.sh: prepare, report on and clean up coder lanes (#727, #715).
#
# Each case builds a scratch repository with a local bare `origin` (no network) whose path
# carries a sentinel. Its default branch commits an .ai/project.yml that declares `lanes.dir`.
# The script under test runs as a copy in a scratch plugin `bin/`, beside stub spec-find.sh
# (prints a canned line), lane-state.sh and lane-groups.sh (print canned files; the latter also records its arguments; one contract case feeds it the real lane-groups.sh's output) and the real
# gh-identity.sh and prune-verdict.sh, with an agents/coder.md one level up. A stub `gh` and a logging `git` wrapper go first on PATH. The stub gh
# holds canned RAW API JSON and applies the caller's own --jq argument with the real `jq -r`,
# the way tests/invariants-files-filter.test.sh reads a canned page, so the script's filters are
# what is tested. (gh's own --jq is gojq; the filters used here behave the same in both.) What
# GitHub filters on the server cannot be checked by canned JSON, so those cases assert the exact
# argument list in the gh log. The git wrapper can fail a subcommand (FX_GIT_FAIL) or run one
# extra git command first (FX_PRE), to stage a race.
# No case's stdout or stderr, and no prompt file, may contain the sentinel planted in the
# issue's title, body, user.login and milestone title, the PR rows' unused fields, and the
# origin path. Not-owned cannot be faked without privilege, so the `test -O` leg is not covered.
# Needs git, yq and jq; skips, loudly, without any of them.
# Permitted toolset: POSIX sh, plus git, yq, jq, sed, awk, grep, cmp and stat as the cases need.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script_src="$root_dir/plugins/way-of-working/bin/lane.sh"
gi="$root_dir/plugins/way-of-working/bin/gh-identity.sh"
rgs="$root_dir/plugins/way-of-working/bin/review-gate-state.sh"
pv="$root_dir/plugins/way-of-working/bin/prune-verdict.sh"

for tool in git yq jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP - $tool not on PATH; lane.test.sh needs it" >&2
    exit 0
  fi
done
real_git="$(command -v git)"
real_ln="$(command -v ln)"
real_jq="$(command -v jq)"

tmp="$(cd -P "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
: >"$tmp/allout"

fail=0
assert_eq() { # <desc> <want> <got>
  if [ "$2" = "$3" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$2], got [$3]" >&2
    fail=1
  fi
}
assert_has() { # <desc> <file> <fixed string>
  if grep -F -- "$3" "$2" >/dev/null 2>&1; then
    echo "ok - $1"
  else
    echo "FAIL - $1: [$3] not in $2" >&2
    fail=1
  fi
}
assert_empty_file() { # <desc> <file>
  if [ ! -s "$2" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: $2 is not empty" >&2
    fail=1
  fi
}

SENT="SENTINEL-7c2d41e9"
ISSUE=727
MS=19
BR=feat/x
CR=architect,security-critic
OTHER_OID=1111111111111111111111111111111111111111
FOUND='found 5001 2026-10-18T00:00:00Z'

cn=0
put() { mkdir -p "$(dirname "$R/$1")" && printf '%s\n' "$2" >"$R/$1"; }
bump() { $real_git -C "$R" add -A && $real_git -C "$R" commit -q -m b && $real_git -C "$R" push -q origin refs/heads/main:refs/heads/main; }
setyml() { # a yq expression applied to the committed project file, then committed and pushed
  yq -i "$1" "$R/.ai/project.yml"
  bump
}
canon() { # rewrite the canned issue with a jq expression
  "$real_jq" "$1" "$CAN/issue.json" >"$CAN/issue.new" && mv "$CAN/issue.new" "$CAN/issue.json"
}

# nc: a fresh driver checkout on `main` with a local bare origin, the stubs, and the canned JSON.
nc() {
  cn=$((cn + 1))
  D="$tmp/c$cn"
  R="$D/work"
  O="$D/origin-$SENT.git"
  FB="$D/fb"
  CAN="$D/canned"
  LD="$D/lanes"
  CWD="$R"
  mkdir -p "$D" "$FB" "$CAN"
  $real_git init -q --bare "$O"
  $real_git -C "$O" symbolic-ref HEAD refs/heads/main
  $real_git init -q "$R"
  $real_git -C "$R" symbolic-ref HEAD refs/heads/main
  $real_git -C "$R" config user.name t
  $real_git -C "$R" config user.email t@example.invalid
  $real_git -C "$R" config commit.gpgsign false
  $real_git -C "$R" remote add origin "$O"
  cat >"$tmp/project.yml.tpl" <<YML
repo: glunk-works/claude-workbench
pr_base: main
backlog:
  kind: github_issues
  repo: null
lanes:
  dir: $LD
identities:
  maintainer:
    - { login: m, id: 1001 }
  dev_app:
    { login: d, id: 2001 }
YML
  mkdir -p "$R/.ai" "$R/dir"
  cp "$tmp/project.yml.tpl" "$R/.ai/project.yml"
  # the scratch plugin: bin/ beside the script under test, agents/coder.md one level up
  PB="$D/plug/bin"
  mkdir -p "$PB" "$D/plug/agents"
  printf 'coder\n' >"$D/plug/agents/coder.md"
  cp "$script_src" "$PB/lane.sh"
  chmod +x "$PB/lane.sh"
  script="$PB/lane.sh"
  printf '#!/bin/sh\nout=$(cat "$FX_FIND_FILE")\nprintf "%%s\\n" "$out"\nexit "${FX_FIND_RC:-0}"\n' >"$PB/spec-find.sh"
  printf '#!/bin/sh\ncat "$FX_STATE_FILE"\nexit "${FX_STATE_RC:-0}"\n' >"$PB/lane-state.sh"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >"$FX_CANNED/groups.args"\ncat "$FX_GROUPS_FILE"\nexit "${FX_GROUPS_RC:-0}"\n' >"$PB/lane-groups.sh"
  cp "$gi" "$PB/gh-identity.sh"
  cp "$pv" "$PB/prune-verdict.sh"
  cp "$rgs" "$PB/review-gate-state.sh"
  chmod +x "$PB"/*.sh
  put dir/f one
  $real_git -C "$R" add -A && $real_git -C "$R" commit -q -m a
  $real_git -C "$R" push -q origin refs/heads/main:refs/heads/main
  $real_git -C "$R" fetch -q origin
  # canned raw API JSON, with the sentinel in every field the script must never read
  cat >"$CAN/repo.json" <<EOF
{"nameWithOwner":"glunk-works/claude-workbench","defaultBranchRef":{"name":"main"},"description":"$SENT"}
EOF
  cat >"$CAN/issue.json" <<EOF
{"number":$ISSUE,"state":"open","title":"$SENT","body":"$SENT","user":{"login":"$SENT","id":9},"milestone":{"number":$MS,"title":"$SENT"}}
EOF
  printf '[]\n' >"$CAN/prs.json"
  printf '[]\n' >"$CAN/refs.json"
  printf '{"repositories":[{"full_name":"glunk-works/claude-workbench","description":"%s"}]}\n' "$SENT" >"$CAN/reach.json"
  printf '{"statusCheckRollup":[],"title":"%s"}\n' "$SENT" >"$CAN/prview.json"
  printf '[]\n' >"$CAN/state.json"
  printf 'group none\n' >"$CAN/groups.txt"
  printf '%s\n' "$FOUND" >"$CAN/find.txt"
  # the logging git wrapper, the stub gh and a stub ln
  cat >"$FB/git" <<'FAKE_GIT'
#!/bin/sh
printf '%s\n' "$*" >>"$FX_LOG"
if [ -n "${FX_GIT_FAIL:-}" ]; then
  case " $* " in *"$FX_GIT_FAIL"*) echo "git: $FX_SENT $FX_ORIGIN" >&2; exit 1 ;; esac
fi
if [ -n "${FX_PRE_SH:-}" ]; then
  case " $* " in *"${FX_PRE_ON:-never-matches}"*) eval "$FX_PRE_SH" || : ;; esac
fi
if [ -n "${FX_PRE:-}" ]; then
  case " $* " in *"${FX_PRE_ON:-never-matches}"*) "$FX_REAL_GIT" $FX_PRE >/dev/null 2>&1 || : ;; esac
fi
exec "$FX_REAL_GIT" "$@"
FAKE_GIT
  cat >"$FB/gh" <<'FAKE_GH'
#!/bin/sh
printf '%s\n' "$*" >>"$FX_GHLOG"
filt= prev=
for a in "$@"; do
  [ "$prev" = --jq ] && filt=$a
  prev=$a
done
# pick KEY: the canned file for this call of KEY: KEY.N.json when it exists (N counts the calls
# of KEY, from 1), else KEY.json; KEY.N.fail makes this call fail.
pick() {
  n=0
  [ ! -f "$FX_CANNED/cnt-$1" ] || n=$(cat "$FX_CANNED/cnt-$1")
  n=$((n + 1))
  echo "$n" >"$FX_CANNED/cnt-$1"
  [ ! -f "$FX_CANNED/$1.$n.fail" ] || { echo "gh: $FX_SENT $FX_ORIGIN" >&2; exit 1; }
  f=$FX_CANNED/$1.json
  [ ! -f "$FX_CANNED/$1.$n.json" ] || f=$FX_CANNED/$1.$n.json
}
case "$1 $2" in
  "repo view") [ "${FX_FAIL:-}" != repoview ] || { echo "gh: $FX_SENT $FX_ORIGIN" >&2; exit 1; }; f=$FX_CANNED/repo.json ;;
  "pr view") [ "${FX_FAIL:-}" != prview ] || { echo "gh: $FX_SENT $FX_ORIGIN" >&2; exit 1; }; f=$FX_CANNED/prview.json ;;
  "api --hostname") [ "${FX_FAIL:-}" != reach ] || { echo "gh: $FX_SENT $FX_ORIGIN" >&2; exit 1; }; f=$FX_CANNED/reach.json ;;
  "api --paginate")
    case "$3" in
      repos/*/*/git/matching-refs/heads/*) ;;
      repos/*/*/pulls/*/reviews) pick reviews; exec jq -r "$filt" "$f" ;;
      repos/*/*/commits/*/status) pick status; exec jq -r "$filt" "$f" ;;
      repos/*/*/commits/*/check-runs) pick checks; exec jq -r "$filt" "$f" ;;
      *) echo "stub gh: unexpected: $*" >&2; exit 1 ;;
    esac
    [ "${FX_FAIL:-}" != refs ] || { echo "gh: $FX_SENT $FX_ORIGIN" >&2; exit 1; }; f=$FX_CANNED/refs.json ;;
  "pr list") [ "${FX_FAIL:-}" != prlist ] || { echo "gh: $FX_SENT $FX_ORIGIN" >&2; exit 1; }; pick prs ;;
  api\ repos/*/pulls/*) pick pull ;;
  api\ repos/*/issues/*)
    [ "${FX_FAIL:-}" != issue ] || { echo "gh: $FX_SENT $FX_ORIGIN" >&2; exit 1; }
    f=$FX_CANNED/issue.json
    [ ! -f "$FX_CANNED/issue-${2##*/}.json" ] || f=$FX_CANNED/issue-${2##*/}.json ;;
  *) echo "stub gh: unexpected: $*" >&2; exit 1 ;;
esac
exec jq -r "$filt" "$f"
FAKE_GH
  cat >"$FB/ln" <<'FAKE_LN'
#!/bin/sh
[ -z "${FX_LN_FAIL:-}" ] || exit 1
exec "$FX_REAL_LN" "$@"
FAKE_LN
  printf '#!/bin/sh\nprintf "sleep %%s\\n" "$*" >>"$FX_SLEEPLOG"\n' >"$FB/sleep"
  chmod +x "$FB/git" "$FB/gh" "$FB/ln" "$FB/sleep"
  FX_SLEEPLOG="$D/sleeplog"
  : >"$FX_SLEEPLOG"
  export FX_SLEEPLOG
  FX_LOG="$D/gitlog"
  FX_GHLOG="$D/ghlog"
  : >"$FX_LOG"
  : >"$FX_GHLOG"
  FX_REAL_GIT=$real_git
  FX_REAL_LN=$real_ln
  FX_CANNED=$CAN
  FX_FIND_FILE=$CAN/find.txt
  FX_STATE_FILE=$CAN/state.json
  FX_GROUPS_FILE=$CAN/groups.txt
  FX_SENT=$SENT FX_ORIGIN=$O
  export FX_SENT FX_ORIGIN
  FX_FIND_RC=0 FX_GIT_FAIL= FX_PRE_SH= FX_PRE= FX_PRE_ON= FX_FAIL= FX_LN_FAIL= FX_STATE_RC=0 FX_GROUPS_RC=0
  export FX_PRE_SH FX_LOG FX_GHLOG FX_REAL_GIT FX_REAL_LN FX_CANNED FX_FIND_FILE FX_FIND_RC FX_GIT_FAIL FX_PRE FX_PRE_ON FX_FAIL FX_LN_FAIL FX_STATE_FILE FX_STATE_RC FX_GROUPS_FILE FX_GROUPS_RC
}

run_lane() {
  rc=0
  (cd "$CWD" && PATH="$FB:$PATH" "$script" "$@") >"$D/out" 2>"$D/err" || rc=$?
  out=$(cat "$D/out")
  err=$(cat "$D/err")
  cat "$D/out" "$D/err" >>"$tmp/allout"
}

snap() {
  {
    $real_git -C "$R" for-each-ref --format='%(refname) %(objectname)' refs/heads
    $real_git -C "$R" config --get-regexp '^branch\.' || :
    $real_git -C "$R" worktree list --porcelain
    if [ -e "$LD" ] || [ -L "$LD" ]; then
      echo "lanes $(stat -c %a "$LD")"
      ls -A "$LD" 2>/dev/null || :
    else
      echo nolanes
    fi
  } 2>&1
}

# stop_case: run, expect <rc> and the exact stdout <word>, and nothing else changed.
stop_case() { # <desc> <rc> <word> <args...>
  d=$1 wrc=$2 word=$3
  shift 3
  before=$(snap)
  run_lane "$@"
  after=$(snap)
  assert_eq "$d: exit" "$wrc" "$rc"
  assert_eq "$d: stdout" "$word" "$out"
  assert_eq "$d: nothing changed" "$before" "$after"
}

PREP="$ISSUE $MS $BR $CR"
prep_ok() { # a normal successful prep in the current case
  run_lane prep $PREP
  assert_eq "prep ok: exit" 0 "$rc"
}

# setld: point the committed project file's lanes.dir at a new directory (and LD with it).
setld() { # <dir>
  LD=$1
  setyml ".lanes.dir = \"$1\""
}

# ---- the script is executable in the index -------------------------------------------------
assert_eq "lane.sh is committed as 100755" 100755 "$($real_git -C "$root_dir" ls-files -s plugins/way-of-working/bin/lane.sh | awk '{print $1}')"
assert_eq "scripts/lanes/lane.sh no longer exists" no "$([ -e "$root_dir/scripts/lanes/lane.sh" ] && echo yes || echo no)"

# ---- arguments: exit 2, no output, no git or gh call ---------------------------------------
nc
nl() { printf '%s\n%s' "$1" "$2"; }
argcase() { # <desc> <args...>
  d=$1
  shift
  : >"$FX_LOG"
  : >"$FX_GHLOG"
  run_lane "$@"
  assert_eq "arg $d: exit" 2 "$rc"
  assert_eq "arg $d: stdout" "" "$out"
  assert_empty_file "arg $d: git log" "$FX_LOG"
  assert_empty_file "arg $d: gh log" "$FX_GHLOG"
}
for v in 0 012 abc ''; do
  argcase "N [$v]" prep "$v" $MS $BR $CR
  argcase "M [$v]" prep $ISSUE "$v" $BR $CR
done
argcase "N newline" prep "$(nl 7 8)" $MS $BR $CR
argcase "M newline" prep $ISSUE "$(nl 7 8)" $BR $CR
argcase "done N 0" done 0
argcase "done N newline" done "$(nl 7 8)"
argcase "no mode"
argcase "bad mode" frob 1
argcase "prep arg count" prep $ISSUE $MS $BR
argcase "prep with a sixth argument" prep $ISSUE $MS $BR $CR 728 extra
for v in '' 0 012 abc 728, ,728 728,,730 728,728 727 728,727 727,728 '728 730' 728.730; do
  argcase "ALSO [$v]" prep $ISSUE $MS $BR $CR "$v"
done
argcase "ALSO newline" prep $ISSUE $MS $BR $CR "$(nl 728 730)"
argcase "ALSO newline after a comma" prep $ISSUE $MS $BR $CR "728,$(nl 7 8)"
argcase "done arg count" done 1 2
argcase "drop N 0" drop 0
argcase "drop N newline" drop "$(nl 7 8)"
argcase "drop no N" drop
argcase "drop a bad third word" drop 1 force
argcase "drop a capitalised third word" drop 1 Discard
argcase "drop an empty third word" drop 1 ''
argcase "drop a fourth argument" drop 1 discard extra
argcase "wait N 0" wait 0
argcase "wait N 012" wait 012
argcase "wait N newline" wait "$(nl 7 8)"
argcase "wait no N" wait
argcase "wait arg count" wait 1 2
argcase "status arg count" status 1
argcase "status with a stray empty argument" status ''
for v in main feat/ sprint/1-x feat/A feat/a.b style/x feat/-a feat/a/b ''; do
  argcase "BRANCH [$v]" prep $ISSUE $MS "$v" $CR
done
argcase "BRANCH newline" prep $ISSUE $MS "$(nl feat/a feat/b)" $CR
for v in '' bogus architect,architect architect, ,architect architect,,docs-consistency; do
  argcase "CRITICS [$v]" prep $ISSUE $MS $BR "$v"
done
argcase "CRITICS newline" prep $ISSUE $MS $BR "$(nl architect architect)"

# a slash-less $0 and a missing sibling: a usage error, nothing on stdout, no git or gh call
sibcase() { # <desc> <setup>
  nc
  $2
  : >"$FX_LOG"
  : >"$FX_GHLOG"
  rc=0
  (cd "$CWD" && PATH="$FB:$PATH" sh "$script" status) >"$D/out" 2>"$D/err" || rc=$?
  assert_eq "$1: exit" 2 "$rc"
  assert_eq "$1: stdout" "" "$(cat "$D/out")"
  assert_empty_file "$1: git log" "$FX_LOG"
  assert_empty_file "$1: gh log" "$FX_GHLOG"
}
s_none() { :; }
s_nosib_find() { rm "$PB/spec-find.sh"; }
s_nosib_gi() { rm "$PB/gh-identity.sh"; }
s_nosib_pv() { rm "$PB/prune-verdict.sh"; }
s_nosib_ls() { rm "$PB/lane-state.sh"; }
s_nosib_lg() { rm "$PB/lane-groups.sh"; }
nc
rc=0
(cd "$PB" && PATH="$FB:$PATH" sh lane.sh status) >"$D/out" 2>"$D/err" || rc=$?
assert_eq "a slash-less \$0: exit" 2 "$rc"
assert_eq "a slash-less \$0: stdout" "" "$(cat "$D/out")"
assert_empty_file "a slash-less \$0: git log" "$FX_LOG"
sibcase "a missing spec-find.sh" s_nosib_find
sibcase "a missing gh-identity.sh" s_nosib_gi
sibcase "a missing prune-verdict.sh" s_nosib_pv
sibcase "a missing lane-state.sh" s_nosib_ls
sibcase "a missing lane-groups.sh" s_nosib_lg
s_nosib_rg() { rm "$PB/review-gate-state.sh"; }
sibcase "a missing review-gate-state.sh" s_nosib_rg

# ---- the main-worktree check ---------------------------------------------------------------
nc
$real_git -C "$R" worktree add -q "$D/other" -b other
CWD="$D/other"
run_lane prep $PREP
assert_eq "not-main from a linked worktree (prep): exit" 1 "$rc"
assert_eq "not-main from a linked worktree (prep): stdout" not-main "$out"
run_lane done $ISSUE
assert_eq "not-main from a linked worktree (done): stdout" not-main "$out"
assert_empty_file "not-main: gh log" "$FX_GHLOG"
CWD="$D"
run_lane prep $PREP
assert_eq "not-main outside a work tree: stdout" not-main "$out"
nc
mkdir -p "$D/lanes"
$real_git -C "$R" worktree add -q "$D/lanes/1" -b lane1
CWD="$D/lanes/1"
run_lane prep $PREP
assert_eq "not-main from inside LANES: stdout" not-main "$out"

# ---- the default-branch read ---------------------------------------------------------------
nc
FX_FAIL=repoview
stop_case "failed repo view" 1 unreadable prep $PREP
nc
FX_GIT_FAIL=" fetch "
stop_case "failed fetch" 1 unreadable prep $PREP
nc
setyml '.pr_base = "-x"'
stop_case "bad pr_base" 1 unreadable prep $PREP
nc
setyml '.pr_base = "a b"'
stop_case "pr_base with a space" 1 unreadable prep $PREP
nc
setyml '.backlog.repo = "a/b/c"'
stop_case "bad backlog.repo" 1 unreadable prep $PREP
nc
setyml '.backlog.repo = "a/.."'
stop_case "backlog.repo with a .. part" 1 unreadable prep $PREP
setyml 'del(.lanes)'
stop_case "no-lanes: lanes absent" 1 no-lanes prep $PREP
nc
setyml '.lanes = null'
stop_case "no-lanes: lanes null" 1 no-lanes prep $PREP
nc
setyml '.lanes = "x"'
stop_case "no-lanes: lanes not a map" 1 no-lanes prep $PREP
nc
setyml '.lanes.dir = 5'
stop_case "no-lanes: dir not a string" 1 no-lanes prep $PREP
for v in rel/x '/a/$(id)' / /a/ /a//b /a/./b /a/../b /a/.. '/a b'; do
  nc
  setyml ".lanes.dir = \"$v\""
  stop_case "no-lanes: dir [$v]" 1 no-lanes prep $PREP
done
nc
setyml 'del(.lanes)'
stop_case "no-lanes: status" 1 no-lanes status
nc
setyml 'del(.lanes)'
stop_case "no-lanes: done" 1 no-lanes done $ISSUE
nc
setyml '.lanes = null'
stop_case "no-lanes: lanes null (done)" 1 no-lanes done $ISSUE
nc
setyml '.repo = "other/repo"'
stop_case "repo-mismatch" 1 repo-mismatch prep $PREP
nc
setyml '.backlog.repo = "Glunk-Works/Claude-Workbench"'
stop_case "backlog-case: prep" 1 backlog-case prep $PREP
nc
setyml '.backlog.repo = "Glunk-Works/Claude-Workbench"'
stop_case "backlog-case: status" 1 backlog-case status
nc
setyml '.identities = null'
stop_case "not-map under identities: null" 1 not-map prep $PREP
nc
setyml '.identities = null'
cp "$tmp/project.yml.tpl" "$R/.ai/project.yml"
stop_case "not-map when only the working tree has a map" 1 not-map prep $PREP
nc
prep_ok
assert_has "backlog.repo: null makes the issue path use .repo" "$FX_GHLOG" "api repos/glunk-works/claude-workbench/issues/$ISSUE --jq "
nc
setyml '.backlog.repo = "glunk-works/backlog"'
prep_ok
assert_has "backlog.repo names the issue path" "$FX_GHLOG" "api repos/glunk-works/backlog/issues/$ISSUE --jq "
assert_has "backlog.repo: the prompt makes no milestone write" "$LD/$ISSUE-prompt.md" "5. Make no milestone write: milestone \`$MS\` is in the backlog repository"
if grep -F "PATCH" "$LD/$ISSUE-prompt.md" >/dev/null; then
  echo "FAIL - backlog.repo: the prompt carries a PATCH" >&2
  fail=1
else
  echo "ok - backlog.repo: the prompt carries no PATCH"
fi

nc
put .ai/project.yml "$(yq '.identities = null' "$R/.ai/project.yml")"
$real_git -C "$R" add -A && $real_git -C "$R" commit -q -m local-only
prep_ok
assert_eq "trust root: an unpushed local edit to the project file is not read" "worktree=$LD/$ISSUE" "$(printf '%s\n' "$out" | awk 'NR==1')"
nc
mkdir -p "$D/lanes"
$real_git clone -q "$O" "$D/lanes/clone"
CWD="$D/lanes/clone"
run_lane prep $PREP
assert_eq "not-main from a main worktree under LANES: stdout" not-main "$out"
assert_eq "not-main from a main worktree under LANES: exit" 1 "$rc"

# ---- the trust root ------------------------------------------------------------------------
nc
printf 'none\n' >"$CAN/find.txt"
mkdir -p "$R/plugins/way-of-working/bin" "$R/bin"
printf '#!/bin/sh\necho "found 9 2026-10-18T00:00:00Z"\n' >"$R/plugins/way-of-working/bin/spec-find.sh"
printf '#!/bin/sh\ntouch "%s/gh-ran"\n' "$D" >"$R/bin/gh"
chmod +x "$R/bin/gh" "$R/plugins/way-of-working/bin/spec-find.sh"
stop_case "trust root: the working tree's spec-find.sh is not used" 1 "finder: none" prep $PREP
# The script never puts a checkout directory on PATH, so this only guards against it starting to.
assert_eq "trust root: a working-tree bin/gh is not run" no "$([ -e "$D/gh-ran" ] && echo yes || echo no)"

# ---- the installed-plugin rule ------------------------------------------------------------
nc
mkdir -p "$R/pb"
cp "$PB"/*.sh "$R/pb/"
mkdir -p "$R/agents"
printf 'coder\n' >"$R/agents/coder.md"
script="$R/pb/lane.sh"
stop_case "a copy run from inside the main worktree" 1 unreadable status
nc
mkdir -p "$LD/9/pb" "$LD/9/agents"
cp "$PB"/*.sh "$LD/9/pb/"
script="$LD/9/pb/lane.sh"
stop_case "a copy run from inside the lanes directory" 1 unreadable status

# ---- the token's reach ---------------------------------------------------------------------
nc
printf '{"repositories":[{"full_name":"glunk-works/other"}]}\n' >"$CAN/reach.json"
stop_case "reach: origin's repository not listed" 1 unreached prep $PREP
nc
printf '{"repositories":[]}\n' >"$CAN/reach.json"
stop_case "reach: an empty installation list" 1 unreadable prep $PREP
nc
FX_FAIL=reach
stop_case "reach: a failed installation call" 1 unreadable prep $PREP
nc
printf '{"repositories":[{"full_name":"a b"}]}\n' >"$CAN/reach.json"
stop_case "reach: a malformed record" 1 unreadable prep $PREP
nc
prep_ok
assert_has "reach: the call names the host" "$FX_GHLOG" "api --hostname github.com --paginate installation/repositories --jq "
nc
printf '{"repositories":[{"full_name":"glunk-works/other"}]}\n' >"$CAN/reach.json"
run_lane done $ISSUE
assert_eq "reach: done adds no probe" no-lane "$out"
assert_eq "reach: done made no installation call" 0 "$(grep -c installation "$FX_GHLOG" || :)"

# ---- the milestone step names the M passed to prep -----------------------------------------
nc
canon '.milestone.number = 23'
run_lane prep $ISSUE 23 $BR $CR
assert_eq "milestone 23: exit" 0 "$rc"
assert_has "milestone 23: the head read names the repo and branch" "$LD/$ISSUE-prompt.md" ".head.repo.full_name + \" \" + .head.ref"
assert_has "milestone 23: the read names 23" "$LD/$ISSUE-prompt.md" "gh api repos/glunk-works/claude-workbench/milestones/23 --jq .state"
assert_has "milestone 23: the PATCH names 23" "$LD/$ISSUE-prompt.md" "issues/\$P -F milestone=23 --jq .milestone.number"
if grep -F "milestone=$MS " "$LD/$ISSUE-prompt.md" >/dev/null; then
  echo "FAIL - milestone 23: the prompt still names $MS" >&2
  fail=1
else
  echo "ok - milestone 23: the prompt does not name $MS"
fi

# ---- prep with found -----------------------------------------------------------------------
nc
prep_ok
BOID=$($real_git -C "$R" rev-parse refs/remotes/origin/main)
prompt="$LD/$ISSUE-prompt.md"
want=$(printf 'worktree=%s\nbranch=%s\nfound=5001 2026-10-18T00:00:00Z\nmilestone=%s\nprompt=%s\nprompt-sha256=%s' "$LD/$ISSUE" "$BR" "$MS" "$prompt" "$(sha256sum "$prompt" | awk '{print $1}')")
assert_eq "prep: the six output lines" "$want" "$out"
assert_eq "prep: worktree is on BRANCH" "$BR" "$($real_git -C "$LD/$ISSUE" symbolic-ref --short HEAD)"
assert_eq "prep: worktree is at origin/main's commit" "$BOID" "$($real_git -C "$LD/$ISSUE" rev-parse HEAD)"
if $real_git -C "$LD/$ISSUE" rev-parse '@{u}' >/dev/null 2>&1; then
  echo "FAIL - prep: the branch has an upstream" >&2
  fail=1
else
  echo "ok - prep: the branch has no upstream"
fi
assert_eq "prep: LANES is mode 700" 700 "$(stat -c %a "$LD")"
assert_eq "prep: no group or world access to the prompt" 0 "$(($(printf '0%s' "$(stat -c %a "$prompt")") & 077))"
assert_eq "prep: no temp name left in LANES" "$ISSUE
$ISSUE-prompt.md" "$(ls -A "$LD")"
sed -e "s#@LANES@#$LD#g" -e "s#@BIN@#$PB#g" -e "s#@CODER@#$D/plug/agents/coder.md#g" -e "s#@TOPLEVEL@#$R#g" >"$D/golden" <<'GOLDEN'
# Lane prompt: glunk-works/claude-workbench#727

You are a **lane**. For this one task you act as the `coder` defined in `@CODER@`. The driver session that ran `lane.sh prep` is your spawner.

## Task

- **Task:** `glunk-works/claude-workbench#727`, on milestone `19`.
- **Missing state file:** this worktree has no `.ai/state.json`. Wherever `coder.md` refers to `plan_anchor.task_issue`, use `727`. Wherever it refers to the anchor's milestone, use `19`.
- **Mode:** `map`.
- **Spec:** the spawner names the found pair `found 5001 2026-10-18T00:00:00Z`. The pin is `PIN_ID='5001'` and `PIN_UP='2026-10-18T00:00:00Z'`.

## PATH: on every Bash call that runs a plugin script

A Bash tool call does not keep exports from earlier calls. So every Bash call that runs a plugin `bin/` script (`spec-find.sh`, `spec-comment.sh`, `spec-fresh.sh`, `gh-identity.sh`, `spec-reaction.sh` and the rest) starts with this line, which also checks that the installed plugin's scripts are the ones found:

    export PATH='@BIN@':"$PATH" && [ "$(command -v spec-find.sh)" = @BIN@/spec-find.sh ] || { echo "PATH check failed"; exit 1; }

If that check fails, stop and report.

## Order of work

1. Build the task per `coder.md`.
2. Run every `gates.green` entry in `.ai/project.yml`, each from its `cwd` (the repo root when absent) in its own Bash call with the tool's maximum timeout (600000 ms); if one times out, stop and report.
3. Run `/way-of-working:critic-gate` with no names on its invocation line. The driver's critics are `architect,security-critic`, given here as names this session holds: when critic-gate selects its critics by rule it unions them with its set and asks nothing; when it proposes, show both lists to the human in the pick-list, as before. That list is not the explicit-names shortcut, which only names the human types count for.
4. Commit and open the PR with `/way-of-working:ship`. This is the explicit instruction to commit and push that `coder.md` asks for.
5. Set this PR's milestone, only when ship's author check passed and ship reported the PR URL; `P` is the number at the end of that URL. In one Bash call, capture each value into a variable, check it is non-empty and chain with `&&`: require `P` to be digits with no leading zero; require `gh api repos/glunk-works/claude-workbench/pulls/$P --jq '.head.repo.full_name + " " + .head.ref'` to print `glunk-works/claude-workbench`, one space, then what `git branch --show-current` prints; require `gh api repos/glunk-works/claude-workbench/milestones/19 --jq .state` to print `open`; then run `gh api -X PATCH repos/glunk-works/claude-workbench/issues/$P -F milestone=19 --jq .milestone.number`, setting no other field. The milestone is set only when that last call prints `19`. Any other outcome (a `P` that is not digits, a head repository or branch mismatch, a closed milestone, a failed read, a PATCH that failed or the session refused, another number printed) is no further write. Report the outcome in your final message either way, and never retry with another value or another command.

## When the spec's own text is defective

This applies only when a finding of the `/way-of-working:critic-gate` run in *Order of work*, not from `security-critic`, shows that text the spec requires (a passage it says to write word for word, or a behaviour it states) is wrong, and fixing it means departing from the spec. A `security-critic` finding of that kind is reported in your final message and nothing is posted. Do not fix the text and do not ship. Instead:

1. Make two fresh directories outside the worktree with `mktemp -d`; the second stays empty. Copy the default branch's committed `.ai/project.yml` into the first.
2. With the Write tool, write `draft.md` in the first. It holds, in order: a title line that names the spec comment `5001` and says this is a lane's escalation of a defect in that spec's own text; a critic line in the grammar the `spec-post.sh` header defines (the critic names that run used, joined by a comma and a space; `1 round` when it ran one round, else the count and `rounds`; the stop `not converging`); the approved spec's sections from its `### Goal` heading on, unchanged; then `### Open findings` with one bullet per finding, naming the section, the passage in paraphrase, what is wrong with the evidence as a repo-relative path and line, and the recommended corrected wording.
3. Run `spec-shape.sh check` on it (the project copy as third argument) and `spec-fresh.sh shape` on it. Each must print `ok`; you get one fix each.
4. Run `spec-post.sh escalate 727 SHA DRAFT OUT`, SHA the approved comment's marker sha, DRAFT the draft's path and OUT the second directory. Report the line it printed in your final message and stop.

This is the one post a lane makes, and for this case only it overrides the coder definition's rule that it never drafts or posts a spec. Never edit, delete or react to a comment, and never read the issue body. On any word but `escalated`, report the word and the draft path, post nothing else, and stop.

## Lane rules

- Never run `/way-of-working:resume`, `/way-of-working:handoff`, `/way-of-working:plan-sprint` or `/way-of-working:archive-sprint`. Never write the `.ai/` cursor: `.ai/state.json`, `.ai/next-steps.md`, `.ai/parked/` or `.ai/archive/`. Write any other path under `.ai/` only when the spec's *Files touched* lists it.
- Never merge, approve or force-push.
- Work only in `@LANES@/727`, never in `@TOPLEVEL@`'s working tree.
- A session that read the issue body or drafted the spec never builds the issue.
- The spec's `### Not applied (tightenings)` section is optional guidance only as far as `coder.md` says, and a note in it is not text the spec requires for the *When the spec's own text is defective* section.

## Identity

- Do not prefix commands with `GH_TOKEN`.
GOLDEN
gold_D=$D
cp "$D/golden" "$tmp/golden.noalso"
if cmp -s "$D/golden" "$prompt"; then
  echo "ok - prep: the prompt matches the golden file byte for byte"
else
  echo "FAIL - prep: the prompt differs from the golden file" >&2
  diff "$D/golden" "$prompt" >&2 || :
  fail=1
fi
assert_has "prep: the PATH line has a literal \$PATH" "$prompt" "/bin':\"\$PATH\" && [ \"\$(command -v spec-find.sh)\" = "
assert_has "prep: the prompt names the scratch bin" "$prompt" "export PATH='$PB':"
assert_has "prep: the prompt names the scratch coder definition" "$prompt" "defined in \`$D/plug/agents/coder.md\`"
assert_has "prep: the prompt names the main worktree" "$prompt" "never in \`$R\`'s working tree"
for bad in "plugins/way-of-working/" "scripts/test-all.sh" "/workspace" "WB-D" "code-owner"; do
  if grep -F -- "$bad" "$prompt" >/dev/null; then
    echo "FAIL - the prompt names [$bad]" >&2
    fail=1
  else
    echo "ok - the prompt does not name [$bad]"
  fi
done
if grep -F "$SENT" "$prompt" >/dev/null; then
  echo "FAIL - the sentinel is in the prompt" >&2
  fail=1
else
  echo "ok - the sentinel is not in the prompt"
fi
assert_eq "prep: the logged git calls start from the top level" 0 "$(grep -v "^-C " "$FX_LOG" | grep -vc "^rev-parse --show-toplevel$" || :)"

nc
CWD="$R/dir"
prep_ok
assert_eq "prep from a subdirectory: the six lines" 6 "$(printf '%s\n' "$out" | awk 'END {print NR}')"
assert_eq "prep from a subdirectory: the worktree" "worktree=$LD/$ISSUE" "$(printf '%s\n' "$out" | awk 'NR==1')"

# ---- prep, finder lines --------------------------------------------------------------------
finder_case() { # <desc> <expected stdout> <find.txt content> [rc]
  nc
  printf '%s' "$3" >"$CAN/find.txt"
  FX_FIND_RC=${4:-0}
  export FX_FIND_RC
  stop_case "finder $1" 1 "$2" prep $PREP
  assert_eq "finder $1: no prompt file" no "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"
}
finder_case none "finder: none" 'none
'
finder_case unreacted "finder: unreacted" 'unreacted 5
'
finder_case escalated "finder: escalated" 'escalated 5
'
finder_case ambiguous "finder: ambiguous" 'ambiguous 5,6
'
finder_case moved "finder: moved" 'moved 5
'
finder_case unreadable "finder: unreadable" 'unreadable
'
finder_case "an empty output" "finder: unreadable" ''
finder_case "a non-zero exit" "finder: unreadable" 'none
' 1
finder_case "a found line with a leading zero" "finder: unreadable" 'found 05 2026-10-18T00:00:00Z
'
finder_case "a found line with two fields" "finder: unreadable" 'found 5
'
finder_case "a found line with a bad time" "finder: unreadable" 'found 5 2026-10-18
'
finder_case "two lines" "finder: unreadable" 'found 5 2026-10-18T00:00:00Z
found 6 2026-10-18T00:00:00Z
'
finder_case "an unknown word" "finder: unreadable" 'frob 5
'

# ---- prep, exists --------------------------------------------------------------------------
exists_case() { # <desc> <setup function>
  nc
  mkdir -m 700 "$LD"
  $2
  stop_case "exists: $1" 1 exists prep $PREP
}
s_wtpath() { mkdir "$LD/$ISSUE"; }
s_promptfile() { : >"$LD/$ISSUE-prompt.md"; }
s_dangling() { ln -s "$D/nowhere" "$LD/$ISSUE-prompt.md"; }
s_gonewt() {
  $real_git -C "$R" worktree add -q "$LD/$ISSUE" -b other
  rm -rf "${LD:?}/$ISSUE"
}
s_localbranch() { $real_git -C "$R" branch "$BR"; }
s_remotebranch() { $real_git -C "$R" push -q origin "HEAD:refs/heads/$BR"; }
s_trackingref() { $real_git -C "$R" update-ref "refs/remotes/origin/$BR" HEAD; }
s_config() { $real_git -C "$R" config "branch.$BR.merge" refs/heads/foo; }
exists_case "an existing worktree path" s_wtpath
exists_case "an existing prompt file" s_promptfile
exists_case "a dangling symbolic link at the prompt path" s_dangling
exists_case "a registered worktree whose directory is gone" s_gonewt
exists_case "an existing local branch" s_localbranch
exists_case "an existing remote branch" s_remotebranch
exists_case "a lingering refs/remotes/origin/BRANCH" s_trackingref
exists_case "a leftover branch.BRANCH.merge key" s_config

# ---- prep, the lanes directory -------------------------------------------------------------
nc
mkdir "$D/real"
ln -s "$D/real" "$LD"
stop_case "LANES is a symbolic link to a directory" 1 unsafe-dir prep $PREP
nc
: >"$LD"
stop_case "LANES is a regular file" 1 unsafe-dir prep $PREP
nc
setld "$D/nope/lanes"
stop_case "LANES has a missing parent" 1 unsafe-dir prep $PREP
nc
mkdir "$D/q'q" "$D/q'q/lanes"
ln -s "$D/q'q" "$D/linkp"
setld "$D/linkp/lanes"
stop_case "a parent link to a directory whose name has a quote (LANES exists)" 1 unsafe-dir prep $PREP
nc
mkdir "$D/q'q"
ln -s "$D/q'q" "$D/linkp"
setld "$D/linkp/lanes"
run_lane prep $PREP
assert_eq "a parent link to a directory whose name has a quote (LANES new): stdout" unsafe-dir "$out"
assert_eq "a parent link to a quoted directory: nothing created" "" "$(ls -A "$D/q'q")"
nc
mkdir -m 755 "$LD"
printf 'none\n' >"$CAN/find.txt"
stop_case "a stop before step 7 keeps LANES at 755" 1 "finder: none" prep $PREP
assert_eq "a stop before step 7: still 755" 755 "$(stat -c %a "$LD")"
nc
mkdir -m 755 "$LD"
prep_ok
assert_eq "an existing LANES at 755 is 700 after prep" 700 "$(stat -c %a "$LD")"
nc
printf 'none\n' >"$CAN/find.txt"
stop_case "a stop before step 7 with no LANES leaves none" 1 "finder: none" prep $PREP

# ---- prep, the issue -----------------------------------------------------------------------
issue_case() { # <desc> <word> <jq expression>
  nc
  canon "$3"
  stop_case "issue $1" 1 "$2" prep $PREP
}
issue_case "closed" bad-issue '.state = "closed"'
issue_case "a pull request" bad-issue '. + {pull_request: {url: "x"}}'
issue_case "on another milestone" bad-issue '.milestone.number = 3'
issue_case "with no milestone" bad-issue '.milestone = null'
issue_case "with another number" bad-issue '.number = 728'
nc
FX_FAIL=issue
stop_case "issue read failed" 1 unreadable prep $PREP

# ---- prep, the folded issues (ALSO) --------------------------------------------------------
# also_mk: a canned answer for folded issue <n> of its own, open and on the milestone.
also_mk() { # <n>
  printf '{"number":%s,"state":"open","title":"%s","body":"%s","user":{"login":"%s","id":9},"milestone":{"number":%s,"title":"%s"}}\n' "$1" "$SENT" "$SENT" "$SENT" "$MS" "$SENT" >"$CAN/issue-$1.json"
}
also_canon() { # <n> <jq expression>
  "$real_jq" "$2" "$CAN/issue-$1.json" >"$CAN/issue-$1.new" && mv "$CAN/issue-$1.new" "$CAN/issue-$1.json"
}
also_case() { # <desc> <word> <n> <jq expression>
  nc
  also_mk 728
  also_mk 730
  also_canon "$3" "$4"
  stop_case "ALSO $1" 1 "$2" prep $PREP 728,730
}
# a folded issue with a lane of its own stops exists, before any issue is read
also_lane_case() { # <desc> <setup function>
  nc
  mkdir -m 700 "$LD"
  also_mk 728
  also_mk 730
  $2
  stop_case "ALSO $1" 1 exists prep $PREP 728,730
  if grep -F -- "/issues/" "$FX_GHLOG" >/dev/null 2>&1; then
    echo "FAIL - ALSO $1: an issue was read" >&2
    fail=1
  else
    echo "ok - ALSO $1: no issue read"
  fi
}
sa_dir() { mkdir "$LD/728"; }
sa_prompt() { : >"$LD/728-prompt.md"; }
sa_dangling() { ln -s "$D/nowhere" "$LD/728-prompt.md"; }
sa_gonewt() {
  $real_git -C "$R" worktree add -q "$LD/728" -b other
  rm -rf "${LD:?}/728"
}
sa_second() { mkdir "$LD/730"; }
also_lane_case "folded lane directory" sa_dir
also_lane_case "folded prompt file" sa_prompt
also_lane_case "folded dangling prompt link" sa_dangling
also_lane_case "folded registered worktree whose directory is gone" sa_gonewt
also_lane_case "second folded item's lane directory" sa_second
also_case "closed" bad-issue 730 '.state = "closed"'
also_case "a pull request" bad-issue 728 '. + {pull_request: {url: "x"}}'
also_case "on another milestone" bad-issue 730 '.milestone.number = 3'
also_case "with no milestone" bad-issue 728 '.milestone = null'
also_case "with another number" bad-issue 730 '.number = 729'
nc
also_mk 728
printf 'not json\n' >"$CAN/issue-730.json"
stop_case "ALSO unreadable read (not JSON)" 1 unreadable prep $PREP 728,730
nc
also_mk 728
stop_case "ALSO with no canned answer of its own (the task's number)" 1 bad-issue prep $PREP 728,730

# success: the closes line, the same six output lines, once per milestone step
nc
also_mk 728
also_mk 730
run_lane prep $PREP 728,730
assert_eq "ALSO: exit" 0 "$rc"
prompt="$LD/$ISSUE-prompt.md"
want=$(printf 'worktree=%s\nbranch=%s\nfound=5001 2026-10-18T00:00:00Z\nmilestone=%s\nprompt=%s\nprompt-sha256=%s' "$LD/$ISSUE" "$BR" "$MS" "$prompt" "$(sha256sum "$prompt" | awk '{print $1}')")
assert_eq "ALSO: the six output lines" "$want" "$out"
assert_has "ALSO: the task issue is read" "$FX_GHLOG" "api repos/glunk-works/claude-workbench/issues/$ISSUE --jq "
assert_has "ALSO: 728 is read" "$FX_GHLOG" "api repos/glunk-works/claude-workbench/issues/728 --jq "
assert_has "ALSO: 730 is read" "$FX_GHLOG" "api repos/glunk-works/claude-workbench/issues/730 --jq "
# the golden is the no-ALSO prompt of the case above with the one line added after step 4
line='   The PR body closes each of these issues: Closes glunk-works/claude-workbench#727, Closes glunk-works/claude-workbench#728, Closes glunk-works/claude-workbench#730.'
sed "s#$gold_D/#$D/#g" "$tmp/golden.noalso" | awk -v l="$line" '{print} /^4\. Commit and open the PR/ {print l}' >"$D/golden2"
grep -F -- "$line" "$D/golden2" >/dev/null && echo "ok - ALSO: the golden carries the closes line"
if cmp -s "$D/golden2" "$prompt"; then
  echo "ok - ALSO: the prompt matches the golden file byte for byte"
else
  echo "FAIL - ALSO: the prompt differs from the golden file" >&2
  diff "$D/golden2" "$prompt" >&2 || :
  fail=1
fi
nc
setyml '.backlog.repo = "glunk-works/backlog"'
also_mk 728
run_lane prep $PREP 728
assert_eq "ALSO, separate backlog: exit" 0 "$rc"
prompt="$LD/$ISSUE-prompt.md"
assert_has "ALSO, separate backlog: the closes line names the backlog repo" "$prompt" "   The PR body closes each of these issues: Closes glunk-works/backlog#727, Closes glunk-works/backlog#728."
assert_has "ALSO, separate backlog: step 5 is the no-milestone step" "$prompt" "5. Make no milestone write: milestone \`$MS\` is in the backlog repository"
assert_eq "ALSO, separate backlog: the closes line sits between steps 4 and 5" "4. Commit and open the PR
   The PR body closes each of these issues: Closes glunk-works/backlog#727, Closes glunk-works/backlog#728.
5. Make no milestone write" "$(grep -E '^(4\. Commit and open the PR|   The PR body closes|5\. )' "$prompt" | cut -c1-120 | sed -e 's/^\(4\. Commit and open the PR\).*/\1/' -e 's/^\(5\. Make no milestone write\).*/\1/')"

# ---- prep, rollback ------------------------------------------------------------------------
nc
FX_GIT_FAIL=" worktree add "
stop_case "rollback: a failing worktree add" 1 failed prep $PREP
nc
FX_GIT_FAIL=" rev-parse --verify -q HEAD "
stop_case "rollback: a failing HEAD check" 1 failed prep $PREP
assert_eq "rollback: no worktree directory after a HEAD check" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
nc
FX_LN_FAIL=1
stop_case "rollback: a failing ln" 1 failed prep $PREP
assert_eq "rollback: no worktree directory after ln" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
nc
mkdir -m 700 "$LD"
FX_LN_FAIL=1
stop_case "rollback: an existing LANES survives a failing ln" 1 failed prep $PREP
nc
put dir/g two
$real_git -C "$R" add -A && $real_git -C "$R" commit -q -m other
OTHER=$($real_git -C "$R" rev-parse HEAD)
FX_PRE="update-ref refs/heads/$BR $OTHER"
FX_PRE_ON=" worktree add "
export FX_PRE FX_PRE_ON
run_lane prep $PREP
assert_eq "rollback: another process's branch: stdout" failed "$out"
assert_eq "rollback: another process's branch is not deleted" "$OTHER" "$($real_git -C "$R" rev-parse --verify -q "refs/heads/$BR" || echo gone)"

nc
FX_PRE="worktree add -q $D/racer -b $BR refs/remotes/origin/main"
FX_PRE_ON=" worktree add --no-track "
export FX_PRE FX_PRE_ON
run_lane prep $PREP
assert_eq "rollback: a branch another prep has checked out: stdout" failed "$out"
assert_eq "rollback: a branch checked out elsewhere is not deleted" "$($real_git -C "$R" rev-parse refs/remotes/origin/main)" "$($real_git -C "$R" rev-parse --verify -q "refs/heads/$BR" || echo gone)"

nc
FX_PRE_SH="mkdir $D/evil && ln -s $D/evil $LD/$ISSUE"
FX_PRE_ON=" worktree add "
export FX_PRE_SH FX_PRE_ON
run_lane prep $PREP
assert_eq "rollback: a link planted at the worktree path: stdout" failed "$out"
assert_eq "rollback: a link planted at the worktree path: no branch left" gone "$($real_git -C "$R" rev-parse --verify -q "refs/heads/$BR" || echo gone)"
assert_eq "rollback: a link planted at the worktree path: no prompt file" no "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"
nc
FX_PRE="worktree add -q $LD/$ISSUE -b racer refs/remotes/origin/main"
FX_PRE_ON=" worktree add --no-track "
export FX_PRE FX_PRE_ON
mkdir -m 700 "$LD"
run_lane prep $PREP
assert_eq "rollback: a racing worktree at the path: stdout" failed "$out"
assert_eq "rollback: a racing worktree at the path survives" yes "$([ -d "$LD/$ISSUE" ] && echo yes || echo no)"
assert_eq "rollback: a racing worktree at the path is still listed" 1 "$($real_git -C "$R" worktree list --porcelain | grep -Fxc "worktree $LD/$ISSUE")"
assert_eq "rollback: a racing worktree at the path: our branch is gone" gone "$($real_git -C "$R" rev-parse --verify -q "refs/heads/$BR" || echo gone)"

nc
FX_PRE_SH='kill -TERM $PPID'
FX_PRE_ON=" worktree add "
export FX_PRE_SH FX_PRE_ON
before=$(snap)
run_lane prep $PREP
assert_eq "rollback: a signal during the add: stdout" failed "$out"
assert_eq "rollback: a signal during the add: nothing left" "$before" "$(snap)"
FX_PRE_SH=
export FX_PRE_SH

# ---- done ----------------------------------------------------------------------------------
# lane_ready: prep, then a commit on the lane's branch that "merged" (the canned PR row).
lane_ready() {
  nc
  prep_ok
  $real_git -C "$LD/$ISSUE" commit -q --allow-empty -m work
  TIP=$($real_git -C "$LD/$ISSUE" rev-parse HEAD)
  $real_git -C "$R" config "branch.$BR.remote" origin
  $real_git -C "$R" config "branch.$BR.merge" "refs/heads/$BR"
  pr_rows "$TIP"
}
pr_rows() { # <oid>
  cat >"$CAN/prs.json" <<EOF
[{"number":9,"headRefOid":"$1","isCrossRepository":false,"title":"$SENT"}]
EOF
}
lane_ready
run_lane done $ISSUE
assert_eq "done: exit" 0 "$rc"
assert_eq "done: the lines" "removed-worktree $LD/$ISSUE
deleted-branch $BR
removed-prompt $LD/$ISSUE-prompt.md
next none" "$out"
assert_eq "done: the worktree is gone" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
assert_eq "done: the branch is gone" gone "$($real_git -C "$R" rev-parse --verify -q "refs/heads/$BR" || echo gone)"
assert_eq "done: every branch.X.* key is gone" "" "$($real_git -C "$R" config --get-regexp '^branch\.feat/x\.' || :)"
assert_eq "done: the prompt file is gone" no "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"
assert_has "done: the exact pr list arguments" "$FX_GHLOG" "pr list --repo glunk-works/claude-workbench --base main --head $BR --state merged --json number,headRefOid,isCrossRepository --jq "

lane_ready
CWD="$R/dir"
run_lane done $ISSUE
assert_eq "done from a subdirectory: the first line" "removed-worktree $LD/$ISSUE" "$(printf '%s\n' "$out" | awk 'NR==1')"

lane_ready
rm -f "$LD/$ISSUE-prompt.md"
run_lane done $ISSUE
assert_eq "done: no prompt file" "removed-worktree $LD/$ISSUE
deleted-branch $BR
no-prompt
next none" "$out"

lane_ready
$real_git -C "$R" worktree add -q -f "$D/second" "$BR"
stop_case "done: checked out elsewhere (nothing removed)" 1 "kept $BR checked-out" done $ISSUE
assert_eq "done: checked out elsewhere: the branch survives" "$TIP" "$($real_git -C "$R" rev-parse "refs/heads/$BR")"
assert_eq "done: checked out elsewhere: the lane worktree stays" yes "$([ -d "$LD/$ISSUE" ] && echo yes || echo no)"

lane_ready
FX_PRE="-C $R worktree add -q -f $D/second $BR"
FX_PRE_ON=" worktree remove "
export FX_PRE FX_PRE_ON
run_lane done $ISSUE
assert_eq "done: checked out during the run: stdout" "kept $BR checked-out" "$out"
assert_eq "done: checked out during the run: the worktree is gone" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
assert_eq "done: checked out during the run: the branch survives" "$TIP" "$($real_git -C "$R" rev-parse "refs/heads/$BR")"
assert_eq "done: checked out during the run: the prompt file stays" yes "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"

lane_ready
$real_git -C "$LD/$ISSUE" commit -q --allow-empty -m ahead
stop_case "done: a local commit the merged head lacks" 1 "kept $BR skip-ahead" done $ISSUE
lane_ready
pr_rows deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
stop_case "done: an oid absent from origin" 1 "kept $BR skip-unfetchable" done $ISSUE
lane_ready
printf '[]\n' >"$CAN/prs.json"
stop_case "done: no merged PR" 1 not-merged done $ISSUE
lane_ready
cat >"$CAN/prs.json" <<EOF
[{"number":9,"headRefOid":"$TIP","isCrossRepository":true,"title":"$SENT"}]
EOF
stop_case "done: only a cross-repository PR" 1 not-merged done $ISSUE
lane_ready
cat >"$CAN/prs.json" <<EOF
[{"number":9,"headRefOid":"$TIP","isCrossRepository":false},{"number":10,"headRefOid":"$TIP","isCrossRepository":false}]
EOF
stop_case "done: two rows" 1 ambiguous done $ISSUE
lane_ready
pr_rows abc123
stop_case "done: a short oid" 1 unreadable done $ISSUE
lane_ready
FX_FAIL=prlist
stop_case "done: a failed gh" 1 unreadable done $ISSUE
nc
stop_case "done: an absent lane" 1 no-lane done $ISSUE
lane_ready
$real_git -C "$LD/$ISSUE" checkout -q --detach
stop_case "done: a detached lane" 1 no-lane done $ISSUE
lane_ready
$real_git -C "$LD/$ISSUE" checkout -q --ignore-other-worktrees main
stop_case "done: a lane switched to main" 1 no-lane done $ISSUE
lane_ready
rm -rf "${LD:?}/$ISSUE"
stop_case "done: a lane whose directory is gone" 1 missing done $ISSUE
lane_ready
: >"$LD/$ISSUE/untracked"
stop_case "done: a dirty worktree" 1 dirty done $ISSUE
assert_eq "done: dirty: the prompt file is still there" yes "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"

lane_ready
FX_PRE="-C $LD/$ISSUE commit -q --allow-empty -m late"
FX_PRE_ON=" worktree remove "
export FX_PRE FX_PRE_ON
run_lane done $ISSUE
assert_eq "done: a commit after the verdict: stdout" "kept $BR moved" "$out"
assert_eq "done: a commit after the verdict: exit" 1 "$rc"
assert_eq "done: moved: the branch survives with that commit" "late" "$($real_git -C "$R" log -1 --format=%s "refs/heads/$BR")"
assert_eq "done: moved: the worktree is gone" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
assert_eq "done: moved: the prompt file is still present" yes "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"

lane_ready
setyml '.identities = null'
stop_case "done: not-map removes nothing" 1 not-map done $ISSUE
lane_ready
setyml '.repo = "other/repo"'
stop_case "done: repo-mismatch removes nothing" 1 repo-mismatch done $ISSUE
lane_ready
setyml '.backlog.repo = "Glunk-Works/Claude-Workbench"'
stop_case "done: backlog-case removes nothing" 1 backlog-case done $ISSUE

# ---- drop ----------------------------------------------------------------------------------
# lane_fresh: prep only, no commit on the lane's branch and nothing pushed.
lane_fresh() {
  nc
  prep_ok
  $real_git -C "$R" config "branch.$BR.remote" origin
  $real_git -C "$R" config "branch.$BR.merge" "refs/heads/$BR"
}
refs_rows() { # <ref>...
  {
    printf '['
    sep=
    for rr in "$@"; do
      printf '%s{"ref":"%s","url":"%s","object":{"sha":"%s"}}' "$sep" "$rr" "$SENT" "$SENT"
      sep=,
    done
    printf ']\n'
  } >"$CAN/refs.json"
}
# the stub's paginated arm answers only a matching-refs path
stub_rc=0
stub_err=$(PATH="$FB:$PATH" "$FB/gh" api --paginate repos/glunk-works/claude-workbench/pulls --jq . 2>&1 >/dev/null) || stub_rc=$?
assert_eq "stub gh: another paginated call: exit" 1 "$stub_rc"
assert_eq "stub gh: another paginated call: message" "stub gh: unexpected: api --paginate repos/glunk-works/claude-workbench/pulls --jq ." "$stub_err"

lane_fresh
run_lane drop $ISSUE
assert_eq "drop: exit" 0 "$rc"
assert_eq "drop: the lines" "removed-worktree $LD/$ISSUE
deleted-branch $BR
removed-prompt $LD/$ISSUE-prompt.md
next none" "$out"
assert_eq "drop: the worktree is gone" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
assert_eq "drop: the branch is gone" gone "$($real_git -C "$R" rev-parse --verify -q "refs/heads/$BR" || echo gone)"
assert_eq "drop: every branch.X.* key is gone" "" "$($real_git -C "$R" config --get-regexp '^branch\.feat/x\.' || :)"
assert_eq "drop: the prompt file is gone" no "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"
assert_has "drop: the exact matching-refs arguments" "$FX_GHLOG" "api --paginate repos/glunk-works/claude-workbench/git/matching-refs/heads/$BR --jq "
assert_eq "drop: no PR list read" 0 "$(grep -c '^pr list' "$FX_GHLOG" || :)"

lane_fresh
rm -f "$LD/$ISSUE-prompt.md"
run_lane drop $ISSUE
assert_eq "drop: no prompt file" "removed-worktree $LD/$ISSUE
deleted-branch $BR
no-prompt
next none" "$out"

lane_fresh
refs_rows "refs/heads/$BR"
stop_case "drop: a pushed branch" 1 pushed drop $ISSUE
stop_case "drop: a pushed branch, with discard" 1 pushed drop $ISSUE discard
lane_fresh
refs_rows "refs/heads/$BR-two" "refs/heads/$BR/sub"
run_lane drop $ISSUE
assert_eq "drop: only longer refs with the branch as prefix: exit" 0 "$rc"
assert_eq "drop: only longer refs with the branch as prefix: first line" "removed-worktree $LD/$ISSUE" "$(printf '%s\n' "$out" | awk 'NR==1')"
lane_fresh
refs_rows "refs/heads/$BR-two" "refs/heads/$BR"
stop_case "drop: the exact row among longer ones" 1 pushed drop $ISSUE

lane_fresh
$real_git -C "$LD/$ISSUE" commit -q --allow-empty -m work
stop_case "drop: a commit beyond the base" 1 has-commits drop $ISSUE
stop_case "drop: a commit beyond the base, with discard" 1 has-commits drop $ISSUE discard
assert_eq "drop: has-commits: the prompt file is still there" yes "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"

lane_fresh
: >"$LD/$ISSUE/untracked"
stop_case "drop: a dirty worktree" 1 dirty drop $ISSUE
assert_eq "drop: dirty: the prompt file is still there" yes "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"
run_lane drop $ISSUE discard
assert_eq "drop discard: exit" 0 "$rc"
assert_eq "drop discard: the lines" "removed-worktree $LD/$ISSUE
deleted-branch $BR
removed-prompt $LD/$ISSUE-prompt.md
next none" "$out"
assert_eq "drop discard: the worktree is gone" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
lane_fresh
echo changed >"$LD/$ISSUE/dir/f"
run_lane drop $ISSUE discard
assert_eq "drop discard: a modified file: exit" 0 "$rc"

lane_fresh
echo changed >"$LD/$ISSUE/dir/f"
stop_case "drop: a modified tracked file" 1 dirty drop $ISSUE
assert_eq "drop: modified: the prompt file is still there" yes "$([ -e "$LD/$ISSUE-prompt.md" ] && echo yes || echo no)"

lane_fresh
$real_git -C "$R" worktree lock "$LD/$ISSUE"
stop_case "drop: a locked worktree, even with discard" 1 dirty drop $ISSUE discard

nc
stop_case "drop: an absent lane" 1 no-lane drop $ISSUE
lane_fresh
$real_git -C "$LD/$ISSUE" checkout -q --detach
stop_case "drop: a detached lane" 1 no-lane drop $ISSUE
lane_fresh
rm -rf "${LD:?}/$ISSUE"
stop_case "drop: a lane whose directory is gone" 1 missing drop $ISSUE
lane_fresh
FX_FAIL=refs
stop_case "drop: a failed matching-refs read" 1 unreadable drop $ISSUE
lane_fresh
FX_GIT_FAIL=" fetch -q origin +refs/heads/main:refs/remotes/origin/main"
stop_case "drop: a failed base fetch" 1 unreadable drop $ISSUE
FX_GIT_FAIL=
lane_fresh
FX_GIT_FAIL=" rev-list --count "
stop_case "drop: a failed commit count" 1 unreadable drop $ISSUE
FX_GIT_FAIL=
lane_fresh
setyml '.identities = null'
stop_case "drop: not-map removes nothing" 1 not-map drop $ISSUE
lane_fresh
setyml '.repo = "other/repo"'
stop_case "drop: repo-mismatch removes nothing" 1 repo-mismatch drop $ISSUE

nc
$real_git -C "$R" worktree add -q "$D/other2" -b other2
CWD="$D/other2"
stop_case "drop: from a linked worktree" 1 not-main drop $ISSUE

# ---- done, the next lines ------------------------------------------------------------------
TAB=$(printf '\t')
groups_two() {
  printf '800\tfound\tp/a\t-\t-\n801\tfound\tp/b\t#800\t-\n802\tfound\tp/c\t-\t-\ngroup\t1\t#800 #802\ngroup\t2\t#801\n' >"$CAN/groups.txt"
}
live_800() { printf '[{"issue":800,"branch":"feat/x-800","worktree":"%s/800","spec":"none","pr":null}]\n' "$LD" >"$CAN/state.json"; }
lane_ready
live_800
groups_two
run_lane done $ISSUE
assert_eq "done next: a live lane and an issue sharing its path are dropped" "removed-worktree $LD/$ISSUE
deleted-branch $BR
removed-prompt $LD/$ISSUE-prompt.md
next 1 #802" "$out"
assert_eq "done next: exit" 0 "$rc"
lane_ready
printf '800\tfound\tp/a\t-\t-\ngroup\t1\t#800\n' >"$CAN/groups.txt"
live_800
run_lane done $ISSUE
assert_eq "done next: every issue dropped is next none" "next none" "$(printf '%s\n' "$out" | tail -n 1)"
lane_ready
printf '800\tstale\tp/a\t-\t-\ngroup none\n' >"$CAN/groups.txt"
run_lane done $ISSUE
assert_eq "done next: a stale row then group none is next none" "next none" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "done next: a stale row then group none: exit" 0 "$rc"
lane_ready
canon '.milestone = null'
groups_two
run_lane done $ISSUE
assert_eq "done next: no milestone is next none" "next none" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "done next: no milestone: exit" 0 "$rc"
lane_ready
FX_FAIL=issue
run_lane done $ISSUE
assert_eq "done next: a failed milestone read" "next unreadable" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "done next: a failed milestone read: exit" 0 "$rc"
FX_FAIL=
for bad in 'unreadable' 'garbage line' '800\tfound\tp/a\t-\t-' 'group\t1\t#800 evil' 'group\tnone' ''; do
  lane_ready
  printf "$bad\n" >"$CAN/groups.txt"
  run_lane done $ISSUE
  assert_eq "done next: lane-groups printing [$bad]" "next unreadable" "$(printf '%s\n' "$out" | tail -n 1)"
  assert_eq "done next: lane-groups printing [$bad]: exit" 0 "$rc"
  assert_eq "done next: lane-groups printing [$bad]: the lane is still removed" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
done
lane_ready
FX_GROUPS_RC=2
: >"$CAN/groups.txt"
export FX_GROUPS_RC
run_lane done $ISSUE
assert_eq "done next: lane-groups exiting 2 with nothing" "next unreadable" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "done next: lane-groups exiting 2: exit" 0 "$rc"
FX_GROUPS_RC=0
export FX_GROUPS_RC

# a trailing live-unknown line: one caution line per named issue, after the next lines
lane_ready
printf '800\tfound\tp/a\t-\t-\ngroup\t1\t#800\nlive-unknown\t#900\n' >"$CAN/groups.txt"
run_lane done $ISSUE
assert_eq "done next: live-unknown: the next lines, then the caution line" "removed-worktree $LD/$ISSUE
deleted-branch $BR
removed-prompt $LD/$ISSUE-prompt.md
next 1 #800
next caution: live lane #900 paths unknown" "$out"
assert_eq "done next: live-unknown: exit" 0 "$rc"
lane_ready
printf '800\tfound\tp/a\t-\t-\ngroup\t1\t#800\nlive-unknown\t#800\n' >"$CAN/groups.txt"
live_800
run_lane done $ISSUE
assert_eq "done next: every candidate dropped: next none, then the caution line" "next none
next caution: live lane #800 paths unknown" "$(printf '%s\n' "$out" | tail -n 2)"
lane_ready
printf '800\tfound\tp/a\t-\t-\ngroup none\nlive-unknown\t#900,#901\n' >"$CAN/groups.txt"
run_lane done $ISSUE
assert_eq "done next: two named issues: two caution lines in order" "next none
next caution: live lane #900 paths unknown
next caution: live lane #901 paths unknown" "$(printf '%s\n' "$out" | tail -n 3)"
for bad in 'live-unknown\t#1 #2' 'live-unknown\t#x' 'live-unknown\t#1\textra' 'live-unknown\t' 'live-unknown\t#1,' 'live-unknown #1'; do
  lane_ready
  printf "800\tfound\tp/a\t-\t-\ngroup\t1\t#800\n$bad\n" >"$CAN/groups.txt"
  run_lane done $ISSUE
  assert_eq "done next: malformed [$bad]: next unreadable" "next unreadable" "$(printf '%s\n' "$out" | tail -n 1)"
  assert_eq "done next: malformed [$bad]: no caution line" 0 "$(printf '%s\n' "$out" | grep -c '^next caution')"
  assert_eq "done next: malformed [$bad]: exit" 0 "$rc"
  assert_eq "done next: malformed [$bad]: the lane is still removed" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
done

# a live lane on another milestone: lane-state.sh lists it, lane-groups.sh gets it as an argument
lane_ready
printf '[{"issue":900,"branch":"feat/y-900","worktree":"%s/900","spec":"none","pr":null}]\n' "$LD" >"$CAN/state.json"
printf '800\tfound\tp/a\t#900\t-\n801\tfound\tp/b\t-\t-\ngroup\t1\t#800 #801\n' >"$CAN/groups.txt"
run_lane done $ISSUE
assert_eq "done next: a row sharing a path with a live lane on another milestone is dropped" "next 1 #801" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "done next: another milestone: exit" 0 "$rc"
assert_eq "done next: lane-groups gets the milestone first and the live issue from the third argument" "19 900" "$(sed -e 's/^\([0-9]*\) [^ ]* /\1 /' "$CAN/groups.args")"
lane_ready
printf '[{"issue":800,"branch":"feat/x-800","worktree":"%s/800","spec":"none","pr":null},{"issue":900,"branch":"feat/y-900","worktree":"%s/900","spec":"none","pr":null}]\n' "$LD" "$LD" >"$CAN/state.json"
groups_two
run_lane done $ISSUE
assert_eq "done next: two live lanes reach lane-groups as two arguments" "19 800 900" "$(sed -e 's/^\([0-9]*\) [^ ]* /\1 /' "$CAN/groups.args")"
# a directory lane-state.sh does not list is not a live lane
lane_ready
mkdir "$LD/800"
groups_two
run_lane done $ISSUE
assert_eq "done next: an unlisted directory is not dropped" "next 1 #800 #802
next 2 #801" "$(printf '%s\n' "$out" | tail -n 2)"
assert_eq "done next: an unlisted directory: no live argument" "19" "$(sed -e 's/^\([0-9]*\) .*/\1/' "$CAN/groups.args")"
for bad in 'unreadable' '[{"issue":"0800","branch":"feat/x-800","worktree":"w","spec":"none","pr":null}]' '[{"branch":"feat/x"}]' '{"issue":800}'; do
  lane_ready
  printf '%s\n' "$bad" >"$CAN/state.json"
  groups_two
  run_lane done $ISSUE
  assert_eq "done next: lane-state printing [$bad]" "next unreadable" "$(printf '%s\n' "$out" | tail -n 1)"
  assert_eq "done next: lane-state printing [$bad]: exit" 0 "$rc"
  assert_eq "done next: lane-state printing [$bad]: the lane is still removed" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
done
lane_ready
printf '[]\n' >"$CAN/state.json"
FX_STATE_RC=1
export FX_STATE_RC
groups_two
run_lane done $ISSUE
assert_eq "done next: lane-state exiting non-zero" "next unreadable" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "done next: lane-state exiting non-zero: exit" 0 "$rc"
assert_eq "done next: lane-state exiting non-zero: the lane is still removed" no "$([ -e "$LD/$ISSUE" ] && echo yes || echo no)"
FX_STATE_RC=0
export FX_STATE_RC
printf '[]\n' >"$CAN/state.json"

# The contract case (#1294): the REAL lane-groups.sh's output for a milestone with no ready issue,
# fed unchanged to `done`. The no-group line is never typed here, so a change to it on either side
# turns the `next none` assertion red. The producer runs as a copy beside stub spec-find.sh (always
# `none`) and the real plan-depends.sh and spec-fresh.sh, with a stub gh first on PATH for this run only.
lane_ready
LGB=$D/lgbin
LGS=$D/lgstub
mkdir -p "$LGB" "$LGS"
for s in lane-groups.sh plan-depends.sh spec-fresh.sh; do
  cp "$root_dir/plugins/way-of-working/bin/$s" "$LGB/$s"
done
printf '#!/bin/sh\necho none\n' >"$LGB/spec-find.sh"
chmod 755 "$LGB"/*.sh
LGREPO=$(yq -r .repo "$R/.ai/project.yml")
printf 'repo: %s\nbacklog:\n  repo: null\n' "$LGREPO" >"$LGS/project.yml"
printf '[{"number":800},{"number":9999,"pull_request":{}}]\n' >"$LGS/list.json"
printf '{"description":"no build order here"}\n' >"$LGS/ms.json"
cat >"$LGS/gh" <<'LG_GH'
#!/bin/sh
[ "$1" = api ] || exit 9
shift
url=; jqf=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --paginate) shift ;;
    --jq) jqf=$2; shift 2 ;;
    *) url=$1; shift ;;
  esac
done
case "$url" in
  "repos/$LG_REPO/issues?milestone=$LG_MS&state=open") f=$LG_DIR/list.json ;;
  "repos/$LG_REPO/milestones/$LG_MS") f=$LG_DIR/ms.json ;;
  *) exit 9 ;;
esac
exec jq -r "$jqf" "$f"
LG_GH
chmod 755 "$LGS/gh"
lg_rc=0
(cd "$R" && PATH="$LGS:$PATH" LG_REPO=$LGREPO LG_MS=$MS LG_DIR=$LGS "$LGB/lane-groups.sh" $MS "$LGS/project.yml") >"$LGS/real.txt" 2>/dev/null || lg_rc=$?
assert_eq "done next contract: the real lane-groups.sh exits 0" 0 "$lg_rc"
assert_eq "done next contract: the real lane-groups.sh's first row is issue 800" 800 "$(awk -F'\t' 'NR==1 {print $1}' "$LGS/real.txt")"
cp "$LGS/real.txt" "$CAN/groups.txt"
run_lane done $ISSUE
assert_eq "done next contract: the real no-group output is next none" "next none" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "done next contract: exit" 0 "$rc"

# ---- groups --------------------------------------------------------------------------------
for v in '' 0 012 abc; do
  nc
  argcase "groups M [$v]" groups "$v"
done
nc
argcase "groups M newline" groups "$(nl 7 8)"
argcase "groups without M" groups
argcase "groups with two arguments" groups $MS 2
nc
groups_two
run_lane groups $MS
assert_eq "groups: the rows and groups verbatim, then live none" "800	found	p/a	-	-
801	found	p/b	#800	-
802	found	p/c	-	-
group	1	#800 #802
group	2	#801
live none" "$out"
assert_eq "groups: exit" 0 "$rc"
assert_eq "groups: lane-groups gets the milestone and no live issue" "$MS 2" "$(awk '{print $1, NF}' "$CAN/groups.args")"
nc
printf 'group none\n' >"$CAN/groups.txt"
run_lane groups $MS
assert_eq "groups: group none succeeds" "group none
live none" "$out"
assert_eq "groups: group none: exit" 0 "$rc"
nc
mkdir -m 700 "$LD"
printf '[{"issue":900,"branch":"feat/y-900","worktree":"%s/900","spec":"none","pr":null},{"issue":800,"branch":"feat/x-800","worktree":"%s/800","spec":"none","pr":null}]\n' "$LD" "$LD" >"$CAN/state.json"
groups_two
run_lane groups $MS
assert_eq "groups: live lanes print ascending after the groups" "live #800 #900" "$(printf '%s\n' "$out" | tail -n 1)"
assert_eq "groups: live lanes: exit" 0 "$rc"
assert_eq "groups: live lanes are arguments after the milestone and the file" "$MS 800 900" "$(sed -e 's/^\([0-9]*\) [^ ]* /\1 /' "$CAN/groups.args")"
assert_eq "groups: no group is dropped for a live lane" 2 "$(printf '%s\n' "$out" | grep -c '^group')"
nc
mkdir -m 700 "$LD"
groups_two
printf '[]\n' >"$CAN/state.json"
run_lane groups $MS
assert_eq "groups: an empty live list" "live none" "$(printf '%s\n' "$out" | tail -n 1)"
nc
printf '800\tfound\tp/a\t-\t-\ngroup\t1\t#800\nlive-unknown\t#900,#901\n' >"$CAN/groups.txt"
run_lane groups $MS
assert_eq "groups: a live-unknown line is printed verbatim before live none" "800	found	p/a	-	-
group	1	#800
live-unknown	#900,#901
live none" "$out"
assert_eq "groups: live-unknown: exit" 0 "$rc"
for bad in 'live-unknown\t#1 #2' 'live-unknown\t#x' 'live-unknown\t#1\textra' 'live-unknown\t' 'live-unknown #1'; do
  nc
  printf "group none\n$bad\n" >"$CAN/groups.txt"
  stop_case "groups: malformed [$bad]" 1 unreadable groups $MS
done
for bad in 'unreadable' 'garbage line' '800\tfound\tp/a\t-\t-' 'group\t1\t#800 evil' 'group\tnone' ''; do
  nc
  printf "$bad\n" >"$CAN/groups.txt"
  stop_case "groups: lane-groups printing [$bad]" 1 unreadable groups $MS
done
nc
FX_GROUPS_RC=2
: >"$CAN/groups.txt"
export FX_GROUPS_RC
stop_case "groups: lane-groups exiting 2" 1 unreadable groups $MS
nc
FX_GROUPS_RC=1
export FX_GROUPS_RC
printf 'group none\n' >"$CAN/groups.txt"
stop_case "groups: lane-groups exiting non-zero after a good line" 1 unreadable groups $MS
FX_GROUPS_RC=0
export FX_GROUPS_RC
for bad in 'unreadable' '[{"issue":"0800","branch":"feat/x-800","worktree":"w","spec":"none","pr":null}]' '[{"branch":"feat/x"}]' '{"issue":800}'; do
  nc
  mkdir -m 700 "$LD"
  printf '%s\n' "$bad" >"$CAN/state.json"
  groups_two
  stop_case "groups: lane-state printing [$bad]" 1 unreadable groups $MS
done
nc
mkdir -m 700 "$LD"
printf '[]\n' >"$CAN/state.json"
FX_STATE_RC=1
export FX_STATE_RC
groups_two
stop_case "groups: lane-state exiting non-zero" 1 unreadable groups $MS
FX_STATE_RC=0
export FX_STATE_RC
printf '[]\n' >"$CAN/state.json"
nc
mkdir "$D/real"
ln -s "$D/real" "$LD"
groups_two
stop_case "groups: LANES is a symbolic link" 1 unsafe-dir groups $MS
nc
setyml '.identities = null'
stop_case "groups: not-map" 1 not-map groups $MS
nc
setyml '.lanes = null'
stop_case "groups: no-lanes" 1 no-lanes groups $MS
nc
$real_git -C "$R" worktree add -q "$D/other" -b other
CWD="$D/other"
stop_case "groups: not-main from a linked worktree" 1 not-main groups $MS

# ---- status --------------------------------------------------------------------------------
nc
stop_case "status: no lanes directory" 0 none status
nc
mkdir -m 700 "$LD"
stop_case "status: an empty lanes directory" 0 none status
state3() {
  cat >"$CAN/state.json" <<EOF
[{"issue":10,"branch":"feat/a","worktree":"$LD/10","spec":{"id":5,"updated_at":"2026-10-18T00:00:00Z"},"pr":{"number":21,"state":"OPEN"},"note":"$SENT"},{"issue":11,"branch":"fix/b","worktree":"$LD/11","spec":"none","pr":null},{"issue":12,"branch":"docs/c","worktree":"$LD/12","spec":"unreacted","pr":{"number":22,"state":"MERGED"}},{"issue":13,"branch":"chore/d","worktree":"$LD/13","spec":"found","pr":"ambiguous"}]
EOF
}
nc
mkdir -m 700 "$LD"
state3
before=$(snap)
run_lane status
assert_eq "status: exit" 0 "$rc"
assert_eq "status: the rows" "glunk-works/claude-workbench${TAB}glunk-works/claude-workbench#10${TAB}feat/a${TAB}#21 OPEN${TAB}none${TAB}found
glunk-works/claude-workbench${TAB}glunk-works/claude-workbench#11${TAB}fix/b${TAB}-${TAB}-${TAB}none
glunk-works/claude-workbench${TAB}glunk-works/claude-workbench#12${TAB}docs/c${TAB}#22 MERGED${TAB}-${TAB}unreacted
glunk-works/claude-workbench${TAB}glunk-works/claude-workbench#13${TAB}chore/d${TAB}ambiguous${TAB}-${TAB}found" "$out"
assert_eq "status: writes nothing" "$before" "$(snap)"
assert_has "status: only the open PR's checks are read" "$FX_GHLOG" "pr view 21 --repo glunk-works/claude-workbench --json statusCheckRollup --jq "
assert_eq "status: one pr view" 1 "$(grep -c '^pr view' "$FX_GHLOG")"
nc
state3
setyml '.backlog.repo = "glunk-works/backlog"'
mkdir -m 700 "$LD"
run_lane status
assert_eq "status: the backlog repo and number in the task column" "glunk-works/claude-workbench${TAB}glunk-works/backlog#10" "$(printf '%s\n' "$out" | awk -F'\t' 'NR==1 {print $1 "\t" $2}')"
check_case() { # <desc> <want> <rollup JSON array>
  nc
  mkdir -m 700 "$LD"
  state3
  printf '{"statusCheckRollup":%s,"title":"%s"}\n' "$3" "$SENT" >"$CAN/prview.json"
  run_lane status
  assert_eq "status checks: $1" "$2" "$(printf '%s\n' "$out" | awk -F'\t' 'NR==1 {print $5}')"
}
check_case "an empty rollup" none '[]'
check_case "all success" pass '[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"StatusContext","state":"SUCCESS"},{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SKIPPED"},{"__typename":"CheckRun","status":"COMPLETED","conclusion":"NEUTRAL"}]'
check_case "a failed run" fail '[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"FAILURE"},{"__typename":"CheckRun","status":"IN_PROGRESS","conclusion":""}]'
check_case "a cancelled run" fail '[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"CANCELLED"}]'
check_case "a failed status context" fail '[{"__typename":"StatusContext","state":"FAILURE"}]'
check_case "an error status context" fail '[{"__typename":"StatusContext","state":"ERROR"}]'
check_case "a run in progress" pending '[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"CheckRun","status":"IN_PROGRESS","conclusion":""}]'
check_case "a queued run" pending '[{"__typename":"CheckRun","status":"QUEUED","conclusion":""}]'
check_case "a pending status context" pending '[{"__typename":"StatusContext","state":"PENDING"}]'
check_case "an expected status context" pending '[{"__typename":"StatusContext","state":"EXPECTED"}]'
nc
mkdir -m 700 "$LD"
state3
FX_FAIL=prview
run_lane status
assert_eq "status: a failed pr view is unreadable for that row only" "unreadable" "$(printf '%s\n' "$out" | awk -F'\t' 'NR==1 {print $5}')"
assert_eq "status: a failed pr view: the other rows print" 4 "$(printf '%s\n' "$out" | awk 'END {print NR}')"
assert_eq "status: a failed pr view: exit" 0 "$rc"
nc
mkdir -m 700 "$LD"
printf 'unreadable\n' >"$CAN/state.json"
stop_case "status: lane-state.sh printing unreadable" 1 unreadable status
nc
mkdir -m 700 "$LD"
FX_STATE_RC=2
: >"$CAN/state.json"
export FX_STATE_RC
stop_case "status: lane-state.sh exiting 2" 1 unreadable status
FX_STATE_RC=0
export FX_STATE_RC
nc
mkdir -m 700 "$LD"
printf '[{"issue":10,"branch":"bad branch","worktree":"x","spec":"none","pr":null}]\n' >"$CAN/state.json"
stop_case "status: a branch outside the shape" 1 unreadable status
nc
mkdir "$D/real"
ln -s "$D/real" "$LD"
stop_case "status: LANES is a symbolic link" 1 unsafe-dir status
nc
$real_git -C "$R" worktree add -q "$D/other" -b other
CWD="$D/other"
stop_case "status: not-main from a linked worktree" 1 not-main status

# ---- wait ----------------------------------------------------------------------------------
HS=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
HB=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
RID=3001
T0=2026-11-14T09:00:00Z
T1=2026-11-14T10:00:00Z
T2=2026-11-14T10:05:00Z
jarr() { # <file> <objects...>: a JSON array
  jf=$1
  shift
  {
    printf '['
    jsep=
    for jo in "$@"; do printf '%s%s' "$jsep" "$jo"; jsep=,; done
    printf ']\n'
  } >"$jf"
}
jwrap() { # <file> <key> <objects...>: {"key":[objects]}
  jwf=$1 jwk=$2
  shift 2
  jarr "$CAN/jw.tmp" "$@"
  printf '{"%s":%s}\n' "$jwk" "$(cat "$CAN/jw.tmp")" >"$jwf"
}
pullj() { # <file> <state> <merged> <sha> [repo]
  printf '{"state":"%s","merged":%s,"head":{"sha":"%s","repo":{"full_name":"%s"}},"title":"%s"}\n' "$2" "$3" "$4" "${5:-glunk-works/claude-workbench}" "$SENT" >"$1"
}
rv() { # <user id> <commit_id json> <state> <submitted_at json>
  printf '{"user":{"id":%s,"login":"%s"},"commit_id":%s,"state":"%s","submitted_at":%s,"body":"%s"}' "$1" "$SENT" "$2" "$3" "$4" "$SENT"
}
gst() { # <state> <created_at json> [context]
  printf '{"context":"%s","state":"%s","created_at":%s,"description":"%s"}' "${3:-architect-review}" "$1" "$2" "$SENT"
}
gcr() { # <status> <conclusion json> <started_at json> [name]
  printf '{"name":"%s","status":"%s","conclusion":%s,"started_at":%s,"output":{"title":"%s"}}' "${4:-architect-review}" "$1" "$2" "$3" "$SENT"
}
GOODREV=$(rv $RID "\"$HS\"" APPROVED "\"$T1\"")
# wait_ready: a lane with a reviewer App and a gate declared on the default branch, an open PR #9
# on HS, a review by the reviewer App on HS, and a gate success posted after it.
wait_ready() {
  nc
  setyml '.identities.reviewer_app = {"login": "r", "id": 3001} | .review.ci_gate.check = "architect-review"'
  prep_ok
  jarr "$CAN/prs.json" '{"number":9,"isCrossRepository":false,"title":"'"$SENT"'"}'
  pullj "$CAN/pull.json" open false $HS
  jarr "$CAN/reviews.json" "$GOODREV"
  jwrap "$CAN/status.json" statuses "$(gst success "\"$T2\"")"
  jwrap "$CAN/checks.json" check_runs
}
wait_case() { # <desc> <rc> <stdout> <sleeplog>
  : >"$FX_SLEEPLOG"
  run_lane wait $ISSUE
  assert_eq "wait $1: exit" "$2" "$rc"
  assert_eq "wait $1: stdout" "$3" "$out"
  assert_eq "wait $1: sleeps" "$4" "$(cat "$FX_SLEEPLOG")"
}
nsleeps() { # <n> <seconds>: n lines of `sleep <seconds>`
  i=0
  while [ "$i" -lt "$1" ]; do
    [ "$i" -eq 0 ] || printf '\n'
    printf 'sleep %s' "$2"
    i=$((i + 1))
  done
}

wait_ready
jarr "$CAN/prs.1.json"
jarr "$CAN/reviews.1.json"
wait_case "review on the head, then gate success after it" 0 "reviewed #9 $HS success" "sleep 120
sleep 90"
assert_has "wait: the pr list arguments" "$FX_GHLOG" "pr list --repo glunk-works/claude-workbench --base main --head $BR --state open --json number,isCrossRepository --jq "

wait_ready
wait_case "an immediate answer sleeps not at all" 0 "reviewed #9 $HS success" ""

wait_ready
jwrap "$CAN/status.1.json" statuses "$(gst failure "\"$T0\"")"
wait_case "a stale gate failure before the review does not end the wait" 0 "reviewed #9 $HS success" "sleep 90"

wait_ready
jwrap "$CAN/status.json" statuses "$(gst failure "\"$T2\"")"
wait_case "a gate failure after the review" 0 "reviewed #9 $HS failure" ""

wait_ready
jwrap "$CAN/status.json" statuses "$(gst failure "\"$T2\"")"
for k in 1 2 3; do jwrap "$CAN/checks.$k.json" check_runs "$(gcr queued '""' null)"; done
wait_case "a check-run with a null started_at is pending, not a failed read" 0 "reviewed #9 $HS failure" "$(nsleeps 3 90)"

wait_ready
jwrap "$CAN/status.json" statuses "$(gst failure "\"$T2\"")"
jwrap "$CAN/checks.json" check_runs "$(gcr queued '""' null)"
wait_case "a check-run with a null started_at never lets a failure end it" 1 "timeout #9" "$(nsleeps 119 90)"

wait_ready
H0A=0e11111111111111111111111111111111111111
H0B=0e22222222222222222222222222222222222222
pullj "$CAN/pull.json" open false $H0A
jarr "$CAN/reviews.1.json" "$(rv 4242 "\"$H0A\"" APPROVED "\"$T1\"")" "$(rv $RID "\"$HB\"" APPROVED "\"$T1\"")" "$(rv $RID "\"$H0B\"" APPROVED "\"$T1\"")" "$(rv $RID "\"$H0A\"" PENDING null)"
jarr "$CAN/reviews.json" "$(rv $RID "\"$H0A\"" APPROVED "\"$T1\"")"
wait_case "another user, an older head, a numerically equal sha and a pending review do not count" 0 "reviewed #9 $H0A success" "sleep 90"

wait_ready
jarr "$CAN/reviews.1.json" "$(rv $RID "\"$HS\"" DISMISSED "\"$T1\"")"
wait_case "a dismissed reviewer-App review on the head does not end the wait" 0 "reviewed #9 $HS success" "sleep 90"

wait_ready
jarr "$CAN/reviews.json" "$(rv 4242 null COMMENTED null)" "$(rv 4242 "\"$HS\"" COMMENTED null)" "$(rv $RID null COMMENTED "\"$T1\"")" "$GOODREV"
wait_case "null fields in rows that are not used are ignored" 0 "reviewed #9 $HS success" ""

wait_ready
pullj "$CAN/pull.1.json" open false $HS
pullj "$CAN/pull.2.json" open false $HB
pullj "$CAN/pull.json" open false $HB
jarr "$CAN/reviews.1.json"
jarr "$CAN/reviews.2.json" "$GOODREV"
jarr "$CAN/reviews.json" "$GOODREV" "$(rv $RID "\"$HB\"" APPROVED "\"$T1\"")"
wait_case "a new head keeps it waiting for a review on that head" 0 "reviewed #9 $HB success" "$(nsleeps 2 90)"

wait_ready
pullj "$CAN/pull.json" closed true $HS
wait_case "a merged PR" 0 "merged #9" ""
wait_ready
pullj "$CAN/pull.json" closed false $HS
wait_case "a closed PR" 0 "closed #9" ""
wait_ready
pullj "$CAN/pull.json" closed true $HS glunk-works/other
wait_case "a head repository that is not this one is a failed read" 1 unreadable "$(nsleeps 2 90)"

wait_ready
jarr "$CAN/prs.json"
wait_case "no PR within 120 polls" 1 no-pr "$(nsleeps 119 120)"
wait_ready
jarr "$CAN/prs.json" '{"number":9,"isCrossRepository":true}'
wait_case "only a cross-repository PR" 1 no-pr "$(nsleeps 119 120)"
wait_ready
jarr "$CAN/reviews.json"
wait_case "no review within 120 polls" 1 "timeout #9" "$(nsleeps 119 90)"
wait_ready
jarr "$CAN/prs.json" '{"number":9,"isCrossRepository":false}' '{"number":10,"isCrossRepository":false}'
wait_case "two open same-repository PRs" 1 ambiguous ""

wait_ready
for k in 1 2 3; do : >"$CAN/pull.$k.fail"; done
wait_case "three failed reads in a row" 1 unreadable "$(nsleeps 2 90)"
wait_ready
: >"$CAN/pull.1.fail"
: >"$CAN/pull.3.fail"
: >"$CAN/pull.5.fail"
jarr "$CAN/reviews.1.json"
jarr "$CAN/reviews.2.json"
wait_case "a failure then a successful poll resets the count" 0 "reviewed #9 $HS success" "$(nsleeps 5 90)"
wait_ready
: >"$CAN/prs.1.fail"
: >"$CAN/prs.2.fail"
: >"$CAN/prs.3.fail"
wait_case "three failed PR lists in a row" 1 unreadable "$(nsleeps 2 120)"

wait_ready
jwrap "$CAN/status.json" statuses "$(gst success '"2026-11-14 10:05"')"
wait_case "a gate status whose time is malformed" 1 unreadable "$(nsleeps 2 90)"
wait_ready
jwrap "$CAN/checks.json" check_runs "$(gcr completed '"success"' '"yesterday"')"
wait_case "a gate check-run whose time is malformed" 1 unreadable "$(nsleeps 2 90)"
wait_ready
jarr "$CAN/reviews.json" "$(rv $RID "\"$HS\"" APPROVED '"10:00"')"
wait_case "a used review whose time is malformed" 1 unreadable "$(nsleeps 2 90)"
wait_ready
jwrap "$CAN/status.json" statuses "$(gst failure '"nonsense"' other-context)" "$(gst success "\"$T2\"")"
wait_case "a malformed time on another context is ignored" 0 "reviewed #9 $HS success" ""
wait_ready
jwrap "$CAN/status.json" statuses "$(gst success "\"$T2\"" other-context)"
wait_case "a status of another context does not make the gate" 1 "timeout #9" "$(nsleeps 119 90)"

wait_ready
yq -i '.identities.reviewer_app = null' "$R/.ai/project.yml"
bump
wait_case "reviewer_app null" 1 no-gate ""
assert_eq "wait: no-gate polls nothing" 0 "$(grep -c 'pr list' "$FX_GHLOG" || :)"
wait_ready
yq -i '.identities.reviewer_app = {"login": "d", "id": 2001}' "$R/.ai/project.yml"
bump
wait_case "reviewer_app with the dev App's id" 1 no-gate ""
assert_eq "wait: the dev App's id polls nothing" 0 "$(grep -c 'pr list' "$FX_GHLOG" || :)"
wait_ready
yq -i '.review.ci_gate = null' "$R/.ai/project.yml"
bump
wait_case "ci_gate null" 1 no-gate ""
assert_eq "wait: ci_gate null polls nothing" 0 "$(grep -c 'pr list' "$FX_GHLOG" || :)"
wait_ready
yq -i '.review.ci_gate.check = ""' "$R/.ai/project.yml"
bump
wait_case "an empty gate name" 1 no-gate ""
nc
setyml '.identities.reviewer_app = {"login": "r", "id": 3001} | .review.ci_gate.check = "architect-review"'
stop_case "wait: no lane worktree" 1 no-lane wait $ISSUE
wait_ready
CWD="$D/other"
$real_git -C "$R" worktree add -q "$D/other" -b other
stop_case "wait: not-main from a linked worktree" 1 not-main wait $ISSUE

# ---- the sentinel --------------------------------------------------------------------------
if grep -F "$SENT" "$tmp/allout" >/dev/null; then
  echo "FAIL - the sentinel appears in some stdout or stderr" >&2
  fail=1
else
  echo "ok - the sentinel appears in no stdout or stderr"
fi

exit "$fail"
