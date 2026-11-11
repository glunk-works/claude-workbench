#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/host-doctor.sh (#1377), run offline: stub tools on a
# temporary PATH print canned version lines, and a stub `git` prints canned `ls-remote` output.
# Needs the real `yq` (mikefarah v4), `jq` and `timeout` on the PATH the script is started with;
# skips loudly without them.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/host-doctor.sh"

for t in yq jq timeout; do
  command -v "$t" >/dev/null 2>&1 || { echo "skip - host-doctor.sh fixtures: no $t on PATH" >&2; exit 0; }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

assert_eq() {
  if [ "$2" = "$3" ]; then echo "ok - $1"; else echo "FAIL - $1: expected [$2], got [$3]" >&2; fail=1; fi
}

# --- stub tools ------------------------------------------------------------
stubs="$tmp/stubs"; mkdir -p "$stubs"
mkstub() { # mkstub <name> <script body>
  printf '#!/bin/sh\n%s\n' "$2" >"$stubs/$1"; chmod +x "$stubs/$1"
}
mkstub newtool 'echo "newtool version 2.40.1 (build 7)"'
mkstub eqtool 'echo "eqtool 3.0"'
mkstub oldtool 'echo "oldtool 1.9.2"'
mkstub padtool 'echo "padtool 01.010.0"'
mkstub nover 'echo "no number here"'
mkstub badcomp 'echo "badcomp 1.12345678901"'
mkstub failing 'echo "failing 9.9"; exit 3'
mkstub slowtool 'sleep 30; echo "slowtool 9.9"'
mkstub ignoreterm 'trap "" TERM; sleep 25; echo "ignoreterm 9.9"'
mkstub stdintool 'cat >/dev/null; echo "stdintool 5.5"'
# git: canned ls-remote answers keyed by the ref asked for; GIT_STUB_MODE selects the answer
mkstub git 'case "$1" in ls-remote) ;; *) exit 2 ;; esac
url=$2; ref=$3
echo "$url" >>"$GIT_STUB_LOG"
case "$GIT_STUB_MODE" in
  fail) exit 128 ;;
  none) exit 0 ;;
  lightweight) printf "%s\t%s\n" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$ref" ;;
  annotated) printf "%s\t%s\n%s\t%s^{}\n" bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb "$ref" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$ref" ;;
  short) printf "%s\t%s\n" abc123 "$ref" ;;
esac'
export GIT_STUB_LOG="$tmp/git.log"; : >"$GIT_STUB_LOG"

run() { PATH="$stubs:$PATH" "$script" "$@"; }

# --- tools -----------------------------------------------------------------
proj="$tmp/p.yml"
cat >"$proj" <<'YML'
repo: acme/widgets
host_tools:
  - {name: newtool, min: "2.40", fix: "install newtool"}
  - {name: eqtool, min: "3.0.0", fix: "x"}
  - {name: oldtool, min: "1.10", fix: "upgrade \"oldtool\" with: tool up"}
  - {name: padtool, min: "1.10", fix: "x"}
  - {name: absenttool, min: "1.0", fix: "get absenttool"}
  - {name: nover, min: "1.0", fix: "x"}
  - {name: badcomp, min: "1.0", fix: "x"}
  - {name: failing, min: "1.0", fix: "x"}
  - {name: stdintool, min: "5.5", fix: "x"}
YML
want='ok newtool 2.40.1
ok eqtool 3.0
old oldtool 1.9.2 1.10
fix oldtool "upgrade \"oldtool\" with: tool up"
ok padtool 01.010.0
missing absenttool 1.0
fix absenttool "get absenttool"
unknown nover 1.0
fix nover "x"
unknown badcomp 1.0
fix badcomp "x"
unknown failing 1.0
fix failing "x"
ok stdintool 5.5'
assert_eq "tools: ok, equal with a missing component, old, leading zeros, missing, unknown, nine-digit cap, non-zero exit, null stdin" "$want" "$(run tools "$proj")"

cat >"$tmp/slow.yml" <<'YML'
host_tools: [{name: slowtool, min: "1.0", fix: "x"}]
YML
s0=$(date +%s)
assert_eq "tools: a tool that hangs reads unknown after the timeout" 'unknown slowtool 1.0
fix slowtool "x"' "$(run tools "$tmp/slow.yml")"
s1=$(date +%s)
[ $((s1 - s0)) -lt 25 ] && echo "ok - tools: the hang was cut at about ten seconds" || { echo "FAIL - tools: the hang ran $((s1 - s0)) s" >&2; fail=1; }

cat >"$tmp/term.yml" <<'YML'
host_tools: [{name: ignoreterm, min: "1.0", fix: "back\\slash C:\\tools"}]
YML
s0=$(date +%s)
out=$(run tools "$tmp/term.yml" 2>"$tmp/term.err")
assert_eq "tools: a killed tool leaves nothing on stderr" "" "$(cat "$tmp/term.err")"
s1=$(date +%s)
assert_eq "tools: a tool that ignores TERM is killed, and a backslash in fix stays valid JSON" 'unknown ignoreterm 1.0
fix ignoreterm "back\\slash C:\\tools"' "$out"
[ $((s1 - s0)) -lt 20 ] && echo "ok - tools: a tool ignoring TERM was cut by the kill delay" || { echo "FAIL - tools: ignoring TERM ran $((s1 - s0)) s" >&2; fail=1; }
printf 'host_tools: [{name: echo, min: "1.0", fix: x}]\n' >"$tmp/echo.yml"
mkdir "$tmp/cwd" && printf '#!/bin/sh\necho "echo 9.9"\n' >"$tmp/cwd/echo" && chmod +x "$tmp/cwd/echo"
assert_eq "tools: a builtin name is missing even when a file of that name sits in the cwd" 'missing echo 1.0
fix echo "x"' "$(cd "$tmp/cwd" && PATH="$stubs:$PATH" "$script" tools "$tmp/echo.yml" | sed 's/^ok echo .*/IGNORED/;' | head -2)" || true

mkdir -p "$tmp/rel" && printf '#!/bin/sh\necho "planted 9.9"\n' >"$tmp/rel/planted" && chmod +x "$tmp/rel/planted"
printf 'host_tools: [{name: planted, min: "1.0", fix: x}]\n' >"$tmp/rel.yml"
assert_eq "tools: a relative or empty PATH entry is never searched" 'missing planted 1.0
fix planted "x"' "$(cd "$tmp/rel" && PATH=".::$stubs:$PATH" "$script" tools "$tmp/rel.yml")"
if command -v bash >/dev/null 2>&1; then
  assert_eq "tools: the same under bash in POSIX mode" 'missing planted 1.0
fix planted "x"' "$(cd "$tmp/rel" && PATH=".::$stubs:$PATH" bash --posix "$script" tools "$tmp/rel.yml")"
fi
printf 'repo: a/b\n' >"$tmp/absent.yml"
assert_eq "tools: host_tools absent prints none" none "$(run tools "$tmp/absent.yml")"
printf 'host_tools: null\n' >"$tmp/null.yml"
assert_eq "tools: host_tools null prints none" none "$(run tools "$tmp/null.yml")"
printf 'host_tools: []\n' >"$tmp/empty.yml"
assert_eq "tools: an empty list prints none" none "$(run tools "$tmp/empty.yml")"
for v in 'host_tools: gh' 'host_tools: [{name: gh, min: 1.10, fix: x}]' 'host_tools: [{name: gh, min: "1"}]' 'host_tools: [{name: a, min: "1", fix: x}, {name: a, min: "1", fix: x}]' 'host_tools: [{name: "a/b", min: "1", fix: x}]'; do
  printf '%s\n' "$v" >"$tmp/bad.yml"
  assert_eq "tools: $v is unreadable" unreadable "$(run tools "$tmp/bad.yml")"
done
printf 'x: [unterminated\n' >"$tmp/broken.yml"
assert_eq "tools: an unparseable file is unreadable" unreadable "$(run tools "$tmp/broken.yml")"
assert_eq "tools: a missing file is unreadable" unreadable "$(run tools "$tmp/none.yml")"
cat >"$tmp/shell.yml" <<'YML'
host_tools: [{name: newtool, min: "9.0", fix: "$(touch PWNED); `touch PWNED`"}]
YML
( cd "$tmp" && run tools "$tmp/shell.yml" >"$tmp/shell.out" )
assert_eq "tools: the fix text is printed as data, never run" 'old newtool 2.40.1 9.0
fix newtool "$(touch PWNED); `touch PWNED`"' "$(cat "$tmp/shell.out")"
[ ! -e "$tmp/PWNED" ] && echo "ok - tools: the fix text created nothing" || { echo "FAIL - tools: the fix text ran" >&2; fail=1; }
# --- tools: a missing yq, jq or timeout ---------------------------------------
nopath="$tmp/nopath"; mkdir -p "$nopath"
for t in sh awk head mktemp rm cat cp printf; do
  p=$(command -v "$t" 2>/dev/null || true); case "$p" in /*) ln -sf "$p" "$nopath/$t" ;; esac
done
assert_eq "no yq, jq or timeout on PATH is unreadable" unreadable "$(PATH="$nopath" /bin/sh "$script" tools "$proj")"

# --- plugin ----------------------------------------------------------------
TAG=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
OTHER=cccccccccccccccccccccccccccccccccccccccc
PDIR=/work/repo
settings() { # settings <file> <enabledPlugins json> <extra json fragment, e.g. ,"statusLine":{}>
  printf '{"enabledPlugins":%s,"extraKnownMarketplaces":{"mkt":{"source":{"source":"github","repo":"acme/market","ref":"v1.2.3"}}}%s}\n' "$2" "$3" >"$1"
}
inst() { # inst <file> <records json array>
  printf '{"version":2,"plugins":{"wow@mkt":%s}}\n' "$2" >"$1"
}
prun() { # prun <mode> <settings> <installed> [dir]
  GIT_STUB_MODE=$1 run plugin "$2" "$3" "${4:-$PDIR}"
}
S="$tmp/s.json"; I="$tmp/i.json"
settings "$tmp/set1.json" '{"wow@mkt":true}' ''
settings "$S" '{"wow@mkt":true}' ',"statusLine":{"type":"command"},"permissions":{"deny":["Bash(gh pr merge:*)"]}'
inst "$I" "[{\"scope\":\"user\",\"gitCommitSha\":\"$TAG\"}]"
assert_eq "plugin: a user record at the tag commit matches; both settings lines present" "match wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun lightweight "$S" "$I")"
assert_eq "plugin: an annotated tag compares its peeled commit" "match wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun annotated "$S" "$I")"
grep -q 'https://github.com/acme/market.git' "$GIT_STUB_LOG" && echo "ok - plugin: ls-remote asked the GitHub URL of the pinned repo" || { echo "FAIL - plugin: ls-remote URL" >&2; fail=1; }

inst "$I" "[{\"scope\":\"user\",\"gitCommitSha\":\"$OTHER\"}]"
assert_eq "plugin: a record at another commit differs" "differs wow@mkt v1.2.3 $TAG $OTHER
statusline present
merge-deny present" "$(prun lightweight "$S" "$I")"
inst "$I" "[{\"scope\":\"user\",\"gitCommitSha\":\"$TAG\"},{\"scope\":\"user\",\"gitCommitSha\":\"notahash\"}]"
assert_eq "plugin: a malformed commit prints as bad and differs" "differs wow@mkt v1.2.3 $TAG bad
statusline present
merge-deny present" "$(prun lightweight "$S" "$I")"
inst "$I" "[{\"scope\":\"project\",\"projectPath\":\"/elsewhere\",\"gitCommitSha\":\"$TAG\"}]"
assert_eq "plugin: a record for another project does not apply, so not-installed" "not-installed wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun lightweight "$S" "$I")"
assert_eq "plugin: an absent installed file has no records" "not-installed wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun lightweight "$S" "$tmp/no-installed.json")"
inst "$I" "[{\"scope\":\"project\",\"projectPath\":\"C:\\\\Work\\\\repo\",\"gitCommitSha\":\"$TAG\"}]"
assert_eq "plugin: a project record differing only by slash direction and drive-letter case applies" "match wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun lightweight "$S" "$I" 'c:/Work/repo')"
inst "$I" "[{\"scope\":\"project\",\"projectPath\":\"C:\\\\Work\\\\repo\",\"gitCommitSha\":\"$OTHER\"},{\"scope\":\"project\",\"projectPath\":\"c:/Work/repo\",\"gitCommitSha\":\"$TAG\"}]"
assert_eq "plugin: every applying record must match; the stale one is named" "differs wow@mkt v1.2.3 $TAG $OTHER
statusline present
merge-deny present" "$(prun lightweight "$S" "$I" 'C:\Work\repo')"
printf 'not json' >"$tmp/badinst.json"
printf 'null\n{"enabledPlugins":{"wow@mkt":true}}\n' >"$tmp/stream.json"
assert_eq "plugin: a settings file of two JSON values is unreadable" unreadable "$(prun lightweight "$tmp/stream.json" "$I")"
printf 'null\n' >"$tmp/nullinst.json"
assert_eq "plugin: an installed file holding the JSON value null has no records" "not-installed wow@mkt v1.2.3
statusline absent
merge-deny absent" "$(prun lightweight "$tmp/set1.json" "$tmp/nullinst.json")"
assert_eq "plugin: an installed file that is not JSON is unreadable" unreadable "$(prun lightweight "$S" "$tmp/badinst.json")"

inst "$I" "[]"
assert_eq "plugin: a tag that cannot be resolved (ls-remote fails)" "unresolved wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun fail "$S" "$I")"
assert_eq "plugin: a tag that is not found" "unresolved wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun none "$S" "$I")"
assert_eq "plugin: a short commit from ls-remote is unresolved" "unresolved wow@mkt v1.2.3
statusline present
merge-deny present" "$(prun short "$S" "$I")"

settings "$S" '{"wow@mkt":true}' ''
assert_eq "plugin: statusline and merge-deny absent" "not-installed wow@mkt v1.2.3
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"
settings "$S" '{"wow@mkt":true}' ',"permissions":{"deny":["Bash(rm:*)"]}'
assert_eq "plugin: a deny list without the merge entry is absent" "not-installed wow@mkt v1.2.3
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"

printf '{"enabledPlugins":{"wow@other":true}}\n' >"$S"
assert_eq "plugin: no marketplace entry is unpinned" "unpinned wow@other
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"
printf '{"enabledPlugins":{"wow@mkt":true},"extraKnownMarketplaces":{"mkt":{"source":{"source":"git","repo":"a/b","ref":"v1"}}}}\n' >"$S"
assert_eq "plugin: a non-github source is unpinned" "unpinned wow@mkt
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"
printf '{"enabledPlugins":{"wow@mkt":true},"extraKnownMarketplaces":{"mkt":{"source":{"source":"github","repo":"a/b"}}}}\n' >"$S"
assert_eq "plugin: a pin without a ref is unpinned" "unpinned wow@mkt
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"

for bad in '"a/b/c","ref":"v1"' '"-a/b","ref":"v1"' '"a/..","ref":"v1"' '"a/b","ref":"-v1"' '"a/b","ref":"v 1"' '"a/b","ref":"v1\n"' '"a b/c","ref":"v1"' '"a/b","ref":5'; do
  printf '{"enabledPlugins":{"wow@mkt":true},"extraKnownMarketplaces":{"mkt":{"source":{"source":"github","repo":%s}}}}\n' "$bad" >"$S"
  assert_eq "plugin: pin {$bad} is bad-pin, naming nothing" "bad-pin
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"
done
for key in 'a@b@c' 'nomarket' '-x@mkt' '..@mkt' 'x@..' 'a b@mkt' '@mkt' 'x@' 'a\n@mkt'; do
  printf '{"enabledPlugins":{"%s":true}}\n' "$key" >"$S"
  assert_eq "plugin: key $key is bad-pin alone" "bad-pin
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"
done
printf '{"enabledPlugins":{"wow@mkt":false}}\n' >"$S"
assert_eq "plugin: a plugin that is not enabled is no plugin" "no-plugin
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"
printf '{}\n' >"$S"
assert_eq "plugin: no enabledPlugins is no-plugin" "no-plugin
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"
settings "$S" '{"wow@mkt":true,"b@mkt":true}' ''
inst "$I" "[{\"scope\":\"user\",\"gitCommitSha\":\"$TAG\"}]"
assert_eq "plugin: one line per enabled key, in file order" "match wow@mkt v1.2.3
not-installed b@mkt v1.2.3
statusline absent
merge-deny absent" "$(prun lightweight "$S" "$I")"

assert_eq "plugin: an absent settings file is no-settings" no-settings "$(prun lightweight "$tmp/none.json" "$I")"
printf '[1]\n' >"$S"
assert_eq "plugin: a settings file that is not an object is unreadable" unreadable "$(prun lightweight "$S" "$I")"
printf 'nope\n' >"$S"
assert_eq "plugin: a settings file that is not JSON is unreadable" unreadable "$(prun lightweight "$S" "$I")"
assert_eq "plugin: a wrong argument count is unreadable" unreadable "$(run plugin "$S" 2>/dev/null)"
assert_eq "an unknown mode is unreadable" unreadable "$("$script" bogus 2>/dev/null)"

[ "$fail" = 0 ] || exit 1
echo "host-doctor: all fixtures passed"
