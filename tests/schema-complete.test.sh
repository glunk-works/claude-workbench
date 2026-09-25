#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/schema-complete.sh (WB-D17, #142).
#
# Runs the REAL script against real, throwaway `.ai/project.yml`-shaped files built
# from one base fixture (`complete.yml`) with single, targeted edits -- the same
# "one real difference per fixture" discipline plan-anchor.test.sh uses, so a
# failure names exactly which check regressed. `yq` is a hard dependency of the
# script itself (see its header), so this suite needs the real mikefarah `yq` on
# PATH -- the one fixture that needs it ABSENT hides it via a PATH-scoped shim
# directory (`review-base-anchor.test.sh`'s own pattern), never by clearing PATH
# outright, which would also break the POSIX utilities this test script itself
# uses (mkdir, sed, cat).
#
# Permitted toolset: POSIX sh, real `yq` on PATH, `git` (only for the
# check-ref-format shape-check fixtures -- the script's own dependency, not an
# extra one this suite adds). No jq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/schema-complete.sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "skip - schema-complete.sh fixtures: no yq on PATH" >&2
  exit 0
fi

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

run_check() { "$script" check "$1"; }

# --- the base fixture: every required key present and well-formed ----------
base="$tmp/complete.yml"
cat >"$base" <<'EOF'
repo: acme/widgets
pr_base: main
migration_base: null

roadmap: docs/roadmap.md
sprints_dir: sprints
threat_model: docs/roadmap.md

planning:
  kind: files

decisions:
  log: docs/roadmap.md
  prefix: WB-D

backlog:
  kind: github_issues
  repo: null
  path: null
  item_prefix: null

load_bearing_docs:
  - CLAUDE.md

code_paths:
  - src/

gates:
  green:
    - { run: echo ok }

ruleset:
  name: protected
  rule_types: [deletion]
  required_checks: [lint]

review:
  ci_gate: null

agents:
  enabled: [architect]
models:
  architect: opus
  coder: sonnet
  second_opinion: null
EOF

echo "# keys"

expected_keys="repo
pr_base
migration_base
roadmap
sprints_dir
threat_model
planning.kind
decisions.log
decisions.prefix
backlog.kind
backlog.repo
backlog.path
backlog.item_prefix
load_bearing_docs
code_paths
gates.green
ruleset.name
ruleset.rule_types
ruleset.required_checks
agents.enabled
models.architect
models.coder
models.second_opinion
review.ci_gate
review.ci_gate.check if-map
review.ci_gate.header if-map
review.ci_gate.attestation if-map
review.ci_gate.triggers_on if-map"
assert_eq "keys: the exact required path set, conditionals suffixed if-map" \
  "$expected_keys" "$("$script" keys)"

echo "# check -- the complete fixture"

assert_eq "check: every required key present and well-formed is complete" \
  "complete" "$(run_check "$base")"

echo "# check -- each nullable key absent (its whole line removed) is 'missing ... nullable'"

f="$tmp/absent_migration_base.yml"; grep -v '^migration_base:' "$base" >"$f"
assert_eq "missing migration_base (line removed entirely)" \
  "incomplete
missing migration_base nullable" "$(run_check "$f")"

f="$tmp/absent_backlog_repo.yml"; sed '/^  repo: null$/d' "$base" >"$f"
assert_eq "missing backlog.repo (line removed entirely)" \
  "incomplete
missing backlog.repo nullable" "$(run_check "$f")"

f="$tmp/absent_second_opinion.yml"; grep -v 'second_opinion:' "$base" >"$f"
assert_eq "missing models.second_opinion (line removed entirely)" \
  "incomplete
missing models.second_opinion nullable" "$(run_check "$f")"

f="$tmp/absent_ci_gate.yml"; grep -v 'ci_gate: null' "$base" >"$f"
assert_eq "missing review.ci_gate (line removed entirely)" \
  "incomplete
missing review.ci_gate nullable" "$(run_check "$f")"

echo "# check -- 'key:' with an empty value, and '~', both parse as null and are legal"

f="$tmp/bare_empty_nullable.yml"; sed 's/^  repo: null$/  repo:/' "$base" >"$f"
assert_eq "backlog.repo: (bare, empty value) is a legal null, same as complete" \
  "complete" "$(run_check "$f")"

f="$tmp/tilde_nullable.yml"; sed 's/^  repo: null$/  repo: ~/' "$base" >"$f"
assert_eq "backlog.repo: ~ is a legal null, same as complete" \
  "complete" "$(run_check "$f")"

echo "# check -- each enum, an out-of-set value is 'invalid', not silently accepted"

f="$tmp/bad_planning_kind.yml"; sed 's/kind: files/kind: bogus/' "$base" >"$f"
assert_eq "planning.kind: bogus is invalid" \
  'incomplete
invalid planning.kind "bogus"' "$(run_check "$f")"

f="$tmp/bad_backlog_kind.yml"; sed 's/kind: github_issues/kind: bogus/' "$base" >"$f"
assert_eq "backlog.kind: bogus is invalid" \
  'incomplete
invalid backlog.kind "bogus"' "$(run_check "$f")"

f="$tmp/bad_models_architect.yml"; sed 's/architect: opus/architect: gpt5/' "$base" >"$f"
assert_eq "models.architect: gpt5 (not a harness model name) is invalid" \
  'incomplete
invalid models.architect "gpt5"' "$(run_check "$f")"

echo "# check -- review.ci_gate: null vs. a map missing triggers_on"

f="$tmp/ci_gate_null.yml"
assert_eq "review.ci_gate: null needs no sub-keys -- complete" \
  "complete" "$(run_check "$base")"

f="$tmp/ci_gate_map_missing_triggers_on.yml"
awk '{ if ($0 == "  ci_gate: null") {
         print "  ci_gate:"; print "    check: architect-review";
         print "    header: h"; print "    attestation: a";
       } else print }' "$base" >"$f"
assert_eq "review.ci_gate as a map without triggers_on: missing that one sub-key" \
  "incomplete
missing review.ci_gate.triggers_on nullable" "$(run_check "$f")"

f="$tmp/ci_gate_map_complete.yml"
awk '{ if ($0 == "  ci_gate: null") {
         print "  ci_gate:"; print "    check: architect-review";
         print "    header: h"; print "    attestation: a";
         print "    triggers_on: null";
       } else print }' "$base" >"$f"
assert_eq "review.ci_gate as a map with all four sub-keys (triggers_on: null) is complete" \
  "complete" "$(run_check "$f")"

f="$tmp/ci_gate_not_a_map.yml"; sed 's/  ci_gate: null/  ci_gate: "yes"/' "$base" >"$f"
assert_eq "review.ci_gate: a bare string (neither null nor a map) is invalid" \
  'incomplete
invalid review.ci_gate "yes"' "$(run_check "$f")"

# Round-2 architect + docs-consistency finding: triggers_on's non-null form is a
# LIST (project-schema.md's own documented example: `triggers_on: [src/]`), not a
# scalar -- the type-tag fix that closed the pr_base/repo gap above briefly
# regressed this by rejecting every !!seq through the shapeless catch-all.
f="$tmp/ci_gate_map_triggers_on_list.yml"
awk '{ if ($0 == "  ci_gate: null") {
         print "  ci_gate:"; print "    check: architect-review";
         print "    header: h"; print "    attestation: a";
         print "    triggers_on: [src/]";
       } else print }' "$base" >"$f"
assert_eq "review.ci_gate.triggers_on: [src/] (a list, the documented non-null form) is complete" \
  "complete" "$(run_check "$f")"

f="$tmp/ci_gate_map_triggers_on_scalar.yml"
awk '{ if ($0 == "  ci_gate: null") {
         print "  ci_gate:"; print "    check: architect-review";
         print "    header: h"; print "    attestation: a";
         print "    triggers_on: src/";
       } else print }' "$base" >"$f"
assert_eq "review.ci_gate.triggers_on: src/ (a scalar, not a list) is invalid" \
  'incomplete
invalid review.ci_gate.triggers_on "src/"' "$(run_check "$f")"

echo "# check -- a block-scalar value stays a legal single value, and its invalid form stays ONE line"

f="$tmp/block_scalar_ok.yml"
awk '{ if ($0 == "roadmap: docs/roadmap.md") { print "roadmap: |"; print "  line one"; print "  line two"; } else print }' "$base" >"$f"
assert_eq "roadmap as a block scalar is still a legal 'value' key -- complete" \
  "complete" "$(run_check "$f")"

f="$tmp/block_scalar_bad.yml"
awk '{ if ($0 == "  kind: files") { print "  kind: |"; print "    line one"; print "    line two"; } else print }' "$base" >"$f"
assert_eq "a block scalar where an enum is expected is invalid, reported on ONE line" \
  'incomplete
invalid planning.kind "line one\nline two\n"' "$(run_check "$f")"

echo "# check -- the routing-key shape checks"

f="$tmp/bad_repo_shape.yml"; sed 's#repo: acme/widgets#repo: acme#' "$base" >"$f"
assert_eq "repo without a '/' fails the owner/name shape check" \
  'incomplete
invalid repo "acme"' "$(run_check "$f")"

f="$tmp/bad_repo_shape2.yml"; sed 's#repo: acme/widgets#repo: acme/widgets/extra#' "$base" >"$f"
assert_eq "repo with more than one '/' fails the owner/name shape check" \
  'incomplete
invalid repo "acme/widgets/extra"' "$(run_check "$f")"

f="$tmp/bad_backlog_repo_shape.yml"; sed 's/^  repo: null$/  repo: nope/' "$base" >"$f"
assert_eq "backlog.repo (non-null) also gets the owner/name shape check" \
  'incomplete
invalid backlog.repo "nope"' "$(run_check "$f")"

# Round-3 security-critic finding, confirmed live against a real GitHub API call:
# a "." or ".." segment is syntactically owner/name-shaped (one slash, non-empty
# both sides, safe charset) but is a path-traversal token GitHub's own API
# actually walks -- `gh api repos/../user` resolves to `/user`, not a 404.
f="$tmp/backlog_repo_path_traversal.yml"; sed 's/^  repo: null$/  repo: "..\/user"/' "$base" >"$f"
assert_eq 'backlog.repo: "../user" (path traversal, not a real owner) is invalid' \
  'incomplete
invalid backlog.repo "../user"' "$(run_check "$f")"

f="$tmp/repo_path_traversal.yml"; sed 's#repo: acme/widgets#repo: ./x#' "$base" >"$f"
assert_eq 'repo: ./x (a "." segment, not a real owner) is invalid' \
  'incomplete
invalid repo "./x"' "$(run_check "$f")"

# The option-injection shape this check exists to catch (review-base-anchor.sh's
# own header): a value that would reach `git switch` as a FLAG, not a ref, if the
# shape check were skipped.
f="$tmp/bad_pr_base_shape.yml"; sed 's/pr_base: main/pr_base: "-Cmain"/' "$base" >"$f"
assert_eq "pr_base spelled -Cmain (option-injection shape) fails check-ref-format" \
  'incomplete
invalid pr_base "-Cmain"' "$(run_check "$f")"

f="$tmp/bad_migration_base_shape.yml"; sed 's/migration_base: null/migration_base: "-Cmain"/' "$base" >"$f"
assert_eq "migration_base (non-null) also gets the check-ref-format shape check" \
  'incomplete
invalid migration_base "-Cmain"' "$(run_check "$f")"

echo "# check -- the routing keys reject shell metacharacters, not just bad shape"

# A security-critic pass on this script's first version found that neither the
# owner/name split nor a bare check-ref-format round-trip rejects shell
# metacharacters -- `repo: "a/b $(id)"` and `pr_base: "m$(id>&2)"` both read
# `complete`. These four keys are interpolated, unsanitized, into shell command
# templates OTHER skills build at runtime (a branch-cut, `gh pr create --base
# {pr_base}`, a `[ "$R" != "{repo}" ]` comparison) -- `complete` on them must mean
# safe to interpolate, not merely shape-plausible. Single-quoted throughout so
# the fixture-building shell never itself expands the payload.
f="$tmp/repo_shell_injection.yml"
awk '{ if ($0 == "repo: acme/widgets") print "repo: \"a/b $(id)\""; else print }' "$base" >"$f"
assert_eq 'repo containing a command substitution is invalid, not complete' \
  'incomplete
invalid repo "a/b $(id)"' "$(run_check "$f")"

f="$tmp/pr_base_shell_injection.yml"
awk '{ if ($0 == "pr_base: main") print "pr_base: \"m$(id>&2)\""; else print }' "$base" >"$f"
assert_eq 'pr_base containing a command substitution is invalid, not complete' \
  'incomplete
invalid pr_base "m$(id>&2)"' "$(run_check "$f")"

f="$tmp/backlog_repo_shell_injection.yml"
awk '{ if ($0 == "  repo: null") print "  repo: \"evil/x; rm -rf /\""; else print }' "$base" >"$f"
assert_eq 'backlog.repo containing a shell metacharacter (;) is invalid, not complete' \
  'incomplete
invalid backlog.repo "evil/x; rm -rf /"' "$(run_check "$f")"

f="$tmp/migration_base_shell_injection.yml"
awk '{ if ($0 == "migration_base: null") print "migration_base: \"m`id`\""; else print }' "$base" >"$f"
assert_eq 'migration_base containing a backtick command substitution is invalid, not complete' \
  'incomplete
invalid migration_base "m`id`"' "$(run_check "$f")"

f="$tmp/repo_legit_chars.yml"
awk '{
  if ($0 == "repo: acme/widgets") print "repo: acme-org/widgets_v2.0";
  else if ($0 == "migration_base: null") print "migration_base: release/2";
  else print
}' "$base" >"$f"
assert_eq 'legitimate repo/migration_base characters (hyphen, underscore, dot, slash) still pass' \
  "complete" "$(run_check "$f")"

echo "# check -- a trailing newline a shell capture would strip is still caught"

# Round-2 security-critic finding: \$(...) strips every trailing newline BEFORE
# is_safe_chars ever sees the value, so a YAML block scalar (which always ends in
# exactly one trailing newline under clip mode) rendered as a harmless string once
# captured through the shell. The charset check must run INSIDE yq, against the
# file directly, to see the byte it's validating.
f="$tmp/pr_base_block_scalar_trailing_newline.yml"
awk '{ if ($0 == "pr_base: main") { print "pr_base: |"; print "  main" } else print }' "$base" >"$f"
assert_eq 'pr_base as a block scalar (trailing newline a shell capture would strip) is invalid' \
  'incomplete
invalid pr_base "main\n"' "$(run_check "$f")"

echo "# check -- a shape check requires the node to actually BE a string"

# An architect pass on this script's first version found that a shape check
# (owner/name, check-ref-format) ran on yq's plain scalar RENDERING of a value
# without ever confirming that value's own YAML tag was a string -- so
# `pr_base: true` (tag !!bool, renders as the string "true", which
# check-ref-format happily accepts as a ref name) and `repo: [a/b]` (tag !!seq)
# both read `complete`.
f="$tmp/pr_base_not_a_string.yml"
awk '{ if ($0 == "pr_base: main") print "pr_base: true"; else print }' "$base" >"$f"
assert_eq 'pr_base: true (a YAML boolean, not a string) is invalid, not complete' \
  'incomplete
invalid pr_base true' "$(run_check "$f")"

f="$tmp/repo_a_sequence.yml"
awk '{ if ($0 == "repo: acme/widgets") print "repo: [a/b]"; else print }' "$base" >"$f"
assert_eq 'repo: [a/b] (a sequence, not a string) is invalid, not complete' \
  'incomplete
invalid repo ["a/b"]' "$(run_check "$f")"

echo "# check -- a shapeless 'value' key still rejects a map or a sequence"

f="$tmp/roadmap_a_map.yml"
awk '{ if ($0 == "roadmap: docs/roadmap.md") print "roadmap: {a: 1}"; else print }' "$base" >"$f"
assert_eq 'roadmap given as a map (no shape check, but still not a scalar) is invalid' \
  'incomplete
invalid roadmap {"a":1}' "$(run_check "$f")"

echo "# check -- models.second_opinion is validated against the same enum as models.architect/coder"

f="$tmp/second_opinion_bad_model.yml"
awk '{ if ($0 == "  second_opinion: null") print "  second_opinion: not-a-model"; else print }' "$base" >"$f"
assert_eq 'models.second_opinion: not-a-model is invalid, not complete' \
  'incomplete
invalid models.second_opinion "not-a-model"' "$(run_check "$f")"

f="$tmp/second_opinion_good_model.yml"
awk '{ if ($0 == "  second_opinion: null") print "  second_opinion: fable"; else print }' "$base" >"$f"
assert_eq 'models.second_opinion: fable (a real harness model name) is complete' \
  "complete" "$(run_check "$f")"

f="$tmp/good_migration_base_shape.yml"; sed 's/migration_base: null/migration_base: release\/2/' "$base" >"$f"
assert_eq "migration_base a real branch name is valid -- complete" \
  "complete" "$(run_check "$f")"

echo "# check -- a wrong-type list key"

f="$tmp/list_as_scalar.yml"
awk '{ if ($0 == "code_paths:") { print "code_paths: not-a-list" } else if ($0 == "  - src/") { next } else print }' "$base" >"$f"
assert_eq "code_paths given as a scalar, not a list, is invalid" \
  'incomplete
invalid code_paths "not-a-list"' "$(run_check "$f")"

echo "# check -- multiple findings accumulate, one line each, in schema order"

f="$tmp/multi.yml"; grep -v '^migration_base:' "$base" | sed 's/kind: files/kind: bogus/' >"$f"
assert_eq "two independent findings both appear, migration_base before planning.kind" \
  "incomplete
missing migration_base nullable
invalid planning.kind \"bogus\"" "$(run_check "$f")"

echo "# check -- unreadable: no file, unparseable YAML, yq missing"

assert_eq "a nonexistent file is unreadable" \
  "unreadable" "$(run_check "$tmp/does-not-exist.yml")"

f="$tmp/malformed.yml"; printf 'a: [1,2\n' >"$f"
assert_eq "unparseable YAML is unreadable, never complete or incomplete" \
  "unreadable" "$(run_check "$f")"

# Shadow ONLY yq, by prepending a directory that shadows it ahead of the real
# PATH (review-base-anchor.test.sh's own pattern) -- never by clearing PATH
# outright, which would take the shell's own builtins/utilities with it.
fakebin="$tmp/no-yq-path"
mkdir -p "$fakebin"
cat >"$fakebin/yq" <<'EOF'
#!/bin/sh
echo "yq: not found (test stub)" >&2
exit 127
EOF
chmod +x "$fakebin/yq"
# The shim directory alone (no real PATH behind it) is enough here: `check`
# mode's very first action is `command -v yq`, before it touches the file.
out="$(PATH="$fakebin" "$script" check "$base")"
assert_eq "yq entirely absent from PATH is unreadable, never 'no findings therefore complete'" \
  "unreadable" "$out"

echo "# keys -- needs no yq at all (a pure static table)"

out="$(PATH="$fakebin" "$script" keys)"
assert_eq "keys mode works even with yq absent -- it is a static list, not a YAML read" \
  "$expected_keys" "$out"

exit "$fail"
