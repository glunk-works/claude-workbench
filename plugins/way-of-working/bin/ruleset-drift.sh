#!/bin/sh
# Check the declared branch-protection rulesets against what GitHub reports, for
# /way-of-working:resume's *Check the branch-protection ruleset for drift* step.
#
# The check lives in a file, not in skill prose, because its control-character test is a
# regex with backslashes in it. A host shell tool was reported to collapse a doubled
# backslash before the command ran, which made every value fail the test and a healthy repo
# read `inconclusive`. In a file the regex never passes through a tool's command-line quoting.
#
# Usage: ruleset-drift.sh <repo> <pr_base> <project.yml>
# Exits 2 with a usage line on a wrong argument count; every other run exits 0 (the caller
# decides policy), and a caller treats a non-zero exit as inconclusive whatever was printed.
#
# Arguments: <repo> is owner/name (two segments, neither `.` nor `..`, of [A-Za-z0-9._-], the first
# not starting with `-`);
# <pr_base> is a branch name of [A-Za-z0-9._/-], not starting with `-`, with no empty, `.` or `..` segment. Both enter the API
# paths below, so anything else is refused.
#
# Output. Any failure before the first entry is read (in the single form, before its name is
# bound) prints exactly one line, `inconclusive <reason>`, and nothing else. The reason is one of:
#   bad-repo, bad-base   -- a refused argument
#   no-gh, no-jq, no-yq  -- a tool is missing from PATH
#   no-tmp               -- the private temporary directory could not be made
#   branch-rules         -- the branch-rules read failed or was not JSON
#   unreadable           -- the project file is missing or not parseable YAML
#   bad-rulesets         -- a `rulesets` key that is empty or not a list (checked by type,
#                           since `length` counts a string or a map)
#   bad-name             -- the single form's `ruleset.name` is not a string free of control
#                           characters
# Otherwise one line per entry.
#
# When the file declares a `rulesets` key, the list form reads every entry and prints:
#   ruleset <name> missing_types=[..] missing_checks=[..] approval=<n> bypass_actors=<n> unpinned_checks=[..] approval_params=[..] wrong_pins=[..] missing_refs=[..]
#   ruleset <name> missing
#   ruleset <name> inconclusive
#   ruleset #<i> inconclusive
#   ruleset <name> inconclusive (bypass actors not visible to this identity) missing_types=[..] missing_checks=[..] unpinned_checks=[..] approval_params=[..] wrong_pins=[..] missing_refs=[..]
# The not-visible line (an identity that cannot edit a ruleset is not shown its bypass actors)
# still carries the rule types and required checks the branch rules lack, and the unpinned
# checks, approval parameters, wrong pins and missing refs, computed as for a visible ruleset (they come from the
# branch-rules read, or a tag entry's own rules; `missing_refs` comes from a tag response's
# `conditions.ref_name.include`); if any of the computations fails the plain
# `ruleset <name> inconclusive` is printed. It has no `approval=` count: without the bypass
# count that count judges nothing.
# `unpinned_checks` (#1383) names the declared `required_checks` that this ruleset's
# `required_status_checks` rule on the branch carries with an `integration_id` absent or null,
# from the branch-rules read already made. It judges only whether a check is pinned to some App;
# which App is judged by `wrong_pins`, and only for checks `check_integrations` names. A declared check the rule does not
# carry at all is in `missing_checks`, not here.
# `approval_params` (#1405) names, comma-joined in this fixed order, the parameters of this
# ruleset's `pull_request` rule on the branch that are not at the cutover value, from the same
# branch-rules read: `require_code_owner_review` not true, `dismiss_stale_reviews_on_push` not
# true, `require_last_push_approval` not true, `required_approving_review_count` not the number 1.
# An absent parameter counts as not at its value. Empty when the ruleset carries no `pull_request`
# rule on the branch.
# Three optional entry fields are compared only when declared (#1413):
# `check_integrations` -- a map from a required check's name to the positive integer
#   `integration_id` it must be pinned to. `wrong_pins` names, comma-joined in the map's declared
#   order, each key with no `required_status_checks` entry of this ruleset carrying that context
#   and that id (a check not carried, or carried with a null or different id, is listed). Empty
#   when none is declared.
# `target` -- absent, null or `branch` is the behaviour above; `tag` describes a tag ruleset,
#   which must be `source: repo` (an org ruleset's repository conditions are not read). After its
#   id is found by name the ruleset is read once by id and its `rules` array (each element given
#   this ruleset's id) replaces the branch rules for every computation above. A response whose
#   `target` is not `tag` or whose `enforcement` is not `active` prints `ruleset <name> missing`
#   (a by-id read also returns a ruleset that enforces nothing). Bypass actors come from the same
#   response.
# `ref_patterns` -- required, a non-empty list of strings, exactly when `target` is `tag`. The
#   patterns the ruleset's `conditions.ref_name.include` must contain, each compared as an exact
#   string; `missing_refs` names those it lacks, in declared order. Always empty for a branch entry.
# An entry prints `ruleset <name> inconclusive` for an unknown `target`, a `tag` entry with
# `source: org`, a malformed `check_integrations` or `ref_patterns`, a tag response whose `rules`
# or `conditions.ref_name.include` is not an array, or one whose `conditions.ref_name.exclude` is
# non-empty (an excluded pattern is not judged).
# An entry's `source` picks the API: `repo` -> repos/<repo>/rulesets, `org` ->
# orgs/<owner>/rulesets; anything else is inconclusive, never read as `repo`.
#
# Without a `rulesets` key, the single form checks `ruleset` and prints one line:
#   ruleset <name> missing_types=[..] missing_checks=[..]
#   ruleset <name> missing_types=[..] missing_checks=[..] bypass_actors=unchecked
#                                  -- the same line when the project file's `identities` is a map
#                                     (no rulesets list, so no bypass check ran); an `identities: null`
#                                     or absent key leaves the line without the suffix
#   ruleset <name> missing         -- no ruleset of that name, or none of its rules applies
#   ruleset <name> inconclusive    -- a failed rulesets read, a non-numeric id, an unreadable
#                                     type or check list, or an unreadable `identities` tag
# `missing_checks` is filled only when `required_status_checks` is a declared type, and then
# `ruleset.required_checks` must be a list: absent, it is inconclusive, never an empty list.
# Bypass actors are not read in this form: a repo that has not cut over still carries the
# admin bypass on purpose.
#
# Values are bound with `jq --arg`/`--argjson`, never spliced into a filter. Each list entry
# is read whole by index as one JSON object, never through a @tsv row, whose CSV-quoting can
# split one entry across lines and pair a name with the wrong entry's fields. Each value
# (name) and each rule-type and check entry is refused unless it is a string with no control
# character, so a value the project file wrote with a newline reads inconclusive instead of
# forging a second report line. The test ends in `\z`, not `$`: `\z` anchors the end of the
# text, where `$` also matches before a final newline and would let a trailing newline through.
#
# Report lines that carry a config value are printed with printf, never echo: a name may carry a backslash, which is no
# control character, and some shells' echo would turn `\n` in it into a second line.
#
# Permitted toolset: gh, jq, yq (mikefarah v4), POSIX sh plus mktemp, tr and rm (the CR-stripping wrappers below, which keep their temp files in a private directory).
set -u

if [ "$#" -ne 3 ]; then
  echo "usage: ruleset-drift.sh <repo> <pr_base> <project.yml>" >&2
  exit 2
fi
R="$1"; BASE="$2"; YML="$3"

inc() { echo "inconclusive $1"; exit 0; }

case "$R" in
  '' | -* | /* | */ | */*/* | *[!A-Za-z0-9._/-]*) inc bad-repo ;;
  */*) ;;
  *) inc bad-repo ;;
esac
OWNER=${R%%/*}; REPO=${R#*/}
case "$OWNER" in . | ..) inc bad-repo ;; esac
case "$REPO" in . | ..) inc bad-repo ;; esac
case "$BASE" in
  '' | -* | /* | */ | *//* | . | .. | ./* | ../* | */. | */.. | */./* | */../* | *[!A-Za-z0-9._/-]*) inc bad-base ;;
esac
command -v gh >/dev/null 2>&1 || inc no-gh
command -v jq >/dev/null 2>&1 || inc no-jq
command -v yq >/dev/null 2>&1 || inc no-yq

# A native jq.exe or yq.exe under Git Bash can end each output line in CR (the sibling host scripts strip it);
# these wrappers keep the exit status and drop the CR from every value read into a variable.
WT=$(umask 077 && mktemp -d) || inc no-tmp
trap 'rm -rf -- "$WT"' EXIT
trap 'exit 1' INT TERM HUP
jq() { _o=$(mktemp "$WT/w.XXXXXX") || return 1; command jq "$@" >"$_o"; _r=$?; tr -d '\r' <"$_o"; rm -f "$_o"; return "$_r"; }
yq() { _o=$(mktemp "$WT/w.XXXXXX") || return 1; command yq "$@" >"$_o"; _r=$?; tr -d '\r' <"$_o"; rm -f "$_o"; return "$_r"; }

B=$(gh api --paginate "repos/$R/rules/branches/$BASE" </dev/null) || inc branch-rules
B=$(printf '%s' "$B" | jq -s 'add // []') || inc branch-rules
[ -n "$B" ] || inc branch-rules

HAS=$(yq 'has("rulesets")' "$YML" </dev/null) || inc unreadable

# The helpers judge the rules array in $RB (the branch rules, or a tag entry's own rules), for ruleset id $1.
RB=$B

# One rule-type list or check list minus what the rules carry, for ruleset id $1.
missing_types() {
  printf '%s' "$RB" | jq -r --argjson id "$1" --argjson t "$2" '[.[] | select(.ruleset_id==$id) | .type] as $have | $t - $have | join(",")'
}
missing_checks() {
  printf '%s' "$RB" | jq -r --argjson id "$1" --argjson c "$2" '[.[] | select(.ruleset_id==$id and .type=="required_status_checks") | .parameters.required_status_checks[].context] as $have | $c - $have | join(",")'
}

# The approval-rule parameters of this ruleset's pull_request rule that are not at the cutover value.
approval_params() {
  printf '%s' "$RB" | jq -r --argjson id "$1" '[.[] | select(.ruleset_id==$id and .type=="pull_request") | .parameters] as $p | if ($p | length) == 0 then "" else [ (if any($p[]; .require_code_owner_review == true) then empty else "require_code_owner_review" end), (if any($p[]; .dismiss_stale_reviews_on_push == true) then empty else "dismiss_stale_reviews_on_push" end), (if any($p[]; .require_last_push_approval == true) then empty else "require_last_push_approval" end), (if any($p[]; .required_approving_review_count == 1) then empty else "required_approving_review_count" end) ] | join(",") end'
}

# The declared checks (a JSON array, $2) this ruleset's required_status_checks rule carries unpinned.
unpinned_checks() {
  printf '%s' "$RB" | jq -r --argjson id "$1" --argjson c "$2" '[.[] | select(.ruleset_id==$id and .type=="required_status_checks") | .parameters.required_status_checks[] | select(.integration_id == null) | .context] as $un | $c | map(select(. as $x | $un | index($x))) | join(",")'
}

# The keys of the declared check_integrations (a JSON object, $2) that have no required_status_checks entry with that context and integration_id.
wrong_pins() {
  printf '%s' "$RB" | jq -r --argjson id "$1" --argjson m "$2" '[.[] | select(.ruleset_id==$id and .type=="required_status_checks") | .parameters.required_status_checks[]] as $have | [$m | to_entries[] | select(. as $e | any($have[]; .context == $e.key and .integration_id == $e.value) | not) | .key] | join(",")'
}

# The declared ref patterns (a JSON array, $1) that the include list (a JSON array, $2) lacks.
missing_refs() {
  jq -nr --argjson p "$1" --argjson i "$2" '$p - $i | join(",")'
}

if [ "$HAS" = true ]; then
  [ "$(yq '.rulesets | tag' "$YML" </dev/null)" = '!!seq' ] || inc bad-rulesets
  N=$(yq '.rulesets | length' "$YML" </dev/null) || inc bad-rulesets
  case "$N" in '' | 0 | *[!0-9]*) inc bad-rulesets ;; esac
  I=-1
  while I=$((I + 1)); [ "$I" -lt "$N" ]; do
    ENT=$(yq -o=json -I=0 ".rulesets[$I]" "$YML" </dev/null) || { printf 'ruleset %s inconclusive\n' "#$I"; continue; }
    NAME=$(printf '%s' "$ENT" | jq -er '.name | strings | select(test("^[^\\p{Cc}]+\\z"))') || { printf 'ruleset %s inconclusive\n' "#$I"; continue; }
    SRC=$(printf '%s' "$ENT" | jq -r '.source | strings')
    TYPES=$(printf '%s' "$ENT" | jq -ce '[.rule_types[]] | select(all(.[]; type == "string" and test("^[^\\p{Cc}]*\\z"))) | map(select(. != ""))') || { printf 'ruleset %s inconclusive\n' "#$I"; continue; }
    CHECKS=$(printf '%s' "$ENT" | jq -ce '[(.required_checks // [])[]] | select(all(.[]; type == "string" and test("^[^\\p{Cc}]*\\z"))) | map(select(. != ""))') || { printf 'ruleset %s inconclusive\n' "#$I"; continue; }
    TGT=$(printf '%s' "$ENT" | jq -r 'if (has("target") | not) or .target == null then "branch" elif (.target | type) == "string" and (.target == "branch" or .target == "tag") then .target else "bad" end')
    [ "$TGT" != bad ] || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    CI=$(printf '%s' "$ENT" | jq -ce '(if (has("check_integrations") | not) or .check_integrations == null then {} else .check_integrations end) | select(type == "object" and all(to_entries[]; (.key | test("^[^\\p{Cc}]+\\z")) and (.value | type == "number" and . > 0 and . == floor)))') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    RP='[]'
    if [ "$TGT" = tag ]; then
      [ "$SRC" = repo ] || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
      RP=$(printf '%s' "$ENT" | jq -ce '.ref_patterns | select(type == "array" and length > 0 and all(.[]; type == "string" and test("^[^\\p{Cc}]+\\z")))') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    fi
    case "$SRC" in repo) API="repos/$R/rulesets" ;; org) API="orgs/$OWNER/rulesets" ;; *) printf 'ruleset %s inconclusive\n' "$NAME"; continue ;; esac
    L=$(gh api --paginate "$API" </dev/null) || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    RID=$(printf '%s' "$L" | jq -r --arg n "$NAME" 'first(.[] | select(.name==$n) | .id) // empty') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    [ -n "$RID" ] || { printf 'ruleset %s missing\n' "$NAME"; continue; }
    case "$RID" in *[!0-9]*) printf 'ruleset %s inconclusive\n' "$NAME"; continue ;; esac
    RB=$B; INC_REFS='[]'
    BYP=; RULESET=
    if [ "$TGT" = tag ]; then
      RULESET=$(gh api "$API/$RID" </dev/null) || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
      V=$(printf '%s' "$RULESET" | jq -er 'objects | if .target == "tag" and .enforcement == "active" then "ok" else "no" end') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
      [ "$V" = ok ] || { printf 'ruleset %s missing\n' "$NAME"; continue; }
      printf '%s' "$RULESET" | jq -e '(.conditions.ref_name.exclude // []) | type == "array" and length == 0' >/dev/null || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
      RB=$(printf '%s' "$RULESET" | jq -ce --argjson id "$RID" '.rules | select(type == "array") | map(. + {ruleset_id: $id})') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
      INC_REFS=$(printf '%s' "$RULESET" | jq -ce '.conditions.ref_name.include | select(type == "array")') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
      BYP=$(printf '%s' "$RULESET" | jq -r 'if (.bypass_actors | type) == "array" then (.bypass_actors | length) else "unknown" end') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    else
      BYP=$(gh api "$API/$RID" --jq 'if (.bypass_actors | type) == "array" then (.bypass_actors | length) else "unknown" end' </dev/null) || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    fi
    case "$BYP" in
      '' | *[!0-9]*)
        MT=$(missing_types "$RID" "$TYPES") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        MC=$(missing_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        UC=$(unpinned_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        PP=$(approval_params "$RID") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        WP=$(wrong_pins "$RID" "$CI") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        MR=$(missing_refs "$RP" "$INC_REFS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        printf 'ruleset %s inconclusive (bypass actors not visible to this identity) missing_types=[%s] missing_checks=[%s] unpinned_checks=[%s] approval_params=[%s] wrong_pins=[%s] missing_refs=[%s]\n' "$NAME" "$MT" "$MC" "$UC" "$PP" "$WP" "$MR"
        continue ;;
    esac
    MT=$(missing_types "$RID" "$TYPES") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    MC=$(missing_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    UC=$(unpinned_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    PP=$(approval_params "$RID") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    WP=$(wrong_pins "$RID" "$CI") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    MR=$(missing_refs "$RP" "$INC_REFS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    AP=$(printf '%s' "$RB" | jq --argjson id "$RID" '[.[] | select(.ruleset_id==$id and .type=="pull_request")] | length') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    printf 'ruleset %s missing_types=[%s] missing_checks=[%s] approval=%s bypass_actors=%s unpinned_checks=[%s] approval_params=[%s] wrong_pins=[%s] missing_refs=[%s]\n' "$NAME" "$MT" "$MC" "$AP" "$BYP" "$UC" "$PP" "$WP" "$MR"
  done
  exit 0
fi

# Single form.
NAME=$(yq -o=json -I=0 '.ruleset.name' "$YML" </dev/null | jq -er 'strings | select(test("^[^\\p{Cc}]+\\z"))') || inc bad-name
TYPES=$(yq -o=json -I=0 '.ruleset.rule_types' "$YML" </dev/null | jq -ce 'arrays | select(all(.[]; type == "string" and test("^[^\\p{Cc}]*\\z"))) | map(select(. != ""))') || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
CHECKS='[]'
case "$(printf '%s' "$TYPES" | jq 'index("required_status_checks")')" in
  null) ;;
  *)
    CHECKS=$(yq -o=json -I=0 '.ruleset.required_checks' "$YML" </dev/null | jq -ce 'arrays | select(all(.[]; type == "string" and test("^[^\\p{Cc}]*\\z"))) | map(select(. != ""))') || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
    ;;
esac
L=$(gh api --paginate "repos/$R/rulesets" </dev/null) || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
RID=$(printf '%s' "$L" | jq -r --arg n "$NAME" 'first(.[] | select(.name==$n) | .id) // empty') || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
[ -n "$RID" ] || { printf 'ruleset %s missing\n' "$NAME"; exit 0; }
case "$RID" in *[!0-9]*) printf 'ruleset %s inconclusive\n' "$NAME"; exit 0 ;; esac
APPLIES=$(printf '%s' "$B" | jq --argjson id "$RID" '[.[] | select(.ruleset_id==$id)] | length') || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
[ "$APPLIES" != 0 ] || { printf 'ruleset %s missing\n' "$NAME"; exit 0; }
MT=$(missing_types "$RID" "$TYPES") || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
MC=$(missing_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
# Under a map the project file declares no rulesets list, so no bypass actor was checked: say so.
IDT=$(yq 'explode(.) | .identities | tag' "$YML" </dev/null) || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
SFX=
[ "$IDT" != '!!map' ] || SFX=' bypass_actors=unchecked'
printf 'ruleset %s missing_types=[%s] missing_checks=[%s]%s\n' "$NAME" "$MT" "$MC" "$SFX"
