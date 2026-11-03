#!/bin/sh
# The identity flags for `plan-anchor.sh verify`, built from a project.yml in one place (#1221). /way-of-working:resume,
# /way-of-working:handoff and /way-of-working:archive-sprint each hand-typed the reads below, and a session that got the
# shell wrong (a failing `&&` test as the last command of a loop ended the chain) ran `verify` with flags missing.
#
# Usage: plan-anchor-flags.sh <project.yml>
#
#   <project.yml>  the DEFAULT branch's committed copy (the callers' $DEF_YML_FILE), never the working
#                  tree's, which a branch under review can edit
#
# On success it exits 0 and prints the flags one argument per line, in this order: `--loop-identity` and the
# login; `--maintainer-ids` and the comma-joined ids; `--dev-app-id` and the id; `--declared-app-ids` and the
# comma-joined ids. An omitted flag prints neither line; exit 0 with nothing on stdout means no flag applies.
# It prints only once every read below has passed, so any non-zero exit leaves stdout empty.
#
# Exits 2, printing nothing to stdout (one reason line to stderr), when it cannot say: a wrong argument
# count, a <project.yml> that is missing or not YAML, `$0` with no slash, a sibling gh-identity.sh not beside
# this script, or any read below failing. Like spec-find.sh it uses only the SIBLING gh-identity.sh: a
# slash-less `$0` would resolve `dirname` to the current directory, where a branch under review could supply
# one that prints `maintainer`.
#
# The `orchestration` and App reads run under `explode(.)`; the top-level `has` reads and the `identities` mode read
# do not, so an `identities` that is itself an alias refuses.
#   --loop-identity    `orchestration` present and null, or `loop_identity` present and null, omits the flag.
#                      `loop_identity` a string of the login shape (a stem of letters, digits and `-`, no
#                      leading or trailing `-`, at most 39 characters, an optional `[bot]` suffix) passes it.
#                      Anything else refuses: a missing key, an empty string, a non-string, a newline.
#   identities         present and null (legacy): only --loop-identity can be printed, and no App key is read.
#                      A map: the three flags below are decided. Anything else, a missing key included, refuses.
#   --maintainer-ids   every `identities.maintainer` entry has an !!int `id` and a string `login`, and
#                      an id above 0, and `gh-identity.sh role` prints `maintainer` for it; the ids are the exact strings passed to
#                      `role`, in list order. An empty or non-sequence list or a malformed entry refuses. Always
#                      printed under a map.
#   --dev-app-id       `identities.dev_app` a map (an !!int `id` above 0, a string `login`) that `role` confirms
#                      as `dev_app`. Present and null omits the flag; a missing key, a malformed entry or a
#                      `role` refusal refuses.
#   --declared-app-ids `dev_app`, `reviewer_app` and `loop_app`, each read the same way and confirmed by `role`
#                      printing its own key; the ids of the non-null entries, in that order. All three null omits
#                      the flag; any of the three missing, malformed or refused by `role` refuses.
# It makes no `gh` call and reads no other file.
#
# Permitted toolset: POSIX sh and yq (mikefarah v4). Runs under LC_ALL=C.
set -eu
LC_ALL=C
export LC_ALL

refuse() {
  echo "plan-anchor-flags.sh: $1" >&2
  exit 2
}

[ "$#" -eq 1 ] || refuse "usage: plan-anchor-flags.sh <project.yml>"
yml="$1"
[ -f "$yml" ] && yq -o=yaml '.' "$yml" >/dev/null 2>&1 || refuse "unreadable project.yml"
case "$0" in
  */*) gi="$(dirname "$0")/gh-identity.sh" ;;
  *) refuse "must be run by path (a slash-less \$0 cannot locate its sibling)" ;;
esac
[ -f "$gi" ] || refuse "gh-identity.sh not beside this script"

# read_yq <expr>: yq on the file, a failure refusing rather than reading as empty.
read_yq() {
  yq -r "$1" "$yml" 2>/dev/null || refuse "unreadable: $1"
}

out=
add() { # <flag> <value>
  out="$out$1
$2
"
}

# --- --loop-identity ---
case "$(read_yq 'has("orchestration")')/$(read_yq 'explode(.) | .orchestration | tag')" in
  true/'!!null') : ;;
  true/'!!map')
    case "$(read_yq 'explode(.) | .orchestration | has("loop_identity")')/$(read_yq 'explode(.) | .orchestration.loop_identity | tag')" in
      true/'!!null') : ;;
      true/'!!str')
        [ "$(read_yq 'explode(.) | .orchestration.loop_identity | test("^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]{0,37}[A-Za-z0-9])(\\[bot\\])?$")')" = true ] ||
          refuse "orchestration.loop_identity is not a login"
        login="$(read_yq 'explode(.) | .orchestration.loop_identity')"
        add --loop-identity "$login"
        ;;
      *) refuse "orchestration.loop_identity is missing or not a string" ;;
    esac
    ;;
  *) refuse "orchestration is missing or neither null nor a map" ;;
esac

# --- identities ---
case "$(read_yq 'has("identities")')/$(read_yq '.identities | tag')" in
  true/'!!null')
    printf '%s' "$out"
    exit 0
    ;;
  true/'!!map') : ;;
  *) refuse "identities is missing or neither null nor a map" ;;
esac

tab="$(printf '\t')"

# --- --maintainer-ids ---
[ "$(read_yq 'explode(.) | .identities.maintainer | tag')" = '!!seq' ] || refuse "identities.maintainer is not a list"
m_total="$(read_yq 'explode(.) | .identities.maintainer | length')"
rows="$(read_yq 'explode(.) | .identities.maintainer | .[] | select(tag == "!!map" and ((.id | tag) == "!!int") and .id > 0 and ((.login | tag) == "!!str")) | [.login, .id] | @tsv')"
[ -n "$rows" ] || refuse "identities.maintainer has no usable entry"
m_ids=
m_good=0
while IFS="$tab" read -r l i; do
  [ "$(sh "$gi" role "$l" "$i" "$yml" 2>/dev/null)" = maintainer ] || refuse "identities.maintainer entry $i is not confirmed by gh-identity.sh role"
  m_ids="${m_ids:+$m_ids,}$i"
  m_good=$((m_good + 1))
done <<EOF
$rows
EOF
[ "$m_good" = "$m_total" ] || refuse "identities.maintainer has a malformed entry"
add --maintainer-ids "$m_ids"

# --- --dev-app-id and --declared-app-ids ---
dev_id=
app_ids=
for key in dev_app reviewer_app loop_app; do
  K="$key"
  export K
  [ "$(read_yq 'explode(.) | .identities | has(strenv(K))')" = true ] || refuse "identities.$key is missing"
  case "$(read_yq 'explode(.) | .identities[strenv(K)] | tag')" in
    '!!null') : ;;
    '!!map')
      row="$(read_yq 'explode(.) | .identities[strenv(K)] | select(tag == "!!map" and ((.id | tag) == "!!int") and .id > 0 and ((.login | tag) == "!!str")) | [.login, .id] | @tsv')"
      [ -n "$row" ] || refuse "identities.$key is malformed"
      l="${row%%"$tab"*}" i="${row#*"$tab"}"
      [ "$(sh "$gi" role "$l" "$i" "$yml" 2>/dev/null)" = "$key" ] || refuse "identities.$key is not confirmed by gh-identity.sh role"
      app_ids="${app_ids:+$app_ids,}$i"
      [ "$key" != dev_app ] || dev_id="$i"
      ;;
    *) refuse "identities.$key is neither null nor a map" ;;
  esac
done
[ -z "$dev_id" ] || add --dev-app-id "$dev_id"
[ -z "$app_ids" ] || add --declared-app-ids "$app_ids"

printf '%s' "$out"
