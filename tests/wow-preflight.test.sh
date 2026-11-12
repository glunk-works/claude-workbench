#!/bin/sh
# Fixture tests for scripts/identity/wow-preflight (#1383).
#
# Runs COPIES of wow-preflight, wow-common.sh, token-check.sh, gh-identity.sh and ruleset-drift.sh from a
# temp bin, against a throwaway $WOW_HOME holding a fake admin token, with a stub `gh` first on PATH. The
# stub maps each endpoint (the first argument that is not a flag, with / ? = replaced by _) to a canned file
# under $STUBS, applies the caller's own --jq filter, fails with `(HTTP 404)` on stderr when the file is
# absent (or with the text of `<name>.rc` when that exists), and logs every call's whole argument list.
#
# Permitted toolset: POSIX sh plus sed -i, jq and yq (mikefarah v4); the suite skips, loudly, without jq or yq.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

for tool in jq yq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "skip - wow-preflight fixtures: no $tool on PATH" >&2
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
TOKEN=ghs_0123456789abcdefghijklmnopqrstuvwxyzABCD
WOW_HOME="$tmp/home"; export WOW_HOME
mkdir -p "$STUBS" "$tmp/bin" "$tmp/ghbin" "$tmp/tmpdir" "$WOW_HOME/tokens/o/r"
for f in scripts/identity/wow-preflight scripts/identity/wow-common.sh plugins/way-of-working/bin/token-check.sh \
         plugins/way-of-working/bin/gh-identity.sh plugins/way-of-working/bin/ruleset-drift.sh; do
  cp "$root_dir/$f" "$tmp/bin/$(basename "$f")"
done
chmod 755 "$tmp/bin"/*

cat >"$tmp/ghbin/gh" <<'STUB'
#!/bin/sh
# gh api [--hostname H] [--paginate] [-H X] <endpoint> [--jq F]
printf 'GH_HOST=%s %s\n' "${GH_HOST:-}" "$*" >>"$STUBS/gh.log"
[ "${GH_TOKEN:-}" = "$FAKE_TOKEN" ] && echo ok >>"$STUBS/tok.log" || echo bad >>"$STUBS/tok.log"
shift
ep= jqf=
while [ $# -gt 0 ]; do
  case "$1" in
    --hostname | -H) shift ;;
    --paginate) ;;
    --jq) shift; jqf=$1 ;;
    *) [ -n "$ep" ] || ep=$1 ;;
  esac
  shift
done
k=$(printf '%s' "$ep" | tr '/?=' '___')
if [ -f "$STUBS/$k.rc" ]; then cat "$STUBS/$k.rc" >&2; exit 1; fi
[ -f "$STUBS/$k" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
if [ -n "$jqf" ]; then "$REAL_JQ" -r "$jqf" <"$STUBS/$k"; else cat "$STUBS/$k"; fi
STUB
chmod 755 "$tmp/ghbin/gh"
FAKE_TOKEN=$TOKEN; export FAKE_TOKEN
REAL_JQ=$(command -v jq); export REAL_JQ
# a jq (and yq) that ends every output line in CR, as a native .exe under Git Bash can
for _t in jq yq; do
  mkdir -p "$tmp/crbin"
  printf '#!/bin/sh\n%s "$@" >"$0.out"; r=$?; sed "s/$/\\r/" "$0.out"; exit $r\n' "$(command -v $_t)" >"$tmp/crbin/$_t"
  chmod 755 "$tmp/crbin/$_t"
done

mkpath() { # mkpath <dir> <tool>...
  d=$1; shift; mkdir -p "$d"
  for _t in "$@"; do ln -sf "$(command -v "$_t")" "$d/$_t"; done
  for _t in sh cat tr printf dirname sed wc grep mktemp rm cut head; do
    _p=$(command -v "$_t" 2>/dev/null || true); case "$_p" in /*) ln -sf "$_p" "$d/$_t" ;; esac
  done
}

put() { # put <endpoint> <json>
  printf '%s\n' "$2" >"$STUBS/$(printf '%s' "$1" | tr '/?=' '___')"
}
fail_ep() { # fail_ep <endpoint> [<stderr text>]
  printf '%s\n' "${2:-gh: Server Error (HTTP 500)}" >"$STUBS/$(printf '%s' "$1" | tr '/?=' '___').rc"
}
drop() { rm -f "$STUBS/$(printf '%s' "$1" | tr '/?=' '___')"; }

write_token() { printf '%s\n%s\n' "$1" "$2" >"$WOW_HOME/tokens/o/r/admin-token"; }

rules_ok='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'
yml="$tmp/p.yml"
write_yml() {
  cat >"$yml" <<'Y'
identities:
  dev_app: { login: "glunk-dev[bot]", id: 1 }
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
setup_ok() {
  rm -rf "$STUBS"; mkdir -p "$STUBS"
  write_token "$TOKEN" 2099-01-01T00:00:00Z
  write_yml
  put installation/repositories '{"repositories":[{"full_name":"o/r"}]}'
  put repos/o/r '{"default_branch":"main","allow_auto_merge":false}'
  put repos/o/r/rules/branches/main "$rules_ok"
  put repos/o/r/rulesets '[{"id":1,"name":"checks"},{"id":2,"name":"approval"}]'
  put repos/o/r/rulesets/1 '{"bypass_actors":[]}'
  put repos/o/r/rulesets/2 '{"bypass_actors":[]}'
  put repos/o/r/actions/permissions/workflow '{"default_workflow_permissions":"read"}'
  put repos/o/r/environments '{"total_count":1,"environments":[{"name":"release","can_admins_bypass":false}]}'
  printf '# owners\r\n* @alice # the code owner\r\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"
  put repos/o/r/collaborators/alice/permission '{"permission":"admin"}'
  put apps/glunk-dev '{"permissions":{"contents":"write","pull_requests":"write"}}'
}

PATH_SAVE=$PATH
run() { # run [args...] -> $tmp/out, $tmp/err, $rc ; default args o/r $yml
  [ $# -gt 0 ] || set -- o/r "$yml"
  rm -f "$STUBS/gh.log" "$STUBS/tok.log"
  rc=0
  TMPDIR="$tmp/tmpdir" PATH="$tmp/ghbin:$PATH_SAVE" "$tmp/bin/wow-preflight" "$@" >"$tmp/out" 2>"$tmp/err" </dev/null || rc=$?
}
state() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' "$tmp/out"; }
detail() { awk -F'\t' -v k="$1" '$1 == k { print $3 }' "$tmp/out"; }
rows() { sed 1d "$tmp/out" | cut -f1; }
logged() { grep -c -- "$1" "$STUBS/gh.log" 2>/dev/null || true; }

# --- all in place ----------------------------------------------------------------------------
check_ui() { # check_ui <label> <row>
  assert_eq "$1: exit 0" 0 "$rc"
  assert_eq "$1: state" "check in the UI" "$(state "$2")"
}

setup_ok; run
assert_eq "all ok: exit 0" 0 "$rc"
assert_eq "all ok: header" "precondition	state	detail" "$(sed -n 1p "$tmp/out")"
assert_eq "all ok: the rows, in order" "ruleset checks
ruleset approval
default workflow token
allow auto-merge
environment release
CODEOWNERS
dev App permissions
reviewer App installation
dev App installation
org secrets
fork pull request workflows" "$(rows)"
for k in 'ruleset checks' 'ruleset approval' 'default workflow token' 'allow auto-merge' 'environment release' 'CODEOWNERS' 'dev App permissions'; do
  assert_eq "all ok: $k" ok "$(state "$k")"
done
for k in 'reviewer App installation' 'dev App installation' 'org secrets' 'fork pull request workflows'; do
  assert_eq "all ok: $k is a fixed UI row" "check in the UI" "$(state "$k")"
done
assert_eq "all ok: no approval rule parameters row, a ruleset declares pull_request" 0 "$(rows | grep -c 'approval rule parameters' || true)"
assert_eq "all ok: every row has three fields" 0 "$(awk -F'\t' 'NF != 3' "$tmp/out" | wc -l | tr -d ' ')"
assert_eq "all ok: the revoke line on stderr" "wow-preflight: done; revoke the admin token now: wow-admin o/r --revoke" "$(tail -n 1 "$tmp/err")"
assert_eq "all ok: every call carried the token in GH_TOKEN" 0 "$(grep -c bad "$STUBS/tok.log" || true)"

# --- CR-ending tool output (Git Bash with native .exe tools) ---------------------------------
setup_ok
rm -f "$STUBS/gh.log" "$STUBS/tok.log"; rc=0
TMPDIR="$tmp/tmpdir" PATH="$tmp/ghbin:$tmp/crbin:$PATH_SAVE" "$tmp/bin/wow-preflight" o/r "$yml" >"$tmp/out" 2>"$tmp/err" </dev/null || rc=$?
for k in 'ruleset checks' 'ruleset approval' 'default workflow token' 'allow auto-merge' 'environment release' 'CODEOWNERS' 'dev App permissions'; do
  assert_eq "CR-ending tools: $k" ok "$(state "$k")"
done

# --- each missing cause ----------------------------------------------------------------------
check_missing() { # check_missing <label> <row> <detail-substring>
  assert_eq "$1: exit 0" 0 "$rc"
  assert_eq "$1: state" missing "$(state "$2")"
  case "$(detail "$2")" in *"$3"*) echo "ok - $1: detail names it" ;; *) echo "FAIL - $1: detail [$(detail "$2")] lacks [$3]" >&2; fail=1 ;; esac
}
setup_ok; put repos/o/r/rulesets/2 '{"bypass_actors":[{"actor_id":1}]}'; run
check_missing "a bypass actor" "ruleset approval" "bypass_actors=1"
assert_eq "a bypass actor: the other ruleset stays ok" ok "$(state 'ruleset checks')"
setup_ok; put repos/o/r/rules/branches/main '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'; run
check_missing "a missing check" "ruleset checks" "missing_checks=[test]"
setup_ok; put repos/o/r/rules/branches/main '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test"}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'; run
check_missing "an unpinned check" "ruleset checks" "unpinned_checks=[test]"
setup_ok; put repos/o/r/rules/branches/main '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test","integration_id":15368}]}},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'; run
check_missing "a missing rule type" "ruleset checks" "missing_types=[deletion]"
setup_ok; put repos/o/r/rulesets '[{"id":2,"name":"approval"}]'; run
check_missing "an absent ruleset" "ruleset checks" "no ruleset"
setup_ok; put repos/o/r/actions/permissions/workflow '{"default_workflow_permissions":"write"}'; run
check_missing "a write default token" "default workflow token" "write"
setup_ok; put repos/o/r '{"default_branch":"main","allow_auto_merge":true}'; run
check_missing "auto-merge on" "allow auto-merge" "on;"
setup_ok; put repos/o/r/environments '{"environments":[{"name":"release","can_admins_bypass":true},{"name":"qa","can_admins_bypass":false}]}'; run
check_missing "an environment with admins bypass" "environment release" "bypass"
assert_eq "an environment with admins bypass: the other environment is ok" ok "$(state 'environment qa')"
setup_ok; printf '* # nobody\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
check_missing "a * line with no owner" CODEOWNERS "no owner"
setup_ok; printf '* @o/team\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
check_ui "a team owner" CODEOWNERS
case "$(detail CODEOWNERS)" in *"team or an email"*) echo "ok - a team owner: detail names it" ;; *) echo "FAIL - a team owner: detail [$(detail CODEOWNERS)]" >&2; fail=1 ;; esac
assert_eq "a team owner: no permission request" 0 "$(logged collaborators)"
setup_ok; printf '* alice@example.com\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
check_ui "an email owner" CODEOWNERS
assert_eq "an email owner: no permission request" 0 "$(logged collaborators)"
setup_ok; printf '* @o/team @alice\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
check_ui "a team owner next to a plain login with write" CODEOWNERS
assert_eq "a team owner next to a plain login with write: only the login is requested" 1 "$(logged collaborators)"
setup_ok; printf '* @o/team @alice\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; put repos/o/r/collaborators/alice/permission '{"permission":"read"}'; run
check_missing "a team owner next to a plain login lacking write" CODEOWNERS "@alice"
setup_ok; printf '* @\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
check_missing "a * line naming @ alone" CODEOWNERS "no recognised shape"
setup_ok; printf '* nobody\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
check_missing "an owner of no recognised shape" CODEOWNERS "no recognised shape"
setup_ok; put repos/o/r/collaborators/alice/permission '{"permission":"read"}'; run
check_missing "an owner without write" CODEOWNERS "@alice"
setup_ok; printf '* @alice\ndocs/ @bob\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
check_missing "a line after the last * line" CODEOWNERS "after"
setup_ok; printf 'docs/ @bob\n* @alice\n' >"$STUBS/repos_o_r_contents_.github_CODEOWNERS_ref_main"; run
assert_eq "a line before the last * line is fine" ok "$(state CODEOWNERS)"
setup_ok; drop repos/o/r/contents/.github/CODEOWNERS?ref=main; run
check_missing "no CODEOWNERS file" CODEOWNERS "no CODEOWNERS"
setup_ok; drop repos/o/r/contents/.github/CODEOWNERS?ref=main; printf '* @alice\n' >"$STUBS/repos_o_r_contents_docs_CODEOWNERS_ref_main"; run
assert_eq "the third CODEOWNERS location is found after two 404s" ok "$(state CODEOWNERS)"
setup_ok; put apps/glunk-dev '{"permissions":{"contents":"write","workflows":"write"}}'; run
check_missing "a dev App holding workflows" "dev App permissions" "workflows"
setup_ok; put apps/glunk-dev '{"permissions":{"administration":"write"}}'; run
check_missing "a dev App holding administration" "dev App permissions" "administration"
setup_ok; put repos/o/r/rules/branches/main "$(printf '%s' "$rules_ok" | sed 's/"require_last_push_approval":true/"require_last_push_approval":false/')"; run
check_missing "last-push approval off" "ruleset approval" "approval_params=[require_last_push_approval]"
setup_ok; sed -i '/name: approval/,$d' "$yml"; run
check_missing "no entry declares pull_request" "approval rule parameters" "no rulesets entry declares a pull_request rule"
# the checks entry's ruleset carries a pull_request rule (all four parameters at their values) its entry does not declare
setup_ok; put repos/o/r/rules/branches/main "$(printf '%s' "$rules_ok" | sed 's/"ruleset_id":2/"ruleset_id":1/')"; run
check_missing "an undeclared pull_request rule" "ruleset checks" "does not declare"
# a map reads through ruleset-drift.sh's join, so only the wrapper's own type test can stop it
setup_ok; sed -i 's/rule_types: \[pull_request\]/rule_types: {a: pull_request}/' "$yml"; run
check_ui "rule_types a map" "ruleset approval"
case "$(detail 'ruleset approval')" in *"could not be read as a list"*) echo "ok - rule_types a map: detail names it" ;; *) echo "FAIL - rule_types a map: detail [$(detail 'ruleset approval')]" >&2; fail=1 ;; esac
assert_eq "rule_types a map: the parameters row is not a contradicting missing" "check in the UI" "$(state 'approval rule parameters')"
assert_eq "rule_types a map: the other ruleset stays ok" ok "$(state 'ruleset checks')"
setup_ok; sed -i '/^rulesets:/,$d' "$yml"; run
check_missing "no rulesets key" rulesets "no rulesets key"
assert_eq "no rulesets key: ruleset-drift.sh is not run" 0 "$(logged rules/branches)"

# --- failed reads and absent fields ----------------------------------------------------------
setup_ok; fail_ep repos/o/r/actions/permissions/workflow; run
check_ui "a failed workflow-token read" "default workflow token"
assert_eq "a failed read: the other rows still print" ok "$(state 'allow auto-merge')"
setup_ok; put repos/o/r/actions/permissions/workflow '{}'; run
check_ui "an absent workflow-token field" "default workflow token"
setup_ok; put repos/o/r '{"default_branch":"main"}'; run
check_ui "an absent allow_auto_merge" "allow auto-merge"
setup_ok; put repos/o/r '{"default_branch":"main","allow_auto_merge":"false"}'; run
check_ui "a string allow_auto_merge" "allow auto-merge"
setup_ok; fail_ep repos/o/r/environments; run
check_ui "a failed environments read" environments
setup_ok; put repos/o/r/environments '{"environments":[{"name":"release"}]}'; run
check_ui "an absent can_admins_bypass" "environment release"
setup_ok; put repos/o/r/environments '{"total_count":0,"environments":[]}'; run
assert_eq "no environments" ok "$(state environments)"
assert_eq "no environments: detail" none "$(detail environments)"
setup_ok; fail_ep 'repos/o/r/contents/.github/CODEOWNERS?ref=main'; run
check_ui "a CODEOWNERS read failing with HTTP 500" CODEOWNERS
setup_ok; fail_ep repos/o/r/collaborators/alice/permission; run
check_ui "a failed collaborator read" CODEOWNERS
setup_ok; put repos/o/r/collaborators/alice/permission '{}'; run
check_ui "an absent collaborator permission" CODEOWNERS
setup_ok; fail_ep apps/glunk-dev; run
check_ui "a failed App read" "dev App permissions"
setup_ok; put apps/glunk-dev '{}'; run
check_ui "an absent App permissions object" "dev App permissions"
setup_ok; sed -i 's/glunk-dev\[bot\]/not a slug/' "$yml"; run
check_ui "an unusable dev App login" "dev App permissions"
setup_ok; sed -i '/identities:/,/dev_app/d' "$yml"; run
check_ui "no identities.dev_app" "dev App permissions"
setup_ok; fail_ep repos/o/r; run
check_ui "a failed repo read: the rulesets" rulesets
check_ui "a failed repo read: CODEOWNERS" CODEOWNERS
setup_ok; fail_ep repos/o/r/rules/branches/main; run
check_ui "a failed branch-rules read" rulesets
setup_ok; put repos/o/r '{"default_branch":"../x","allow_auto_merge":false}'; run
check_ui "a default branch failing the base rule: rulesets" rulesets
check_ui "a default branch failing the base rule: CODEOWNERS" CODEOWNERS
setup_ok; fail_ep repos/o/r/rulesets/1; run
check_ui "a failed ruleset read" "ruleset checks"
assert_eq "a failed ruleset read: the other ruleset is ok" ok "$(state 'ruleset approval')"
setup_ok; put repos/o/r/rulesets/1 '{"bypass_actors":null}'; run
check_ui "bypass actors not visible" "ruleset checks"
setup_ok; sed -i 's/source: repo/source: org/' "$yml"; run
check_ui "an org entry: first" "ruleset checks"
check_ui "an org entry: second" "ruleset approval"
setup_ok; printf 'rulesets: []\n' >"$yml"; run
check_ui "an empty rulesets list" rulesets

# --- a name that would forge the ok form -----------------------------------------------------
forged='checks missing_types=[] missing_checks=[] approval=0 bypass_actors=0 unpinned_checks=[] approval_params=[]'
setup_ok
put repos/o/r/rules/branches/main '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'
jq -n --arg n "$forged" '[{"id":1,"name":$n},{"id":2,"name":"approval"}]' >"$STUBS/repos_o_r_rulesets"
{ echo 'rulesets:'; printf '  - name: "%s"\n' "$forged"; echo '    source: repo'; echo '    rule_types: [required_status_checks, deletion]'
  echo '    required_checks: [lint, test]'; echo '  - name: approval'; echo '    source: repo'; echo '    rule_types: [pull_request]'; } >"$yml"
run
assert_eq "a forged name: the row is not ok" missing "$(state "ruleset $forged")"
# a name whose own text is the whole tail of an ok line does not make a differing line read ok
setup_ok; forged2='x unpinned_checks=[]'
jq -n --arg n "$forged2" '[{"id":1,"name":$n},{"id":2,"name":"approval"}]' >"$STUBS/repos_o_r_rulesets"
sed -i "s/name: checks/name: \"$forged2\"/" "$yml"
put repos/o/r/rules/branches/main '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368},{"context":"test"}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'
run
assert_eq "a name ending like an ok tail: an unpinned check is still missing" missing "$(state "ruleset $forged2")"

# --- stops before any row request ------------------------------------------------------------
stops() { # stops <label>: exit 1, no row endpoint requested
  assert_eq "$1: exit 1" 1 "$rc"
  assert_eq "$1: no table" "" "$(cat "$tmp/out")"
  if [ -f "$STUBS/gh.log" ]; then n=$(grep -vc 'installation/repositories' "$STUBS/gh.log" || true); else n=0; fi
  assert_eq "$1: no row endpoint requested" 0 "$n"
}
setup_ok; rm -f "$WOW_HOME/tokens/o/r/admin-token"; run
stops "a missing token file"
case "$(cat "$tmp/err")" in *"wow-admin o/r --revoke"*"wow-admin o/r --perms administration=write,contents=read,actions=read"*) echo "ok - a stop names the revoke and the mint" ;; *) echo "FAIL - a stop names the revoke and the mint: $(cat "$tmp/err")" >&2; fail=1 ;; esac
setup_ok; write_token "$TOKEN" 2000-01-01T00:00:00Z; run
stops "an expired token"
setup_ok; write_token "ghs_short" 2099-01-01T00:00:00Z; run
stops "a malformed token"
setup_ok; write_token "ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD" 2099-01-01T00:00:00Z; run
stops "a user-shaped token"
setup_ok; fail_ep installation/repositories; run
stops "a failed installation read"
setup_ok; put installation/repositories '{"repositories":[{"full_name":"o/other"}]}'; run
stops "an installation that does not list the repo"
setup_ok; put installation/repositories '{"repositories":[]}'; run
stops "an empty installation"
setup_ok; printf 'rulesets: [\n' >"$yml"; run
assert_eq "an unparseable project file: exit 1" 1 "$rc"
assert_eq "an unparseable project file: no request at all" "" "$(cat "$STUBS/gh.log" 2>/dev/null || true)"
setup_ok; run o/r "$tmp/absent.yml"
assert_eq "a missing project file: exit 1" 1 "$rc"
for t in gh jq yq; do
  setup_ok
  case $t in gh) set -- jq yq awk ;; jq) set -- gh yq awk ;; yq) set -- gh jq awk ;; esac
  mkpath "$tmp/p-no$t" "$@"; ln -sf "$tmp/ghbin/gh" "$tmp/p-no$t/gh" 2>/dev/null || true
  [ "$t" != gh ] || rm -f "$tmp/p-no$t/gh"
  rc=0; PATH="$tmp/p-no$t" "$tmp/bin/wow-preflight" o/r "$yml" >"$tmp/out" 2>"$tmp/err" </dev/null || rc=$?
  assert_eq "no $t: exit 1" 1 "$rc"
  assert_eq "no $t: no table" "" "$(cat "$tmp/out")"
done

# --- usage -----------------------------------------------------------------------------------
setup_ok
for args in "o/r" "o/r $yml extra" "r $yml" "o/r/x $yml" "/r $yml" "o/ $yml" "-o/r $yml" "o/-r $yml" "./r $yml" "../r $yml" "o/. $yml" "o/.. $yml" "o/r;x $yml"; do
  # shellcheck disable=SC2086
  run $args
  assert_eq "usage: [$args] exits 2" 2 "$rc"
done
rc=0; "$tmp/bin/wow-preflight" >/dev/null 2>&1 </dev/null || rc=$?
assert_eq "usage: no arguments exits 2" 2 "$rc"
run "" "$yml"
assert_eq "usage: an empty repo exits 2" 2 "$rc"
run o/r ""
assert_eq "usage: an empty project file exits 2" 2 "$rc"

# --- reads only ------------------------------------------------------------------------------
setup_ok; run
assert_eq "the log has calls" ok "$([ -s "$STUBS/gh.log" ] && echo ok || echo empty)"
assert_eq "no logged call carries a method, field or input flag" 0 "$(grep -cE -- '(^| )(-X|--method|-f|-F|--field|--raw-field|--input)( |$)' "$STUBS/gh.log" || true)"
assert_eq "every logged call is gh api's argument list with --hostname github.com or GH_HOST=github.com" 0 \
  "$(grep -vcE -- '^GH_HOST= api --hostname github.com |^GH_HOST=github.com api ' "$STUBS/gh.log" || true)"
assert_eq "no gh api call in the script carries a method, field or input flag" 0 \
  "$(grep -E 'gh api' "$root_dir/scripts/identity/wow-preflight" | grep -vE '^[[:space:]]*#' | grep -cE -- ' (-X|--method|-f|-F|--field|--raw-field|--input)( |$)' || true)"

# --- the token never leaves the environment --------------------------------------------------
setup_ok; run
leak=0
for f in "$tmp/out" "$tmp/err" "$STUBS/gh.log"; do grep -q "$TOKEN" "$f" && leak=1; done
assert_eq "the token is in none of stdout, stderr or the recorded argv" 0 "$leak"
setup_ok; fail_ep repos/o/r/actions/permissions/workflow "gh: Server Error (HTTP 500)"; run
leak=0
for f in "$tmp/out" "$tmp/err" "$STUBS/gh.log"; do grep -q "$TOKEN" "$f" && leak=1; done
assert_eq "the token is in none of the outputs after a failed read" 0 "$leak"

# --- an unprintable value --------------------------------------------------------------------
setup_ok; printf '{"environments":[{"name":"re\\u0001lease","can_admins_bypass":false},{"name":"ok","can_admins_bypass":false}]}\n' >"$STUBS/repos_o_r_environments"; run
check_ui "an environment name with a control character" "environment #0"
assert_eq "an unprintable value: the next environment still reads" ok "$(state 'environment ok')"
assert_eq "an unprintable value: the control byte is not printed" 0 "$(LC_ALL=C grep -c "$(printf '\001')" "$tmp/out" || true)"
setup_ok; printf '{"environments":[{"name":"a\\tb","can_admins_bypass":false}]}\n' >"$STUBS/repos_o_r_environments"; run
check_ui "an environment name with a tab" "environment #0"

# --- $WOW_HOME untouched, temp file gone -----------------------------------------------------
snap() { (cd "$WOW_HOME" && find . -print | sort | while read -r p; do [ -d "$p" ] && echo "$p" || { echo "$p"; cksum <"$p"; }; done); }
setup_ok; before=$(snap); run; after=$(snap)
assert_eq "\$WOW_HOME is unchanged by a run" "$before" "$after"
assert_eq "no temp file is left after a run" "" "$(ls -A "$tmp/tmpdir")"
setup_ok; rm -f "$WOW_HOME/tokens/o/r/admin-token"; before=$(snap); run; after=$(snap)
assert_eq "\$WOW_HOME is unchanged by a stopped run" "$before" "$after"
assert_eq "no temp file is left after a stopped run" "" "$(ls -A "$tmp/tmpdir")"
setup_ok; fail_ep installation/repositories; run
assert_eq "no temp file is left after a stop at the installation read" "" "$(ls -A "$tmp/tmpdir")"

exit "$fail"
