#!/bin/sh
# Fixture tests for scripts/label-sync.sh and .github/workflows/label-sync.yml (#1566).
#
# The sync must never create a label it could not vouch for: an unreadable source fails
# closed with nothing on stdout, the script holds no network call or token, and the only
# workflow job that can write holds no checkout and runs no repo file. Fixtures are
# throwaway trees used as cwd, as the workflow runs them. The workflow's two `run: |` blocks
# are extracted and run under a stub `gh`.
#
# Permitted toolset: POSIX sh plus awk and grep. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/label-sync.sh"
titlechk="$root_dir/scripts/pr-title-check.sh"
wf="$root_dir/.github/workflows/label-sync.yml"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
n=0

ok() { echo "ok - $1"; }
bad() { echo "FAIL - $1" >&2; fail=1; }

# run_in DIR ARGS...: sets rc and out (stdout) and err (stderr)
run_in() {
  dir="$1"; shift
  n=$((n + 1))
  rc=0
  ( cd "$dir" && bash "$script" "$@" ) >"$tmp/out.$n" 2>"$tmp/err.$n" || rc=$?
  out="$(cat "$tmp/out.$n")"
}

# expect DESC STATUS DIR ARGS...: status checked; for status 1 and 2 stdout must be empty
expect() {
  desc="$1"; want="$2"; dir="$3"; shift 3
  run_in "$dir" "$@"
  if [ "$rc" != "$want" ]; then
    bad "$desc: expected exit [$want], got [$rc]"
  elif [ "$want" != 0 ] && [ -n "$out" ]; then
    bad "$desc: stdout not empty: $out"
  else
    ok "$desc"
  fi
}

# expect_out DESC EXPECTED: compares $out (from the last run_in) to EXPECTED
expect_out() {
  if [ "$out" = "$2" ]; then ok "$1"; else bad "$1: got [$out], want [$2]"; fi
}

mkfix() { # DIR: valid fixture with three areas and a list holding one entry twice
  mkdir -p "$1/.github"
  cat >"$1/CLAUDE.md" <<'MD'
# fixture

## Areas

Prose.

- `alpha` — `a/`
  - `nested` — not top-level
- `beta` — `b/`
- `gamma-2` — `c/`

## Other

- `delta` — not an area
MD
  cat >"$1/.github/labels.txt" <<'LST'
# a comment

type/bug
dependencies

type/bug
LST
}

fx="$tmp/fx"
mkfix "$fx"
printf 'area/alpha\narea/beta\narea/gamma-2\ndependencies\ntype/bug\n' >"$tmp/want-declared"

# --- declared ---------------------------------------------------------------
run_in "$fx" declared
expect_out "declared: sorted, unique, areas plus list entries" "$(cat "$tmp/want-declared")"
[ "$rc" = 0 ] || bad "declared exit [$rc]"

# parity with pr-title-check.sh
for a in alpha beta gamma-2; do
  if ( cd "$fx" && bash "$titlechk" "feat($a): x" ) >/dev/null 2>&1; then
    ok "parity: pr-title accepts $a"
  else bad "parity: pr-title refuses $a"; fi
done
if ( cd "$fx" && bash "$titlechk" "feat(delta): x" ) >/dev/null 2>&1; then
  bad "parity: pr-title accepts a scope not in the list"
else ok "parity: pr-title refuses a scope not in the list"; fi

# --- fail closed, for declared and plan -------------------------------------
printf 'type/bug\n' >"$tmp/valid-labels"
failcase() { # DESC SETUP-FUNCTION
  d="$tmp/fc.$n"; mkfix "$d"; $2 "$d"
  expect "$1 (declared)" 1 "$d" declared
  expect "$1 (plan)" 1 "$d" plan "$tmp/valid-labels"
}
f_noclaude() { rm "$1/CLAUDE.md"; }
f_noheading() { printf '# x\n\n- `alpha` - a\n' >"$1/CLAUDE.md"; }
f_prose() { printf '# x\n\n## Areas\n\nonly prose\n\n## Other\n' >"$1/CLAUDE.md"; }
f_badarea() { printf '# x\n\n## Areas\n\n- `Al_pha` - a\n' >"$1/CLAUDE.md"; }
f_hyphenarea() { printf '# x\n\n## Areas\n\n- `-alpha` - a\n' >"$1/CLAUDE.md"; }
f_nolist() { rm "$1/.github/labels.txt"; }
f_badentry() { printf 'Type/Bug\n' >"$1/.github/labels.txt"; }
f_hyphenentry() { printf -- '--force\n' >"$1/.github/labels.txt"; }
f_areaentry() { printf 'area/alpha\n' >"$1/.github/labels.txt"; }
f_spaceentry() { printf 'two words\n' >"$1/.github/labels.txt"; }
failcase "no CLAUDE.md" f_noclaude
failcase "no Areas heading" f_noheading
failcase "Areas heading with only prose" f_prose
failcase "area outside [a-z0-9-]" f_badarea
failcase "area starting with a hyphen" f_hyphenarea
failcase "no list file" f_nolist
failcase "malformed list entry" f_badentry
failcase "list entry starting with a hyphen" f_hyphenentry
failcase "area/ entry in the list" f_areaentry
failcase "list entry with a space" f_spaceentry

# comments and blank lines ignored
d="$tmp/cm"; mkfix "$d"; printf '#x\n\n#y\n' >"$d/.github/labels.txt"
run_in "$d" declared
expect_out "comments and blank lines in the list are ignored" "area/alpha
area/beta
area/gamma-2"

# --- plan -------------------------------------------------------------------
printf 'type/bug\ndependencies\narea/alpha\narea/beta\narea/gamma-2\n' >"$tmp/l-all"
run_in "$fx" plan "$tmp/l-all"
expect_out "plan: every declared label exists, nothing printed" ""
[ "$rc" = 0 ] || bad "plan exit [$rc]"

printf 'type/bug\narea/alpha\n' >"$tmp/l-missing"
run_in "$fx" plan "$tmp/l-missing"
expect_out "plan: missing declared labels print create" "create area/beta
create area/gamma-2
create dependencies"

printf 'type/bug\ndependencies\narea/alpha\narea/beta\narea/gamma-2\nwontfix\n' >"$tmp/l-extra"
run_in "$fx" plan "$tmp/l-extra"
expect_out "plan: an extra existing label prints undeclared" "undeclared wontfix"

printf 'type/bug\ndependencies\nArea/Alpha\narea/beta\narea/gamma-2\n' >"$tmp/l-case"
run_in "$fx" plan "$tmp/l-case"
expect_out "plan: a case-only difference prints case-mismatch with the declared spelling" "case-mismatch area/alpha"

printf 'type/bug\r\ndependencies\r\narea/alpha\r\narea/beta\r\narea/gamma-2\r\n' >"$tmp/l-cr"
run_in "$fx" plan "$tmp/l-cr"
expect_out "plan: a trailing CR is removed before matching" ""

printf 'type/bug\ndependencies\narea/alpha\narea/beta\narea/gamma-2\n::set-output x=\303\251\n' >"$tmp/l-unp"
run_in "$fx" plan "$tmp/l-unp"
expect_out "plan: an unprintable name prints undeclared-unprintable, not the name" "undeclared-unprintable"

printf 'type/bug\ndependencies\narea/alpha\narea/beta\narea/gamma-2\ncaf\303\251\n' >"$tmp/l-nonascii"
[ "$(wc -c <"$tmp/l-nonascii")" -eq 62 ] || bad "plan: non-ASCII fixture is not 62 bytes (printf wrote escape text, not bytes)"
run_in "$fx" plan "$tmp/l-nonascii"
expect_out "plan: a name unprintable only by non-ASCII bytes prints undeclared-unprintable" "undeclared-unprintable"

printf 'type/bug' >"$tmp/l-nonl"
run_in "$fx" plan "$tmp/l-nonl"
case "$out" in *"create type/bug"*) bad "plan: a last line without newline missed" ;; *) ok "plan: a last line without trailing newline is read" ;; esac

expect "plan: a missing FILE" 1 "$fx" plan "$tmp/nope"

# --- usage ------------------------------------------------------------------
expect "usage: no argument" 2 "$fx"
expect "usage: unknown subcommand" 2 "$fx" frobnicate
expect "usage: declared with an argument" 2 "$fx" declared x
expect "usage: plan with no FILE" 2 "$fx" plan
expect "usage: plan with two arguments" 2 "$fx" plan "$tmp/l-all" "$tmp/l-all"

# --- real tree --------------------------------------------------------------
run_in "$root_dir" declared
if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qx 'area/ci' && printf '%s\n' "$out" | grep -qx 'type/bug'; then
  ok "real tree: declared exits 0 and includes area/ci and type/bug"
else bad "real tree: declared rc=$rc"; fi

# --- workflow steps ---------------------------------------------------------
if [ ! -f "$wf" ]; then
  bad "workflow: .github/workflows/label-sync.yml is absent"
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
  extract_run plan >"$tmp/plan-step.sh"
  extract_run create >"$tmp/create-step.sh"
  [ -s "$tmp/plan-step.sh" ] && ok "workflow: plan step extracted" || bad "workflow: plan step not found"
  [ -s "$tmp/create-step.sh" ] && ok "workflow: create step extracted" || bad "workflow: create step not found"

  stubdir="$tmp/stub"; mkdir -p "$stubdir"
  cat >"$stubdir/gh" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_LOG"
[ -z "${STUB_FAIL:-}" ] || exit 1
if [ "${1:-}" = api ]; then cat "$STUB_LABELS"; fi
exit 0
STUB
  chmod +x "$stubdir/gh"

  # step_env: run a step script in dir D with the stub first on PATH. Sets rc.
  run_step() { # SCRIPT DIR [env...]
    s="$1"; d="$2"; shift 2
    : >"$tmp/gh.log"; : >"$tmp/gh-out"; : >"$tmp/gh-sum"
    rc=0
    ( cd "$d" && env PATH="$stubdir:$PATH" STUB_LOG="$tmp/gh.log" REPO=o/r GH_TOKEN=t \
        RUNNER_TEMP="$tmp/rt" GITHUB_OUTPUT="$tmp/gh-out" GITHUB_STEP_SUMMARY="$tmp/gh-sum" "$@" \
        bash "$s" ) >"$tmp/step.out" 2>"$tmp/step.err" || rc=$?
  }
  mkdir -p "$tmp/rt"
  px="$tmp/px"; mkfix "$px"; mkdir -p "$px/scripts"; cp "$script" "$px/scripts/label-sync.sh"

  run_step "$tmp/plan-step.sh" "$px" STUB_LABELS="$tmp/l-all"
  if [ "$rc" = 0 ] && [ -z "$(sed '/^PLAN_/d;/^plan<</d' "$tmp/gh-out")" ]; then ok "plan step: matching labels give an empty plan"; else bad "plan step: matching labels rc=$rc"; fi
  grep -q 'api' "$tmp/gh.log" && grep -q -- '--paginate' "$tmp/gh.log" && grep -q 'repos/o/r/labels' "$tmp/gh.log" \
    && ok "plan step: lists labels paginated for the repository" || bad "plan step: listing call: $(cat "$tmp/gh.log")"

  printf 'type/bug\narea/alpha\nArea/Beta\nwontfix\n' >"$tmp/l-mix"
  run_step "$tmp/plan-step.sh" "$px" STUB_LABELS="$tmp/l-mix"
  # declared labels come in sorted order, then the undeclared ones
  want="case-mismatch area/beta
create area/gamma-2
create dependencies
undeclared wontfix"
  got="$(awk '/^plan<</{d=substr($0,7);on=1;next} on&&$0==d{on=0;next} on' "$tmp/gh-out")"
  if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then ok "plan step: output is exactly the plan's lines"; else bad "plan step: rc=$rc output [$got]"; fi
  if grep -qx 'undeclared wontfix' "$tmp/gh-sum" && grep -qx 'case-mismatch area/beta' "$tmp/gh-sum" && ! grep -q '^create' "$tmp/gh-sum"; then
    ok "plan step: summary holds undeclared and case-mismatch lines only"
  else bad "plan step: summary [$(cat "$tmp/gh-sum")]"; fi

  run_step "$tmp/plan-step.sh" "$px" STUB_LABELS="$tmp/l-all" STUB_FAIL=1
  [ "$rc" != 0 ] && ok "plan step: a failing gh fails the step" || bad "plan step: failing gh passed"

  pn="$tmp/pn"; mkfix "$pn"; rm "$pn/.github/labels.txt"; mkdir -p "$pn/scripts"; cp "$script" "$pn/scripts/label-sync.sh"
  run_step "$tmp/plan-step.sh" "$pn" STUB_LABELS="$tmp/l-all"
  [ "$rc" != 0 ] && ok "plan step: a tree with no list file fails the step" || bad "plan step: no list file passed"

  # create step
  cr() { run_step "$tmp/create-step.sh" "$tmp" "PLAN=$1" "${2:-X=1}"; }
  cr ""
  [ "$rc" = 0 ] && [ ! -s "$tmp/gh.log" ] && ok "create step: an empty plan does nothing" || bad "create step: empty plan rc=$rc"
  cr "$(printf 'create area/x\ncreate type/y')"
  if [ "$rc" = 0 ] && [ "$(cat "$tmp/gh.log")" = "label create --repo o/r -- area/x
label create --repo o/r -- type/y" ]; then ok "create step: a last line without trailing newline is created"; else bad "create step: calls [$(cat "$tmp/gh.log")]"; fi
  cr "$(printf 'undeclared a\nundeclared-unprintable\ncase-mismatch b')"
  [ "$rc" = 0 ] && [ ! -s "$tmp/gh.log" ] && ok "create step: undeclared and case-mismatch lines make no call" || bad "create step: report lines rc=$rc"
  cr "frobnicate x"
  [ "$rc" != 0 ] && ok "create step: an unknown line fails" || bad "create step: unknown line passed"
  for badname in '--force' 'Area/x' 'two words' ''; do
    cr "create $badname"
    if [ "$rc" != 0 ] && [ ! -s "$tmp/gh.log" ]; then ok "create step: bad NAME [$badname] fails with no call"; else bad "create step: bad NAME [$badname] rc=$rc"; fi
  done
  cr "create area/x" STUB_FAIL=1
  [ "$rc" != 0 ] && ok "create step: a failing gh create fails the step" || bad "create step: failing create passed"

  # --- static checks --------------------------------------------------------
  if grep -nEv '^[[:space:]]*#' "$script" | grep -Ew 'gh|curl|wget|GH_TOKEN|GITHUB_TOKEN' >/dev/null; then
    bad "static: label-sync.sh names gh, curl, wget or a token outside comments"
  else ok "static: label-sync.sh has no gh, curl, wget or token name outside comments"; fi

  code="$(grep -v '^[[:space:]]*#' "$wf")"
  for pat in 'gh label delete' 'gh label edit' 'DELETE' 'PATCH' 'write-all'; do
    if printf '%s\n' "$code" | grep -q -- "$pat"; then bad "static: workflow contains [$pat]"; else ok "static: workflow lacks [$pat]"; fi
  done
  grep -q '^permissions: {}$' "$wf" && ok "static: top-level permissions are {}" || bad "static: top-level permissions"

  awk -v dir="$tmp" '
    /^jobs:/ { injobs = 1; next }
    injobs && /^  [a-z][a-z-]*:$/ { name = $1; sub(/:$/, "", name); f = dir "/job." name; next }
    injobs && f != "" { print >> f }
  ' "$wf"
  jobs="$(ls "$tmp"/job.* 2>/dev/null | wc -l | tr -d ' ')"
  [ "$jobs" = 2 ] && ok "static: exactly two job blocks" || bad "static: $jobs job blocks"
  writers=0; scripters=0
  for j in "$tmp"/job.*; do
    grep -q 'refs/heads/main' "$j" && ok "static: $(basename "$j") carries the main-ref condition" || bad "static: $(basename "$j") lacks the main-ref condition"
    if grep -q 'issues: write' "$j"; then
      writers=$((writers + 1))
      if grep -q 'actions/checkout' "$j" || grep -q 'scripts/' "$j"; then bad "static: the write job checks out or names scripts/"; else ok "static: the write job has no checkout and names no scripts/"; fi
    elif grep -q 'scripts/label-sync.sh' "$j"; then
      scripters=$((scripters + 1))
      if grep -v '^[[:space:]]*#' "$j" | grep -q 'write'; then bad "static: the script job holds a write"; else ok "static: the script job holds no write"; fi
    fi
  done
  [ "$writers" = 1 ] && ok "static: exactly one job holds issues: write" || bad "static: $writers write jobs"
  [ "$scripters" = 1 ] && ok "static: exactly one other job names scripts/label-sync.sh" || bad "static: $scripters script jobs"
fi

exit "$fail"
