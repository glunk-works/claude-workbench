#!/bin/sh
# What does this machine lack that the repo relies on? (#1377) Two read-only checks that
# /way-of-working:resume reports on two lines of its pick-up point, and that never block or enable
# auto-start, install, update or edit anything:
#
#   host-doctor.sh tools <project-file>
#   host-doctor.sh plugin <settings-file> <installed-file> <project-dir>
#
# Always exits 0. A missing yq (mikefarah v4), jq or timeout prints `unreadable`, as does a mode or
# argument count it does not know. It names no host tool and no repo-specific value: the tools come
# from the consuming repo's `host_tools` key (reference/project-schema.md, `### host_tools`).
#
# `tools <project-file>` reads `host_tools` from the file it is given (the caller passes the default
# branch's committed copy, never the working tree's). Absent, `null` or an empty list prints `none`;
# a value that breaks the entry rule schema-complete.sh applies (a list of maps of exactly `name`,
# `min` and `fix`, as below) prints `unreadable`. Otherwise one line per entry, in list order:
#     ok <name> <found>
#     old <name> <found> <min>
#     missing <name> <min>
#     unknown <name> <min>
# and after each line that is not `ok`, one line `fix <name> <json>`, <json> the entry's `fix` text
# as one compact JSON string. A tool is `missing` when `command -v` gives no absolute path of an
# executable regular file (a builtin, function, alias or relative PATH entry counts as missing). Otherwise the script runs that path with the one
# argument `--version`, standard input from the null device, under `timeout -k 5 10`, and reads the first
# run of digits and dots of the form N.N (or longer) on the first line of standard output. No such
# run, a run with a component longer than nine digits, a non-zero exit or a timeout reads `unknown`.
# Versions compare component by component as decimal integers (leading zeros ignored, a missing
# component read as 0); `old` means found is lower than `min`. The `fix` text is data and is never run.
#
# `plugin <settings-file> <installed-file> <project-dir>` compares the plugin pin in the settings
# file with the user's installed-plugins record. An absent settings file prints `no-settings`; a
# settings file that is not a JSON object, or an installed file that exists but is not JSON, prints
# `unreadable` (the settings file must hold exactly one JSON value; so must the installed file, which
# may be any value). For each `enabledPlugins` key whose value is `true`, in file order:
#     bad-pin                         the key, or the pin's repo or ref, is out of shape (printed alone,
#                                     never the key or any part of the pin)
#     unpinned <key>                  no `extraKnownMarketplaces` entry for the marketplace with a
#                                     github `source` carrying a `repo` and a `ref`
#     unresolved <key> <ref>          the ref could not be resolved as a tag (git ls-remote failed, timed
#                                     out at 60 s or found none)
#     match <key> <ref>               an installed record applies and every applying record is at the
#                                     tag's commit
#     not-installed <key> <ref>       no installed record applies
#     differs <key> <ref> <tag-commit> <commit>[,<commit>...]   the applying records' commits that
#                                     differ (a commit not 40 lowercase hex characters prints as `bad`)
# A record applies when its `scope` is `user`, or its `projectPath` equals <project-dir> once every
# backslash is read as a slash and a leading drive letter is compared without case. Then
# `statusline present|absent` (a `statusLine` object) and `merge-deny present|absent` (a string
# starting with `Bash(gh pr merge` in `permissions.deny`), after `no-plugin` when no plugin is
# enabled. No value from the settings file is printed before it passed its shape check.

LC_ALL=C
export LC_ALL
GIT_TERMINAL_PROMPT=0
export GIT_TERMINAL_PROMPT

# Only absolute PATH entries are searched: a relative or empty entry would resolve a name to a file
# in the working tree (which a branch can edit), and some shells print that as an absolute path.
set -f; P=; IFS=:
for d in $PATH; do case "$d" in /*) P=${P:+$P:}$d ;; esac; done
unset IFS; set +f
PATH=$P
export PATH

for t in yq jq timeout; do
  command -v "$t" >/dev/null 2>&1 || { echo unreadable; exit 0; }
done

T=$(mktemp -d 2>/dev/null) || { echo unreadable; exit 0; }
trap 'rm -rf "$T"' EXIT HUP INT TERM

# The entry rule, the one schema-complete.sh applies to `host_tools` (keep the two in step).
ENTRY_RULE='.host_tools | explode(.) | ([.[] | (select(tag == "!!map") | select((keys | sort | join(",")) == "fix,min,name") | select((.name | tag) == "!!str" and (.min | tag) == "!!str" and (.fix | tag) == "!!str") | ((.name | test("^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")) and (.min | test("^[0-9]{1,9}([.][0-9]{1,9})*$")) and (.fix | test("^[ -~]{1,200}$")))) // false] | all) as $ok | (if $ok then (([.[] | .name] | unique | length) == length) else false end) | to_string'

# cmp_version <found> <min> -- prints `unknown` (a component over nine digits), `old` or `ok`
cmp_version() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    na = split(a, x, "."); nb = split(b, y, ".")
    for (i = 1; i <= na; i++) if (length(x[i]) > 9) { print "unknown"; exit }
    n = (na > nb) ? na : nb
    for (i = 1; i <= n; i++) {
      p = (i <= na) ? x[i] + 0 : 0; q = (i <= nb) ? y[i] + 0 : 0
      if (p < q) { print "old"; exit }
      if (p > q) { print "ok"; exit }
    }
    print "ok"
  }'
}

# tool_version <name> -- prints the version found, or nothing (unknown); returns 1 for missing
tool_version() {
  p=$(command -v "$1" 2>/dev/null)
  case "$p" in /*) ;; *) return 1 ;; esac   # a builtin, function, alias or relative path is missing
  { [ -f "$p" ] && [ -x "$p" ]; } || return 1
  ( ulimit -f 2048 2>/dev/null; timeout -k 5 10 "$p" --version </dev/null >"$T/out" 2>/dev/null ) || return 0
  head -n 1 "$T/out" 2>/dev/null | head -c 1024 | awk '{ if (match($0, /[0-9]+([.][0-9]+)+/)) print substr($0, RSTART, RLENGTH); exit }'
  return 0
}

mode_tools() {
  [ $# -eq 1 ] && [ -f "$1" ] || { echo unreadable; return; }
  f=$1
  tag=$(yq eval '.host_tools | tag' "$f" 2>/dev/null) || { echo unreadable; return; }
  case "$tag" in
    '!!null') echo none; return ;;
    '!!seq') ;;
    *) echo unreadable; return ;;
  esac
  count=$(yq eval '.host_tools | length' "$f" 2>/dev/null) || { echo unreadable; return; }
  [ "$count" = 0 ] && { echo none; return; }
  good=$(yq eval "$ENTRY_RULE" "$f" 2>/dev/null) || { echo unreadable; return; }
  [ "$good" = true ] || { echo unreadable; return; }
  yq eval -o=json -I=0 '.host_tools | explode(.) | .[]' "$f" >"$T/entries.json" 2>/dev/null || { echo unreadable; return; }
  jq -r '.name + "\t" + .min + "\t" + (.fix | tojson)' "$T/entries.json" >"$T/entries.tsv" 2>/dev/null || { echo unreadable; return; }
  tab=$(printf '\t')
  while IFS="$tab" read -r name min fixjson; do
    if found=$(tool_version "$name" 2>/dev/null); then
      state=unknown
      if [ -n "$found" ]; then state=$(cmp_version "$found" "$min"); fi
      case "$state" in
        ok) echo "ok $name $found"; continue ;;
        old) echo "old $name $found $min" ;;
        *) echo "unknown $name $min" ;;
      esac
    else
      echo "missing $name $min"
    fi
    printf '%s\n' "fix $name $fixjson"
  done <"$T/entries.tsv"
}

# the jq shape checks for a plugin key and its marketplace pin; prints one tab-separated line per
# enabled plugin: `bad`, `unpinned<TAB>key` or `pin<TAB>key<TAB>repo<TAB>ref`, only values that passed
PIN_JQ='
def half: type == "string" and test("\\A[A-Za-z0-9._-]+\\z") and . != "." and . != ".." and (startswith("-") | not);
def refok: type == "string" and test("\\A[A-Za-z0-9._-]+\\z") and (startswith("-") | not);
(.enabledPlugins // {}) as $e | (.extraKnownMarketplaces // {}) as $m |
if ($e | type) != "object" then empty else
  $e | to_entries[] | select(.value == true) | .key as $k | ($k | split("@")) as $h |
  if ($h | length) != 2 or ($h | all(half) | not) then "bad"
  else
    (if ($m | type) == "object" then $m[$h[1]] else null end) as $mk |
    (if ($mk | type) == "object" then $mk.source else null end) as $s |
    if ($s | type) != "object" or $s.source != "github" or ($s.repo // null) == null or ($s.ref // null) == null then "unpinned\t" + $k
    elif (($s.repo | type) != "string") or (($s.repo | split("/")) as $r | ($r | length) != 2 or ($r | all(half) | not)) or ($s.ref | refok | not) then "bad"
    else "pin\t" + $k + "\t" + $s.repo + "\t" + $s.ref end
  end
end'

# record commits applying to the project for one key, one per line (`bad` for a non-40-hex value)
REC_JQ='
def norm: gsub("\\\\"; "/") | if test("\\A[A-Za-z]:") then (.[0:1] | ascii_downcase) + .[1:] else . end;
((.plugins? | objects | .[$k]) // []) | arrays | .[] | objects
| select(.scope == "user" or ((.projectPath | type) == "string" and (.projectPath | norm) == ($dir | norm)))
| (.gitCommitSha | if type == "string" and test("\\A[0-9a-f]{40}\\z") then . else "bad" end)'

mode_plugin() {
  [ $# -eq 3 ] || { echo unreadable; return; }
  settings=$1; installed=$2; dir=$3
  [ -e "$settings" ] || { echo no-settings; return; }
  jq -e -s 'length == 1 and (.[0] | type) == "object"' "$settings" >/dev/null 2>&1 || { echo unreadable; return; }
  if [ -e "$installed" ]; then
    jq -e -s 'length == 1' "$installed" >/dev/null 2>&1 || { echo unreadable; return; }
    cp "$installed" "$T/installed.json" || { echo unreadable; return; }
  else
    echo '{}' >"$T/installed.json"
  fi
  jq -r "$PIN_JQ" "$settings" >"$T/pins.tsv" 2>/dev/null || { echo unreadable; return; }
  tab=$(printf '\t')
  n=0
  while IFS="$tab" read -r kind key repo ref; do
    n=$((n + 1))
    case "$kind" in
      unpinned) echo "unpinned $key"; continue ;;
      pin) ;;
      *) echo bad-pin; continue ;;
    esac
    tagc=
    if ( timeout -k 5 60 git ls-remote "https://github.com/$repo.git" "refs/tags/$ref" "refs/tags/$ref^{}" </dev/null >"$T/ls" 2>/dev/null ); then
      tagc=$(awk -v r="refs/tags/$ref" '$2 == r "^{}" { p = $1 } $2 == r { l = $1 } END { v = (p != "") ? p : l; if (v ~ /^[0-9a-f]+$/ && length(v) == 40) print v }' "$T/ls")
    fi
    [ -n "$tagc" ] || { echo "unresolved $key $ref"; continue; }
    jq -r --arg k "$key" --arg dir "$dir" "$REC_JQ" "$T/installed.json" >"$T/recs" 2>/dev/null || { echo unreadable; return; }
    if [ ! -s "$T/recs" ]; then
      echo "not-installed $key $ref"
    else
      differ=$(awk -v t="$tagc" '$0 != t { printf "%s%s", (c++ ? "," : ""), $0 }' "$T/recs")
      if [ -z "$differ" ]; then echo "match $key $ref"; else echo "differs $key $ref $tagc $differ"; fi
    fi
  done <"$T/pins.tsv"
  [ "$n" -gt 0 ] || echo no-plugin
  if jq -e '(.statusLine | type) == "object"' "$settings" >/dev/null 2>&1; then echo "statusline present"; else echo "statusline absent"; fi
  if jq -e '[.permissions? | objects | .deny? | arrays | .[] | strings | select(startswith("Bash(gh pr merge"))] | length > 0' "$settings" >/dev/null 2>&1; then echo "merge-deny present"; else echo "merge-deny absent"; fi
}

case "$1" in
  tools) shift; mode_tools "$@" ;;
  plugin) shift; mode_plugin "$@" ;;
  *) echo "usage: host-doctor.sh tools <project-file> | host-doctor.sh plugin <settings-file> <installed-file> <project-dir>" >&2; echo unreadable ;;
esac
exit 0
