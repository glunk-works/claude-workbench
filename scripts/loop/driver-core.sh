#!/usr/bin/env bash
# Driver core: from a dead session's working tree to one local commit, hermetic.
#
# Issue #319, plan v9 § 7.3 ("Driver-side git rule", "How the copy is made safe") and
# § 8.13a: the driver, not the session, commits and pushes. This is the part that runs before
# any token exists: copy the tree into a fresh clone, check it, commit it, scan it. It stops at
# a local commit. Minting the App token, pushing and opening the PR are later tasks.
#
# Usage:
#   driver-core.sh run --session-tree DIR --session-id ID --origin URL --base BRANCH \
#       --workdir DIR --branch task/NAME --stop-json FILE \
#       --author-name NAME --author-email EMAIL \
#       --human-only-path PATH... [--token-prefix STR]
#
#   --session-tree   the session's working tree. Read as plain files; no git command ever
#                    runs in it, and its .git (top level or nested) is never read or copied.
#   --session-id     the container label value (loop.session=ID) that every session process
#                    carries. The copy waits on docker saying none is running.
#   --origin/--base  the driver makes a fresh clone of origin/{pr_base} itself.
#   --workdir        where that clone goes; must not exist or be empty. It must be on a
#                    case-sensitive Linux filesystem (plan § 7.3); the tree-scan refuses the
#                    .git spellings a case-insensitive one would fold onto the clone's .git.
#   --branch         the task branch to commit on; must match task/*.
#   --stop-json      the session's structured output (scripts/loop/stop-schema.json); the
#                    commit message is its commit_message field.
#   --human-only-path  repeatable, at least one (a missing list is a refusal, never an empty
#                    one): a path prefix, matched as `entry` or `entry/...`, case-folded.
#                    Nested names (a `sub/CLAUDE.md`) and `.gitattributes` are the caller's list
#                    to name; this script matches only what it is given.
#   --token-prefix   default sk-ant-oat, the OAuth token family. Any added line (symlink targets
#                    and converted encodings included), changed path or the message holding it
#                    refuses the commit. A tripwire for accidents, not a control against a
#                    hostile encoding.
#
# Output, one line on stdout:
#   committed <sha> <branch>      exit 0
#   empty                         exit 0, the tree matches the base, nothing committed
#   refused <rule>: <detail>      exit 3, a rule fired; the token prefix is redacted in the detail
#   (usage or environment fault is a message on stderr and exit 2)
#
# Rules, in order (each refuses and stops):
#   1. liveness   `docker ps -q --filter label=loop.session=ID` prints nothing. The launcher does
#                 not set that label yet and no issue tracks that (a follow-up is needed), so until it lands this rule cannot see a
#                 live session; do not call this script on a session it cannot label. A docker error
#                 is a refusal: unknown is not dead.
#   2. tree-scan  no special file (fifo, socket, device); no name that folds onto .git (any case,
#                 `.git.`, `.git `, `GIT~1`); no symlink that leaves the tree or points at a
#                 .git: an absolute target, a newline in the target, more leading `..` than the
#                 link is deep, or a `..` after a plain component (which a symlinked directory
#                 could make mean something other than what it reads as).
#   3. copy       the clone is emptied (mirrors deletions), then the tree is copied with a
#                 non-dereferencing tar that excludes .git at any depth. Gitignored files are
#                 not added (no `git add --force`).
#   4. human-only the staged diff, rename detection off so both sides of a move are listed as
#                 their own paths, touches no human-only path. A path with a newline refuses.
#   5. fixture    a diff that adds or changes anything under plugins/*/bin/ or scripts/ (any
#                 case) must add or change a file under tests/ (plan principle 12).
#   6. message    validated against the commit grammar; closing keywords are stripped from the
#                 body, and so is any final paragraph git itself parses as trailers, and then
#                 any remaining line containing Co-authored-by: or Signed-off-by: (locale-proof, so a leading
#                 non-breaking space cannot hide it). A closing keyword in the subject refuses.
#   7. token      grep of the staged diff's added lines, the changed paths and the message
#                 for the token prefix. Only what the commit adds: a base that already holds
#                 the string does not stop every commit.
#   8. commit     GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1, explicit bot author and
#                 committer, commit.gpgsign=false, no hooks.
#
# Never touches GitHub: nothing here calls gh. The tests put a gh stub on PATH that fails if
# anything runs it. Needs bash, git, GNU tar, jq, docker (stubbed in tests).
set -euo pipefail

die() { echo "driver-core.sh: $*" >&2; exit 2; }

tree= sid= origin= base= workdir= branch= stopjson= aname= aemail= prefix=sk-ant-oat

refuse() {
  # One line, no control characters, and the token redacted from its prefix to the end of
  # the path segment: details quote session-chosen paths, and a caller may mirror this line.
  local esc detail
  esc=$(printf '%s' "$prefix" | sed 's/[][\.*^$|/]/\\&/g')
  detail=$(printf '%s' "$2" | tr '\000-\037\177' '?' | sed -E "s|${esc}[^[:space:]/]*|[token-prefix]|g")
  printf 'refused %s: %s\n' "$1" "$detail"
  exit 3
}

[ "${1:-}" = run ] || die "usage: driver-core.sh run --session-tree DIR ... (see the header)"
shift

hop=()
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || die "$1 needs a value"
  case "$1" in
    --session-tree)    tree=$2 ;;
    --session-id)      sid=$2 ;;
    --origin)          origin=$2 ;;
    --base)            base=$2 ;;
    --workdir)         workdir=$2 ;;
    --branch)          branch=$2 ;;
    --stop-json)       stopjson=$2 ;;
    --author-name)     aname=$2 ;;
    --author-email)    aemail=$2 ;;
    --human-only-path) hop+=("$2") ;;
    --token-prefix)    prefix=$2 ;;
    *)                 die "unknown option: $1" ;;
  esac
  shift 2
done

for v in tree sid origin base workdir branch stopjson aname aemail prefix; do
  [ -n "${!v}" ] || die "--${v//_/-} is required"
done
[ ${#hop[@]} -gt 0 ] || die "at least one --human-only-path is required"
[[ "$prefix" =~ ^[A-Za-z0-9_.-]+$ ]] || die "--token-prefix must be 1+ of [A-Za-z0-9_.-]"
# Normalise caller entries now: a typo that would silently protect nothing is a usage fault.
hopn=()
for entry in "${hop[@]}"; do
  e=$entry
  case "$e" in ''|*[[:space:]]|[[:space:]]*) die "--human-only-path is empty or has whitespace at an end: [$entry]" ;; esac
  case "$e" in *[\\*?[]*|*[[:cntrl:]]*) die "--human-only-path has a glob, backslash or control character (entries are literal path prefixes): [$entry]" ;; esac
  while [[ "$e" == */ ]]; do e=${e%/}; done
  while [[ "$e" == ./* ]]; do e=${e#./}; done
  case "$e" in
    ''|.|/*|*//*|..|../*|*/..|*/../*|*/.|./*|*/./*) die "--human-only-path is not a plain relative path: $entry" ;;
  esac
  hopn+=("$(printf '%s' "$e" | tr 'A-Z' 'a-z')")
done
case "$sid" in *[!A-Za-z0-9._-]*) die "--session-id has characters outside [A-Za-z0-9._-]" ;; esac
case "$base" in ''|-*|*[!A-Za-z0-9._/-]*) die "--base is not a plain branch name" ;; esac
case "$branch" in
  task/*) ;;
  *) die "--branch must match task/*" ;;
esac
case "$branch" in -*|*[!A-Za-z0-9._/-]*|*..*) die "--branch is not a plain branch name" ;; esac
[ -d "$tree" ] || die "--session-tree is not a directory: $tree"
[ -r "$stopjson" ] || die "cannot read --stop-json $stopjson"
command -v jq >/dev/null 2>&1 || die "jq not on PATH"

tree=$(cd -P "$tree" && pwd)
if [ -d "$origin" ]; then origin=$(cd -P "$origin" && pwd); fi
if [ -e "$workdir" ]; then
  [ -d "$workdir" ] && [ -z "$(ls -A "$workdir")" ] || die "--workdir exists and is not empty"
fi
mkdir -p "$workdir"
workdir=$(cd -P "$workdir" && pwd)
case "$workdir/" in "$tree"/*) die "--workdir is inside the session tree" ;; esac
case "$tree/" in "$workdir"/*) die "--session-tree is inside the workdir" ;; esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The driver's git: no global or system config, none of the caller's git environment, no
# hooks, no fsmonitor, never a prompt. Apart from the clone itself and the trailer probe (both run from outside any repo), it only ever runs in $workdir, a clone this script made.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
      GIT_COMMON_DIR GIT_NAMESPACE GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_CEILING_DIRECTORIES \
      GIT_TEMPLATE_DIR GIT_EXEC_PATH GIT_EXTERNAL_DIFF
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
G() {
  git -C "$workdir" -c core.hooksPath=/dev/null -c core.fsmonitor=false -c core.symlinks=true \
      -c core.autocrlf=false -c core.quotePath=false -c commit.gpgsign=false "$@"
}
lc() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# --- 1. liveness ---------------------------------------------------------------------------
if ! alive=$(docker ps -q --filter "label=loop.session=$sid" 2>"$tmp/docker.err"); then
  refuse liveness "docker could not say whether session $sid is still running"
fi
[ -z "$alive" ] || refuse liveness "session $sid still has a running container"

# --- 2. tree-scan --------------------------------------------------------------------------
(cd "$tree" && find . -name .git -prune -o ! -type f ! -type d ! -type l -print0) >"$tmp/special" 2>/dev/null \
  || refuse tree-scan "could not walk the session tree"
if [ -s "$tmp/special" ]; then
  refuse tree-scan "special file in the tree: $(tr '\0' '\n' <"$tmp/special" | head -n 1)"
fi

# A name that a case-insensitive or NTFS/HFS filesystem folds onto .git would land on the
# clone's own .git/config; the exact name .git is pruned above and excluded from the copy.
(cd "$tree" && find . -name .git -prune -o \( -iname '.git*' -o -iname 'git~*' \) -print0) >"$tmp/aliases" 2>/dev/null \
  || refuse tree-scan "could not walk the session tree"
while IFS= read -r -d '' p; do
  b=${p##*/}
  if [[ "$b" =~ ^\.[gG][iI][tT][.\ ]*$ ]] || [[ "$b" =~ ^[gG][iI][tT]~[0-9]+$ ]]; then
    refuse tree-scan "name that folds onto .git: ${p#./}"
  fi
done <"$tmp/aliases"

(cd "$tree" && find . -name .git -prune -o -type l -print0) >"$tmp/links" 2>/dev/null \
  || refuse tree-scan "could not walk the session tree"
while IFS= read -r -d '' link; do
  rel=${link#./}
  target=$(readlink "$tree/$rel") || refuse tree-scan "unreadable symlink: $rel"
  [ -n "$target" ] || refuse tree-scan "empty symlink target: $rel"
  case "$target" in
    /*)      refuse tree-scan "absolute symlink target: $rel" ;;
    *$'\n'*) refuse tree-scan "newline in a symlink target: $rel" ;;
  esac
  dir=$(dirname "$rel")
  depth=0
  if [ "$dir" != . ]; then
    IFS=/ read -r -a dparts <<<"$dir"
    depth=${#dparts[@]}
  fi
  ups=0 seen_plain=0
  IFS=/ read -r -a tparts <<<"$target"
  for part in "${tparts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..)
        [ "$seen_plain" -eq 0 ] || refuse tree-scan "symlink target climbs after a plain component: $rel"
        ups=$((ups + 1)) ;;
      *)
        if [[ "$part" =~ ^\.[gG][iI][tT][.\ ]*$ ]] || [[ "$part" =~ ^[gG][iI][tT]~[0-9]+$ ]]; then
          refuse tree-scan "symlink target names a .git: $rel"
        fi
        seen_plain=1 ;;
    esac
  done
  [ "$ups" -le "$depth" ] || refuse tree-scan "symlink leaves the tree: $rel"
done <"$tmp/links"

# --- 3. copy -------------------------------------------------------------------------------
rmdir "$workdir"
git -C "$tmp" -c core.hooksPath=/dev/null -c core.fsmonitor=false clone --quiet --single-branch --template= \
    --branch "$base" --no-hardlinks -- "$origin" "$workdir" >/dev/null 2>"$tmp/clone.err" \
  || die "could not clone $origin at $base: $(head -n 1 "$tmp/clone.err")"
G checkout --quiet -b "$branch" || die "could not create branch $branch"

find "$workdir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + \
  || die "could not empty the clone"
tar -C "$tree" --exclude=.git -cf - . | tar -C "$workdir" --no-same-owner --no-same-permissions -xf - \
  || refuse copy "the session tree could not be copied"

G add -A || refuse copy "git could not stage the copied tree"

# --- 4. human-only paths -------------------------------------------------------------------
G diff --cached --name-only --no-renames -z >"$tmp/changed.z" || die "git diff failed"
nuls=$(tr -cd '\0' <"$tmp/changed.z" | wc -c)
lines=$(tr '\0' '\n' <"$tmp/changed.z" | wc -l)
[ "$nuls" -eq "$lines" ] || refuse human-only "a changed path contains a newline"
tr '\0' '\n' <"$tmp/changed.z" >"$tmp/changed"

if [ ! -s "$tmp/changed" ]; then
  echo empty
  exit 0
fi

while IFS= read -r path; do
  lpath=$(lc "$path")
  for lentry in "${hopn[@]}"; do
    if [ "$lpath" = "$lentry" ]; then refuse human-only "changes $path"; fi
    case "$lpath" in "$lentry"/*) refuse human-only "changes $path (under $lentry/)" ;; esac
  done
done <"$tmp/changed"

# --- 5. fixture ----------------------------------------------------------------------------
G diff --cached --name-only --no-renames --diff-filter=AMT -z >"$tmp/amt.z" || die "git diff failed"
tr '\0' '\n' <"$tmp/amt.z" >"$tmp/amt"
if lc "$(cat "$tmp/amt")" | grep -Eq '^(plugins/[^/]+/bin/|scripts/)'; then
  grep -q '^tests/' "$tmp/amt" \
    || refuse fixture "plugins/*/bin/ or scripts/ changed with no added or changed file under tests/"
fi

# --- 6. message ----------------------------------------------------------------------------
jq -e '.status == "done" and (.commit_message | type == "string")' "$stopjson" >/dev/null 2>&1 \
  || refuse message "stop output is not status done with a commit_message string"
jq -e '.commit_message | contains("\r") | not' "$stopjson" >/dev/null 2>&1 \
  || refuse message "commit message has a carriage return"
# jq writes text-mode newlines on Windows; the check above leaves no real CR to lose here.
jq -j '.commit_message' "$stopjson" | tr -d '\r' >"$tmp/raw"
[ "$(wc -c <"$tmp/raw")" -le 8192 ] || refuse message "commit message over 8192 bytes"

closing='(^|[^[:alnum:]_])(close[sd]?|fix(e[sd])?|resolve[sd]?)[:[:space:]]+(https?://github\.com/[^[:space:]]+/(issues|pull)/[0-9]+|([[:alnum:]_.-]+/[[:alnum:]_.-]+)?#[0-9]+)'
subject_re='^(feat|fix|docs|test|refactor|perf|chore|ci|revert)(\([a-z0-9][a-z0-9/_-]*\))?!?: ([^[:space:]].*)$'

mapfile -t msg <"$tmp/raw"
[ ${#msg[@]} -gt 0 ] || refuse message "commit message is empty"
subject=${msg[0]}
[[ "$subject" =~ $subject_re ]] || refuse message "subject is not type(scope): description"
desc=${BASH_REMATCH[3]}
[ ${#subject} -le 72 ] || refuse message "subject is over 72 characters"
case "$subject" in *.|*[[:space:]]) refuse message "subject ends with a period or a space" ;; esac
if [[ "$desc" =~ ^[[:upper:]] ]]; then refuse message "subject description starts with a capital"; fi
shopt -s nocasematch
if [[ "$subject" =~ $closing ]]; then refuse message "subject holds a closing keyword"; fi
if [ ${#msg[@]} -gt 1 ] && [ -n "${msg[1]}" ]; then refuse message "line 2 is not blank"; fi

body=()
for ((i = 2; i < ${#msg[@]}; i++)); do
  if [[ "${msg[i]}" =~ $closing ]]; then continue; fi
  body+=("${msg[i]}")
done
shopt -u nocasematch

trim_body() {
  while [ ${#body[@]} -gt 0 ] && [ -z "${body[${#body[@]}-1]//[[:space:]]/}" ]; do
    unset 'body[${#body[@]}-1]'
  done
  while [ ${#body[@]} -gt 0 ] && [ -z "${body[0]//[[:space:]]/}" ]; do body=("${body[@]:1}"); done
}
git_trailers() { # what git parses as trailers in the body; a dummy first paragraph keeps the
                 # subject (which can look like `token: value`) out of it
  { printf 'x\n\n'; [ ${#body[@]} -eq 0 ] || printf '%s\n' "${body[@]}"; } >"$tmp/probe"
  GIT_CEILING_DIRECTORIES=$(dirname "$tmp") git -C "$tmp" interpret-trailers --parse --no-divider <"$tmp/probe"
}
trim_body
# Drop the final paragraph while git reads trailers in it (attribution comes from git-shaped
# trailers; prose that merely looks like `Key: value` is left alone).
while :; do
  found=$(git_trailers) || refuse message "git could not read the message trailers"
  { [ -n "$found" ] && [ ${#body[@]} -gt 0 ]; } || break
  cut=0
  for ((i = ${#body[@]} - 1; i >= 0; i--)); do
    if [ -z "${body[i]//[[:space:]]/}" ]; then cut=$i; break; fi
  done
  body=("${body[@]:0:$cut}")
  trim_body
done
# Whatever prose is left may still carry an attribution line git did not read as a trailer.
shopt -s nocasematch
kept=()
for line in ${body[@]+"${body[@]}"}; do
  if [[ "$line" =~ (co-authored-by|signed-off-by)[[:space:]]*: ]]; then continue; fi
  kept+=("$line")
done
shopt -u nocasematch
body=(${kept[@]+"${kept[@]}"})
trim_body
{
  printf '%s\n' "$subject"
  if [ ${#body[@]} -gt 0 ]; then printf '\n'; printf '%s\n' "${body[@]}"; fi
} >"$tmp/message"

# --- 7. token prefix -----------------------------------------------------------------------
scan() { # scan <label> <file>: refuse when the file holds the prefix; a failed grep refuses too
  local rc=0
  grep -aF -- "$prefix" "$2" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) refuse token "token prefix in $1" ;;
    1) ;;
    *) refuse token "could not scan $1" ;;
  esac
}
# The staged diff shows each added blob as git will store it: symlink targets, and files after
# any working-tree-encoding conversion, which a grep of the files on disk would not see.
G diff --cached --no-renames --no-ext-diff --no-textconv -a -U0 >"$tmp/diff" || die "git diff failed"
grep -a "^+" "$tmp/diff" >"$tmp/added" || true
scan "the commit message" "$tmp/message"
scan "a changed path" "$tmp/changed"
scan "what the commit adds" "$tmp/added"

# --- 8. commit -----------------------------------------------------------------------------
GIT_AUTHOR_NAME=$aname GIT_AUTHOR_EMAIL=$aemail GIT_COMMITTER_NAME=$aname GIT_COMMITTER_EMAIL=$aemail \
  G commit --quiet --no-verify -F "$tmp/message" >/dev/null || die "git commit failed"
printf 'committed %s %s\n' "$(G rev-parse HEAD)" "$branch"
