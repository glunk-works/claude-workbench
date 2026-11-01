#!/bin/sh
# UserPromptSubmit hook: refuse a session whose GitHub token is an installation token that does
# not reach the repository its checkout's `origin` names (WB-D42). A dev-container directory
# copied into another repo without editing the token mount source starts fine and makes every
# call with the other repo's token; the SessionStart banner only prints `Acting as: unknown`, and
# a SessionStart hook cannot refuse anything, so the refusal is made on the first prompt.
#
# In order:
#   - no .ai/project.yml in the session directory: exit 0.
#   - a remembered pass for this session id: exit 0.
#   - GET /user (`gh api user`) names a login: a user token, which this check does not cover.
#     The prompt passes and the result is remembered.
#   - otherwise the installation probe from conventions.md's "Acting identity and reach", fed
#     to gh-identity.sh reach with origin's owner/name (parsed from the URL `git remote get-url
#     origin` prints (so an insteadOf rewrite applies), never printed itself, and never asked of GitHub with the token under test).
#       reached    pass, remembered.
#       unreached  exit 2 with one stderr line naming the repo: every prompt is refused until the
#                  token reaches it (a dev container mounting another repo's token directory is
#                  the usual cause). Not remembered, so the next prompt checks again.
#       anything else (no gh, git or timeout, no origin, an origin URL not in the three accepted
#                  forms, a failed, partial or timed-out call, reach exit 2): the prompt passes
#                  and nothing is remembered.
#
# Accepted origin forms, each with an optional `.git`: https://github.com/owner/name (optionally
# with a user name of letters, digits, `.`, `_` and `-`, no password, dropped), git@github.com:
# owner/name and ssh://git@github.com/owner/name. Both gh calls run with GH_HOST,
# GH_ENTERPRISE_TOKEN and GH_REPO unset and are bounded at 3 seconds each, under the hook's
# 10-second timeout. The hook writes nothing to stdout on any path.
#
# The remembered pass is one empty file per session id in a per-user directory under TMPDIR
# (default /tmp), created mode 700. A session id that is not plain letters, digits and hyphens, a
# missing jq, or a directory that is a link, not owned by the user, or writable by group or others
# only turns remembering off: the probe still runs on every prompt and still refuses on
# `unreached`.
#
# Limits: this is an accident guard, not a boundary. A repo that controls the session's settings
# can disable any hook, as the banner's header says, and any process running as the same user can
# write a pass. A pass on a tmp volume that outlives the container is kept by a session resumed
# after a recreate. An origin URL still naming a renamed repo's old name refuses until origin is
# updated. An origin in any other form (a password part, an ssh host alias) is not checked.
#
# Permitted toolset: POSIX sh and its standard utilities, jq, git, gh, timeout.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR
LC_ALL=C
export LC_ALL

[ -f .ai/project.yml ] || exit 0

here=$(cd -P -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0

# --- the remembered pass: dir/file stay empty when remembering is off ------------------------
pass=
input=$(cat 2>/dev/null) || input=
if command -v jq >/dev/null 2>&1; then
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || sid=
  case "$sid" in
    '' | *[!A-Za-z0-9-]*) ;;
    *)
      base=${TMPDIR:-/tmp}
      dir="$base/wow-reach-gate-$(id -u 2>/dev/null)"
      if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
        (umask 077 && mkdir -m 700 "$dir") 2>/dev/null || true
      fi
      if [ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ]; then
        # shellcheck disable=SC2012
        perms=$(ls -ld "$dir" 2>/dev/null | awk '{print $1}')
        case "$perms" in
          ?????w* | ????????w*) ;;
          d*) pass="$dir/$sid" ;;
        esac
      fi
      ;;
  esac
fi

if [ -n "$pass" ] && [ -f "$pass" ] && [ ! -L "$pass" ]; then exit 0; fi

remember() {
  [ -z "$pass" ] || [ -e "$pass" ] || [ -L "$pass" ] || : >"$pass" 2>/dev/null || true
}

command -v gh >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0
command -v timeout >/dev/null 2>&1 || exit 0

bounded_gh() {
  env -u GH_HOST -u GH_ENTERPRISE_TOKEN -u GH_REPO -u GIT_DIR -u GIT_WORK_TREE timeout 3 gh "$@" 2>/dev/null
}

# A login the banner would accept means a user token: this check does not cover it.
login=$(bounded_gh api user --hostname github.com --jq .login) || login=
rest=${login%\[bot\]}
case "$rest" in
  '' | -* | *- | *--* | *[!A-Za-z0-9-]*) login= ;;
esac
if [ -n "$login" ] && [ "${#login}" -le 45 ]; then
  remember
  exit 0
fi

# origin's owner/name, from the URL alone. The URL and any user name in it are never printed.
url=$(git remote get-url origin 2>/dev/null) || exit 0
case "$url" in
  https://github.com/*) rest=${url#https://github.com/} ;;
  https://*@github.com/*)
    user=${url#https://}
    user=${user%%@*}
    case "$user" in
      '' | *[!A-Za-z0-9._-]*) exit 0 ;;
    esac
    case "$url" in
      "https://$user@github.com/"*) rest=${url#"https://$user@github.com/"} ;;
      *) exit 0 ;;
    esac
    ;;
  git@github.com:*) rest=${url#git@github.com:} ;;
  ssh://git@github.com/*) rest=${url#ssh://git@github.com/} ;;
  *) exit 0 ;;
esac
rest=${rest%.git}
case "$rest" in
  */*/* | /* | */ | '' | *[!A-Za-z0-9._/-]*) exit 0 ;;
  */*) ;;
  *) exit 0 ;;
esac
repo=$rest

recs=$(bounded_gh api --hostname github.com --paginate installation/repositories --jq '.repositories[].full_name') || exit 0
[ -n "$recs" ] || exit 0
verdict=$(printf '%s\n' "$recs" | sh "$here/../bin/gh-identity.sh" reach "$repo" 2>/dev/null) || exit 0
case "$verdict" in
  reached) remember; exit 0 ;;
  unreached)
    echo "reach-gate: the token in use does not reach $repo, so every prompt is refused until it does (a dev container mounting another repo's token directory is the usual cause)." >&2
    exit 2
    ;;
esac
exit 0
