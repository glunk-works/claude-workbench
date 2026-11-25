#!/bin/sh
# Fixture tests for scripts/identity/wow-publish (issue #1681).
#
# wow-publish, wow-common.sh, token-check.sh and gh-identity.sh are copied into a temporary directory beside a stub
# wow-admin, with a throwaway $WOW_HOME, $WOW_TTY pointing at a file and a stub `gh` first on PATH. The stub gh records each
# call's argv, stdin and whether GH_TOKEN and GH_CONFIG_DIR were set, and answers canned replies by method and path; switches
# in the environment fail a given call, answer a PUT with a wrong parent or a bad sha, or sleep in a PUT. The stub wow-admin
# records its arguments, writes a configurable token file on a mint and exits with a configurable status; its revoke writes one
# stdout line and then a finish marker file, so a revoke cut short by a failed write is visible.
#
# Covered: the happy path on an existing branch and on a new one; every refusal of steps 1 to 4 (manifest keys and patterns,
# files, hashes, modes, the answer), each with wow-admin and gh uncalled and no refused value in the output; a mint that
# exits 1 (no revoke, no gh); the granted-line check; every post-mint failure (nothing further written, one revoke, exit 1);
# the last verified head after a failed PUT; TERM during a PUT (the stopped-by-a-signal line and the last verified head) and during the mint (neither line; a token this run did not write is left alone); a manifest of two documents; a failed revoke; an escaped compare file name; a file over
# 32 KB (no argv carries it); an output reader that goes away after the mint (the signal line once, one revoke that finishes); the token in no output or argv; no .publish.* directory left; a second home with a tokens-root
# file; usage errors (exit 2).
set -u
here=$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -P -- "$here/.." && pwd)
for t in jq openssl; do command -v "$t" >/dev/null 2>&1 || { echo "SKIP - $t not on PATH"; exit 0; }; done

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
inst=$tmp/inst
mkdir "$inst" "$tmp/bin" "$tmp/stub"
cp "$root/scripts/identity/wow-publish" "$root/scripts/identity/wow-common.sh" \
   "$root/plugins/way-of-working/bin/token-check.sh" "$root/plugins/way-of-working/bin/gh-identity.sh" "$inst/"

TOKEN=ghs_AbCdEf0123456789AbCdEf0123456789AbCdEf
EXPIRES=2099-01-01T00:00:00Z
HEAD0=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
BASEHEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
OLD1=1111111111111111111111111111111111111111
export STUB_DIR="$tmp/stub" TOKEN EXPIRES HEAD0 BASEHEAD

cat >"$inst/wow-admin" <<'STUB'
#!/bin/sh
# stub wow-admin: records its arguments; on a mint writes the token file and prints the granted line
printf '%s\n' "$*" >>"$STUB_DIR/admin.calls"
if [ -n "${STUB_MINT_SLEEP:-}" ]; then : >"$STUB_DIR/mint.started"; sleep "$STUB_MINT_SLEEP"; fi
case " $* " in
  *" --revoke "*)
    # one stdout line under set -e, and only then the finish marker: a write to a gone reader that fails stops it before the marker
    set -e
    echo "revoking $1"
    : >"$STUB_DIR/revoke.finished"
    exit "${STUB_REVOKE_RC:-0}" ;;
esac
[ "${STUB_MINT_RC:-0}" = 0 ] || exit "$STUB_MINT_RC"
repo=${1#*/}; owner=${1%%/*}
d=$WOW_HOME/admin/$owner/$repo
mkdir -p "$d"
if [ -n "${STUB_TOKEN_CONTENT:-}" ]; then printf '%s\n' "$STUB_TOKEN_CONTENT" >"$d/admin-token"
else printf '%s\n%s\n' "${STUB_TOKEN:-$TOKEN}" "$EXPIRES" >"$d/admin-token"; fi
printf '%s\n' "${STUB_GRANTED:-granted: permissions contents=write,metadata=read,pull_requests=write,workflows=write repositories repo1}"
echo "admin token for $1 written"
STUB

cat >"$tmp/bin/gh" <<'STUB'
#!/bin/sh
# stub gh: only `gh api`; answers by method and endpoint
d=$STUB_DIR
printf '%s\n' "$*" >>"$d/gh.rawargv"
method=GET ep= jqx= input= host=none
[ "$1" = api ] && shift
while [ $# -gt 0 ]; do
  case "$1" in
    --hostname) host=$2; shift ;;
    -X) method=$2; shift ;;
    --paginate) ;;
    --jq) jqx=$2; shift ;;
    --input) input=$2; shift ;;
    *) ep=$1 ;;
  esac
  shift
done
printf '%s %s\n' "$method" "$ep" >>"$d/gh.calls"
printf '%s\n' "${GH_TOKEN:-}" >>"$d/gh.tok"
printf '%s\n' "$host" >>"$d/gh.host"
printf 'token=%s cfg=%s\n' "$([ -n "${GH_TOKEN:-}" ] && echo 1 || echo 0)" "${GH_CONFIG_DIR:-}" >>"$d/gh.env"
[ -z "${GH_HOST:-}${GITHUB_TOKEN:-}${GH_ENTERPRISE_TOKEN:-}" ] || echo leaked >>"$d/gh.leak"
printf '%s\n' "$method $ep $jqx" >>"$d/gh.argv"
has() { case " ${STUB_FAIL:-} " in *" $1 "*) return 0 ;; esac; return 1; }
out() { if [ -n "$jqx" ]; then printf '%s' "$1" | jq -r "$jqx"; else printf '%s\n' "$1"; fi; }
fail() { echo "gh: $1" >&2; exit 1; }
n=$(wc -l <"$d/gh.calls" | tr -d ' ')
body=
if [ "$input" = - ]; then cat >"$d/body.$n"; body=$d/body.$n; fi
case "$method $ep" in
  "GET installation/repositories")
    has inst && fail "Server Error (HTTP 500)"
    out "{\"repositories\":[{\"full_name\":\"${STUB_INST:-acme/repo1}\"}]}" ;;
  "GET repos/acme/repo1")
    has default && fail "Server Error (HTTP 500)"
    out "{\"default_branch\":\"${STUB_DEFAULT:-main}\"}" ;;
  "GET repos/acme/repo1/git/ref/heads/main")
    has baseref && fail "Server Error (HTTP 500)"
    out "{\"object\":{\"sha\":\"$BASEHEAD\"}}" ;;
  "GET repos/acme/repo1/git/ref/heads/"*)
    has branchref500 && fail "Server Error (HTTP 500)"
    [ -f "$d/head" ] || fail "Not Found (HTTP 404)"
    out "{\"object\":{\"sha\":\"$(cat "$d/head")\"}}" ;;
  "POST repos/acme/repo1/git/refs")
    has refspost && fail "Server Error (HTTP 500)"
    sha=$(jq -r .sha "$body"); printf '%s' "$sha" >"$d/head"
    cp "$body" "$d/refs.body"
    out "{\"ref\":\"x\",\"object\":{\"sha\":\"$sha\"}}" ;;
  "PUT repos/acme/repo1/contents/"*)
    i=$(( $(cat "$d/putn" 2>/dev/null || echo 0) + 1 )); printf '%s' "$i" >"$d/putn"
    cp "$body" "$d/put.$i.body"; printf '%s\n' "${ep#repos/acme/repo1/contents/}" >>"$d/put.paths"
    [ "${STUB_SLEEP:-}" != "$i" ] || sleep 2
    has "put$i" && fail "Server Error (HTTP 500)"
    parent=$(cat "$d/head")
    [ "${STUB_WRONGPARENT:-}" != "$i" ] || parent=dddddddddddddddddddddddddddddddddddddddd
    sha=$(printf 'c%039d' "$i")
    [ "${STUB_BADSHA:-}" != "$i" ] || sha=nothex
    printf '%s' "$sha" >"$d/head"
    out "{\"commit\":{\"sha\":\"$sha\",\"parents\":[{\"sha\":\"$parent\"}]}}" ;;
  "GET repos/acme/repo1/compare/"*)
    has compare && fail "Server Error (HTTP 500)"
    out "$(jq -nc --arg f "${STUB_COMPARE_FILE:-.github/workflows/a.yml}" --argjson n "$(cat "$d/putn" 2>/dev/null || echo 0)" \
      '{ahead_by: $n, commits: [range(0; $n) | {sha: ("e" + ("0" * 39)), commit: {message: "SECRET-COMMIT-MESSAGE"}}], files: [{filename: $f}]}')" ;;
  *) fail "unexpected call $method $ep" ;;
esac
STUB
chmod +x "$tmp/bin/gh"

fail=0
pass_count=0
ok() { pass_count=$((pass_count + 1)); }
bad() { echo "FAIL: $1 -- $2" >&2; fail=1; }
assert_eq() { if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$2', got '$3'"; fi; }
cnt() { printf '%s\n' "$1" | grep -c -- "$2" || true; }
nl() { if [ -f "$1" ]; then wc -l <"$1" | tr -d ' '; else echo 0; fi; }

home=$tmp/home
printf 'y\n' >"$tmp/tty-y"
printf 'n\n' >"$tmp/tty-n"
printf '{}\n' >"$tmp/dummy"

# reset: a clean home, stub state and environment switches
reset() {
  rm -rf "$tmp/stub" "$home"
  mkdir -p "$tmp/stub" "$home"
  unset STUB_MINT_SLEEP STUB_FAIL STUB_INST STUB_DEFAULT STUB_WRONGPARENT STUB_BADSHA STUB_SLEEP STUB_COMPARE_FILE STUB_MINT_RC STUB_REVOKE_RC STUB_GRANTED STUB_TOKEN_CONTENT STUB_TOKEN
  printf '%s' "$HEAD0" >"$tmp/stub/head"
}

hcount=0
# newhand [big]: a handoff directory $hd with a.yml (update, old set) and b.md (new), manifest 7-manifest.json
newhand() {
  hcount=$((hcount + 1)); hd=$tmp/hand.$hcount
  mkdir "$hd"
  if [ "${1:-}" = big ]; then
    { echo 'on: push'; head -c 40000 /dev/zero | tr '\0' 'a'; echo; } >"$hd/a.yml"
  else printf 'on: push\n' >"$hd/a.yml"; fi
  printf '# notes\n' >"$hd/b.md"
  sa=$(openssl dgst -sha256 -r "$hd/a.yml" | cut -d ' ' -f 1); sb=$(openssl dgst -sha256 -r "$hd/b.md" | cut -d ' ' -f 1)
  jq -n --arg expect "$HEAD0" --arg sa "$sa" --arg sb "$sb" --arg old "$OLD1" '
    {branch: "feat/x", base: "main", expect: $expect, files: [
      {src: "a.yml", path: ".github/workflows/a.yml", sha256: $sa, msg: "ci: update a", old: $old},
      {src: "b.md", path: ".github/b.md", sha256: $sb, msg: "docs: add b"}]}' >"$hd/7-manifest.json"
}
# modman <jq filter>: edit the manifest
modman() { jq "$1" "$hd/7-manifest.json" >"$hd/m.tmp" && mv "$hd/m.tmp" "$hd/7-manifest.json"; }
# three files: adds c.md
add3() {
  printf '# c\n' >"$hd/c.md"; sc=$(openssl dgst -sha256 -r "$hd/c.md" | cut -d ' ' -f 1)
  modman ".files += [{src: \"c.md\", path: \".github/c.md\", sha256: \"$sc\", msg: \"docs: add c\"}]"
}

# run <args...> under WOW_TTY=$tty (default the y answer): sets rc and out
tty=$tmp/tty-y
run() {
  rc=0
  out=$(PATH="$tmp/bin:$PATH" WOW_HOME="$home" WOW_TTY="$tty" sh "$inst/wow-publish" "$@" 2>&1) || rc=$?
}
pub() { run acme/repo1 "$hd" 7; }
puts() { if [ -f "$tmp/stub/gh.calls" ]; then grep -c '^PUT' "$tmp/stub/gh.calls" || true; else echo 0; fi; }
revokes() { if [ -f "$tmp/stub/admin.calls" ]; then grep -c -- '--revoke' "$tmp/stub/admin.calls" || true; else echo 0; fi; }
leftover() { ls -A "$home" 2>/dev/null | grep -c '^\.publish\.' || true; }
# nocalls <label>: neither stub was called
nocalls() {
  [ ! -e "$tmp/stub/admin.calls" ] && [ ! -e "$tmp/stub/gh.calls" ] && ok || bad "$1" "a stub was called"
}
# refused <label> <refused-value>: exit 1, nothing called, the refused value not echoed, nothing left behind
refused() {
  assert_eq "$1: rc" 1 "$rc"
  nocalls "$1"
  [ -z "${2:-}" ] || assert_eq "$1: the refused value is not printed" 0 "$(cnt "$out" "$2")"
  assert_eq "$1: no .publish directory left" 0 "$(leftover)"
}
BADV=ZZREFUSEDZZ

# --- happy path on an existing branch
reset; newhand; pub
assert_eq "happy: rc" 0 "$rc"
assert_eq "happy: no shell error line in the output" 0 "$(cnt "$out" 'cannot open\|No such file')"
assert_eq "happy: one revoke" 1 "$(revokes)"
assert_eq "happy: one mint" 1 "$(grep -c -- '--perms contents=write,pull_requests=write,workflows=write' "$tmp/stub/admin.calls" || true)"
assert_eq "happy: revoke ok" 1 "$(cnt "$out" '^revoke: ok$')"
assert_eq "happy: the published line" 1 "$(cnt "$out" "^published 2 files onto feat/x; head $(printf 'c%039d' 2)\$")"
assert_eq "happy: the compare" 1 "$(cnt "$out" '^ahead by 2 commits$')"
assert_eq "happy: a changed file is printed through @json" 1 "$(cnt "$out" '^file ".github/workflows/a.yml"$')"
assert_eq "happy: no commit message printed" 0 "$(cnt "$out" 'SECRET-COMMIT-MESSAGE')"
assert_eq "happy: the yml line is marked" 1 "$(cnt "$out" '^file: .github/workflows/a.yml update 100644 .* read before publishing$')"
assert_eq "happy: the md line is not marked" 0 "$(printf '%s\n' "$out" | grep '^file: .github/b.md' | grep -c 'read before publishing' || true)"
assert_eq "happy: the md line says new" 1 "$(cnt "$out" '^file: .github/b.md new 100644 ')"
assert_eq "happy: PUT 1 branch" feat/x "$(jq -r .branch "$tmp/stub/put.1.body")"
assert_eq "happy: PUT 1 message" "ci: update a" "$(jq -r .message "$tmp/stub/put.1.body")"
assert_eq "happy: PUT 1 sha is old" "$OLD1" "$(jq -r .sha "$tmp/stub/put.1.body")"
assert_eq "happy: PUT 1 content is the base64" "$(openssl base64 -A -in "$hd/a.yml")" "$(jq -r .content "$tmp/stub/put.1.body")"
assert_eq "happy: PUT 2 carries no sha" false "$(jq 'has("sha")' "$tmp/stub/put.2.body")"
assert_eq "happy: PUT order" ".github/workflows/a.yml .github/b.md" "$(tr '\n' ' ' <"$tmp/stub/put.paths" | sed 's/ $//')"
# the token and the environment
assert_eq "happy: every gh call had a token" 0 "$(grep -c 'token=0' "$tmp/stub/gh.env" || true)"
assert_eq "happy: every GH_CONFIG_DIR is under the home's .publish dir" 0 "$(grep -vc "cfg=$home/\.publish\." "$tmp/stub/gh.env" || true)"
assert_eq "happy: GH_HOST and friends are not set" 0 "$(nl "$tmp/stub/gh.leak")"
assert_eq "happy: no gh argv carries the token" 0 "$(grep -c "$TOKEN" "$tmp/stub/gh.rawargv" || true)"
assert_eq "happy: the token is not in the output" 0 "$(cnt "$out" "$TOKEN")"
assert_eq "happy: the token is not in the admin calls" 0 "$(grep -c "$TOKEN" "$tmp/stub/admin.calls" || true)"
assert_eq "happy: no .publish directory left" 0 "$(leftover)"
assert_eq "happy: every gh call names --hostname github.com" 0 "$(grep -vc '^github.com$' "$tmp/stub/gh.host" || true)"

# --- a 100755 update with an old is accepted
reset; newhand; modman '.files[0].mode="100755"'; pub
assert_eq "mode 100755 update: rc" 0 "$rc"
assert_eq "mode 100755 update: the confirm line says 100755" 1 "$(cnt "$out" '^file: .github/workflows/a.yml update 100755 ')"

# --- a src named x.md with a .yml path is still marked
reset; newhand; cp "$hd/a.yml" "$hd/x.md"; modman '.files[0].src="x.md"'; pub
assert_eq "x.md with a .yml path: rc" 0 "$rc"
assert_eq "x.md with a .yml path is marked" 1 "$(cnt "$out" '^file: .github/workflows/a.yml .* read before publishing$')"

# --- expect new: a 404 ref read, the refs POST at the base head, a new file with no sha
reset; rm -f "$tmp/stub/head"; newhand; modman '.expect="new" | del(.files[0].old)'; pub
assert_eq "expect new: rc" 0 "$rc"
assert_eq "expect new: the branch ref is read before the POST" "GET repos/acme/repo1/git/ref/heads/main
GET repos/acme/repo1/git/ref/heads/feat/x
POST repos/acme/repo1/git/refs" "$(sed -n '3,5p' "$tmp/stub/gh.calls")"
assert_eq "expect new: the refs POST names the branch" refs/heads/feat/x "$(jq -r .ref "$tmp/stub/refs.body")"
assert_eq "expect new: the refs POST is at the base head" "$BASEHEAD" "$(jq -r .sha "$tmp/stub/refs.body")"
assert_eq "expect new: the first PUT's parent chain starts at the base head, so the run published" 1 "$(cnt "$out" '^published 2 files onto feat/x')"
assert_eq "expect new: a new file's PUT carries no sha" false "$(jq 'has("sha")' "$tmp/stub/put.1.body")"
assert_eq "expect new: one revoke" 1 "$(revokes)"

# --- the refusals of steps 1 to 4
refuse() { # <label> <jq filter> [value]
  reset; newhand; modman "$2"; pub; refused "$1" "${3:-}"
}
refuse "missing branch" 'del(.branch)'
refuse "missing base" 'del(.base)'
refuse "missing expect" 'del(.expect)'
refuse "missing files" 'del(.files)'
refuse "extra key" ".extra=\"$BADV\"" "$BADV"
refuse "branch with a space" ".branch=\"$BADV bad\"" "$BADV"
refuse "branch starting with a dash" ".branch=\"-$BADV\"" "$BADV"
refuse "branch with .." ".branch=\"a/../$BADV\"" "$BADV"
refuse "branch with //" ".branch=\"a//$BADV\"" "$BADV"
refuse "branch ending in a slash" ".branch=\"$BADV/\"" "$BADV"
refuse "base starting with a slash" ".base=\"/$BADV\"" "$BADV"
refuse "base with a space" ".base=\"$BADV bad\"" "$BADV"
refuse "branch equal to base" '.base=.branch'
refuse "expect not hex" ".expect=\"$BADV\"" "$BADV"
refuse "expect uppercase hex" '.expect="BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"' BBBBBBBBBBBB
refuse "expect not a string" '.expect=5'
refuse "files empty" '.files=[]'
refuse "files not an array" '.files={}'
refuse "file not an object" '.files[0]="x"'
refuse "file missing src" 'del(.files[0].src)'
refuse "file missing path" 'del(.files[0].path)'
refuse "file missing sha256" 'del(.files[0].sha256)'
refuse "file missing msg" 'del(.files[0].msg)'
refuse "file extra key" ".files[0].extra=\"$BADV\"" "$BADV"
refuse "src of .." '.files[0].src=".."'
refuse "src with a slash" ".files[0].src=\"x/$BADV\"" "$BADV"
refuse "src starting with a dot" ".files[0].src=\".$BADV\"" "$BADV"
refuse "path outside .github" ".files[0].path=\"src/$BADV\"" "$BADV"
refuse "path with .." ".files[0].path=\".github/../$BADV\"" "$BADV"
refuse "path with an empty segment" ".files[0].path=\".github/a//$BADV\"" "$BADV"
refuse "path ending in a slash" ".files[0].path=\".github/$BADV/\"" "$BADV"
refuse "path with a bad character" ".files[0].path=\".github/$BADV x\"" "$BADV"
refuse "sha256 short" ".files[0].sha256=\"$BADV\"" "$BADV"
refuse "sha256 uppercase" '.files[0].sha256="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"' AAAAAAAAAAAA
refuse "msg empty" '.files[0].msg=""'
refuse "msg with a control character" ".files[0].msg=\"$BADV\\u001bx\"" "$BADV"
refuse "msg with a newline" ".files[0].msg=\"$BADV\\nx\"" "$BADV"
refuse "msg too long" ".files[0].msg=\"$BADV$(head -c 210 /dev/zero | tr '\0' 'x')\"" "$BADV"
refuse "old not hex" ".files[0].old=\"$BADV\"" "$BADV"
refuse "mode not allowed" ".files[0].mode=\"$BADV\"" "$BADV"
refuse "duplicate path" '.files[1].path=.files[0].path'
refuse "src absent" '.files[0].src="nofile.yml"'
refuse "new 100755 file" '.files[1].mode="100755"'
reset; newhand; modman '.files[0].sha256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'; pub
refused "hash mismatch" ''
assert_eq "hash mismatch names files[0].sha256" 1 "$(cnt "$out" 'files\[0\]\.sha256')"
reset; newhand; modman ".files[0].src=\"$BADV x\""; pub
refused "a bad files[0].src" "$BADV"
assert_eq "a bad src is named by position" 1 "$(cnt "$out" 'files\[0\]\.src')"
reset; newhand; modman '.files[1].path="src/x"'; pub
assert_eq "a bad path is named by its position" 1 "$(cnt "$out" 'files\[1\]\.path')"
reset; newhand; ln -s a.yml "$hd/link.yml"; modman '.files[0].src="link.yml"'; pub
refused "src a symbolic link" ''
reset; newhand; mkdir "$hd/dir.d"; modman '.files[0].src="dir.d"'; pub
refused "src a directory" ''
reset; newhand; rm -f "$hd/7-manifest.json"; pub
refused "manifest absent" ''
reset; newhand; mv "$hd/7-manifest.json" "$hd/real.json"; ln -s real.json "$hd/7-manifest.json"; pub
refused "manifest a symbolic link" ''
reset; newhand; rm -f "$hd/7-manifest.json"; mkdir "$hd/7-manifest.json"; pub
refused "manifest a directory" ''
reset; newhand; printf '{not json %s\n' "$BADV" >"$hd/7-manifest.json"; pub
refused "manifest not JSON" "$BADV"
reset; newhand; { cat "$hd/7-manifest.json"; cat "$hd/7-manifest.json"; } >"$hd/two.json"; mv "$hd/two.json" "$hd/7-manifest.json"; pub
refused "manifest holding two documents" ''
reset; newhand; printf '[]\n' >"$hd/7-manifest.json"; pub
refused "manifest not an object" ''
reset; newhand; tty=$tmp/tty-n pub; tty=$tmp/tty-y
refused "an answer other than y" ''
reset; newhand; printf '\n' >"$tmp/tty-empty"; tty=$tmp/tty-empty pub; tty=$tmp/tty-y
refused "an empty answer" ''
reset; newhand; tty=$tmp/no-such-tty pub; tty=$tmp/tty-y
refused "no terminal" ''
reset; newhand; run acme/repo1 "$tmp/no-such-dir" 7
refused "handoff directory absent" ''

# --- a mint that exits 1: no revoke, no gh call
reset; newhand; STUB_MINT_RC=1 pub
assert_eq "mint rc 1: rc" 1 "$rc"
assert_eq "mint rc 1: no revoke" 0 "$(revokes)"
assert_eq "mint rc 1: no gh call" 0 "$(nl "$tmp/stub/gh.calls")"
assert_eq "mint rc 1: no .publish directory" 0 "$(leftover)"

# --- the granted line
reset; newhand; STUB_GRANTED='granted: permissions contents=write,pull_requests=write,workflows=write repositories repo1' pub
assert_eq "granted without metadata=read: rc" 0 "$rc"
G_OK='granted: permissions contents=write,metadata=read,pull_requests=write,workflows=write repositories repo1'
gref() { # <label> <granted text>
  reset; newhand; STUB_GRANTED=$2 pub
  assert_eq "$1: rc" 1 "$rc"
  assert_eq "$1: one revoke" 1 "$(revokes)"
  assert_eq "$1: no gh call" 0 "$(nl "$tmp/stub/gh.calls")"
  assert_eq "$1: no .publish directory" 0 "$(leftover)"
}
gref "an extra permission" 'granted: permissions administration=write,contents=write,metadata=read,pull_requests=write,workflows=write repositories repo1'
gref "a missing permission" 'granted: permissions contents=write,metadata=read,pull_requests=write repositories repo1'
gref "another repository" 'granted: permissions contents=write,metadata=read,pull_requests=write,workflows=write repositories other'
gref "two granted lines" "$G_OK
$G_OK"
gref "granted not shown" 'granted: not shown (unexpected response)'
gref "no granted line" 'something else'

# --- each failure after a zero mint exit: nothing further written, one revoke, exit 1
post() { # <label> <env assignments applied by the caller before> -- uses current environment; asserts after pub
  assert_eq "$1: rc" 1 "$rc"
  assert_eq "$1: one revoke" 1 "$(revokes)"
  assert_eq "$1: PUTs attempted" "${PUTS:-0}" "$(puts)"
  assert_eq "$1: no .publish directory" 0 "$(leftover)"
  assert_eq "$1: the revoke line" 1 "$(cnt "$out" '^revoke: ok$')"
  assert_eq "$1: the token is not printed" 0 "$(cnt "$out" "$TOKEN")"
}
reset; newhand; STUB_TOKEN_CONTENT="not-a-token
$EXPIRES" pub; post "a token file token-check refuses"
assert_eq "a refused token file: no gh call" 0 "$(nl "$tmp/stub/gh.calls")"
reset; newhand; STUB_FAIL=inst pub; post "a failed installation read"
reset; newhand; STUB_INST=acme/other pub; post "an installation listing only another repository"
reset; newhand; STUB_FAIL=default pub; post "a failed default-branch read"
reset; newhand; STUB_DEFAULT=feat/x pub; post "a branch equal to the default branch"
reset; newhand; modman '.expect="new" | del(.files[0].old)'; printf '%s' "$HEAD0" >"$tmp/stub/head"; pub; post "an existing branch under new"
assert_eq "an existing branch under new: no refs POST" 0 "$(grep -c '^POST' "$tmp/stub/gh.calls" || true)"
reset; newhand; modman '.expect="new" | del(.files[0].old)'; rm -f "$tmp/stub/head"; STUB_FAIL=branchref500 pub; post "a non-404 ref read failure"
assert_eq "a non-404 ref read failure: no refs POST" 0 "$(grep -c '^POST' "$tmp/stub/gh.calls" || true)"
reset; newhand; modman '.expect="new" | del(.files[0].old)'; rm -f "$tmp/stub/head"; STUB_FAIL=baseref pub; post "a failed base read"
reset; newhand; modman '.expect="new" | del(.files[0].old)'; rm -f "$tmp/stub/head"; STUB_FAIL=refspost pub; post "a failed refs POST"
reset; newhand; printf '%s' "$BASEHEAD" >"$tmp/stub/head"; pub; post "a head other than expect"
reset; newhand; STUB_FAIL=put1 pub; PUTS=1 post "a failed first PUT"
assert_eq "a failed first PUT: no second PUT" 1 "$(nl "$tmp/stub/put.paths")"
reset; newhand; STUB_WRONGPARENT=1 pub
assert_eq "a wrong parent: rc" 1 "$rc"
assert_eq "a wrong parent: one revoke" 1 "$(revokes)"
assert_eq "a wrong parent: names the file" 1 "$(cnt "$out" '\.github/workflows/a\.yml landed as commit ')"
assert_eq "a wrong parent: names the returned commit" 1 "$(cnt "$out" "landed as commit $(printf 'c%039d' 1) ")"
assert_eq "a wrong parent: no second PUT" 1 "$(nl "$tmp/stub/put.paths")"
reset; newhand; STUB_BADSHA=1 pub
assert_eq "a commit sha that is not 40 hex: rc" 1 "$rc"
assert_eq "a commit sha that is not 40 hex: one revoke" 1 "$(revokes)"
assert_eq "a commit sha that is not 40 hex: no second PUT" 1 "$(nl "$tmp/stub/put.paths")"
reset; newhand; STUB_FAIL=compare pub
assert_eq "a failed compare: rc" 1 "$rc"
assert_eq "a failed compare: one revoke" 1 "$(revokes)"
assert_eq "a failed compare: no published line" 0 "$(cnt "$out" '^published ')"
assert_eq "a failed compare: no .publish directory" 0 "$(leftover)"

# --- the second of three PUTs failing: no third PUT, the first commit is the last verified head
reset; newhand; add3; STUB_FAIL=put2 pub
assert_eq "second of three PUTs fails: rc" 1 "$rc"
assert_eq "second of three PUTs fails: two PUTs only" 2 "$(nl "$tmp/stub/put.paths")"
assert_eq "second of three PUTs fails: the first commit is the last verified head" 1 "$(cnt "$out" "^last verified head: $(printf 'c%039d' 1)\$")"
assert_eq "second of three PUTs fails: the verified file is listed" 1 "$(cnt "$out" '^verified so far: .github/workflows/a.yml$')"
assert_eq "second of three PUTs fails: one revoke" 1 "$(revokes)"

# --- TERM while a PUT sleeps: one revoke, no .publish directory
reset; newhand
( PATH="$tmp/bin:$PATH" WOW_HOME="$home" WOW_TTY="$tty" STUB_SLEEP=1 exec sh "$inst/wow-publish" acme/repo1 "$hd" 7 >"$tmp/term.out" 2>&1 ) &
pid=$!
w=0
while [ ! -f "$tmp/stub/put.1.body" ] && [ "$w" -lt 100 ]; do sleep 0.1; w=$((w + 1)); done
kill -TERM "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
assert_eq "TERM during a PUT: one revoke" 1 "$(revokes)"
assert_eq "TERM during a PUT: no .publish directory left" 0 "$(leftover)"
assert_eq "TERM during a PUT: no second PUT" 1 "$(nl "$tmp/stub/put.paths")"
assert_eq "TERM during a PUT: the stopped-by-a-signal line" 1 "$(cnt "$(cat "$tmp/term.out")" '^wow-publish: stopped by a signal; the last verified head may lag')"
assert_eq "TERM during a PUT: the last verified head is the one before that PUT" 1 "$(cnt "$(cat "$tmp/term.out")" "^last verified head: $HEAD0\$")"

# --- TERM while wow-admin is minting: the token it then writes is revoked
reset; newhand
( PATH="$tmp/bin:$PATH" WOW_HOME="$home" WOW_TTY="$tty" STUB_MINT_SLEEP=2 exec sh "$inst/wow-publish" acme/repo1 "$hd" 7 >"$tmp/term2.out" 2>&1 ) &
pid=$!
w=0
while [ ! -f "$tmp/stub/mint.started" ] && [ "$w" -lt 100 ]; do sleep 0.1; w=$((w + 1)); done
kill -TERM "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
assert_eq "TERM during the mint: one revoke" 1 "$(revokes)"
assert_eq "TERM during the mint: no gh call" 0 "$(nl "$tmp/stub/gh.calls")"
assert_eq "TERM during the mint: no stopped-by-a-signal line" 0 "$(cnt "$(cat "$tmp/term2.out")" 'stopped by a signal')"
assert_eq "TERM during the mint: no last verified head line" 0 "$(cnt "$(cat "$tmp/term2.out")" 'last verified head')"
assert_eq "TERM during the mint: no .publish directory left" 0 "$(leftover)"

# --- an output reader that goes away after the mint: PIPE is handled like TERM, and the revoke still completes
reset; newhand
# PIPE must be at its default for wow-publish: a non-interactive sh cannot trap a signal ignored on entry (a CI step may
# start the suite that way), so the run starts through env --default-signal=PIPE where env has it
dsp=; if env --default-signal=PIPE true 2>/dev/null; then dsp="env --default-signal=PIPE"; fi
( PATH="$tmp/bin:$PATH" WOW_HOME="$home" WOW_TTY="$tty" STUB_SLEEP=1 $dsp sh "$inst/wow-publish" acme/repo1 "$hd" 7 2>"$tmp/pipe.err" ) | { IFS= read -r _l; while [ "${_l#granted: }" = "$_l" ]; do IFS= read -r _l || break; done; exit 0; }
w=0
while [ ! -f "$tmp/stub/revoke.finished" ] && [ "$w" -lt 100 ]; do sleep 0.1; w=$((w + 1)); done
sleep 0.3
if [ -z "$dsp" ] && [ $(( 0x$(sed -n 's/^SigIgn:[[:space:]]*//p' /proc/self/status) >> 12 & 1 )) = 1 ]; then
  echo "SKIP - the stopped-by-a-signal line: PIPE is ignored on entry and env has no --default-signal"
else
  assert_eq "a reader that went away: the stopped-by-a-signal line once on stderr" 1 "$(cnt "$(cat "$tmp/pipe.err")" '^wow-publish: stopped by a signal')"
fi
assert_eq "a reader that went away: one revoke" 1 "$(revokes)"
assert_eq "a reader that went away: the revoke finished" 1 "$([ -f "$tmp/stub/revoke.finished" ] && echo 1 || echo 0)"
assert_eq "a reader that went away: no .publish directory left" 0 "$(leftover)"

# --- TERM during a mint that refuses beside a live token already on file: that token is left alone
reset; newhand; mkdir -p "$home/admin/acme/repo1"; printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$home/admin/acme/repo1/admin-token"
( PATH="$tmp/bin:$PATH" WOW_HOME="$home" WOW_TTY="$tty" STUB_MINT_SLEEP=2 STUB_MINT_RC=1 exec sh "$inst/wow-publish" acme/repo1 "$hd" 7 >"$tmp/term3.out" 2>&1 ) &
pid=$!
w=0
while [ ! -f "$tmp/stub/mint.started" ] && [ "$w" -lt 100 ]; do sleep 0.1; w=$((w + 1)); done
kill -TERM "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
assert_eq "TERM during a refused mint: no revoke of the token already on file" 0 "$(revokes)"

# --- a revoke exiting non-zero
reset; newhand; STUB_REVOKE_RC=3 pub
assert_eq "a failed revoke: rc" 1 "$rc"
assert_eq "a failed revoke is reported" 1 "$(cnt "$out" '^revoke: failed (exit 3)$')"
assert_eq "a failed revoke: the run itself published" 1 "$(cnt "$out" '^published 2 files')"

# --- a compare file name with an escape byte
reset; newhand; STUB_COMPARE_FILE=$(printf 'a\033b') pub
assert_eq "an escape byte in a compare file name: rc" 0 "$rc"
assert_eq "an escape byte is printed escaped" 1 "$(cnt "$out" '^file "a\\u001bb"$')"
assert_eq "no raw control character in the output" 0 "$(printf '%s' "$out" | tr -d '\n' | tr -d '[:print:]' | wc -c | tr -d ' ')"

# --- a file over 32 KB
reset; newhand big; pub
assert_eq "a 40 KB file: rc" 0 "$rc"
b64=$(openssl base64 -A -in "$hd/a.yml")
assert_eq "a 40 KB file: the PUT body on stdin carries the base64" "$b64" "$(jq -r .content "$tmp/stub/put.1.body")"
assert_eq "a 40 KB file: no gh argv carries the base64" 0 "$(grep -c "$(printf '%s' "$b64" | cut -c1-60)" "$tmp/stub/gh.rawargv" || true)"
assert_eq "a 40 KB file: no recorded argument is longer than 4096" 0 "$(awk 'length > 4096' "$tmp/stub/gh.rawargv" | wc -l | tr -d ' ')"

# --- a second home holding a tokens-root file reads its own admin/ token
reset; newhand
fakehome=$tmp/fakehome; mkdir -p "$fakehome/.config/glunk-identity/admin/acme/repo1"
printf 'ghs_DecoyDecoyDecoyDecoyDecoyDecoyDecoyDecoy\n%s\n' "$EXPIRES" >"$fakehome/.config/glunk-identity/admin/acme/repo1/admin-token"
printf 'default-home\n' >"$home/tokens-root"
OWN=ghs_OwnOwnOwnOwnOwnOwnOwnOwnOwnOwnOwnOwnOwnOwn
rc=0
out=$(PATH="$tmp/bin:$PATH" HOME="$fakehome" WOW_HOME="$home" WOW_TTY="$tty" STUB_TOKEN=$OWN sh "$inst/wow-publish" acme/repo1 "$hd" 7 2>&1) || rc=$?
assert_eq "a second home: rc" 0 "$rc"
assert_eq "a second home: every call used the home's own token" 0 "$(grep -vc "^$OWN\$" "$tmp/stub/gh.tok" || true)"

# --- usage
reset; newhand
( cd "$inst" && rc=0; PATH="$tmp/bin:$PATH" WOW_HOME="$home" WOW_TTY="$tty" sh wow-publish acme/repo1 "$hd" 7 >"$tmp/u.out" 2>&1 || rc=$?; echo "$rc" >"$tmp/u.rc" )
assert_eq "a slash-less invocation: exit 2" 2 "$(cat "$tmp/u.rc")"
run repo1 "$hd" 7; assert_eq "a bare repo name: exit 2" 2 "$rc"
run acme/repo1 "$hd" abc; assert_eq "a non-decimal N: exit 2" 2 "$rc"
run acme/repo1 "$hd" 07; assert_eq "a leading-zero N: exit 2" 2 "$rc"
run acme/repo1 "$hd"; assert_eq "two arguments: exit 2" 2 "$rc"
run acme/.repo "$hd" 7; assert_eq "a dotted name half: exit 2" 2 "$rc"
nocalls "usage errors"

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "identity-publish: $pass_count assertions passed"
