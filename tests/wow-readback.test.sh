#!/bin/sh
# Fixture tests for scripts/identity/wow-readback (#1414).
#
# Runs COPIES of wow-readback, wow-common.sh, token-check.sh, gh-identity.sh and ruleset-drift.sh from a
# temp bin, against a throwaway $WOW_HOME holding a fake admin token and an apps.json, with a stub `gh`
# first on PATH. The stub maps each endpoint (the first argument that is not a flag, with / ? = replaced
# by _) to a canned file under $STUBS, applies the caller's own --jq filter, fails with `(HTTP 404)` on
# stderr when the file is absent (or with the text of `<name>.rc` when that exists), and logs every call.
#
# Permitted toolset: POSIX sh, GNU date, jq and yq (mikefarah v4); the suite skips, loudly, without jq or yq.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"

for tool in jq yq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "skip - wow-readback fixtures: no $tool on PATH" >&2
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
for f in scripts/identity/wow-readback scripts/identity/wow-common.sh plugins/way-of-working/bin/token-check.sh \
         plugins/way-of-working/bin/gh-identity.sh plugins/way-of-working/bin/ruleset-drift.sh; do
  cp "$root_dir/$f" "$tmp/bin/$(basename "$f")"
done
chmod 755 "$tmp/bin"/*

cat >"$tmp/ghbin/gh" <<'STUB'
#!/bin/sh
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

ep_key() { printf '%s' "$1" | tr '/?=' '___'; }
put() { printf '%s\n' "$2" >"$STUBS/$(ep_key "$1")"; }
fail_ep() { printf '%s\n' "${2:-gh: Server Error (HTTP 500)}" >"$STUBS/$(ep_key "$1").rc"; }
write_token() { printf '%s\n%s\n' "$1" "$2" >"$WOW_HOME/tokens/o/r/admin-token"; }

rules_ok='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"lint","integration_id":15368}]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'
YML='pr_base: main
rulesets:
  - name: checks
    source: repo
    rule_types: [required_status_checks, deletion]
    required_checks: [lint]
  - name: approval
    source: repo
    rule_types: [pull_request]
'
ENVY='environments:
  - { name: rel, reviewers: [{ type: User, id: 7 }], branch_policy: custom, branches: [main], admins_can_bypass: false }
'
WF_KEY='repos/o/r/contents/.github/workflows?ref=main'
ACT_B="repos/o/r/activity?ref=refs/heads/main&time_period=year&per_page=100"
ACT_ALL="repos/o/r/activity?time_period=year&per_page=100"
# The window, relative to now so the 365-day limit on --since never ages the fixtures: --since is 30 days
# back at midnight UTC; "before" and "after" bracket it, "until" times fall either side of "after".
day() { date -u -d "$(date -u +%Y-%m-%d) $1 days" +%Y-%m-%dT00:00:00Z; }
SINCE=$(day -30)
BEFORE=$(day -60)
AFTER=$(day -26)
UNTIL_LATE=$(day -21)
UNTIL_EARLY=$(day -29)
SINCE_DAY=${SINCE%%T*}
PREV_DAY=$(day -31); PREV_DAY=${PREV_DAY%%T*}
ENV_OK='{"name":"rel","can_admins_bypass":false,"protection_rules":[{"type":"required_reviewers","reviewers":[{"type":"User","reviewer":{"id":7}}]}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
drop_ep() { rm -f "$STUBS/$(ep_key "$1")"; }
setup_ok() {
  rm -rf "$STUBS"; mkdir -p "$STUBS"
  write_token "$TOKEN" 2099-01-01T00:00:00Z
  printf '{"admin":{"bot_user_id":"900"}}\n' >"$WOW_HOME/apps.json"
  put installation/repositories '{"repositories":[{"full_name":"o/r"}]}'
  put repos/o/r '{"default_branch":"main","allow_merge_commit":true,"allow_squash_merge":true,"allow_rebase_merge":false,"allow_auto_merge":false}'
  printf '%s%s' "$YML" "$ENVY" >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"
  put repos/o/r/actions/workflows '{"total_count":3,"workflows":[{"path":".github/workflows/ci.yml","state":"active"},{"path":"dynamic/pages/pages-build-deployment","state":"active"},{"path":".github/workflows/old.yml","state":"disabled_manually"}]}'
  put "$WF_KEY" '[{"type":"file","path":".github/workflows/ci.yml"}]'
  put repos/o/r/environments/rel "$ENV_OK"
  put repos/o/r/environments/rel/deployment-branch-policies '{"total_count":1,"branch_policies":[{"name":"main","type":"branch"}]}'
  put repos/o/r/actions/permissions/workflow '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}'
  put repos/o/r/rules/branches/main "$rules_ok"
  put repos/o/r/rulesets '[{"id":1,"name":"checks"},{"id":2,"name":"approval"}]'
  put repos/o/r/rulesets/1 "{\"bypass_actors\":[],\"created_at\":\"$BEFORE\",\"updated_at\":\"$BEFORE\"}"
  put repos/o/r/rulesets/2 "{\"bypass_actors\":[],\"created_at\":\"$BEFORE\",\"updated_at\":\"$BEFORE\"}"
  put repos/o/r/rulesets/1/history "[{\"version_id\":1,\"updated_at\":\"$BEFORE\"}]"
  put repos/o/r/rulesets/2/history "[{\"version_id\":1,\"updated_at\":\"$BEFORE\"}]"
  put "$ACT_B" '[]'
  put "$ACT_ALL" "[{\"timestamp\":\"$BEFORE\",\"ref\":\"refs/heads/x\",\"actor\":{\"id\":900}},{\"timestamp\":\"$AFTER\",\"ref\":\"refs/heads/x\",\"actor\":{\"id\":5}}]"
}

PATH_SAVE=$PATH
run() { # run [args...] -> $tmp/out, $tmp/err, $rc ; default args o/r --since $SINCE
  [ $# -gt 0 ] || set -- o/r --since "$SINCE"
  rm -f "$STUBS/gh.log" "$STUBS/tok.log"
  rc=0
  TMPDIR="$tmp/tmpdir" PATH="$tmp/ghbin:$PATH_SAVE" "$tmp/bin/wow-readback" "$@" >"$tmp/out" 2>"$tmp/err" </dev/null || rc=$?
}
result() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' "$tmp/out"; }
detail() { awk -F'\t' -v k="$1" '$1 == k { print $3 }' "$tmp/out"; }
expect() { # expect <label> <exit> <check> <result>
  assert_eq "$1: exit" "$2" "$rc"
  assert_eq "$1: $3" "$4" "$(result "$3")"
}

# --- all clean -------------------------------------------------------------------------------
setup_ok; run o/r --since "$SINCE" --until "$UNTIL_LATE"
assert_eq "clean: exit 0" 0 "$rc"
assert_eq "clean: header" "check	result	detail" "$(sed -n 1p "$tmp/out")"
assert_eq "clean: the lines, in order" "drift checks
by id checks
history checks
drift approval
by id approval
history approval
default-branch activity
admin App activity
active workflows
environment rel
repo settings
audit log: default branch
audit log: rename" "$(sed 1d "$tmp/out" | cut -f1)"
assert_eq "clean: no fail line" 0 "$(awk -F'\t' '$2 == "fail"' "$tmp/out" | wc -l | tr -d ' ')"
assert_eq "clean: eleven pass lines" 11 "$(awk -F'\t' '$2 == "pass"' "$tmp/out" | wc -l | tr -d ' ')"
assert_eq "clean: two by hand lines" 2 "$(awk -F'\t' '$2 == "by hand"' "$tmp/out" | wc -l | tr -d ' ')"
assert_eq "clean: every line has three fields" 0 "$(awk -F'\t' 'NF != 3' "$tmp/out" | wc -l | tr -d ' ')"
case "$(detail 'audit log: default branch')" in *"repo:o/r"*"from $SINCE to the time of the search"*) echo "ok - clean: default-branch search names the repo and --since" ;; *) echo "FAIL - clean: default-branch search: $(detail 'audit log: default branch')" >&2; fail=1 ;; esac
case "$(detail 'audit log: rename')" in *"action:repo.rename"*"from $SINCE to the time of the search"*) echo "ok - clean: rename search names --since" ;; *) echo "FAIL - clean: rename search" >&2; fail=1 ;; esac
assert_eq "clean: --until is not in the by hand lines" 0 "$(grep -c "$UNTIL_LATE" "$tmp/out" || true)"
assert_eq "clean: the default-branch row names the branch" "no activity on main in the window" "$(detail 'default-branch activity')"
assert_eq "clean: every call carried the token" 0 "$(grep -c bad "$STUBS/tok.log" || true)"
assert_eq "clean: the revoke line on stderr" "wow-readback: done; revoke the admin token now: wow-admin o/r --revoke" "$(tail -n 1 "$tmp/err")"

# --- CR-ending tool output ------------------------------------------------------------------
setup_ok; rm -f "$STUBS/gh.log" "$STUBS/tok.log"; rc=0
TMPDIR="$tmp/tmpdir" PATH="$tmp/ghbin:$tmp/crbin:$PATH_SAVE" "$tmp/bin/wow-readback" o/r --since "$SINCE" >"$tmp/out" 2>"$tmp/err" </dev/null || rc=$?
assert_eq "CR-ending tools: exit 0" 0 "$rc"
assert_eq "CR-ending tools: eleven pass lines" 11 "$(awk -F'\t' '$2 == "pass"' "$tmp/out" | wc -l | tr -d ' ')"

# --- ruleset by id and history ----------------------------------------------------------------
setup_ok; put repos/o/r/rulesets/1 "{\"bypass_actors\":[],\"created_at\":\"$BEFORE\",\"updated_at\":\"$AFTER\"}"; run
expect "updated after --since" 1 "by id checks" fail
assert_eq "updated after --since: the other ruleset passes" pass "$(result 'by id approval')"
setup_ok; put repos/o/r/rulesets/1 "{\"bypass_actors\":[],\"created_at\":\"$BEFORE\",\"updated_at\":\"$AFTER\"}"; run o/r --since "$SINCE" --until "$UNTIL_EARLY"
expect "updated after --until still fails" 1 "by id checks" fail
setup_ok; put repos/o/r/rulesets/2 "{\"bypass_actors\":[],\"created_at\":\"$AFTER\",\"updated_at\":\"$BEFORE\"}"; run
expect "recreated (created_at after --since)" 1 "by id approval" fail
setup_ok; put repos/o/r/rulesets '[{"id":2,"name":"approval"}]'; run
expect "a declared name with no match" 1 "by id checks" fail
assert_eq "no match: history fails too" fail "$(result 'history checks')"
setup_ok; put repos/o/r/rulesets '[{"id":1,"name":"checks"},{"id":3,"name":"checks"},{"id":2,"name":"approval"}]'; run
expect "two matches by name" 1 "by id checks" fail
setup_ok; put repos/o/r/rulesets/1/history "[{\"updated_at\":\"$AFTER\"}]"; run
expect "a history entry after --since" 1 "history checks" fail
setup_ok; put repos/o/r/rulesets/1/history "[{\"updated_at\":\"$BEFORE\"},{\"updated_at\":\"$BEFORE\"}]"; run
expect "a history entry before --since" 0 "history checks" pass
setup_ok; put repos/o/r/rulesets/1 "{\"bypass_actors\":[],\"created_at\":\"${SINCE_DAY}T00:00:00.123Z\",\"updated_at\":\"$BEFORE\"}"; run
expect "a fractional-second time just after --since" 1 "by id checks" fail
setup_ok; put repos/o/r/rulesets/1 "{\"bypass_actors\":[],\"created_at\":\"${PREV_DAY}T23:30:00-00:30\",\"updated_at\":\"$BEFORE\"}"; run
expect "an offset time equal to --since" 1 "by id checks" fail
setup_ok; put repos/o/r/rulesets/1 "{\"bypass_actors\":[],\"created_at\":\"${SINCE_DAY}T01:00:00+02:00\",\"updated_at\":\"$BEFORE\"}"; run
expect "an offset time just before --since" 0 "by id checks" pass
setup_ok; put repos/o/r/rulesets/1 "{\"bypass_actors\":[],\"created_at\":\"yesterday\",\"updated_at\":\"$BEFORE\"}"; run
expect "a time that does not parse" 1 "by id checks" fail

# --- tag bypass -------------------------------------------------------------------------------
tagyml() { YML='pr_base: main
rulesets:
  - name: tags
    source: repo
    target: tag
    rule_types: [deletion]
    ref_patterns: ["refs/tags/v*"]
'; }
rules_tag='{"id":1,"name":"tags","target":"tag","enforcement":"active","rules":[{"type":"deletion"}],"conditions":{"ref_name":{"include":["refs/tags/v*"],"exclude":[]}}'
tag_setup() {
  setup_ok; tagyml
  printf '%s' "$YML" >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"
  put repos/o/r/rulesets '[{"id":1,"name":"tags"}]'
  put repos/o/r/rulesets/1/history '[]'
}
tag_setup
put repos/o/r/rulesets/1 "$rules_tag,\"bypass_actors\":[],\"created_at\":\"$BEFORE\",\"updated_at\":\"$BEFORE\"}"
run
expect "a tag ruleset with no bypass actor" 0 "tag bypass tags" pass
tag_setup
put repos/o/r/rulesets/1 "$rules_tag,\"bypass_actors\":[{\"actor_id\":1,\"actor_type\":\"RepositoryRole\"}],\"created_at\":\"$BEFORE\",\"updated_at\":\"$BEFORE\"}"
run
expect "a tag entry with a bypass actor" 1 "tag bypass tags" fail
tag_setup
put repos/o/r/rulesets/1 "$rules_tag,\"created_at\":\"$BEFORE\",\"updated_at\":\"$BEFORE\"}"
run
expect "a tag entry whose bypass_actors is absent" 1 "tag bypass tags" fail
tag_setup
put repos/o/r/rulesets/1 "$rules_tag,\"bypass_actors\":null,\"created_at\":\"$BEFORE\",\"updated_at\":\"$BEFORE\"}"
run
expect "a tag entry whose bypass_actors is null" 1 "tag bypass tags" fail
YML='pr_base: main
rulesets:
  - name: checks
    source: repo
    rule_types: [required_status_checks, deletion]
    required_checks: [lint]
  - name: approval
    source: repo
    rule_types: [pull_request]
'
setup_ok; run
assert_eq "a branch entry has no tag bypass line" 0 "$(grep -c '^tag bypass' "$tmp/out" || true)"

# --- default-branch activity --------------------------------------------------------------------
setup_ok; put "$ACT_B" "[{\"timestamp\":\"$AFTER\",\"ref\":\"refs/heads/main\",\"actor\":{\"id\":5}}]"; run
expect "a default-branch entry inside the window" 1 "default-branch activity" fail
setup_ok; put "$ACT_B" "[{\"timestamp\":\"$BEFORE\",\"ref\":\"refs/heads/main\",\"actor\":{\"id\":5}}]"; run
expect "a default-branch entry before the window" 0 "default-branch activity" pass
setup_ok; put "$ACT_B" "[{\"timestamp\":\"$AFTER\",\"actor\":{\"id\":5}}]"; run o/r --since "$SINCE" --until "$UNTIL_EARLY"
expect "a default-branch entry after --until" 0 "default-branch activity" pass
setup_ok; printf '[{"timestamp":"%s","actor":{"id":5}}]\n[{"timestamp":"%s","actor":{"id":5}}]\n' "$BEFORE" "$AFTER" >"$STUBS/$(ep_key "$ACT_B")"; run
expect "an entry on a second page inside the window" 1 "default-branch activity" fail
setup_ok; put "$ACT_B" "[{\"timestamp\":\"nope\"}]"; run
expect "an activity entry whose time does not parse" 1 "default-branch activity" fail

# --- admin App activity -------------------------------------------------------------------------
setup_ok; put "$ACT_ALL" "[{\"timestamp\":\"$AFTER\",\"ref\":\"refs/heads/other\",\"actor\":{\"id\":900}}]"; run
expect "an admin App entry on another ref inside the window" 1 "admin App activity" fail
setup_ok; put "$ACT_ALL" "[{\"timestamp\":\"$AFTER\",\"ref\":\"refs/heads/other\",\"actor\":{\"id\":5}}]"; run
expect "another actor's entry on another ref" 0 "admin App activity" pass
setup_ok; put "$ACT_ALL" "[{\"timestamp\":\"$AFTER\",\"ref\":\"refs/heads/other\",\"actor\":null}]"; run
expect "a null actor inside the window" 1 "admin App activity" fail
setup_ok; printf '{"admin":{}}\n' >"$WOW_HOME/apps.json"; run
expect "no bot_user_id" 1 "admin App activity" fail
setup_ok; printf '{"admin":{"bot_user_id":"x9"}}\n' >"$WOW_HOME/apps.json"; run
expect "a non-numeric bot_user_id" 1 "admin App activity" fail

# --- drift --------------------------------------------------------------------------------------
setup_ok; put repos/o/r/rules/branches/main '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[]}},{"type":"deletion","ruleset_id":1},{"type":"pull_request","ruleset_id":2,"parameters":{"require_code_owner_review":true,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true,"required_approving_review_count":1}}]'; run
expect "a drift line with a non-empty list" 1 "drift checks" fail
assert_eq "a drift line with a non-empty list: the other ruleset passes" pass "$(result 'drift approval')"
setup_ok; put repos/o/r/rulesets/2 "{\"bypass_actors\":[{\"actor_id\":1}],\"created_at\":\"$BEFORE\",\"updated_at\":\"$BEFORE\"}"; run
expect "a bypass actor in the drift line" 1 "drift approval" fail
setup_ok; drop_ep repos/o/r/rules/branches/main; run
expect "an inconclusive drift run" 1 "drift checks" fail

# --- a source: org entry ------------------------------------------------------------------------
setup_ok
printf 'rulesets:\n  - name: orgrule\n    source: org\n    rule_types: [pull_request]\n' >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"
run
expect "a source: org entry" 1 "ruleset orgrule" fail
assert_eq "a source: org entry: exactly one line for it" 1 "$(grep -c 'orgrule' "$tmp/out" || true)"

# --- a name with a control character ----------------------------------------------------------
setup_ok
printf 'rulesets:\n  - name: "a\\x01b"\n    source: repo\n    rule_types: [deletion]\n' >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"
run
assert_eq "an unreadable name: exit 1" 1 "$rc"
assert_eq "an unreadable name: its drift line fails" fail "$(result 'drift #0')"
assert_eq "an unreadable name: its by id line fails" fail "$(result 'by id #0')"
assert_eq "an unreadable name: the control byte is not printed" 0 "$(LC_ALL=C grep -c "$(printf '\001')" "$tmp/out" || true)"

# --- no rulesets list ---------------------------------------------------------------------------
for body in 'identities: {}' 'rulesets: []' 'rulesets: nope'; do
  setup_ok; printf '%s\n' "$body" >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"; run
  assert_eq "[$body]: exit 1" 1 "$rc"
  assert_eq "[$body]: one rulesets fail line" fail "$(result rulesets)"
  assert_eq "[$body]: the activity rows still run" pass "$(result 'default-branch activity')"
done
setup_ok; rm -f "$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"; run
assert_eq "an unreadable project file: rulesets fails" fail "$(result rulesets)"
assert_eq "an unreadable project file: the activity rows still run" pass "$(result 'admin App activity')"

# --- reads that fail ----------------------------------------------------------------------------
setup_ok; fail_ep "$ACT_B"; run
expect "a failed default-branch activity read" 1 "default-branch activity" fail
setup_ok; fail_ep "$ACT_ALL"; run
expect "a failed all-refs activity read" 1 "admin App activity" fail
setup_ok; fail_ep repos/o/r/rulesets/1/history; run
expect "a failed history read" 1 "history checks" fail
setup_ok; fail_ep repos/o/r/rulesets/1; run
expect "a failed by-id read" 1 "by id checks" fail
setup_ok; fail_ep repos/o/r/rulesets; run
expect "a failed rulesets list read" 1 "by id checks" fail
setup_ok; fail_ep repos/o/r; run
expect "a failed repo read" 1 "default-branch activity" fail
assert_eq "a failed repo read: the rulesets line fails" fail "$(result rulesets)"

# --- active workflows --------------------------------------------------------------------------
WF_ALL='{"total_count":2,"workflows":[{"path":".github/workflows/ci.yml","state":"active"},{"path":".github/workflows/x.yml","state":"active"}]}'
setup_ok; run
assert_eq "clean: the active workflows row counts what it compared" "1 active workflows compared, each with a tracked file on main" "$(detail 'active workflows')"
setup_ok; put repos/o/r/actions/workflows "$WF_ALL"; run
expect "an active workflow with no tracked file" 1 "active workflows" fail
assert_eq "an untracked workflow: the detail names it" "1 active workflows with no tracked file on main: .github/workflows/x.yml" "$(detail 'active workflows')"
for other in 'environment rel' 'repo settings'; do
  assert_eq "an untracked workflow: $other is unaffected" pass "$(result "$other")"
done
setup_ok; put repos/o/r/actions/workflows '{"total_count":1,"workflows":[{"path":".github/workflows/x.yml","state":"disabled_manually"}]}'; run
expect "a disabled untracked workflow" 0 "active workflows" pass
setup_ok; put repos/o/r/actions/workflows '{"total_count":1,"workflows":[{"path":"dynamic/a/b","state":"active"}]}'; run
expect "a dynamic/ workflow" 0 "active workflows" pass
setup_ok; printf '%s\n%s\n' '{"total_count":2,"workflows":[{"path":".github/workflows/ci.yml","state":"active"}]}' '{"total_count":2,"workflows":[{"path":".github/workflows/x.yml","state":"active"}]}' >"$STUBS/$(ep_key repos/o/r/actions/workflows)"; run
expect "an untracked workflow on a second page" 1 "active workflows" fail
setup_ok; put "$WF_KEY" '[{"type":"dir","path":".github/workflows/ci.yml"}]'; run
expect "a tracked path that is a directory" 1 "active workflows" fail
setup_ok; fail_ep repos/o/r/actions/workflows; run
expect "a failed workflows read" 1 "active workflows" fail
setup_ok; fail_ep "$WF_KEY"; run
expect "a failed directory read" 1 "active workflows" fail
setup_ok; drop_ep "$WF_KEY"; run
expect "a missing workflows directory" 1 "active workflows" fail
setup_ok; put "$WF_KEY" '{"type":"file","path":".github/workflows"}'; run
expect "a directory listing that is not a list" 1 "active workflows" fail
setup_ok; put repos/o/r/actions/workflows '{"workflows":[{"path":3,"state":"active"}]}'; run
expect "a workflow entry of the wrong shape" 1 "active workflows" fail
setup_ok; put repos/o/r/actions/workflows '[1]'; run
expect "a workflows page of the wrong shape" 1 "active workflows" fail
setup_ok; fail_ep repos/o/r; run
expect "no default branch" 1 "active workflows" fail

# --- environments -------------------------------------------------------------------------------
envp() { put repos/o/r/environments/rel "$1"; }
env_json() { # env_json <reviewers-json> <policy-json> <bypass-json>
  printf '{"name":"rel","can_admins_bypass":%s,"protection_rules":[{"type":"required_reviewers","reviewers":%s}],"deployment_branch_policy":%s}' "$3" "$1" "$2"
}
REV7='[{"type":"User","reviewer":{"id":7}}]'
POL_C='{"protected_branches":false,"custom_branch_policies":true}'
envcase() { # envcase <label> <env json> -> the environment row fails alone
  setup_ok; envp "$2"; run
  expect "$1" 1 "environment rel" fail
  assert_eq "$1: the other new rows are unaffected" "pass pass" "$(result 'active workflows') $(result 'repo settings')"
}
envcase "an extra reviewer" "$(env_json '[{"type":"User","reviewer":{"id":7}},{"type":"User","reviewer":{"id":8}}]' "$POL_C" false)"
assert_eq "reviewers: the detail names only reviewers" "reviewers differ" "$(detail 'environment rel')"
envcase "a missing reviewer" "$(env_json '[]' "$POL_C" false)"
envcase "a Team where a User of the same id is declared" "$(env_json '[{"type":"Team","reviewer":{"id":7}}]' "$POL_C" false)"
envcase "a live reviewer with no readable id" '{"name":"rel","can_admins_bypass":false,"protection_rules":[{"type":"required_reviewers","reviewers":[{"type":"User","reviewer":{"id":7}},{"type":"Team","reviewer":null}]}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
assert_eq "an unreadable reviewer: the detail says could not be read" "reviewers could not be read (a read failed, or a value was absent or the wrong type)" "$(detail 'environment rel')"
envcase "no protection_rules" '{"name":"rel","can_admins_bypass":false,"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
envcase "branch policy all against custom" "$(env_json "$REV7" null false)"
assert_eq "branch policy: named" "branch policy differ" "$(detail 'environment rel')"
envcase "branch policy protected against custom" "$(env_json "$REV7" '{"protected_branches":true,"custom_branch_policies":false}' false)"
envcase "a branch policy of neither kind" "$(env_json "$REV7" '{"protected_branches":true,"custom_branch_policies":true}' false)"
envcase "a missing deployment_branch_policy" '{"name":"rel","can_admins_bypass":false,"protection_rules":[{"type":"required_reviewers","reviewers":[{"type":"User","reviewer":{"id":7}}]}]}'
envcase "admins can bypass" "$(env_json "$REV7" "$POL_C" true)"
assert_eq "bypass: named" "admin bypass differ" "$(detail 'environment rel')"
envcase "can_admins_bypass absent" '{"name":"rel","protection_rules":[{"type":"required_reviewers","reviewers":[{"type":"User","reviewer":{"id":7}}]}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
setup_ok; put repos/o/r/environments/rel/deployment-branch-policies '{"total_count":2,"branch_policies":[{"name":"main","type":"branch"},{"name":"dev","type":"branch"}]}'; run
expect "a branch-name set that differs" 1 "environment rel" fail
assert_eq "branches: named" "branches differ" "$(detail 'environment rel')"
setup_ok; put repos/o/r/environments/rel/deployment-branch-policies '{"total_count":1,"branch_policies":[{"name":"v1","type":"tag"}]}'; run
expect "a tag-type policy" 1 "environment rel" fail
setup_ok; put repos/o/r/environments/rel/deployment-branch-policies '{"total_count":2,"branch_policies":[{"name":"main","type":"branch"},{"name":"v1","type":"tag"}]}'; run
expect "a tag-type policy beside the declared branch" 1 "environment rel" fail
setup_ok; printf '%s\n%s\n' '{"total_count":2,"branch_policies":[{"name":"main","type":"branch"}]}' '{"total_count":2,"branch_policies":[{"name":"dev","type":"branch"}]}' >"$STUBS/$(ep_key repos/o/r/environments/rel/deployment-branch-policies)"; run
expect "a second page of branch policies that adds a name" 1 "environment rel" fail
setup_ok; fail_ep repos/o/r/environments/rel/deployment-branch-policies; run
expect "a failed branch-policies read" 1 "environment rel" fail
setup_ok; drop_ep repos/o/r/environments/rel; run
expect "a 404 on the environment read" 1 "environment rel" fail
# the environment list and its rule
envyml() { # envyml <text>: the project file with the given environments text after the rulesets
  printf '%s%s' "$YML" "$1" >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"
}
envone() { # envone <label> <text>: one environments fail line, no environment read
  setup_ok; envyml "$2"; run
  assert_eq "$1: exit 1" 1 "$rc"
  assert_eq "$1: one environments fail line" fail "$(result environments)"
  assert_eq "$1: no environment row" 0 "$(grep -c '^environment ' "$tmp/out" || true)"
  assert_eq "$1: no environment read" 0 "$(grep -c 'repos/o/r/environments' "$STUBS/gh.log" || true)"
}
envone "an environments scalar" 'environments: rel
'
envone "an environments map" 'environments: {name: rel}
'
envone "a bad name" 'environments:
  - { name: "-rel", reviewers: [], branch_policy: all, branches: null, admins_can_bypass: false }
'
envone "a name with a newline" 'environments:
  - { name: "rel\n", reviewers: [], branch_policy: all, branches: null, admins_can_bypass: false }
'
envone "a duplicated name" 'environments:
  - { name: rel, reviewers: [], branch_policy: all, branches: null, admins_can_bypass: false }
  - { name: rel, reviewers: [], branch_policy: all, branches: null, admins_can_bypass: false }
'
envone "a repeated reviewer" 'environments:
  - { name: rel, reviewers: [{ type: User, id: 7 }, { type: User, id: 7 }], branch_policy: all, branches: null, admins_can_bypass: false }
'
envone "branches under all" 'environments:
  - { name: rel, reviewers: [], branch_policy: all, branches: [main], admins_can_bypass: false }
'
envone "a string admins_can_bypass" 'environments:
  - { name: rel, reviewers: [], branch_policy: all, branches: null, admins_can_bypass: "false" }
'
setup_ok; drop_ep 'repos/o/r/contents/.ai/project.yml?ref=main'; run
assert_eq "an unreadable project file: environments fails" fail "$(result environments)"
for body in 'none' 'environments: null
' 'environments: []
'; do
  setup_ok; if [ "$body" = none ]; then envyml ''; else envyml "$body"; fi; run
  assert_eq "no environments declared [$(printf '%s' "$body" | head -n 1)]: exit 0" 0 "$rc"
  assert_eq "no environments declared [$(printf '%s' "$body" | head -n 1)]: one environments pass line" pass "$(result environments)"
  assert_eq "no environments declared [$(printf '%s' "$body" | head -n 1)]: no environment row" 0 "$(grep -c '^environment ' "$tmp/out" || true)"
done
setup_ok; envyml 'environments:
  - { name: rel, reviewers: [{ type: User, id: 7 }], branch_policy: custom, branches: [main], admins_can_bypass: false }
  - { name: stage, reviewers: [], branch_policy: protected, branches: null, admins_can_bypass: true }
'
put repos/o/r/environments/stage '{"name":"stage","can_admins_bypass":true,"protection_rules":[],"deployment_branch_policy":{"protected_branches":true,"custom_branch_policies":false}}'; run
assert_eq "two declared environments: exit 0" 0 "$rc"
assert_eq "two declared environments: in list order" "environment rel
environment stage" "$(grep '^environment ' "$tmp/out" | cut -f1)"
setup_ok; put repos/o/r/environments/other '{"name":"other","can_admins_bypass":true}'; run
assert_eq "an undeclared environment is not read" 0 "$(grep -c 'environments/other' "$STUBS/gh.log" || true)"

# --- repo settings ------------------------------------------------------------------------------
setup_ok; run
assert_eq "clean: repo settings names the judged fields" "judged: default_branch, default_workflow_permissions, can_approve_pull_request_reviews" "$(detail 'repo settings')"
rsyml() { printf '%s%s%s' "$YML" "$ENVY" "$1" >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"; }
rscase() { # rscase <label> <fail|pass>
  expect "$1" "$([ "$2" = fail ] && echo 1 || echo 0)" "repo settings" "$2"
  assert_eq "$1: the other new rows are unaffected" "pass pass" "$(result 'active workflows') $(result 'environment rel')"
}
setup_ok; put repos/o/r/actions/permissions/workflow '{"default_workflow_permissions":"write","can_approve_pull_request_reviews":false}'; run
rscase "a write workflow token with no repo_settings" fail
assert_eq "write token: named" "default_workflow_permissions differs" "$(detail 'repo settings')"
setup_ok; put repos/o/r/actions/permissions/workflow '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":true}'; run
rscase "Actions approving PRs with no repo_settings" fail
setup_ok; put repos/o/r '{"default_branch":"main","allow_merge_commit":false,"allow_squash_merge":false,"allow_rebase_merge":true,"allow_auto_merge":true}'; run
rscase "merge methods and auto-merge are not judged with no repo_settings" pass
setup_ok; rsyml 'repo_settings: { merge_methods: [merge, squash], auto_merge: false }
'; run
rscase "merge methods and auto-merge matching once declared" pass
assert_eq "declared: the detail names the fields" "judged: default_branch, default_workflow_permissions, can_approve_pull_request_reviews, allow_merge_commit, allow_squash_merge, allow_rebase_merge, allow_auto_merge" "$(detail 'repo settings')"
setup_ok; rsyml 'repo_settings: { merge_methods: [squash] }
'; run
rscase "a merge method that differs once declared" fail
assert_eq "merge methods: named" "allow_merge_commit differs" "$(detail 'repo settings')"
setup_ok; rsyml 'repo_settings: { auto_merge: true }
'; run
rscase "auto-merge that differs once declared" fail
setup_ok; put repos/o/r '{"default_branch":"main","allow_merge_commit":true,"allow_squash_merge":true,"allow_rebase_merge":false}'; rsyml 'repo_settings: { auto_merge: false }
'; run
rscase "a declared auto-merge with the field absent" fail
setup_ok; put repos/o/r/actions/permissions/workflow '{"default_workflow_permissions":"write","can_approve_pull_request_reviews":true}'; rsyml 'repo_settings: { workflow_permissions: write, actions_can_approve: true }
'; run
rscase "an override that matches a non-default live value" pass
setup_ok; put repos/o/r '{"default_branch":"trunk","allow_merge_commit":true,"allow_squash_merge":true,"allow_rebase_merge":false,"allow_auto_merge":false}'
cp "$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')" "$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=trunk')"; run
assert_eq "a default branch that is not pr_base: exit 1" 1 "$rc"
assert_eq "a default branch that is not pr_base: the row fails" fail "$(result 'repo settings')"
assert_eq "default_branch: named" "default_branch differs" "$(detail 'repo settings')"
setup_ok; fail_ep repos/o/r/actions/permissions/workflow; run
rscase "a failed workflow-permissions read" fail
setup_ok; put repos/o/r/actions/permissions/workflow '{"default_workflow_permissions":"read"}'; run
rscase "a workflow-permissions read with a field absent" fail
for body in 'repo_settings: [merge]
' 'repo_settings: { merge_methods: [ff] }
' 'repo_settings: { workflow_permissions: admin }
' 'repo_settings: { unknown: 1 }
'; do
  setup_ok; rsyml "$body"; run
  rscase "a malformed repo_settings [$(printf '%s' "$body" | head -n 1)]" fail
done
setup_ok; printf '%s%s' "$(printf '%s' "$YML" | sed '/^pr_base/d')" "$ENVY" >"$STUBS/$(ep_key 'repos/o/r/contents/.ai/project.yml?ref=main')"; run
expect "no pr_base" 1 "repo settings" fail
setup_ok; drop_ep 'repos/o/r/contents/.ai/project.yml?ref=main'; run
expect "an unreadable project file: repo settings" 1 "repo settings" fail

# --- stops before any request ---------------------------------------------------------------------
stops() { # stops <label>: exit 1, no table, no request but the installation read
  assert_eq "$1: exit 1" 1 "$rc"
  assert_eq "$1: no table" "" "$(cat "$tmp/out")"
  if [ -f "$STUBS/gh.log" ]; then n=$(grep -vc 'installation/repositories' "$STUBS/gh.log" || true); else n=0; fi
  assert_eq "$1: no row endpoint requested" 0 "$n"
}
setup_ok; rm -f "$WOW_HOME/tokens/o/r/admin-token"; run
stops "a missing token file"
assert_eq "a missing token file: no gh call at all" 0 "$([ -f "$STUBS/gh.log" ] && wc -l <"$STUBS/gh.log" | tr -d ' ' || echo 0)"
case "$(cat "$tmp/err")" in *"wow-admin o/r --revoke"*"wow-admin o/r --perms administration=write,contents=read,actions=read"*) echo "ok - a stop names the revoke and the mint" ;; *) echo "FAIL - a stop names the revoke and the mint: $(cat "$tmp/err")" >&2; fail=1 ;; esac
setup_ok; write_token "$TOKEN" 2000-01-01T00:00:00Z; run
stops "an expired token"
assert_eq "an expired token: no gh call at all" 0 "$([ -f "$STUBS/gh.log" ] && wc -l <"$STUBS/gh.log" | tr -d ' ' || echo 0)"
setup_ok; write_token "ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD" 2099-01-01T00:00:00Z; run
stops "a user-shaped token"
setup_ok; fail_ep installation/repositories; run
stops "a failed installation read"
setup_ok; put installation/repositories '{"repositories":[{"full_name":"o/other"}]}'; run
stops "an installation that does not list the repo"

# --- usage -----------------------------------------------------------------------------------
setup_ok
usage_case() { # usage_case <label> <args...>
  l=$1; shift
  run "$@"
  assert_eq "usage: $l exits 2" 2 "$rc"
  assert_eq "usage: $l makes no gh call" 0 "$([ -f "$STUBS/gh.log" ] && wc -l <"$STUBS/gh.log" | tr -d ' ' || echo 0)"
}
usage_case "no --since" o/r
usage_case "an empty --since" o/r --since ""
usage_case "a malformed --since" o/r --since 2026-11-01
usage_case "a --since with an offset" o/r --since "${SINCE%Z}+00:00"
usage_case "an impossible date" o/r --since 2026-02-30T00:00:00Z
usage_case "a malformed --until" o/r --since "$SINCE" --until tomorrow
usage_case "--since after --until" o/r --since "$AFTER" --until "$SINCE"
usage_case "--since in the future" o/r --since 2999-01-01T00:00:00Z
usage_case "--since over 365 days back" o/r --since 2020-01-01T00:00:00Z
usage_case "a repeated --since" o/r --since "$SINCE" --since "$SINCE"
usage_case "an unknown flag" o/r --since "$SINCE" --x
usage_case "no repo" --since "$SINCE"
for r in "r" "o/r/x" "/r" "o/" "-o/r" "o/-r" "./r" "../r" "o/." "o/.." "o/r;x" ""; do
  usage_case "repo [$r]" "$r" --since "$SINCE"
done
rc=0; "$tmp/bin/wow-readback" >/dev/null 2>&1 </dev/null || rc=$?
assert_eq "usage: no arguments exits 2" 2 "$rc"

# --- reads only ------------------------------------------------------------------------------
setup_ok; run
assert_eq "the log has calls" ok "$([ -s "$STUBS/gh.log" ] && echo ok || echo empty)"
assert_eq "no logged call carries a method, field or input flag" 0 "$(grep -cE -- '(^| )(-X|--method|-f|-F|--field|--raw-field|--input)( |$)' "$STUBS/gh.log" || true)"
assert_eq "every logged call is gh api with --hostname github.com or GH_HOST=github.com" 0 \
  "$(grep -vcE -- '^GH_HOST= api --hostname github.com |^GH_HOST=github.com api ' "$STUBS/gh.log" || true)"
assert_eq "every call carried the admin token" 0 "$(grep -c bad "$STUBS/tok.log" || true)"
assert_eq "no gh api call in the script carries a method, field or input flag" 0 \
  "$(grep -E 'gh api' "$root_dir/scripts/identity/wow-readback" | grep -vE '^[[:space:]]*#' | grep -cE -- ' (-X|--method|-f|-F|--field|--raw-field|--input)( |$)' || true)"
leak=0
for f in "$tmp/out" "$tmp/err" "$STUBS/gh.log"; do grep -q "$TOKEN" "$f" && leak=1; done
assert_eq "the token is in none of stdout, stderr or the recorded argv" 0 "$leak"

# --- $WOW_HOME untouched, temp files gone ----------------------------------------------------
snap() { (cd "$WOW_HOME" && find . -print | sort | while read -r p; do [ -d "$p" ] && echo "$p" || { echo "$p"; cksum <"$p"; }; done); }
setup_ok; before=$(snap); run; after=$(snap)
assert_eq "\$WOW_HOME is unchanged by a run" "$before" "$after"
assert_eq "no temp file is left after a run" "" "$(ls -A "$tmp/tmpdir")"
setup_ok; rm -f "$WOW_HOME/tokens/o/r/admin-token"; run
assert_eq "no temp file is left after a stopped run" "" "$(ls -A "$tmp/tmpdir")"

# --- install table ---------------------------------------------------------------------------
assert_eq "install-host-tools.ps1 installs wow-readback" 1 \
  "$(grep -c "^  ,@('scripts/identity/wow-readback', 'wow-readback')\$" "$root_dir/scripts/identity/install-host-tools.ps1" || true)"
assert_eq "install-host-tools.ps1 installs ruleset-drift.sh beside it" 1 \
  "$(grep -c "^  ,@('plugins/way-of-working/bin/ruleset-drift.sh', 'ruleset-drift.sh')\$" "$root_dir/scripts/identity/install-host-tools.ps1" || true)"

exit "$fail"
