#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/ruleset-drift.sh (#1211).
#
# Runs a COPY of the real script with a stub `gh` first on PATH. The stub maps each endpoint
# to a canned JSON file under $STUBS (the endpoint with / replaced by _), applies the caller's
# own --jq filter with jq, fails when the file is absent or `<name>.rc` exists, and logs the
# endpoints it was called with. The branch-rules read is paged by `<name>.1`, `<name>.2` files.
#
# Permitted toolset: POSIX sh plus sed -i, jq and yq (mikefarah v4); the suite skips, loudly, without jq or yq.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script_src="$root_dir/plugins/way-of-working/bin/ruleset-drift.sh"

for tool in jq yq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "skip - ruleset-drift.sh fixtures: no $tool on PATH" >&2
    exit 0
  fi
done

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

fail=0
assert_eq() {
  if [ "$2" = "$3" ]; then echo "ok - $1"; else
    echo "FAIL - $1: expected [$2], got [$3]" >&2; fail=1
  fi
}

STUBS="$tmp/stubs"; export STUBS
mkdir -p "$STUBS" "$tmp/bin" "$tmp/ghbin"
cp "$script_src" "$tmp/bin/ruleset-drift.sh"
chmod 755 "$tmp/bin/ruleset-drift.sh"

cat >"$tmp/ghbin/gh" <<'STUB'
#!/bin/sh
# gh api [--paginate] <endpoint> [--jq F]
shift
[ "${1:-}" != --paginate ] || shift
ep=$1; shift
printf '%s\n' "$ep" >>"$STUBS/gh.log"
k=$(printf '%s' "$ep" | tr / _)
[ ! -f "$STUBS/$k.rc" ] || exit 1
if [ -f "$STUBS/$k.1" ]; then
  i=1; while [ -f "$STUBS/$k.$i" ]; do cat "$STUBS/$k.$i"; i=$((i + 1)); done
  exit 0
fi
[ -f "$STUBS/$k" ] || exit 1
if [ "${1:-}" = --jq ]; then jq -r "$2" <"$STUBS/$k"; else cat "$STUBS/$k"; fi
STUB
chmod 755 "$tmp/ghbin/gh"

# A PATH with the real tools but no gh/jq/yq as asked: symlink each wanted tool into a dir.
mkpath() { # mkpath <dir> <tool>...
  d=$1; shift; mkdir -p "$d"
  for t in "$@"; do ln -sf "$(command -v "$t")" "$d/$t"; done
  for t in sh cat tr printf; do
    p=$(command -v "$t" 2>/dev/null || true); case "$p" in /*) ln -sf "$p" "$d/$t" ;; esac
  done
}
mkpath "$tmp/p-nogh" jq yq
mkpath "$tmp/p-nojq" yq; ln -sf "$tmp/ghbin/gh" "$tmp/p-nojq/gh"
mkpath "$tmp/p-noyq" jq; ln -sf "$tmp/ghbin/gh" "$tmp/p-noyq/gh"

reset() { rm -f "$STUBS"/* ; }
SHELL_BIN=$(command -v sh)
run() { # run <repo> <base> <yml> -> stdout
  PATH="$tmp/ghbin:$PATH" "$tmp/bin/ruleset-drift.sh" "$@" 2>/dev/null </dev/null || echo "exit=$?"
}
run_path() { # run_path <path> <repo> <base> <yml>
  _p=$1; shift
  PATH="$_p" "$SHELL_BIN" "$tmp/bin/ruleset-drift.sh" "$@" 2>/dev/null </dev/null || echo "exit=$?"
}

R=o/r; BASE=main
EP_B="repos_o_r_rules_branches_main"; EP_L="repos_o_r_rulesets"

# Branch rules: ruleset 1 = checks (pull_request none), ruleset 2 = approval.
rules_json() {
  cat <<'J'
[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test","integration_id":15368}]}},
 {"type":"deletion","ruleset_id":1},
 {"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]
J
}
list_json() { echo '[{"id":1,"name":"checks"},{"id":2,"name":"approval"}]'; }

yml="$tmp/p.yml"
list_yml() {
  cat >"$yml" <<'Y'
rulesets:
  - name: checks
    source: repo
    rule_types: [required_status_checks, deletion]
    required_checks: [lint, test]
  - name: approval
    source: repo
    rule_types: [pull_request]
Y
}
single_yml() { # single_yml <types-flow> [<checks-flow or ->]
  { echo "ruleset:"; echo "  name: checks"; echo "  rule_types: $1"
    [ "${2:--}" = - ] || echo "  required_checks: $2"; } >"$yml"
}
setup_ok() {
  reset; rules_json >"$STUBS/$EP_B"; list_json >"$STUBS/$EP_L"
  echo '{"bypass_actors":[]}' >"$STUBS/repos_o_r_rulesets_1"
  echo '{"bypass_actors":[]}' >"$STUBS/repos_o_r_rulesets_2"
}

# --- usage ---------------------------------------------------------------------------------
out=$("$tmp/bin/ruleset-drift.sh" a b 2>/dev/null) && rc=0 || rc=$?
assert_eq "a wrong argument count exits 2" "2" "$rc"

# --- list form -----------------------------------------------------------------------------
setup_ok; list_yml
assert_eq "list form healthy" \
"ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

# --- approval_params (#1405) ---------------------------------------------------------------
PRX='"type":"pull_request","ruleset_id":2'
APP_OK='"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1'
approval_line() { # approval_line <rule-json-object-without-braces> -> the approval ruleset's line
  setup_ok; list_yml
  printf '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{%s}]\n' "$1" >"$STUBS/$EP_B"
  run $R $BASE $yml | sed -n 2p
}
pfx="ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[]"
assert_eq "approval_params: all four at their values" "$pfx approval_params=[] wrong_pins=[] missing_refs=[]" "$(approval_line "$PRX,\"parameters\":{$APP_OK}")"
assert_eq "approval_params: code-owner review off" "$pfx approval_params=[require_code_owner_review] wrong_pins=[] missing_refs=[]" \
  "$(approval_line "$PRX,\"parameters\":{\"require_code_owner_review\":false,\"dismiss_stale_reviews_on_push\":true,\"require_last_push_approval\":true,\"required_approving_review_count\":1}")"
assert_eq "approval_params: stale-review dismissal off" "$pfx approval_params=[dismiss_stale_reviews_on_push] wrong_pins=[] missing_refs=[]" \
  "$(approval_line "$PRX,\"parameters\":{\"require_code_owner_review\":true,\"dismiss_stale_reviews_on_push\":false,\"require_last_push_approval\":true,\"required_approving_review_count\":1}")"
assert_eq "approval_params: last-push approval off" "$pfx approval_params=[require_last_push_approval] wrong_pins=[] missing_refs=[]" \
  "$(approval_line "$PRX,\"parameters\":{\"require_code_owner_review\":true,\"dismiss_stale_reviews_on_push\":true,\"require_last_push_approval\":false,\"required_approving_review_count\":1}")"
assert_eq "approval_params: review count 2" "$pfx approval_params=[required_approving_review_count] wrong_pins=[] missing_refs=[]" \
  "$(approval_line "$PRX,\"parameters\":{\"require_code_owner_review\":true,\"dismiss_stale_reviews_on_push\":true,\"require_last_push_approval\":true,\"required_approving_review_count\":2}")"
assert_eq "approval_params: all four off, in the fixed order" \
  "$pfx approval_params=[require_code_owner_review,dismiss_stale_reviews_on_push,require_last_push_approval,required_approving_review_count] wrong_pins=[] missing_refs=[]" \
  "$(approval_line "$PRX,\"parameters\":{\"require_code_owner_review\":false,\"dismiss_stale_reviews_on_push\":false,\"require_last_push_approval\":false,\"required_approving_review_count\":0}")"
assert_eq "approval_params: a pull_request rule with no parameters names all four" \
  "$pfx approval_params=[require_code_owner_review,dismiss_stale_reviews_on_push,require_last_push_approval,required_approving_review_count] wrong_pins=[] missing_refs=[]" \
  "$(approval_line "$PRX")"
setup_ok; list_yml
assert_eq "approval_params: a ruleset with no pull_request rule prints an empty list" \
  "ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml | sed -n 1p)"

setup_ok; list_yml; echo '[{"id":2,"name":"approval"}]' >"$STUBS/$EP_L"
assert_eq "list form missing" "ruleset checks missing
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml
echo '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368}]}},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]' >"$STUBS/$EP_B"
assert_eq "list form weakened names the absent type and check" \
"ruleset checks missing_types=[deletion] missing_checks=[test] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml
echo '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":null},{"context":"test"},{"context":"extra"}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]' >"$STUBS/$EP_B"
assert_eq "list form: a null or absent integration_id names the check; an undeclared check is not judged" \
"ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[lint,test] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml
echo '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]' >"$STUBS/$EP_B"
assert_eq "list form: an absent check is missing, not unpinned" \
"ruleset checks missing_types=[] missing_checks=[test] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml; echo '{"bypass_actors":[{"actor_id":1}]}' >"$STUBS/repos_o_r_rulesets_2"
assert_eq "list form drift: one bypass actor" \
"ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=1 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml; echo '{"bypass_actors":null}' >"$STUBS/repos_o_r_rulesets_2"
assert_eq "list form bypass actors not visible" \
"ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval inconclusive (bypass actors not visible to this identity) missing_types=[] missing_checks=[] unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml; echo '{"bypass_actors":null}' >"$STUBS/repos_o_r_rulesets_1"
echo '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368}]}},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]' >"$STUBS/$EP_B"
assert_eq "list form bypass actors not visible still names a missing type and check" \
"ruleset checks inconclusive (bypass actors not visible to this identity) missing_types=[deletion] missing_checks=[test] unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml; echo '{"bypass_actors":null}' >"$STUBS/repos_o_r_rulesets_1"
echo '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test"}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]' >"$STUBS/$EP_B"
assert_eq "list form bypass actors not visible still names an unpinned check" \
"ruleset checks inconclusive (bypass actors not visible to this identity) missing_types=[] missing_checks=[] unpinned_checks=[test] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml; echo '{"bypass_actors":null}' >"$STUBS/repos_o_r_rulesets_2"
echo '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":false,"required_approving_review_count":1}}]' >"$STUBS/$EP_B"
assert_eq "list form bypass actors not visible still names a weakened approval parameter" \
"ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval inconclusive (bypass actors not visible to this identity) missing_types=[] missing_checks=[] unpinned_checks=[] approval_params=[require_last_push_approval] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

setup_ok; list_yml; touch "$STUBS/$EP_L.rc"
assert_eq "list form: a failed rulesets-list read" "ruleset checks inconclusive
ruleset approval inconclusive" "$(run $R $BASE $yml)"

setup_ok; list_yml; sed -i 's/source: repo/source: team/' "$yml"
assert_eq "list form: a source other than repo or org" "ruleset checks inconclusive
ruleset approval inconclusive" "$(run $R $BASE $yml)"

setup_ok; list_yml; sed -i 's/source: repo/source: org/' "$yml"
echo '[{"id":1,"name":"checks"},{"id":2,"name":"approval"}]' >"$STUBS/orgs_o_rulesets"
echo '{"bypass_actors":[]}' >"$STUBS/orgs_o_rulesets_1"; echo '{"bypass_actors":[]}' >"$STUBS/orgs_o_rulesets_2"
run $R $BASE $yml >/dev/null
assert_eq "list form: an org entry reads the org endpoint" "2" "$(grep -c '^orgs/o/rulesets$' "$STUBS/gh.log")"
assert_eq "list form: an org entry never reads the repo endpoint" "0" "$(grep -c '^repos/o/r/rulesets$' "$STUBS/gh.log" || true)"

setup_ok; list_yml
printf '%s\n' 'rulesets:' '  - name: "a\nb"' '    source: repo' '    rule_types: [deletion]' >"$yml"
assert_eq "list form: a newline inside a name" "ruleset #0 inconclusive" "$(run $R $BASE $yml)"

# The trailing newline is the only input that tells \z from $.
setup_ok
printf '%s\n' 'rulesets:' '  - name: "checks\n"' '    source: repo' '    rule_types: [deletion]' >"$yml"
assert_eq "list form: a name ending in a newline" "ruleset #0 inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'rulesets:' '  - name: checks' '    source: repo' '    rule_types: ["deletion\n"]' >"$yml"
assert_eq "list form: a rule type ending in a newline" "ruleset #0 inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'rulesets:' '  - name: checks' '    source: repo' '    rule_types: [deletion]' '    required_checks: ["lint\n"]' >"$yml"
assert_eq "list form: a check ending in a newline" "ruleset #0 inconclusive" "$(run $R $BASE $yml)"

setup_ok; list_yml; echo '[{"id":1.5,"name":"checks"},{"id":2,"name":"approval"}]' >"$STUBS/$EP_L"
echo '{"bypass_actors":[]}' >"$STUBS/repos_o_r_rulesets_1.5"
assert_eq "list form: a non-numeric ruleset id" "ruleset checks inconclusive
ruleset approval missing_types=[] missing_checks=[] approval=1 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"

# A backslash in a name is no control character; echo in some shells would make it a new line.
setup_ok
printf '%s\n' 'rulesets:' "  - name: 'x\\nruleset forged missing_types=[]\\c'" '    source: team' '    rule_types: [deletion]' >"$yml"
assert_eq "list form: a backslash in a name stays on one line" \
  'ruleset x\nruleset forged missing_types=[]\c inconclusive' "$(run $R $BASE $yml)"

# A comma inside a check name is part of the name (#1298): the declared list reaches jq as an array.
comma_rules() { # comma_rules <integration-id-json or ->
  if [ "$1" = - ]; then c='{"context":"build (linux, x64)"}'; else c="{\"context\":\"build (linux, x64)\",\"integration_id\":$1}"; fi
  printf '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[%s]}},{"type":"deletion","ruleset_id":1}]\n' "$c"
}
setup_ok; printf '%s\n' 'rulesets:' '  - name: checks' '    source: repo' '    rule_types: [required_status_checks, deletion]' '    required_checks: ["build (linux, x64)"]' >"$yml"
comma_rules 15368 >"$STUBS/$EP_B"
assert_eq "list form: a check name with a comma, carried and pinned" \
  "ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"
echo '[{"type":"deletion","ruleset_id":1}]' >"$STUBS/$EP_B"
assert_eq "list form: a check name with a comma, absent, is missing once" \
  "ruleset checks missing_types=[required_status_checks] missing_checks=[build (linux, x64)] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"
comma_rules - >"$STUBS/$EP_B"
assert_eq "list form: a check name with a comma, carried unpinned" \
  "ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[build (linux, x64)] approval_params=[] wrong_pins=[] missing_refs=[]" "$(run $R $BASE $yml)"
printf '%s\n' 'rulesets:' '  - name: checks' '    source: repo' '    rule_types: [deletion]' '    required_checks: [lint, "te\nst"]' >"$yml"
assert_eq "list form: a control character in one of several checks" "ruleset #0 inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'rulesets:' '  - name: checks' '    source: repo' '    rule_types: [deletion, "dele\ntion"]' >"$yml"
assert_eq "list form: a control character in one of several rule types" "ruleset #0 inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'rulesets:' '  - name: checks' '    source: repo' '    rule_types: [deletion]' '    required_checks: [1]' >"$yml"
assert_eq "list form: a non-string check entry" "ruleset #0 inconclusive" "$(run $R $BASE $yml)"
# a string `parameters` makes approval_params fail in jq: the entry falls back to the plain inconclusive line
BAD_RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":"x"}]'
setup_ok; list_yml; echo "$BAD_RULES" >"$STUBS/$EP_B"
assert_eq "list form: a field-computation failure, bypass actors visible" \
"ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval inconclusive" "$(run $R $BASE $yml)"
setup_ok; list_yml; echo "$BAD_RULES" >"$STUBS/$EP_B"; echo '{"bypass_actors":null}' >"$STUBS/repos_o_r_rulesets_2"
assert_eq "list form: a field-computation failure, bypass actors not visible" \
"ruleset checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[]
ruleset approval inconclusive" "$(run $R $BASE $yml)"

# The CR-stripping wrappers keep their temp files in a private directory, removed on exit.
setup_ok; list_yml; mkdir -p "$tmp/td"
TMPDIR="$tmp/td" run $R $BASE $yml >/dev/null
assert_eq "no temp file is left after a run" "" "$(ls -A "$tmp/td")"

# --- pre-name inconclusive -----------------------------------------------------------------
setup_ok; list_yml
assert_eq "a failed branch-rules read, list form" "inconclusive branch-rules" \
  "$(touch "$STUBS/$EP_B.rc"; run $R $BASE $yml)"
setup_ok; single_yml '[deletion]'
assert_eq "a failed branch-rules read, single form" "inconclusive branch-rules" \
  "$(touch "$STUBS/$EP_B.rc"; run $R $BASE $yml)"

setup_ok; list_yml
assert_eq "a refused repo: leading slash" "inconclusive bad-repo" "$(run /x $BASE $yml)"
assert_eq "a refused repo: no slash" "inconclusive bad-repo" "$(run x $BASE $yml)"
assert_eq "a refused repo: three segments" "inconclusive bad-repo" "$(run a/b/c $BASE $yml)"
assert_eq "a refused repo: trailing slash" "inconclusive bad-repo" "$(run a/ $BASE $yml)"
assert_eq "a refused repo: leading dash" "inconclusive bad-repo" "$(run -a/b $BASE $yml)"
assert_eq "a refused repo: a space" "inconclusive bad-repo" "$(run 'a/b c' $BASE $yml)"
assert_eq "a refused repo: dot owner" "inconclusive bad-repo" "$(run ./r $BASE $yml)"
assert_eq "a refused repo: dot-dot owner" "inconclusive bad-repo" "$(run ../r $BASE $yml)"
assert_eq "a refused repo: dot name" "inconclusive bad-repo" "$(run o/. $BASE $yml)"
assert_eq "a refused repo: dot-dot name" "inconclusive bad-repo" "$(run o/.. $BASE $yml)"
assert_eq "a name that merely starts with dots is not a dot segment" "inconclusive branch-rules" \
  "$(run o/..r $BASE $yml)"
assert_eq "a refused base: empty" "inconclusive bad-base" "$(run $R '' $yml)"
assert_eq "a refused base: leading dash" "inconclusive bad-base" "$(run $R -x $yml)"
for b in . .. ../x x/.. a/../b ./x a/. a/./b a//b a/ /a; do
  assert_eq "a refused base: $b" "inconclusive bad-base" "$(run $R "$b" $yml)"
done
assert_eq "a refused base: a space" "inconclusive bad-base" "$(run $R 'a b' $yml)"

setup_ok; printf 'rulesets: []\n' >"$yml"
assert_eq "an empty rulesets list" "inconclusive bad-rulesets" "$(run $R $BASE $yml)"
printf 'rulesets: checks\n' >"$yml"
assert_eq "a scalar rulesets" "inconclusive bad-rulesets" "$(run $R $BASE $yml)"
printf 'rulesets: {a: b}\n' >"$yml"
assert_eq "a map rulesets" "inconclusive bad-rulesets" "$(run $R $BASE $yml)"

setup_ok
assert_eq "an unreadable project file" "inconclusive unreadable" "$(run $R $BASE "$tmp/absent.yml")"

# --- missing tools -------------------------------------------------------------------------
setup_ok; list_yml
assert_eq "no gh" "inconclusive no-gh" "$(run_path "$tmp/p-nogh" $R $BASE $yml)"
assert_eq "no jq" "inconclusive no-jq" "$(run_path "$tmp/p-nojq" $R $BASE $yml)"
assert_eq "no yq" "inconclusive no-yq" "$(run_path "$tmp/p-noyq" $R $BASE $yml)"

# --- single form ---------------------------------------------------------------------------
setup_ok; single_yml '[required_status_checks, deletion]' '[lint, test]'
assert_eq "single form healthy" "ruleset checks missing_types=[] missing_checks=[]" "$(run $R $BASE $yml)"

setup_ok; single_yml '[required_status_checks, deletion]' '[lint, test]'; echo 'identities: {}' >>"$yml"
assert_eq "single form under an identities map ends bypass_actors=unchecked" \
  "ruleset checks missing_types=[] missing_checks=[] bypass_actors=unchecked" "$(run $R $BASE $yml)"
setup_ok; single_yml '[required_status_checks, deletion, non_fast_forward]' '[lint, e2e]'; echo 'identities: {}' >>"$yml"
assert_eq "single form under an identities map, weakened, keeps the suffix" \
  "ruleset checks missing_types=[non_fast_forward] missing_checks=[e2e] bypass_actors=unchecked" "$(run $R $BASE $yml)"
setup_ok; single_yml '[required_status_checks, deletion]' '[lint, test]'; printf '%s\n' 'base: &a {}' 'identities: *a' >>"$yml"
assert_eq "single form under an aliased identities map still ends bypass_actors=unchecked" \
  "ruleset checks missing_types=[] missing_checks=[] bypass_actors=unchecked" "$(run $R $BASE $yml)"
setup_ok; single_yml '[required_status_checks, deletion]' '[lint, test]'; echo 'identities: null' >>"$yml"
assert_eq "single form with identities null is exactly as before" \
  "ruleset checks missing_types=[] missing_checks=[]" "$(run $R $BASE $yml)"
setup_ok; single_yml '[required_status_checks, deletion]' '[lint, test]'
assert_eq "single form with no identities key is exactly as before" \
  "ruleset checks missing_types=[] missing_checks=[]" "$(run $R $BASE $yml)"

setup_ok; single_yml '[deletion]'; printf '%s\n' 's: &s foo' 'x:' '  <<: *s' >>"$yml"
assert_eq "single form: a failed identities tag read is inconclusive" "ruleset checks inconclusive" "$(run $R $BASE $yml)"

# branch rules split over two pages
setup_ok; single_yml '[required_status_checks, deletion]' '[lint, test]'
echo '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint"},{"context":"test"}]}}]' >"$STUBS/$EP_B.1"
echo '[{"type":"deletion","ruleset_id":1}]' >"$STUBS/$EP_B.2"
assert_eq "single form healthy with the branch rules over two pages" \
  "ruleset checks missing_types=[] missing_checks=[]" "$(run $R $BASE $yml)"

setup_ok; single_yml '[deletion]'; echo '[{"id":9,"name":"other"}]' >"$STUBS/$EP_L"
assert_eq "single form: no such name" "ruleset checks missing" "$(run $R $BASE $yml)"
setup_ok; single_yml '[deletion]'; echo '[{"type":"deletion","ruleset_id":2}]' >"$STUBS/$EP_B"
assert_eq "single form: its rules do not apply to the base" "ruleset checks missing" "$(run $R $BASE $yml)"

setup_ok; single_yml '[required_status_checks, deletion, non_fast_forward]' '[lint, e2e]'
assert_eq "single form weakened" "ruleset checks missing_types=[non_fast_forward] missing_checks=[e2e]" "$(run $R $BASE $yml)"

setup_ok; single_yml '[required_status_checks]'
assert_eq "single form: required_status_checks declared with no required_checks" \
  "ruleset checks inconclusive" "$(run $R $BASE $yml)"
setup_ok; single_yml '[deletion]'
assert_eq "single form: no required_checks needed without that type" \
  "ruleset checks missing_types=[] missing_checks=[]" "$(run $R $BASE $yml)"

setup_ok; single_yml '[deletion]'; touch "$STUBS/$EP_L.rc"
assert_eq "single form: a failed rulesets-list read" "ruleset checks inconclusive" "$(run $R $BASE $yml)"
setup_ok; single_yml '[deletion]'; echo '[{"id":1.5,"name":"checks"}]' >"$STUBS/$EP_L"
assert_eq "single form: a non-numeric ruleset id" "ruleset checks inconclusive" "$(run $R $BASE $yml)"

setup_ok; printf '%s\n' 'ruleset:' '  name: "a\nb"' '  rule_types: [deletion]' >"$yml"
assert_eq "single form: a newline inside the name" "inconclusive bad-name" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: "checks\n"' '  rule_types: [deletion]' >"$yml"
assert_eq "single form: a name ending in a newline" "inconclusive bad-name" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  rule_types: [deletion]' >"$yml"
assert_eq "single form: no name" "inconclusive bad-name" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: checks' '  rule_types: ["deletion\n"]' >"$yml"
assert_eq "single form: a rule type ending in a newline" "ruleset checks inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: checks' '  rule_types: ["del\netion"]' >"$yml"
assert_eq "single form: a newline inside a rule type" "ruleset checks inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: checks' '  rule_types: [required_status_checks]' '  required_checks: ["lint\n"]' >"$yml"
assert_eq "single form: a check ending in a newline" "ruleset checks inconclusive" "$(run $R $BASE $yml)"

setup_ok; single_yml '[required_status_checks]' '["build (linux, x64)"]'; comma_rules 15368 >"$STUBS/$EP_B"
assert_eq "single form: a check name with a comma, carried" \
  "ruleset checks missing_types=[] missing_checks=[]" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: checks' '  rule_types: [required_status_checks]' '  required_checks: [lint, "te\nst"]' >"$yml"
assert_eq "single form: a control character in one of several checks" "ruleset checks inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: checks' '  rule_types: [required_status_checks]' '  required_checks: [1]' >"$yml"
assert_eq "single form: a non-string check entry" "ruleset checks inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: checks' '  rule_types: [required_status_checks]' '  required_checks: [lint, ~]' >"$yml"
assert_eq "single form: a null check entry" "ruleset checks inconclusive" "$(run $R $BASE $yml)"
printf '%s\n' 'ruleset:' '  name: checks' '  rule_types: [deletion, "dele\ntion"]' >"$yml"
assert_eq "single form: a control character in one of several rule types" "ruleset checks inconclusive" "$(run $R $BASE $yml)"

# --- check_integrations, target and ref_patterns (#1413) -----------------------------------
pin_yml() { # pin_yml <check_integrations flow map>
  printf '%s\n' 'rulesets:' '  - name: checks' '    source: repo' '    rule_types: [required_status_checks]' '    required_checks: [lint, test]' "    check_integrations: $1" >"$yml"
}
pin_line() { setup_ok; pin_yml "$1"; run $R $BASE $yml; }
PINTAIL="approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[]"
assert_eq "pins: matching ids" "ruleset checks missing_types=[] missing_checks=[] $PINTAIL wrong_pins=[] missing_refs=[]" "$(pin_line '{lint: 15368, test: 15368}')"
assert_eq "pins: a different id" "ruleset checks missing_types=[] missing_checks=[] $PINTAIL wrong_pins=[test] missing_refs=[]" "$(pin_line '{lint: 15368, test: 99}')"
assert_eq "pins: two wrong ids, in declared order" "ruleset checks missing_types=[] missing_checks=[] $PINTAIL wrong_pins=[test,lint] missing_refs=[]" "$(pin_line '{test: 1, lint: 2}')"
assert_eq "pins: a check the rule does not carry" "ruleset checks missing_types=[] missing_checks=[] $PINTAIL wrong_pins=[other] missing_refs=[]" "$(pin_line '{lint: 15368, other: 15368}')"
setup_ok; pin_yml '{lint: 15368}'
printf '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":null},{"context":"test"}]}}]\n' >"$STUBS/$EP_B"
assert_eq "pins: a null id" "ruleset checks missing_types=[] missing_checks=[] $PINTAIL wrong_pins=[lint] missing_refs=[]" "$(run $R $BASE $yml | sed 's/unpinned_checks=\[[^]]*\]/unpinned_checks=[]/')"
for bad in 'false' '{lint: "x"}' '{lint: 0}' '{lint: -1}' '[lint]' '{lint: 1.5}'; do
  assert_eq "pins: malformed check_integrations $bad" "ruleset checks inconclusive" "$(pin_line "$bad")"
done

TL='[{"id":1,"name":"checks"},{"id":3,"name":"tags"}]'
tag_yml() { # tag_yml <extra entry lines...>
  { printf '%s\n' 'rulesets:' '  - name: tags' '    source: repo' '    target: tag' '    rule_types: [deletion, non_fast_forward]' '    ref_patterns: ["refs/tags/v*"]'; for l in "$@"; do printf '%s\n' "$l"; done; } >"$yml"
}
tag_ok='{"id":3,"target":"tag","enforcement":"active","bypass_actors":[],"conditions":{"ref_name":{"include":["refs/tags/v*"],"exclude":[]}},"rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}'
tag_run() { # tag_run <by-id json>
  setup_ok; echo "$TL" >"$STUBS/$EP_L"; echo "$1" >"$STUBS/repos_o_r_rulesets_3"; run $R $BASE $yml
}
TT="approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[]"
tag_yml
assert_eq "tag: healthy" "ruleset tags missing_types=[] missing_checks=[] $TT wrong_pins=[] missing_refs=[]" "$(tag_run "$tag_ok")"
assert_eq "tag: a missing rule type" "ruleset tags missing_types=[non_fast_forward] missing_checks=[] $TT wrong_pins=[] missing_refs=[]" \
  "$(tag_run "$(echo "$tag_ok" | jq -c '.rules = [{"type":"deletion"}]')")"
assert_eq "tag: a missing ref pattern" "ruleset tags missing_types=[] missing_checks=[] $TT wrong_pins=[] missing_refs=[refs/tags/v*]" \
  "$(tag_run "$(echo "$tag_ok" | jq -c '.conditions.ref_name.include = ["refs/tags/x"]')")"
assert_eq "tag: a branch ruleset reads missing" "ruleset tags missing" "$(tag_run "$(echo "$tag_ok" | jq -c '.target = "branch"')")"
assert_eq "tag: disabled reads missing" "ruleset tags missing" "$(tag_run "$(echo "$tag_ok" | jq -c '.enforcement = "disabled"')")"
assert_eq "tag: evaluate reads missing" "ruleset tags missing" "$(tag_run "$(echo "$tag_ok" | jq -c '.enforcement = "evaluate"')")"
setup_ok; echo "$TL" >"$STUBS/$EP_L"; echo 'not json <html>' >"$STUBS/repos_o_r_rulesets_3"
assert_eq "tag: a by-id response that is not JSON is inconclusive" "ruleset tags inconclusive" "$(run $R $BASE $yml)"
assert_eq "tag: rules not an array" "ruleset tags inconclusive" "$(tag_run "$(echo "$tag_ok" | jq -c '.rules = {}')")"
assert_eq "tag: include not an array" "ruleset tags inconclusive" "$(tag_run "$(echo "$tag_ok" | jq -c '.conditions.ref_name.include = "x"')")"
assert_eq "tag: a non-empty exclude" "ruleset tags inconclusive" "$(tag_run "$(echo "$tag_ok" | jq -c '.conditions.ref_name.exclude = ["refs/tags/old"]')")"
assert_eq "tag: the not-visible line carries the new fields" \
  "ruleset tags inconclusive (bypass actors not visible to this identity) missing_types=[] missing_checks=[] unpinned_checks=[] approval_params=[] wrong_pins=[] missing_refs=[refs/tags/v*]" \
  "$(tag_run "$(echo "$tag_ok" | jq -c 'del(.bypass_actors) | .conditions.ref_name.include = []')")"
tag_yml '    source_x: 1'; sed -i 's/source: repo/source: org/' "$yml"
assert_eq "tag: source org is inconclusive" "ruleset tags inconclusive" "$(tag_run "$tag_ok")"
printf '%s\n' 'rulesets:' '  - name: tags' '    source: repo' '    target: ref' '    rule_types: [deletion]' >"$yml"
assert_eq "an unknown target is inconclusive" "ruleset tags inconclusive" "$(tag_run "$tag_ok")"

exit "$fail"
