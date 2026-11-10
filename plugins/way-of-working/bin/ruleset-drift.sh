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
#   ruleset <name> missing_types=[..] missing_checks=[..] approval=<n> bypass_actors=<n> unpinned_checks=[..]
#   ruleset <name> missing
#   ruleset <name> inconclusive
#   ruleset #<i> inconclusive
#   ruleset <name> inconclusive (bypass actors not visible to this identity) missing_types=[..] missing_checks=[..]
# The not-visible line (an identity that cannot edit a ruleset is not shown its bypass actors)
# still carries the rule types and required checks the branch rules lack, computed as for a
# visible ruleset; if either computation fails the plain `ruleset <name> inconclusive` is printed.
# `unpinned_checks` (#1383) names the declared `required_checks` that this ruleset's
# `required_status_checks` rule on the branch carries with an `integration_id` absent or null,
# from the branch-rules read already made. It judges only whether a check is pinned to some App,
# never which App: a pin to the wrong App reads as pinned. A declared check the rule does not
# carry at all is in `missing_checks`, not here.
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
# (name, joined rule types, joined checks) is refused unless it is a string with no control
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

# One rule-type list or check list minus what the branch rules carry, for ruleset id $1.
missing_types() {
  printf '%s' "$B" | jq -r --argjson id "$1" --arg t "$2" '[.[] | select(.ruleset_id==$id) | .type] as $have | ($t | split(",") | map(select(. != ""))) - $have | join(",")'
}
missing_checks() {
  printf '%s' "$B" | jq -r --argjson id "$1" --arg c "$2" '[.[] | select(.ruleset_id==$id and .type=="required_status_checks") | .parameters.required_status_checks[].context] as $have | ($c | split(",") | map(select(. != ""))) - $have | join(",")'
}

# The declared checks (comma-joined, $2) this ruleset's required_status_checks rule carries unpinned.
unpinned_checks() {
  printf '%s' "$B" | jq -r --argjson id "$1" --arg c "$2" '[.[] | select(.ruleset_id==$id and .type=="required_status_checks") | .parameters.required_status_checks[] | select(.integration_id == null) | .context] as $un | ($c | split(",") | map(select(. != ""))) | map(select(. as $x | $un | index($x))) | join(",")'
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
    TYPES=$(printf '%s' "$ENT" | jq -er '.rule_types | join(",") | select(test("^[^\\p{Cc}]*\\z"))') || { printf 'ruleset %s inconclusive\n' "#$I"; continue; }
    CHECKS=$(printf '%s' "$ENT" | jq -er '(.required_checks // []) | join(",") | select(test("^[^\\p{Cc}]*\\z"))') || { printf 'ruleset %s inconclusive\n' "#$I"; continue; }
    case "$SRC" in repo) API="repos/$R/rulesets" ;; org) API="orgs/$OWNER/rulesets" ;; *) printf 'ruleset %s inconclusive\n' "$NAME"; continue ;; esac
    L=$(gh api --paginate "$API" </dev/null) || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    RID=$(printf '%s' "$L" | jq -r --arg n "$NAME" 'first(.[] | select(.name==$n) | .id) // empty') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    [ -n "$RID" ] || { printf 'ruleset %s missing\n' "$NAME"; continue; }
    case "$RID" in *[!0-9]*) printf 'ruleset %s inconclusive\n' "$NAME"; continue ;; esac
    BYP=$(gh api "$API/$RID" --jq 'if (.bypass_actors | type) == "array" then (.bypass_actors | length) else "unknown" end' </dev/null) || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    case "$BYP" in
      '' | *[!0-9]*)
        MT=$(missing_types "$RID" "$TYPES") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        MC=$(missing_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
        printf 'ruleset %s inconclusive (bypass actors not visible to this identity) missing_types=[%s] missing_checks=[%s]\n' "$NAME" "$MT" "$MC"
        continue ;;
    esac
    MT=$(missing_types "$RID" "$TYPES") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    MC=$(missing_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    UC=$(unpinned_checks "$RID" "$CHECKS") || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    AP=$(printf '%s' "$B" | jq --argjson id "$RID" '[.[] | select(.ruleset_id==$id and .type=="pull_request")] | length') || { printf 'ruleset %s inconclusive\n' "$NAME"; continue; }
    printf 'ruleset %s missing_types=[%s] missing_checks=[%s] approval=%s bypass_actors=%s unpinned_checks=[%s]\n' "$NAME" "$MT" "$MC" "$AP" "$BYP" "$UC"
  done
  exit 0
fi

# Single form.
NAME=$(yq -o=json -I=0 '.ruleset.name' "$YML" </dev/null | jq -er 'strings | select(test("^[^\\p{Cc}]+\\z"))') || inc bad-name
TYPES=$(yq -o=json -I=0 '.ruleset.rule_types' "$YML" </dev/null | jq -er 'arrays | join(",") | select(test("^[^\\p{Cc}]*\\z"))') || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
CHECKS=
case ",$TYPES," in
  *,required_status_checks,*)
    CHECKS=$(yq -o=json -I=0 '.ruleset.required_checks' "$YML" </dev/null | jq -er 'arrays | join(",") | select(test("^[^\\p{Cc}]*\\z"))') || { printf 'ruleset %s inconclusive\n' "$NAME"; exit 0; }
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
