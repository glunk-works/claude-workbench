#!/bin/sh
# Which identity is acting: a human's login (user mode) or this repo's declared dev App
# (App mode)? One place that says so (WB-D24, #379), so no skill guesses it from a token
# prefix or from `gh auth status`, which reports scope, not who is acting.
#
# Trust is by DECLARED identity, never by name alone (WB-D24 item 6): the acting account
# is matched against `identities` in .ai/project.yml on its numeric `id`, which a login
# rename cannot move. This script is a pure predicate. It calls no `gh`; the caller
# captures `gh` output first, with `&&`, and passes the values, so a failed call breaks
# the chain before this script runs and can never read as "no identity".
#
# Usage:
#   gh-identity.sh classify <login> <id> <project.yml>
#   <records> | gh-identity.sh reach <owner/repo>
#
#   LU=$(gh api user --jq '[.login, .id] | @tsv') &&
#   LOGIN=$(printf '%s' "$LU" | cut -f1) && ID=$(printf '%s' "$LU" | cut -f2) &&
#   gh-identity.sh classify "$LOGIN" "$ID" "$DEF_YML_FILE"
#
# That recipe is the USER-token source and is the only one this task measured. GitHub
# refuses `GET /user` to an installation token, so under an installation token it fails and the
# chain stops: App mode is then unreachable by this source, and fails closed. Where the
# {login, id} of an App actor comes from is the caller's to establish (for example the
# `user` object of a write response), and is NOT yet measured; classify is source-agnostic
# and only compares what it is given. Until that is measured, do not document the recipe
# above as the way to reach `app`. A GitHub App USER-to-server token is different: it may
# call `GET /user` and returns the human it acts for, so it classifies as that human.
#
# `user` is a MODE, never a trust grant. With identities null it is printed for any plain
# account (the pre-cutover model trusts by author_association, not by this word); with a map
# it means a declared maintainer. A reader that gates TRUST on a maintainer must run against
# a map and must not treat `user` from a null file as one.
#
# classify prints exactly one word to stdout and exits 0:
#   user  -- identities is null (the repo has not cut over) and the login is a plain
#            account, OR the id and login match an `identities.maintainer` entry
#   app   -- the id and login match `identities.dev_app`
# It exits 2, printing NOTHING to stdout, when it cannot say; one stderr line gives the
# reason. The CALLER decides policy for 2: treat it as neither mode, and wait. Unsure is:
#   - login or id missing, or not the shape GitHub reports (login: letters, digits, `-`,
#     optional `[bot]`; id: a positive integer)
#   - .ai/project.yml unreadable, no `identities` key (absent is the unanswered question),
#     or `identities` neither null nor a map
#   - identities is null and the login ends `[bot]` -- an App with no declared identity is
#     never assumed to be the user model
#   - the id matches reviewer_app or loop_app -- a declared identity, but not one of the
#     two modes this predicate answers; those Apps do not run the dev flow
#   - the account is not declared at all, or the id matches an entry whose login differs
#     (a rename or a stale declaration: do not guess which side is right)
#   - an entry is malformed. A malformed entry (not a map, a non-integer or non-positive
#     `id`, a non-string `login`) matches nothing -- never by login alone -- so a file whose
#     only matching entry is malformed reads as undeclared. `identities.maintainer` must be a
#     sequence; a map there is malformed. YAML aliases inside `identities` are expanded before matching; `identities` itself must not be an alias (that reads as not a map).
#   - one id is declared more than once, under one role or several: do not guess which.
# Login comparison is case-insensitive (GitHub logins are); the id is exact.
#
# reach is the App-mode probe: is the token in use an installation token that can reach
# <owner/repo>? Feed it one `full_name` per line from
#   gh api --paginate installation/repositories --jq '.repositories[].full_name'
# captured to a file first. A user token cannot call that endpoint, so a failed call is the
# caller's "not an App token", and must not reach this script as empty input.
#   reached    -- <owner/repo> is listed (compared case-insensitively)
#   unreached  -- records arrived, none is <owner/repo>
# Exits 2, nothing on stdout, for empty input (a call that returned nothing is not "an
# installation with no access"), a malformed <owner/repo> or record. A reached probe says
# the token is an installation token with access; WHICH App it is stays `classify`'s answer.
#
# The caller reads `.ai/project.yml` from the DEFAULT branch's committed copy, never the
# working tree (the same stance as `orchestration` and the review gate): a PR under review
# can edit its own `identities`.
#
# Permitted toolset: POSIX sh, tr(1), yq (mikefarah v4) for classify only.
set -eu

die() { echo "gh-identity.sh: $1" >&2; exit 2; }

lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

valid_login() {
  case "$1" in
    ''|-*|*-|*--*) return 1 ;;
  esac
  rest="${1%\[bot\]}"
  case "$rest" in
    ''|*[!A-Za-z0-9-]*) return 1 ;;
  esac
  return 0
}

valid_id() {
  case "$1" in
    ''|0*|*[!0-9]*) return 1 ;;
  esac
  return 0
}

classify() {
  [ "$#" -eq 3 ] || { echo "usage: gh-identity.sh classify <login> <id> <project.yml>" >&2; exit 2; }
  login="$1" id="$2" yml="$3"
  valid_login "$login" || die "login is not an account name"
  valid_id "$id" || die "id is not a positive integer"
  [ -f "$yml" ] || die "project file unreadable"
  command -v yq >/dev/null 2>&1 || die "yq is not on PATH"

  has=$(yq -r 'has("identities")' "$yml" 2>/dev/null) || die "project file unparseable"
  [ "$has" = true ] || die "no identities key -- the question is unanswered"
  tag=$(yq -r '.identities | tag' "$yml" 2>/dev/null) || die "project file unparseable"
  want=$(lower "$login")

  case "$tag" in
    '!!null')
      case "$login" in
        *'[bot]') die "identities is null and the actor is a [bot]; an undeclared App is not user mode" ;;
      esac
      echo user
      return 0 ;;
    '!!map') ;;
    *) die "identities is neither null nor a map" ;;
  esac

  # Each role is read on its own; a malformed entry prints nothing and so matches nothing.
  tab=$(printf '\t')
  match=
  for r in maintainer dev_app reviewer_app loop_app; do
    if [ "$r" = maintainer ]; then
      rows=$(yq -r 'explode(.) | (.identities.maintainer | select(tag == "!!seq") | .[]) | select(tag == "!!map" and ((.id | tag) == "!!int") and .id > 0 and ((.login | tag) == "!!str")) | [.login, .id] | @tsv' "$yml" 2>/dev/null) || die "identities.maintainer unreadable"
    else
      rows=$(yq -r "explode(.) | .identities.$r | select(tag == \"!!map\" and ((.id | tag) == \"!!int\") and .id > 0 and ((.login | tag) == \"!!str\")) | [.login, .id] | @tsv" "$yml" 2>/dev/null) || die "identities.$r unreadable"
    fi
    [ -n "$rows" ] || continue
    while IFS="$tab" read -r l i; do
      [ "$i" = "$id" ] || continue
      if [ "$(lower "$l")" != "$want" ]; then
        die "id $id is declared under a different login; will not guess"
      fi
      [ -z "$match" ] || die "id $id is declared more than once; will not guess"
      match="$r"
    done <<EOF
$rows
EOF
  done

  case "$match" in
    maintainer) echo user ;;
    dev_app) echo app ;;
    reviewer_app|loop_app) die "the acting identity is the declared $match, not a user or the dev App" ;;
    *) die "the acting identity is not declared in identities" ;;
  esac
}

reach() {
  [ "$#" -eq 1 ] || { echo "usage: <records> | gh-identity.sh reach <owner/repo>" >&2; exit 2; }
  repo="$1"
  case "$repo" in
    */*/*|/*|*/|*[!A-Za-z0-9._/-]*|'') die "repo is not owner/name" ;;
    */*) ;;
    *) die "repo is not owner/name" ;;
  esac
  want=$(lower "$repo")
  seen=0
  found=0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%"$(printf '\r')"}
    [ -n "$line" ] || continue
    case "$line" in
      */*/*|/*|*/|*[!A-Za-z0-9._/-]*) die "malformed record" ;;
      */*) ;;
      *) die "malformed record" ;;
    esac
    seen=1
    [ "$(lower "$line")" != "$want" ] || found=1
  done
  [ "$seen" -eq 1 ] || die "no records -- a call that returned nothing is not a probe result"
  if [ "$found" -eq 1 ]; then echo reached; else echo unreached; fi
}

case "${1:-}" in
  classify) shift; classify "$@" ;;
  reach) shift; reach "$@" ;;
  *) echo "usage: gh-identity.sh classify <login> <id> <project.yml> | reach <owner/repo>" >&2; exit 2 ;;
esac
