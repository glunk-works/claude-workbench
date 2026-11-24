#!/bin/sh
# Fixture tests for scripts/identity/wow-admin and wow-review-mint (issue #374).
#
# A stub `curl` stands in for GitHub (as in identity-mint.test.sh): it records the config piped to
# it and answers with a canned body and status. A throwaway RSA key, encrypted for the admin App
# and plain for the reviewer App, lives under a throwaway $WOW_HOME laid out like the real one (apps.json); $WOW_TTY points at a file
# holding the passphrase.
#
#   admin mint       token + expires_at land in admin/<owner>/<name>/admin-token (#1608, a directory no container mounts, private
#                    modes) and nowhere else, nothing under tokens/; request carries the admin installation, the one repo and the
#                    default (contents and pull_requests write; administration only when named) or given permissions; the output
#                    names the granted permissions and repositories, or says they are not shown, and a mint is not strict
#   legacy path      a live or unreadable tokens/<owner>/<name>/admin-token refuses a mint (curl uncalled, the message names
#                    --revoke), an expired one does not, and --revoke revokes and removes it only when it can read the file and its
#                    first line holds a token (alone, or beside an own file with the same or a different token)
#   passphrase       wrong or empty: exit 1, curl never called, no token file
#   live token       refused while one is on file (curl uncalled); an expired one is replaced
#   revoke           DELETE /installation/token with the token as bearer; a 401 removes the file, a 204 removes it only after a
#                    GET /installation/repositories with the same token answers 401 (any other status on either call, or a
#                    curl failure, keeps it and exits 1); each step prints its own line, never the token; no file is an error
#                    (two failures are both named with their kept paths, a 204-then-200 failure keeps its advice to run again
#                    beside a later 500, and a file rm cannot remove is kept, named with the remedy and exits 1 while the next token is
#                    still tried; every closing line carries the wow-admin: prefix and a status failure names each file it keeps on a
#                    line of its own (kept <path>), while a could-not-remove failure names its path mid-line; a curl failure on a later
#                    token's DELETE or confirming read still prints the failures collected before it, each prefixed)
#   reviewer         reviewer installation, fixed permissions, written under review-tokens/ and never tokens/, --out or the default path
#   reviewer shapes  post (default) unchanged and non-strict; --read sends the six reads (--also adds a
#                    second repo to the same request, either flag order); --file sends issues write;
#                    both are strict (one extra permission, or a missing repo, exits 1 with no token
#                    file); every usage rule exits 2 before curl with a message naming it
#   owner/name       a bare argument or one with more than one slash exits 2 with nothing written; with no
#                    broker.json, or an entry equal to the argument, mint writes only the owner file; a mint
#                    refuses (exit 1, own reason, no curl, no directory) a broker.json breaking the broker's
#                    rules (a bare-name entry included), a case-only name match, the same name under another
#                    owner, an owner equal to another entry's name, and another owner's live (or unreadable)
#                    admin-token for the repo under admin/, found by a scan that runs under set -f; a live leftover
#                    tokens/<name>/admin-token blocks too; revoke reads no broker.json, takes a token under
#                    any owner by naming it, takes a leftover bare copy and an owner-only copy, and for two
#                    differing tokens removes what each answer allows (204 then 500: leftover gone, owner
#                    kept, exit 1) (#1340, #1348)
#   owner check      a mint reads the admin installation's account login once, after the unlock, and refuses
#                    (exit 1, no POST, no admin/ or tokens/ entry, no unlock directory) an owner that differs from it
#                    ignoring case, a failed read (HTTP 500) and a login of the wrong shape; ACME/repo1
#                    mints into admin/ACME; --revoke makes no read; acme/.hidden and acme/repo1. are usage
#                    errors for mint and revoke (#1425, #1428)
#   tokens root      a home with a tokens-root file holding default-home (#1568) writes and reads its token in its own admin/ (#1608),
#                    revokes it and the legacy copies under the default home's tokens/ (HOME points at a fixture), makes its per-name lock in the default home (seen
#                    while the run goes), creates a missing default home private, skips the scan of the shared root's other owners and the leftover
#                    check but still refuses a live legacy token of its own owner and a live admin/ token of another owner, and in the two-home order of the spec leaves each owner's token to its own revoke; default-home,
#                    default-home LF and CRLF are accepted, two LFs, other content, an empty file, a link, a directory, an
#                    empty HOME and the file in the default home itself (also through a link, a parent-component link or another letter case, with or without a trailing slash or /./) refuse mint and revoke (exit 1, curl uncalled)
#                    (#1598) under a sed that refuses ;-joined labels a valid second home still mints and the default-home variants still refuse; under a sed that prints
#                    nothing for one side's path a valid second home refuses with "could not be normalised" and curl uncalled, for each side; path_is_root_spelling
#                    (a home at the filesystem root, #1698) is true for a lone slash, two slashes, slash-dot and slash-dot-slash and false for an ordinary home path, the empty
#                    string, a lone dot and slash-dot-dot, and resolve_tokens_root asks it before the "could not be normalised" refusal and dies with a message naming the root
#   slash-less $0    a slash-less run from the tool's own directory exits 2 with nothing on stdout, never sources the planted
#                    wow-common.sh and names the tool on stderr; a run by command name through PATH sources the copy beside the tool
#   secrecy          neither token nor passphrase reaches stdout, stderr or argv
#   usage / config   bad arguments exit 2 and missing config exits 1, before curl is called
#
# Permitted toolset: POSIX sh, its standard utilities, openssl and jq.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
admin="$root_dir/scripts/identity/wow-admin"
review="$root_dir/scripts/identity/wow-review-mint"

for tool in openssl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP - $tool not on PATH; identity-wow fixtures not run" >&2
    exit 0
  fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/stub"

cat >"$tmp/bin/curl" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" >"$STUB_DIR/argv"
cat >"$STUB_DIR/stdin"
# An account read (GET /app/installations/<id>, no further segment) is answered from its own
# variables and recorded in its own file, so the mint-call assertions on calls/stdin hold (#1425).
if grep -q '^url = "https://api.github.com/app/installations/[0-9]*"$' "$STUB_DIR/stdin"; then
  cp "$STUB_DIR/stdin" "$STUB_DIR/acct-stdin"
  echo read >>"$STUB_DIR/acct"
  if [ -n "${STUB_ACCT_BODY:-}" ]; then body=$STUB_ACCT_BODY; else body="{\"account\":{\"login\":\"${STUB_ACCT_LOGIN:-acme}\"}}"; fi
  printf '%s\n%s' "$body" "${STUB_ACCT_STATUS:-200}"
  exit 0
fi
echo called >>"$STUB_DIR/calls"
# each call's own config and argv, numbered, so an assertion can read the DELETE and the confirming read apart (#1608)
n=$(wc -l <"$STUB_DIR/calls" | tr -d ' ')
cp "$STUB_DIR/stdin" "$STUB_DIR/cfg.$n"
cp "$STUB_DIR/argv" "$STUB_DIR/argv.$n"
# a lock directory the test names is looked for while the run goes (the run removes it on exit)
if [ -n "${STUB_LOCKDIR:-}" ] && [ -d "$STUB_LOCKDIR" ]; then echo seen >>"$STUB_DIR/lockseen"; fi
if [ -n "${STUB_LOCKDIR2:-}" ] && [ -d "$STUB_LOCKDIR2" ]; then echo seen >>"$STUB_DIR/lockseen2"; fi
st=$STUB_STATUS
if [ -s "$STUB_DIR/statuses" ]; then
  st=$(sed -n 1p "$STUB_DIR/statuses")
  sed 1d "$STUB_DIR/statuses" >"$STUB_DIR/statuses.new"
  mv "$STUB_DIR/statuses.new" "$STUB_DIR/statuses"
fi
# a queued or fixed status of CURLFAIL stands in for curl itself failing
if [ "$st" = CURLFAIL ]; then exit 7; fi
printf '%s\n%s' "$STUB_BODY" "$st"
STUB
chmod +x "$tmp/bin/curl"
real_openssl=$(command -v openssl)
cat >"$tmp/bin/openssl" <<'STUB'
#!/bin/sh
printf '%s
' "$@" >>"$STUB_DIR/openssl-argv"
exec "$REAL_OPENSSL" "$@"
STUB
REAL_OPENSSL=$real_openssl; export REAL_OPENSSL
chmod +x "$tmp/bin/openssl"

home="$tmp/home"
mkdir "$home"
openssl genrsa -out "$tmp/key.pem" 2048 >/dev/null 2>&1
openssl pkey -in "$tmp/key.pem" -aes256 -passout pass:correct-horse -out "$home/admin.enc.pem" 2>/dev/null
cp "$tmp/key.pem" "$home/review.pem"
cat >"$home/apps.json" <<'CONF'
{"admin": {"app_id": 1, "client_id": "IvAdminClient", "installation_id": 111, "bot_user_id": 9, "key": "admin.enc.pem"},
 "review": {"app_id": 2, "client_id": "IvReviewClient", "installation_id": 222, "bot_user_id": 8, "key": "review.pem"}}
CONF
printf 'correct-horse\n' >"$tmp/tty-good"
printf 'wrong-guess\n' >"$tmp/tty-bad"
printf '\n' >"$tmp/tty-empty"

fail=0
pass_count=0
ok() { pass_count=$((pass_count + 1)); }
bad() { echo "FAIL: $1 -- $2" >&2; fail=1; }
assert_eq() { if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$2', got '$3'"; fi; }

TOKEN=ghs_AbCdEf0123456789AbCdEf0123456789AbCdEf
EXPIRES=2099-01-01T00:00:00Z
export STUB_DIR="$tmp/stub" WOW_HOME="$home"
STUB_BODY="{\"token\":\"$TOKEN\",\"expires_at\":\"$EXPIRES\"}" STUB_STATUS=201
export STUB_BODY STUB_STATUS

tokfile="$home/admin/acme/repo1/admin-token"
legacyfile="$home/tokens/acme/repo1/admin-token"
# q <status...>: the statuses the next curl calls answer, one each (a revoke makes a DELETE, then for a 204 a confirming read)
q() { printf '%s\n' "$@" >"$tmp/stub/statuses"; }

# run <cmd...>: runs with the stub curl first on PATH; sets rc, out (stdout+stderr).
run() {
  rm -f "$tmp/stub/calls" "$tmp/stub/acct" "$tmp/stub"/cfg.* "$tmp/stub"/argv.*
  rc=0
  out=$(PATH="$tmp/bin:$PATH" "$@" 2>&1) || rc=$?
}
calls() { if [ -f "$tmp/stub/calls" ]; then wc -l <"$tmp/stub/calls" | tr -d ' '; else echo 0; fi; }
acct_reads() { if [ -f "$tmp/stub/acct" ]; then wc -l <"$tmp/stub/acct" | tr -d ' '; else echo 0; fi; }
sent() { sed -n 's/^data-binary = "\(.*\)"$/\1/p' "$tmp/stub/stdin" | sed 's/\\"/"/g'; }

# --- admin mint
WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1
assert_eq "admin mint rc" 0 "$rc"
assert_eq "admin mint token line" "$TOKEN" "$(sed -n 1p "$tokfile")"
assert_eq "admin mint expiry line" "$EXPIRES" "$(sed -n 2p "$tokfile")"
assert_eq "admin mint installation" 1 "$(grep -c '/app/installations/111/access_tokens' "$tmp/stub/stdin")"
assert_eq "admin mint repo" '["repo1"]' "$(sent | jq -c .repositories)"
assert_eq "admin mint default perms" \
  '{"contents":"write","pull_requests":"write"}' "$(sent | jq -c .permissions)"
# the token lands only in the home's own admin/, made private level by level, and nothing is made under tokens/ (#1608)
[ ! -e "$home/tokens" ] && ok || bad "admin mint" "wrote under tokens/"
assert_eq "admin mint: admin/ and each level are mode 700" "drwx------ drwx------ drwx------" \
  "$(for d in "$home/admin" "$home/admin/acme" "$home/admin/acme/repo1"; do ls -ld "$d" | cut -d' ' -f1; done | tr '\n' ' ' | sed 's/ $//')"
assert_eq "admin mint: the file is mode 600" "-rw-------" "$(ls -l "$tokfile" | cut -d' ' -f1)"
assert_eq "admin mint: the output names the new path and no container mount" 1 "$(printf '%s' "$out" | grep -c "$tokfile (outside every container mount)" || true)"
# no strict check, and the grant is printed (#1608): a body with no permissions still writes the token
assert_eq "admin mint: no permissions field prints the not-shown line" 1 "$(printf '%s' "$out" | grep -c '^granted: not shown (unexpected response)$' || true)"
assert_eq "admin mint no token in output" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
assert_eq "admin mint no passphrase in output" 0 "$(printf '%s' "$out" | grep -c 'correct-horse' || true)"
assert_eq "admin mint no passphrase in argv" 0 "$(grep -c 'correct-horse' "$tmp/stub/argv" || true)"
assert_eq "admin mint no passphrase in openssl argv" 0 "$(grep -c 'correct-horse' "$tmp/stub/openssl-argv" || true)"
assert_eq "admin mint leaves no unlocked key behind" 0 "$(ls -A "$home" | grep -c '^\.unlock' || true)"

# --- a live token blocks a second mint; an expired one does not
WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1
assert_eq "live token rc" 1 "$rc"
assert_eq "live token curl uncalled" 0 "$(calls)"
printf '%s\n2000-01-01T00:00:00Z\n' "$TOKEN" >"$tokfile"
WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1 --perms contents=read
assert_eq "expired token replaced rc" 0 "$rc"
assert_eq "custom perms" '{"contents":"read"}' "$(sent | jq -c .permissions)"
rm -f "$tokfile"
WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1 --perms administration=write,contents=read
assert_eq "administration is sent only when named: rc" 0 "$rc"
assert_eq "administration is sent only when named" '{"administration":"write","contents":"read"}' "$(sent | jq -c .permissions)"
# a body carrying permissions and repositories prints the granted line, never the token
rm -f "$tokfile"
STUB_BODY=$(printf '{"token":"%s","expires_at":"%s","permissions":{"pull_requests":"write","contents":"write","metadata":"read"},"repositories":[{"name":"repo1"}]}' "$TOKEN" "$EXPIRES") \
  WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1
assert_eq "grant line: rc" 0 "$rc"
assert_eq "grant line names the permissions and the repository" 1 "$(printf '%s' "$out" | grep -c '^granted: permissions contents=write,metadata=read,pull_requests=write repositories repo1$' || true)"
assert_eq "grant line: no token in the output" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
STUB_BODY="{\"token\":\"$TOKEN\",\"expires_at\":\"$EXPIRES\"}"
# a mint is not strict: a request for contents=read still writes the token when GitHub grants something else
rm -f "$tokfile"
STUB_BODY=$(printf '{"token":"%s","expires_at":"%s","permissions":{"contents":"write"},"repositories":[{"name":"other"}]}' "$TOKEN" "$EXPIRES") \
  WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1 --perms contents=read
assert_eq "not strict: rc" 0 "$rc"
assert_eq "not strict: the token is written" "$TOKEN" "$(sed -n 1p "$tokfile")"
STUB_BODY="{\"token\":\"$TOKEN\",\"expires_at\":\"$EXPIRES\"}"

# --- passphrase failures leave nothing behind
rm -f "$tokfile"
WOW_TTY="$tmp/tty-bad" run sh "$admin" acme/repo1
assert_eq "wrong passphrase rc" 1 "$rc"
assert_eq "wrong passphrase curl uncalled" 0 "$(calls)"
[ ! -e "$tokfile" ] && ok || bad "wrong passphrase" "token file exists"
WOW_TTY="$tmp/tty-empty" run sh "$admin" acme/repo1
assert_eq "empty passphrase rc" 1 "$rc"
assert_eq "empty passphrase stopped before unlocking" 1 "$(printf '%s' "$out" | grep -c 'empty passphrase' || true)"
assert_eq "empty passphrase curl uncalled" 0 "$(calls)"
[ ! -e "$tokfile" ] && ok || bad "empty passphrase" "token file exists"
WOW_TTY="$tmp/nonexistent" run sh "$admin" acme/repo1
assert_eq "no terminal rc" 1 "$rc"
assert_eq "no terminal curl uncalled" 0 "$(calls)"

# --- revoke (#1608): a DELETE 204 is confirmed by a read that must answer 401 before the file goes
put_own() { mkdir -p "$home/admin/acme/repo1"; printf '%s\n%s\n' "${1:-$TOKEN}" "$EXPIRES" >"$tokfile"; }
put_own
q 204 401
STUB_BODY= run sh "$admin" acme/repo1 --revoke
assert_eq "revoke rc" 0 "$rc"
assert_eq "revoke makes a DELETE and a confirming read" 2 "$(calls)"
assert_eq "revoke method" 1 "$(grep -c '^request = "DELETE"' "$tmp/stub/cfg.1")"
assert_eq "revoke url" 1 "$(grep -c '^url = "https://api.github.com/installation/token"' "$tmp/stub/cfg.1")"
assert_eq "revoke bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $TOKEN\"" "$tmp/stub/cfg.1")"
assert_eq "the confirming read is a GET of the installation's repositories" 1 "$(grep -c '^url = "https://api.github.com/installation/repositories"$' "$tmp/stub/cfg.2")"
assert_eq "the confirming read has no request line" 0 "$(grep -c '^request' "$tmp/stub/cfg.2" || true)"
assert_eq "the confirming read carries the same token as bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $TOKEN\"" "$tmp/stub/cfg.2")"
assert_eq "revoke token not in any call's argv" 0 "$(cat "$tmp/stub"/argv.* | grep -c "$TOKEN" || true)"
assert_eq "revoke prints the DELETE step" 1 "$(printf '%s' "$out" | grep -c 'DELETE /installation/token for acme/repo1: HTTP 204' || true)"
assert_eq "revoke prints the read step" 1 "$(printf '%s' "$out" | grep -c 'GET /installation/repositories with the same token: HTTP 401' || true)"
assert_eq "revoke prints the removed path" 1 "$(printf '%s' "$out" | grep -c "removed $tokfile" || true)"
assert_eq "revoke prints no token" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
[ ! -e "$tokfile" ] && ok || bad "revoke 204 then 401" "token file kept"

# DELETE 204 then a read that answers 200: the token still works, so the file stays and the exit is 1
put_own; q 204 200
STUB_BODY= run sh "$admin" acme/repo1 --revoke
assert_eq "revoke 204 then 200 rc" 1 "$rc"
[ -e "$tokfile" ] && ok || bad "revoke 204 then 200" "token file removed"
assert_eq "revoke 204 then 200 names the read status" 1 "$(printf '%s' "$out" | grep -c 'confirming read answered HTTP 200' || true)"
assert_eq "revoke 204 then 200 says to run the revoke again" 1 "$(printf '%s' "$out" | grep -c 'run wow-admin acme/repo1 --revoke again' || true)"
assert_eq "revoke 204 then 200 prints no token" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
# a DELETE 401 removes the file with no second request
put_own
STUB_BODY='{"message":"Bad credentials"}' STUB_STATUS=401 run sh "$admin" acme/repo1 --revoke
assert_eq "revoke 401 rc" 0 "$rc"
assert_eq "revoke 401 makes no second request" 1 "$(calls)"
assert_eq "revoke 401 says it was already expired or revoked" 1 "$(printf '%s' "$out" | grep -c 'was already expired or revoked' || true)"
[ ! -e "$tokfile" ] && ok || bad "revoke 401" "token file kept"
# a DELETE 500 keeps the file and exits 1
put_own
STUB_BODY='{"message":"boom"}' STUB_STATUS=500 run sh "$admin" acme/repo1 --revoke
assert_eq "revoke 500 rc" 1 "$rc"
assert_eq "revoke 500 makes no second request" 1 "$(calls)"
[ -e "$tokfile" ] && ok || bad "revoke 500" "token file removed"
# curl failing on the DELETE, and on the confirming read, keeps the file and exits 1
put_own; q CURLFAIL
STUB_BODY= run sh "$admin" acme/repo1 --revoke
assert_eq "revoke curl failure on the DELETE rc" 1 "$rc"
[ -e "$tokfile" ] && ok || bad "revoke curl failure on the DELETE" "token file removed"
put_own; q 204 CURLFAIL
STUB_BODY= run sh "$admin" acme/repo1 --revoke
assert_eq "revoke curl failure on the confirming read rc" 1 "$rc"
assert_eq "revoke curl failure on the confirming read made both calls" 2 "$(calls)"
[ -e "$tokfile" ] && ok || bad "revoke curl failure on the confirming read" "token file removed"
rm -f "$tmp/stub/statuses"

rm -f "$tokfile"
run sh "$admin" acme/repo1 --revoke
assert_eq "revoke without a token rc" 1 "$rc"
assert_eq "revoke without a token curl uncalled" 0 "$(calls)"

# --- reviewer
rtok="$home/review-tokens/repo1/reviewer-token"
run sh "$review" repo1
assert_eq "reviewer rc" 0 "$rc"
[ ! -e "$home/tokens/acme/repo1/reviewer-token" ] && ok || bad "reviewer token location" "written under the container-mounted tokens/"
assert_eq "reviewer default path" "$TOKEN" "$(sed -n 1p "$rtok")"
assert_eq "reviewer installation" 1 "$(grep -c '/app/installations/222/access_tokens' "$tmp/stub/stdin")"
assert_eq "reviewer perms" \
  '{"contents":"read","checks":"read","statuses":"read","pull_requests":"write"}' "$(sent | jq -c .permissions)"
assert_eq "reviewer repo" '["repo1"]' "$(sent | jq -c .repositories)"
assert_eq "reviewer no token in output" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
mkdir "$tmp/outdir"
run sh "$review" repo1 --out "$tmp/outdir/t"
assert_eq "reviewer --out rc" 0 "$rc"
assert_eq "reviewer --out token" "$TOKEN" "$(sed -n 1p "$tmp/outdir/t")"

# --- reviewer shapes: post (default, non-strict), --read, --read --also, --file (strict)
RP_POST='{"contents":"read","checks":"read","statuses":"read","pull_requests":"write","metadata":"read"}'
RP_READ='{"contents":"read","pull_requests":"read","checks":"read","statuses":"read","issues":"read","actions":"read","metadata":"read"}'
RP_FILE='{"issues":"write","metadata":"read"}'
# rbody <permissions-json> <repo names...>: a 201 body echoing a grant
rbody() {
  perms=$1; shift
  names=$(printf '%s\n' "$@" | jq -R '{name: .}' | jq -sc .)
  printf '{"token":"%s","expires_at":"%s","permissions":%s,"repositories":%s}' "$TOKEN" "$EXPIRES" "$perms" "$names"
}
READ_PERMS='{"contents":"read","pull_requests":"read","checks":"read","statuses":"read","issues":"read","actions":"read"}'

# post shape unchanged: the four permissions, one repo, default path, and still non-strict
rm -f "$rtok"
STUB_BODY=$(rbody "$RP_POST" repo1) run sh "$review" repo1
assert_eq "post shape rc" 0 "$rc"
assert_eq "post shape installation" 1 "$(grep -c '/app/installations/222/access_tokens' "$tmp/stub/stdin")"
assert_eq "post shape perms" \
  '{"contents":"read","checks":"read","statuses":"read","pull_requests":"write"}' "$(sent | jq -c .permissions)"
assert_eq "post shape repo" '["repo1"]' "$(sent | jq -c .repositories)"
assert_eq "post shape default path" "$TOKEN" "$(sed -n 1p "$rtok")"
rm -f "$rtok"
STUB_BODY=$(rbody '{"contents":"read","checks":"read","statuses":"read","pull_requests":"write","issues":"write"}' repo1) run sh "$review" repo1
assert_eq "post shape stays non-strict: an extra permission still exits 0" 0 "$rc"
assert_eq "post shape non-strict token written" "$TOKEN" "$(sed -n 1p "$rtok")"

# --read: the six reads on one repo, to the --out path
rm -f "$tmp/outdir/read" "$rtok"
STUB_BODY=$(rbody "$RP_READ" repo1) run sh "$review" repo1 --read --out "$tmp/outdir/read"
assert_eq "--read rc" 0 "$rc"
assert_eq "--read perms" "$READ_PERMS" "$(sent | jq -c .permissions)"
assert_eq "--read repo" '["repo1"]' "$(sent | jq -c .repositories)"
assert_eq "--read installation" 1 "$(grep -c '/app/installations/222/access_tokens' "$tmp/stub/stdin")"
assert_eq "--read token at --out" "$TOKEN" "$(sed -n 1p "$tmp/outdir/read")"
assert_eq "--read no token in output" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
# --read --also: one request, both repositories, either flag order
for order in "repo1 --read --also repo2" "repo1 --also repo2 --read"; do
  rm -f "$tmp/outdir/read"
  # shellcheck disable=SC2086
  STUB_BODY=$(rbody "$RP_READ" repo1 repo2) run sh "$review" $order --out "$tmp/outdir/read"
  assert_eq "[$order] rc" 0 "$rc"
  assert_eq "[$order] repositories" '["repo1","repo2"]' "$(sent | jq -c .repositories)"
  assert_eq "[$order] perms" "$READ_PERMS" "$(sent | jq -c .permissions)"
  assert_eq "[$order] one curl call" 1 "$(calls)"
  assert_eq "[$order] token at --out" "$TOKEN" "$(sed -n 1p "$tmp/outdir/read")"
done
# a grant of only one of the two repositories is refused
rm -f "$tmp/outdir/read"
STUB_BODY=$(rbody "$RP_READ" repo1) run sh "$review" repo1 --read --also repo2 --out "$tmp/outdir/read"
assert_eq "--read --also granting one repository rc" 1 "$rc"
[ ! -e "$tmp/outdir/read" ] && ok || bad "--read --also partial grant" "token file written"

# --file: exactly issues write
rm -f "$tmp/outdir/file"
STUB_BODY=$(rbody "$RP_FILE" repo1) run sh "$review" repo1 --file --out "$tmp/outdir/file"
assert_eq "--file rc" 0 "$rc"
assert_eq "--file perms" '{"issues":"write"}' "$(sent | jq -c .permissions)"
assert_eq "--file repo" '["repo1"]' "$(sent | jq -c .repositories)"
assert_eq "--file token at --out" "$TOKEN" "$(sed -n 1p "$tmp/outdir/file")"

# strictness: one extra permission refuses --read and --file, and nothing is written
rm -f "$tmp/outdir/read"
STUB_BODY=$(rbody '{"contents":"read","pull_requests":"read","checks":"read","statuses":"read","issues":"read","actions":"read","issues_extra":"read"}' repo1) \
  run sh "$review" repo1 --read --out "$tmp/outdir/read"
assert_eq "--read refuses an extra permission rc" 1 "$rc"
[ ! -e "$tmp/outdir/read" ] && ok || bad "--read extra permission" "token file written"
assert_eq "--read refusal prints no token" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
rm -f "$tmp/outdir/file"
STUB_BODY=$(rbody '{"issues":"write","contents":"read"}' repo1) run sh "$review" repo1 --file --out "$tmp/outdir/file"
assert_eq "--file refuses an extra permission rc" 1 "$rc"
[ ! -e "$tmp/outdir/file" ] && ok || bad "--file extra permission" "token file written"
assert_eq "--file refusal prints no token" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
# neither new shape writes anywhere but --out
[ ! -e "$rtok" ] && ok || bad "new shapes" "wrote the default post-token path"
assert_eq "new shapes wrote nothing else beside the post token" "" "$(ls -A "$home/review-tokens/repo1" || true)"
assert_eq "new shapes wrote nothing under tokens/" "" "$(ls -A "$home/tokens/acme/repo1" 2>/dev/null || true)"
STUB_BODY="{\"token\":\"$TOKEN\",\"expires_at\":\"$EXPIRES\"}"

# usage errors: exit 2, curl uncalled, and the message names the rule that fired
review_usage() { # needle args...
  needle=$1; shift
  run sh "$review" "$@"
  assert_eq "review usage rc [$*]" 2 "$rc"
  assert_eq "review usage curl uncalled [$*]" 0 "$(calls)"
  case "$out" in *"$needle"*) ok ;; *) bad "review usage message [$*]" "'$needle' not in: $out" ;; esac
}
review_usage "--read and --file require --out" repo1 --read
review_usage "--read and --file require --out" repo1 --file
review_usage "cannot be combined" repo1 --read --file --out "$tmp/outdir/x"
review_usage "--also requires --read" repo1 --also repo2 --out "$tmp/outdir/x"
review_usage "--also requires --read" repo1 --file --also repo2 --out "$tmp/outdir/x"
review_usage "same repository" repo1 --read --also repo1 --out "$tmp/outdir/x"
review_usage "same repository" repo1 --read --also REPO1 --out "$tmp/outdir/x"
review_usage "not a bare repository name" repo1 --read --also ../x --out "$tmp/outdir/x"
review_usage "must not begin with '-'" repo1 --read --also --out x
review_usage "must not begin with '-'" repo1 --out --read
review_usage "--also given twice" repo1 --read --also a --also b --out "$tmp/outdir/x"
review_usage "--read given twice" repo1 --read --read --out "$tmp/outdir/x"
review_usage "--file given twice" repo1 --file --file --out "$tmp/outdir/x"
review_usage "--out given twice" repo1 --out "$tmp/outdir/x" --out "$tmp/outdir/y"
review_usage "unknown flag" repo1 --bogus
review_usage "empty repository name" "" repo1 --read --out "$tmp/outdir/x"

# --- revoke accepts the stateless ghs_APPID_JWT format (dots and dashes)
JWT_TOKEN=ghs_12345_eyJhbGciOiJSUzI1NiJ9.eyJpYXQiOjE3NjAwMDAwMDB9-abc_DEF.c2lnbmF0dXJlLXNpZ25hdHVyZS1zaWduYXR1cmU
printf '%s
%s
' "$JWT_TOKEN" "$EXPIRES" >"$tokfile"
q 204 401
STUB_BODY= run sh "$admin" acme/repo1 --revoke
assert_eq "revoke JWT-format token rc" 0 "$rc"
assert_eq "revoke JWT-format bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $JWT_TOKEN\"" "$tmp/stub/cfg.1")"
assert_eq "revoke JWT-format confirming read bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $JWT_TOKEN\"" "$tmp/stub/cfg.2")"
[ ! -e "$tokfile" ] && ok || bad "revoke JWT-format token" "token file kept"

# --- guards: malformed token file, concurrent run, a key that is not encrypted
printf 'bad token!\n' >"$tokfile"
WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1
assert_eq "malformed token file blocks mint rc" 1 "$rc"
assert_eq "malformed token file blocks mint curl uncalled" 0 "$(calls)"
run sh "$admin" acme/repo1 --revoke
assert_eq "malformed token file revoke rc" 1 "$rc"
assert_eq "malformed token file revoke curl uncalled" 0 "$(calls)"
[ -e "$tokfile" ] && ok || bad "malformed token file" "removed"
rm -f "$tokfile"
mkdir "$home/.admin-lock.repo1"
WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1
assert_eq "held lock rc" 1 "$rc"
assert_eq "held lock curl uncalled" 0 "$(calls)"
[ -d "$home/.admin-lock.repo1" ] && ok || bad "held lock" "removed by the run that did not take it"
rmdir "$home/.admin-lock.repo1"
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
mkdir "$home/.admin-lock.repo1"
run sh "$admin" acme/repo1 --revoke
assert_eq "revoke under a held lock rc" 1 "$rc"
assert_eq "revoke under a held lock curl uncalled" 0 "$(calls)"
[ -e "$tokfile" ] && ok || bad "revoke under a held lock" "token file removed"
rmdir "$home/.admin-lock.repo1"
rm -f "$tokfile"
run sh "$admin" acme/freshrepo --revoke
assert_eq "revoke of an unknown repo rc" 1 "$rc"
[ ! -e "$home/tokens/acme/freshrepo" ] && ok || bad "revoke of an unknown repo" "created a tokens/ directory"
mv "$home/admin.enc.pem" "$tmp/admin.enc.bak"
cp "$tmp/key.pem" "$home/admin.enc.pem"
WOW_TTY="$tmp/tty-bad" run sh "$admin" acme/repo1
assert_eq "plaintext admin key rc" 1 "$rc"
assert_eq "plaintext admin key curl uncalled" 0 "$(calls)"
mv "$tmp/admin.enc.bak" "$home/admin.enc.pem"
assert_eq "no unlocked key left after any admin run" 0 "$(ls -A "$home" | grep -c '^\.unlock' || true)"
[ ! -e "$home/.admin-lock.repo1" ] && ok || bad "lock" "left behind after the runs"

# --- usage and config, all before any curl call
for args in "" "--revoke" "a b" "../x" "-x" "repo1" "repo1 --revoke" "a/b/c" "acme/" "/repo1" "acme/.." "../repo1" "-acme/repo1" ".acme/repo1" "acme./repo1" "acme/-x" "acme/a b" "acme/repo1 --bogus" "acme/repo1 --perms" "acme/repo1 --revoke --perms contents=read" "acme/repo1 --revoke --perms administration=write,contents=write,pull_requests=write"; do
  # shellcheck disable=SC2086
  run sh "$admin" $args
  assert_eq "admin usage rc [$args]" 2 "$rc"
  assert_eq "admin usage curl uncalled [$args]" 0 "$(calls)"
  [ ! -e "$home/tokens/repo1" ] && [ ! -e "$home/tokens/a" ] && [ ! -e "$home/tokens/-acme" ] && [ ! -e "$home/tokens/.acme" ] && ok || bad "admin usage [$args]" "created a directory"
done
for args in "" "a b" ".." "repo1 --out" "repo1 --bogus"; do
  # shellcheck disable=SC2086
  run sh "$review" $args
  assert_eq "review usage rc [$args]" 2 "$rc"
  assert_eq "review usage curl uncalled [$args]" 0 "$(calls)"
done
assert_eq "usage curl uncalled" 0 "$(calls)"

# --- owner/name: the one token directory, and what mint refuses before it creates anything (#1340)
TOKEN2=ghs_ZyXwVu9876543210ZyXwVu9876543210ZyXwVu
# newhome <name> [broker.json text]: a throwaway $WOW_HOME with the same apps.json and keys
newhome() {
  h="$tmp/h-$1"
  mkdir "$h"
  cp "$home/apps.json" "$home/admin.enc.pem" "$home/review.pem" "$h/"
  if [ $# -ge 2 ]; then printf '%s' "$2" >"$h/broker.json"; fi
  printf '%s' "$h"
}
mint_in() { WOW_HOME="$1" WOW_TTY="$tmp/tty-good" run sh "$admin" "${2:-acme/repo1}"; }
revoke_in() { WOW_HOME="$1" run sh "$admin" "${2:-acme/repo1}" --revoke; }
# put_tok <file> [token] [expires]: a token file, with its directory
put_tok() { mkdir -p "$(dirname "$1")"; printf '%s\n%s\n' "${2:-$TOKEN}" "${3:-$EXPIRES}" >"$1"; }
# untouched <home> <label>: nothing under tokens/ and no unlock directory
untouched() {
  [ ! -e "$1/tokens" ] && [ ! -e "$1/admin" ] && ok || bad "$2" "created tokens/ or admin/"
  assert_eq "$2: no unlocked key left" 0 "$(ls -A "$1" | grep -c '^\.unlock' || true)"
}
has_msg() { case "$out" in *"$2"*) ok ;; *) bad "$1" "'$2' not in: $out" ;; esac; }

# no broker.json, and an entry equal to the argument: only the owner file, no tokens/<name>
for case_name in none exact; do
  if [ "$case_name" = none ]; then h=$(newhome "own-$case_name"); else h=$(newhome "own-$case_name" '{"repos": ["acme/repo1", "acme/other"]}'); fi
  mint_in "$h"
  assert_eq "mint [$case_name] rc" 0 "$rc"
  assert_eq "mint [$case_name] one curl call" 1 "$(calls)"
  assert_eq "mint [$case_name] repo requested" '["repo1"]' "$(sent | jq -c .repositories)"
  assert_eq "mint [$case_name] token line" "$TOKEN" "$(sed -n 1p "$h/admin/acme/repo1/admin-token")"
  assert_eq "mint [$case_name] expiry line" "$EXPIRES" "$(sed -n 2p "$h/admin/acme/repo1/admin-token")"
  assert_eq "mint [$case_name] admin/ holds only the owner directory" acme "$(ls -A "$h/admin")"
  assert_eq "mint [$case_name] owner directory holds only the repo" repo1 "$(ls -A "$h/admin/acme")"
  only_admin() { assert_eq "$1" admin-token "$(ls -A "$2")"; }
  only_admin "mint [$case_name] repo directory holds only admin-token" "$h/admin/acme/repo1"
  [ ! -e "$h/tokens" ] && ok || bad "mint [$case_name]" "created tokens/"
  assert_eq "mint [$case_name] output names the owner file" 1 "$(printf '%s' "$out" | grep -c "$h/admin/acme/repo1/admin-token" || true)"
  assert_eq "mint [$case_name] output names the owner/name revoke" 1 "$(printf '%s' "$out" | grep -c 'wow-admin acme/repo1 --revoke' || true)"
  assert_eq "mint [$case_name] no token in output" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
  assert_eq "mint [$case_name] no passphrase in output" 0 "$(printf '%s' "$out" | grep -c 'correct-horse' || true)"
  assert_eq "mint [$case_name] no token in argv" 0 "$(grep -c "$TOKEN" "$tmp/stub/argv" || true)"
done
# the live owner copy refuses a second mint
mint_in "$h"
assert_eq "owner copy live rc" 1 "$rc"
assert_eq "owner copy live curl uncalled" 0 "$(calls)"

# an owner equal to its own entry's name is accepted, and the owner directory is the whole result
h=$(newhome ownname '{"repos": ["acme/acme"]}')
mint_in "$h" acme/acme
assert_eq "acme/acme with its own entry: rc" 0 "$rc"
assert_eq "acme/acme: token written" "$TOKEN" "$(sed -n 1p "$h/admin/acme/acme/admin-token")"
assert_eq "acme/acme: admin/acme holds only the repo directory" acme "$(ls -A "$h/admin/acme")"

# usage: bare or malformed arguments leave nothing, mint and revoke alike
for arg in repo1 a/b/c acme/ /repo1 ../x acme/.. .acme/repo1 acme./repo1 acme/.hidden acme/repo1.; do
  h=$(newhome "usage-$(printf '%s' "$arg" | tr -c 'A-Za-z0-9\n' _)")
  mint_in "$h" "$arg"
  assert_eq "mint [$arg] usage rc" 2 "$rc"
  assert_eq "mint [$arg] usage curl uncalled" 0 "$(calls)"
  untouched "$h" "mint [$arg] usage"
  revoke_in "$h" "$arg"
  assert_eq "revoke [$arg] usage rc" 2 "$rc"
  assert_eq "revoke [$arg] usage curl uncalled" 0 "$(calls)"
  untouched "$h" "revoke [$arg] usage"
done

# a mint refusal: exit 1, a reason of its own, no curl, no directory, no unlocked key
refused() { # refused <label> <broker.json text> <needle> [arg]
  h=$(newhome "ref-$1" "$2")
  mint_in "$h" "${4:-acme/repo1}"
  assert_eq "refusal [$1] rc" 1 "$rc"
  assert_eq "refusal [$1] curl uncalled" 0 "$(calls)"
  has_msg "refusal [$1] reason" "$3"
  untouched "$h" "refusal [$1]"
}
refused bare '{"repos": ["repo1"]}' 'bare-name entry'
refused bare-beside '{"repos": ["acme/repo1", "other"]}' 'bare-name entry'
refused case-only '{"repos": ["acme/REPO1"]}' 'only ignoring case'
refused other-owner '{"repos": ["beta/repo1"]}' 'under another owner'
refused owner-is-a-name '{"repos": ["zed/acme"]}' 'owner acme is the name half'

# revoke ignores broker.json: the same files, a token on file, and the revoke still lands
revoke_ignores() { # revoke_ignores <label> <broker.json text>
  h=$(newhome "rv-$1" "$2")
  put_tok "$h/admin/acme/repo1/admin-token"
  q 204 401; STUB_BODY= revoke_in "$h"
  assert_eq "revoke [$1] rc" 0 "$rc"
  assert_eq "revoke [$1] one DELETE and its confirming read" 2 "$(calls)"
  [ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke [$1]" "token kept"
}
revoke_ignores bare-entry '{"repos": ["repo1"]}'
revoke_ignores same-name-other-owner '{"repos": ["beta/repo1"]}'
revoke_ignores case-variant '{"repos": ["acme/REPO1"]}'
revoke_ignores notjson 'not json'
revoke_ignores emptyrepos '{"repos": []}'

# every malformed broker.json refuses mint before curl with nothing created; revoke revokes
badcase() {
  name=$1 text=$2
  h=$(newhome "bad-$name" "$text")
  mint_in "$h"
  assert_eq "broker.json $name: mint rc" 1 "$rc"
  assert_eq "broker.json $name: mint curl uncalled" 0 "$(calls)"
  assert_eq "broker.json $name: mint names broker.json" 1 "$(printf '%s' "$out" | grep -c 'broker.json' || true)"
  untouched "$h" "broker.json $name: mint"
  put_tok "$h/admin/acme/repo1/admin-token"
  q 204 401; STUB_BODY= revoke_in "$h"
  assert_eq "broker.json $name: revoke rc" 0 "$rc"
  assert_eq "broker.json $name: revoke one DELETE and its confirming read" 2 "$(calls)"
  [ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "broker.json $name" "revoke kept the token"
}
badcase notjson 'not json'
badcase emptyrepos '{"repos": []}'
badcase nonstring '{"repos": ["acme/repo1", 5]}'
badcase twoslashes '{"repos": ["a/b/repo1"]}'
badcase dotstart '{"repos": [".acme/repo1"]}'
badcase trailingnewline '{"repos": ["acme/repo1\n"]}'
badcase casevariant '{"repos": ["acme/repo1", "beta/REPO1"]}'
badcase twovalues '{"repos": ["acme/repo1"]} {"repos": []}'
badcase ownerisname '{"repos": ["repo1", "repo1/other"]}'
badcase ownerisname2 '{"repos": ["acme/repo1", "beta/acme"]}'

# another owner's live admin token for the same repo refuses a mint, with or without a broker.json.
# The scan runs under `set -f`; a scan that finds nothing would mint here, so rc 1 and the named
# owner/name are the proof that it expanded admin/*/repo1/admin-token.
for bj in none present; do
  if [ "$bj" = none ]; then h=$(newhome "oo-$bj"); else h=$(newhome "oo-$bj" '{"repos": ["acme/repo1"]}'); fi
  put_tok "$h/admin/beta/repo1/admin-token"
  put_tok "$h/admin/gamma/unrelated/admin-token"
  mint_in "$h"
  assert_eq "other owner live [$bj] rc" 1 "$rc"
  assert_eq "other owner live [$bj] curl uncalled" 0 "$(calls)"
  has_msg "other owner live [$bj] names owner/name" "beta/repo1 --revoke"
  [ ! -e "$h/admin/acme" ] && ok || bad "other owner live [$bj]" "created admin/acme"
  assert_eq "other owner live [$bj] no unlocked key left" 0 "$(ls -A "$h" | grep -c '^\.unlock' || true)"
  # revoking the owner it names clears the block, and the mint then goes through
  q 204 401; STUB_BODY= revoke_in "$h" beta/repo1
  assert_eq "other owner live [$bj] revoke by naming that owner rc" 0 "$rc"
  [ ! -e "$h/admin/beta/repo1/admin-token" ] && ok || bad "other owner live [$bj]" "revoke kept the token"
  mint_in "$h"
  assert_eq "other owner live [$bj] mint after the revoke rc" 0 "$rc"
done
# a token for another repo under another owner, an expired one for this repo and the repo's own
# directory under a different owner's name do not block; an unreadable expiry does
h=$(newhome oo-other-repo)
put_tok "$h/admin/beta/repo2/admin-token"
mint_in "$h"
assert_eq "another owner's token for another repo does not block: rc" 0 "$rc"
h=$(newhome oo-expired)
put_tok "$h/admin/beta/repo1/admin-token" "$TOKEN" 2000-01-01T00:00:00Z
mint_in "$h"
assert_eq "another owner's expired token does not block: rc" 0 "$rc"
h=$(newhome oo-unreadable)
mkdir -p "$h/admin/beta/repo1"; printf 'junk\n' >"$h/admin/beta/repo1/admin-token"
mint_in "$h"
assert_eq "another owner's unreadable token blocks: rc" 1 "$rc"
assert_eq "another owner's unreadable token blocks: curl uncalled" 0 "$(calls)"
has_msg "another owner's unreadable token names owner/name" "beta/repo1 --revoke"
# a second live owner among several still blocks (the scan reads every match, not the first)
h=$(newhome oo-several)
put_tok "$h/admin/aaa/repo1/admin-token" "$TOKEN" 2000-01-01T00:00:00Z
put_tok "$h/admin/zzz/repo1/admin-token"
mint_in "$h"
assert_eq "an expired first match does not hide a live later one: rc" 1 "$rc"
has_msg "an expired first match does not hide a live later one" "zzz/repo1 --revoke"

# a live leftover bare copy (the layout before #1340) blocks a mint and is revoked by naming the repo
h=$(newhome leftover-live)
put_tok "$h/tokens/repo1/admin-token"
mint_in "$h"
assert_eq "leftover bare copy live rc" 1 "$rc"
assert_eq "leftover bare copy live curl uncalled" 0 "$(calls)"
has_msg "leftover bare copy live names the revoke" "wow-admin acme/repo1 --revoke"
[ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "leftover bare copy live" "wrote the owner file"
q 204 401; STUB_BODY= revoke_in "$h"
assert_eq "revoke of a leftover bare copy rc" 0 "$rc"
assert_eq "revoke of a leftover bare copy one DELETE and its confirming read" 2 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && ok || bad "revoke of a leftover bare copy" "copy kept"
[ -d "$h/tokens/repo1" ] && ok || bad "revoke of a leftover bare copy" "removed the leftover directory itself"
[ ! -e "$h/.admin-lock.repo1" ] && ok || bad "revoke of a leftover bare copy" "left a lock"

# the layout before #1608: <tokens root>/<owner>/<name>/admin-token, a directory a dev container mounts. A live or unreadable
# one refuses a mint before any passphrase read or curl call; an expired one does not; --revoke revokes and removes it
h=$(newhome legacy-live)
put_tok "$h/tokens/acme/repo1/admin-token"
mint_in "$h"
assert_eq "legacy token live: mint rc" 1 "$rc"
assert_eq "legacy token live: curl uncalled" 0 "$(calls)"
has_msg "legacy token live: the message names the revoke" "wow-admin acme/repo1 --revoke"
[ ! -e "$h/admin" ] && ok || bad "legacy token live" "created admin/"
assert_eq "legacy token live: no unlocked key left" 0 "$(ls -A "$h" | grep -c '^\.unlock' || true)"
h=$(newhome legacy-unreadable)
mkdir -p "$h/tokens/acme/repo1"; printf 'junk\n' >"$h/tokens/acme/repo1/admin-token"
mint_in "$h"
assert_eq "legacy token unreadable: mint rc" 1 "$rc"
assert_eq "legacy token unreadable: curl uncalled" 0 "$(calls)"
has_msg "legacy token unreadable: the message names the revoke" "wow-admin acme/repo1 --revoke"
h=$(newhome legacy-expired)
put_tok "$h/tokens/acme/repo1/admin-token" "$TOKEN" 2000-01-01T00:00:00Z
mint_in "$h"
assert_eq "legacy token expired: mint rc" 0 "$rc"
assert_eq "legacy token expired: the new token is in admin/" "$TOKEN" "$(sed -n 1p "$h/admin/acme/repo1/admin-token")"
# revoke with only a legacy file on file revokes and removes it
h=$(newhome legacy-only)
put_tok "$h/tokens/acme/repo1/admin-token"
q 204 401; STUB_BODY= revoke_in "$h"
assert_eq "revoke legacy only rc" 0 "$rc"
assert_eq "revoke legacy only: a DELETE and a confirming read" 2 "$(calls)"
[ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke legacy only" "legacy file kept"
assert_eq "revoke legacy only names the removed path" 1 "$(printf '%s' "$out" | grep -c "removed $h/tokens/acme/repo1/admin-token" || true)"
[ ! -e "$h/admin" ] && ok || bad "revoke legacy only" "created admin/"
# a legacy file and an own file with different tokens are each settled by their own answers
h=$(newhome legacy-differing)
put_tok "$h/tokens/acme/repo1/admin-token" "$TOKEN"
put_tok "$h/admin/acme/repo1/admin-token" "$TOKEN2"
q 204 401 500; STUB_BODY= revoke_in "$h"
rm -f "$tmp/stub/statuses"
assert_eq "revoke legacy then own: rc" 1 "$rc"
assert_eq "revoke legacy then own: three calls" 3 "$(calls)"
[ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke legacy then own" "legacy file kept after its 204 and 401"
[ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke legacy then own" "own file removed after its DELETE 500"
assert_eq "revoke legacy then own: the legacy token was the first DELETE" 1 "$(grep -c "Bearer $TOKEN\"" "$tmp/stub/cfg.1")"
assert_eq "revoke legacy then own: the own token was the last call" 1 "$(grep -c "Bearer $TOKEN2\"" "$tmp/stub/cfg.3")"
# every failure is named, not only the last: two distinct tokens whose DELETEs both answer 500
h=$(newhome fail-both)
put_tok "$h/tokens/acme/repo1/admin-token" "$TOKEN"
put_tok "$h/admin/acme/repo1/admin-token" "$TOKEN2"
q 500 500; STUB_BODY= revoke_in "$h"
rm -f "$tmp/stub/statuses"
assert_eq "revoke two 500s: rc" 1 "$rc"
assert_eq "revoke two 500s: two DELETEs" 2 "$(calls)"
[ -e "$h/tokens/acme/repo1/admin-token" ] && [ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke two 500s" "a file was removed"
assert_eq "revoke two 500s names the legacy kept path on its own line" 1 "$(printf '%s\n' "$out" | grep -Fxc "wow-admin: kept $h/tokens/acme/repo1/admin-token" || true)"
assert_eq "revoke two 500s names the own kept path on its own line" 1 "$(printf '%s\n' "$out" | grep -Fxc "wow-admin: kept $h/admin/acme/repo1/admin-token" || true)"
assert_eq "revoke two 500s: both cause lines carry the prefix" 2 "$(printf '%s\n' "$out" | grep -c '^wow-admin: GitHub answered HTTP 500' || true)"
assert_eq "revoke two 500s never prints a token" 0 "$(printf '%s\n' "$out" | grep -c "$TOKEN\|$TOKEN2" || true)"
# a 204 then an unconfirming 200, then a 500 on the next token: the advice to run --revoke again survives
h=$(newhome fail-unconfirmed-then-500)
put_tok "$h/tokens/acme/repo1/admin-token" "$TOKEN"
put_tok "$h/admin/acme/repo1/admin-token" "$TOKEN2"
q 204 200 500; STUB_BODY= revoke_in "$h"
rm -f "$tmp/stub/statuses"
assert_eq "revoke 204-200-500: rc" 1 "$rc"
assert_eq "revoke 204-200-500: three calls" 3 "$(calls)"
assert_eq "revoke 204-200-500 keeps the advice to run again" 1 "$(printf '%s\n' "$out" | grep -c "run wow-admin acme/repo1 --revoke again" || true)"
assert_eq "revoke 204-200-500 puts the advice on a prefixed line" 1 "$(printf '%s\n' "$out" | grep -c '^wow-admin: .*run wow-admin acme/repo1 --revoke again' || true)"
assert_eq "revoke 204-200-500 names the legacy kept path on its own line" 1 "$(printf '%s\n' "$out" | grep -Fxc "wow-admin: kept $h/tokens/acme/repo1/admin-token" || true)"
assert_eq "revoke 204-200-500 names the own kept path on its own line" 1 "$(printf '%s\n' "$out" | grep -Fxc "wow-admin: kept $h/admin/acme/repo1/admin-token" || true)"
assert_eq "revoke 204-200-500 names the own token's failure" 1 "$(printf '%s\n' "$out" | grep -c "GitHub answered HTTP 500" || true)"
[ -e "$h/tokens/acme/repo1/admin-token" ] && [ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke 204-200-500" "a file was removed"
# a first token's DELETE answering 500, then the second token's curl failing (on the DELETE, then on the confirming read): both failures are printed, each prefixed
for case_q in "500 CURLFAIL:DELETE" "500 204 CURLFAIL:confirming read"; do
  qs=${case_q%%:*}; lbl=${case_q#*:}
  h=$(newhome "fail-500-then-curl-$(printf '%s' "$lbl" | tr -c 'A-Za-z' '-')")
  put_tok "$h/tokens/acme/repo1/admin-token" "$TOKEN"
  put_tok "$h/admin/acme/repo1/admin-token" "$TOKEN2"
  # shellcheck disable=SC2086
  q $qs; STUB_BODY= revoke_in "$h"
  rm -f "$tmp/stub/statuses"
  assert_eq "revoke 500 then a curl failure on the $lbl: rc" 1 "$rc"
  assert_eq "revoke 500 then a curl failure on the $lbl: the first token's HTTP 500 is printed with the prefix" 1 "$(printf '%s\n' "$out" | grep -c '^wow-admin: GitHub answered HTTP 500' || true)"
  assert_eq "revoke 500 then a curl failure on the $lbl: the kept line is printed with the prefix" 1 "$(printf '%s\n' "$out" | grep -Fxc "wow-admin: kept $h/tokens/acme/repo1/admin-token" || true)"
  assert_eq "revoke 500 then a curl failure on the $lbl: the curl failure is printed with the prefix" 1 "$(printf '%s\n' "$out" | grep -c '^wow-admin: curl failed' || true)"
  [ -e "$h/tokens/acme/repo1/admin-token" ] && [ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke 500 then a curl failure on the $lbl" "a file was removed"
done
# a home path with a space: the kept files stay whole on lines of their own
h=$(newhome "with space")
put_tok "$h/tokens/acme/repo1/admin-token"
put_tok "$h/admin/acme/repo1/admin-token"
STUB_BODY= STUB_STATUS=500 revoke_in "$h"
assert_eq "revoke path with a space: rc" 1 "$rc"
assert_eq "revoke path with a space: one DELETE" 1 "$(calls)"
[ -e "$h/tokens/acme/repo1/admin-token" ] && [ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke path with a space" "a file was removed"
assert_eq "revoke path with a space: the legacy path is one whole line" 1 "$(printf '%s\n' "$out" | grep -Fxc "wow-admin: kept $h/tokens/acme/repo1/admin-token" || true)"
assert_eq "revoke path with a space: the own path is one whole line" 1 "$(printf '%s\n' "$out" | grep -Fxc "wow-admin: kept $h/admin/acme/repo1/admin-token" || true)"
# a legacy file whose first line holds no token: no call, the file is kept
h=$(newhome legacy-notoken)
mkdir -p "$h/tokens/acme/repo1"; printf 'junk\n' >"$h/tokens/acme/repo1/admin-token"
revoke_in "$h"
assert_eq "revoke legacy file with no token: rc" 1 "$rc"
assert_eq "revoke legacy file with no token: curl uncalled" 0 "$(calls)"
[ -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke legacy file with no token" "the file was removed"
# a file rm cannot remove is kept and reported, and the next token is still tried
h=$(newhome fail-rm)
put_tok "$h/tokens/acme/repo1/admin-token" "$TOKEN"
put_tok "$h/admin/acme/repo1/admin-token" "$TOKEN2"
chmod 555 "$h/tokens/acme/repo1"
if ( : >"$h/tokens/acme/repo1/probe" ) 2>/dev/null; then
  rm -f "$h/tokens/acme/repo1/probe"
  chmod 755 "$h/tokens/acme/repo1"
  echo "skip - revoke failed removal: a non-writable directory does not stop a removal here (uid $(id -u))"
else
  q 401 401; STUB_BODY= revoke_in "$h"
  rm -f "$tmp/stub/statuses"
  chmod 755 "$h/tokens/acme/repo1"
  assert_eq "revoke failed removal: rc" 1 "$rc"
  assert_eq "revoke failed removal: both tokens tried" 2 "$(calls)"
  [ -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke failed removal" "the legacy file is gone"
  [ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke failed removal" "the own file was kept"
  assert_eq "revoke failed removal: no removed line for the kept file" 0 "$(printf '%s\n' "$out" | grep -c "removed $h/tokens/acme/repo1/admin-token" || true)"
  assert_eq "revoke failed removal: the kept file is named" 1 "$(printf '%s\n' "$out" | grep -c "could not remove $h/tokens/acme/repo1/admin-token" || true)"
  assert_eq "revoke failed removal: the line gives the remedy" 1 "$(printf '%s\n' "$out" | grep -c "could not remove $h/tokens/acme/repo1/admin-token; the token file is kept; fix the permissions of its directory, or delete the file by hand" || true)"
  assert_eq "revoke failed removal: the own file has its removed line" 1 "$(printf '%s\n' "$out" | grep -c "removed $h/admin/acme/repo1/admin-token" || true)"
fi
# the same token in both: one DELETE, one read, both files go and each is named
h=$(newhome legacy-same)
put_tok "$h/tokens/acme/repo1/admin-token"
put_tok "$h/admin/acme/repo1/admin-token"
q 204 401; STUB_BODY= revoke_in "$h"
assert_eq "revoke the same token in both files: rc" 0 "$rc"
assert_eq "revoke the same token in both files: one DELETE and one read" 2 "$(calls)"
[ ! -e "$h/tokens/acme/repo1/admin-token" ] && [ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke the same token in both files" "a file was kept"
assert_eq "revoke the same token in both files: both paths named" 2 "$(printf '%s' "$out" | grep -c '^removed ' || true)"

# a missing identity home is named as such, not as a held lock
WOW_HOME="$tmp/no-such-home" run sh "$admin" acme/repo1 --revoke
assert_eq "missing home rc" 1 "$rc"
has_msg "missing home reason" "no identity home"

# the lock is per repo name: a run for the same name under another owner (or in another case) is refused while it is held
h=$(newhome name-lock)
mkdir "$h/.admin-lock.repo1"
mint_in "$h" typo/repo1
assert_eq "name lock held, other owner: mint rc" 1 "$rc"
assert_eq "name lock held, other owner: curl uncalled" 0 "$(calls)"
mint_in "$h" typo/REPO1
assert_eq "name lock held, other case: mint rc" 1 "$rc"
put_tok "$h/admin/typo/repo1/admin-token"
revoke_in "$h" typo/repo1
assert_eq "name lock held, other owner: revoke rc" 1 "$rc"
assert_eq "name lock held, other owner: revoke curl uncalled" 0 "$(calls)"
[ -d "$h/.admin-lock.repo1" ] && ok || bad "name lock" "removed by a run that did not take it"
rmdir "$h/.admin-lock.repo1"
# a live leftover with a mistyped owner refuses the mint and creates no directory for it
h=$(newhome leftover-typo)
put_tok "$h/tokens/repo1/admin-token"
mint_in "$h" typo/repo1
assert_eq "leftover live, typo owner: rc" 1 "$rc"
[ ! -e "$h/admin/typo" ] && ok || bad "leftover live, typo owner" "created admin/typo"

# revoke of identical copies: one DELETE, both removed (204 and 401)
h=$(newhome revoke-copies)
for st in 204 401; do
  put_tok "$h/tokens/repo1/admin-token"
  put_tok "$h/admin/acme/repo1/admin-token"
  if [ "$st" = 204 ]; then q 204 401; want=2; else q 401; want=1; fi
  STUB_BODY= revoke_in "$h"
  assert_eq "revoke identical $st rc" 0 "$rc"
  assert_eq "revoke identical $st one DELETE (and its confirming read after a 204)" "$want" "$(calls)"
  [ ! -e "$h/tokens/repo1/admin-token" ] && [ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke identical $st" "a copy was kept"
done

# #1348 finding 3: only the owner copy on file
h=$(newhome owner-only)
put_tok "$h/admin/acme/repo1/admin-token"
q 204 401; STUB_BODY= revoke_in "$h"
assert_eq "revoke owner copy only rc" 0 "$rc"
assert_eq "revoke owner copy only one DELETE and its confirming read" 2 "$(calls)"
[ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke owner copy only" "copy kept"
[ ! -e "$h/tokens/repo1" ] && ok || bad "revoke owner copy only" "created tokens/repo1"

h=$(newhome differing)
# #1348 finding 3: two differing tokens, the first DELETE answers 204 and the second 500. The
# leftover copy is revoked first: it is removed, the owner copy is kept, the exit is 1.
put_tok "$h/tokens/repo1/admin-token" "$TOKEN"
put_tok "$h/admin/acme/repo1/admin-token" "$TOKEN2"
q 204 401 500
STUB_BODY= revoke_in "$h"
rm -f "$tmp/stub/statuses"
assert_eq "revoke differing 204 then 500 rc" 1 "$rc"
assert_eq "revoke differing 204 then 500 two DELETEs and one confirming read" 3 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && ok || bad "revoke differing 204 then 500" "the leftover copy was kept"
[ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke differing 204 then 500" "the owner copy was removed"
assert_eq "revoke differing 204 then 500 kept the owner token" "$TOKEN2" "$(sed -n 1p "$h/admin/acme/repo1/admin-token")"
# all 500: both kept
put_tok "$h/tokens/repo1/admin-token" "$TOKEN"
STUB_BODY= STUB_STATUS=500 revoke_in "$h"
assert_eq "revoke differing 500 rc" 1 "$rc"
[ -e "$h/tokens/repo1/admin-token" ] && [ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke differing 500" "a copy was removed"
# both answer 204: both removed, two DELETEs
q 204 401 204 401; STUB_BODY= revoke_in "$h"
assert_eq "revoke differing rc" 0 "$rc"
assert_eq "revoke differing two DELETEs, each confirmed" 4 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && [ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke differing" "a copy was kept"

# a malformed copy stops revoke before curl and keeps every file
put_tok "$h/tokens/repo1/admin-token"
mkdir -p "$h/admin/acme/repo1"; printf 'junk\n' >"$h/admin/acme/repo1/admin-token"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke malformed copy rc" 1 "$rc"
assert_eq "revoke malformed copy curl uncalled" 0 "$(calls)"
[ -e "$h/tokens/repo1/admin-token" ] && [ -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "revoke malformed copy" "a file was removed"

# revoke with nothing on file creates no directory
h=$(newhome nothing '{"repos": ["acme/repo1"]}')
revoke_in "$h"
assert_eq "revoke nothing rc" 1 "$rc"
untouched "$h" "revoke nothing"

# a dangling symlink at the owner path: refused before curl, nothing written through it
h=$(newhome link)
mkdir -p "$h/admin/acme/repo1"
ln -s "$tmp/linktarget" "$h/admin/acme/repo1/admin-token"
mint_in "$h"
assert_eq "symlink rc" 1 "$rc"
assert_eq "symlink curl uncalled" 0 "$(calls)"
[ ! -e "$tmp/linktarget" ] && ok || bad "symlink" "something was written through it"
[ ! -e "$h/.admin-lock.repo1" ] && ok || bad "symlink" "left a lock"

empty="$tmp/empty"
mkdir "$empty"
WOW_HOME="$empty" WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1
assert_eq "admin missing config rc" 1 "$rc"
assert_eq "admin missing config curl uncalled" 0 "$(calls)"
WOW_HOME="$empty" run sh "$review" repo1
assert_eq "review missing config rc" 1 "$rc"
assert_eq "missing config curl uncalled" 0 "$(calls)"

# an apps.json still keyed by org name (the pre-#443 layout) is a missing config, not a fallback
oldkeys="$tmp/oldkeys"
mkdir "$oldkeys"
printf '{"glunk-admin": {"client_id": "x", "installation_id": 1, "key": "k.pem"}, "glunk-review": {"client_id": "y", "installation_id": 2, "key": "r.pem"}}\n' >"$oldkeys/apps.json"
# real key files, so a fallback to the org-keyed entries would get past the key checks and reach curl
cp "$home/admin.enc.pem" "$oldkeys/k.pem"
cp "$home/review.pem" "$oldkeys/r.pem"
WOW_HOME="$oldkeys" WOW_TTY="$tmp/tty-good" run sh "$admin" acme/repo1
assert_eq "admin old-keys config rc" 1 "$rc"
assert_eq "admin old-keys config curl uncalled" 0 "$(calls)"
assert_eq "admin old-keys config names the role keys" 1 "$(printf '%s' "$out" | grep -c 'keyed by role' || true)"
WOW_HOME="$oldkeys" run sh "$review" repo1
assert_eq "review old-keys config rc" 1 "$rc"
assert_eq "review old-keys config curl uncalled" 0 "$(calls)"
assert_eq "review old-keys config names the role keys" 1 "$(printf '%s' "$out" | grep -c 'keyed by role' || true)"

# --- the typed owner is checked against the admin installation's account (#1425)
# a successful mint makes exactly one account read, then the mint
h=$(newhome acct-ok)
mint_in "$h"
assert_eq "owner check ok: rc" 0 "$rc"
assert_eq "owner check ok: one account read" 1 "$(acct_reads)"
assert_eq "owner check ok: one mint call" 1 "$(calls)"
assert_eq "owner check ok: the read asked for the admin installation" 1 "$(grep -c '^url = "https://api.github.com/app/installations/111"$' "$tmp/stub/acct-stdin")"
assert_eq "owner check ok: the passphrase is not in the read" 0 "$(grep -c 'correct-horse' "$tmp/stub/acct-stdin" || true)"

# a mismatch: after the prompt, no POST, nothing left behind
h=$(newhome acct-typo)
STUB_ACCT_LOGIN=acme mint_in "$h" typo/repo1
assert_eq "owner mismatch rc" 1 "$rc"
assert_eq "owner mismatch no POST" 0 "$(calls)"
assert_eq "owner mismatch one account read" 1 "$(acct_reads)"
has_msg "owner mismatch names both logins" "the admin App's installation belongs to acme, not typo; refusing typo/repo1"
untouched "$h" "owner mismatch"

# case is ignored, and the typed spelling picks the directory
h=$(newhome acct-case)
mint_in "$h" ACME/repo1
assert_eq "owner case rc" 0 "$rc"
assert_eq "owner case one account read" 1 "$(acct_reads)"
assert_eq "owner case token written under the typed owner" "$TOKEN" "$(sed -n 1p "$h/admin/ACME/repo1/admin-token")"
h=$(newhome acct-case2)
STUB_ACCT_LOGIN=Acme mint_in "$h" acme/repo1
assert_eq "account in another case rc" 0 "$rc"

# a failed read, or a login of the wrong shape, refuses the same way
h=$(newhome acct-500)
STUB_ACCT_STATUS=500 STUB_ACCT_BODY='{"message":"boom"}' mint_in "$h"
assert_eq "account read 500 rc" 1 "$rc"
assert_eq "account read 500 no POST" 0 "$(calls)"
has_msg "account read 500 message" "could not read the admin App's installation account; refusing acme/repo1"
untouched "$h" "account read 500"
for badlogin in '{"account":{"login":"-acme"}}' '{"account":{"login":"ac/me"}}' '{"account":{"login":""}}' '{"account":{"login":7}}' '{"account":null}' '{}'; do
  h=$(newhome "acct-bad-$(printf '%s' "$badlogin" | tr -c 'A-Za-z0-9' _)")
  STUB_ACCT_BODY=$badlogin mint_in "$h"
  assert_eq "bad account [$badlogin] rc" 1 "$rc"
  assert_eq "bad account [$badlogin] no POST" 0 "$(calls)"
  untouched "$h" "bad account [$badlogin]"
done

# --revoke makes no account read
h=$(newhome acct-revoke)
put_tok "$h/admin/typo/repo1/admin-token"
q 204 401; STUB_BODY= revoke_in "$h" typo/repo1
assert_eq "revoke under a mistyped owner rc" 0 "$rc"
assert_eq "revoke makes no account read" 0 "$(acct_reads)"
assert_eq "revoke makes one DELETE and its confirming read" 2 "$(calls)"

# --- tokens root (#1568)
real_home=${HOME:-}
trn=0
# newfh: a fresh fixture HOME (no default home in it); sets fh, dh
newfh() { trn=$((trn + 1)); fh="$tmp/fh$trn"; mkdir "$fh"; dh="$fh/.config/glunk-identity"; HOME="$fh"; export HOME; }
# shared_home <name> <content, printf form>: a second home with a tokens-root file
shared_home() { h=$(newhome "tr$trn-$1"); printf "$2" >"$h/tokens-root"; }
default_home() { mkdir -p "$dh"; cp "$home/apps.json" "$home/admin.enc.pem" "$home/review.pem" "$dh/"; }

# a missing default home is created private for the lock, and the token goes to the second home's own admin/ (#1608)
newfh
shared_home absent 'default-home\n'
rm -f "$tmp/stub/lockseen" "$tmp/stub/lockseen2"
STUB_LOCKDIR="$dh/.admin-lock.repo1" STUB_LOCKDIR2="$h/.admin-lock.repo1" mint_in "$h"
assert_eq "tokens root absent home: rc" 0 "$rc"
assert_eq "tokens root absent home: token in the second home's own admin/" "$TOKEN" "$(sed -n 1p "$h/admin/acme/repo1/admin-token")"
[ ! -e "$h/tokens" ] && ok || bad "tokens root absent home" "created tokens/ in the second home"
[ ! -e "$dh/tokens" ] && ok || bad "tokens root absent home" "created tokens/ in the default home"
[ ! -e "$dh/admin" ] && ok || bad "tokens root absent home" "created admin/ in the default home"
assert_eq "tokens root absent home: lock seen in the default home during the run" 1 "$([ -s "$tmp/stub/lockseen" ] && echo 1 || echo 0)"
assert_eq "tokens root absent home: lock not made in the second home" 0 "$([ -s "$tmp/stub/lockseen2" ] && echo 1 || echo 0)"
[ ! -e "$dh/.admin-lock.repo1" ] && ok || bad "tokens root absent home" "left the lock"
assert_eq "tokens root absent home: default home has no group or other bits" "------" "$(ls -ld "$dh" | cut -c5-10)"
assert_eq "tokens root absent home: admin/ in the second home has no group or other bits" "------" "$(ls -ld "$h/admin" | cut -c5-10)"

# revoke removes the second home's own file
q 204 401; STUB_BODY= revoke_in "$h"
assert_eq "tokens root revoke rc" 0 "$rc"
[ ! -e "$h/admin/acme/repo1/admin-token" ] && ok || bad "tokens root revoke" "token kept"
[ ! -e "$h/tokens" ] && ok || bad "tokens root revoke" "created tokens/ in the second home"

# a live legacy token under the default home's tokens/ refuses a mint from the second home (curl uncalled); an expired one does not
newfh; default_home
shared_home legacy 'default-home\n'
put_tok "$dh/tokens/acme/repo1/admin-token"
mint_in "$h"
assert_eq "tokens root, live legacy token in the default home: mint rc" 1 "$rc"
assert_eq "tokens root, live legacy token in the default home: curl uncalled" 0 "$(calls)"
has_msg "tokens root, live legacy token names the revoke" "wow-admin acme/repo1 --revoke"
put_tok "$dh/tokens/acme/repo1/admin-token" "$TOKEN" 2000-01-01T00:00:00Z
mint_in "$h"
assert_eq "tokens root, expired legacy token: mint rc" 0 "$rc"
# a live token under admin/<other owner>/repo1 in the second home refuses a mint there too
newfh; default_home
shared_home otheradmin 'default-home\n'
put_tok "$h/admin/beta/repo1/admin-token"
mint_in "$h"
assert_eq "tokens root, live admin token under another owner: mint rc" 1 "$rc"
assert_eq "tokens root, live admin token under another owner: curl uncalled" 0 "$(calls)"
has_msg "tokens root, live admin token under another owner names owner/name" "beta/repo1 --revoke"

# a lock held in the default home refuses mint and revoke
newfh; default_home
shared_home lockheld 'default-home\n'
mkdir "$dh/.admin-lock.repo1"
put_tok "$dh/tokens/acme/repo1/admin-token" "$TOKEN" 2000-01-01T00:00:00Z
mint_in "$h"
assert_eq "tokens root lock held: mint rc" 1 "$rc"
assert_eq "tokens root lock held: mint curl uncalled" 0 "$(calls)"
revoke_in "$h"
assert_eq "tokens root lock held: revoke rc" 1 "$rc"
assert_eq "tokens root lock held: revoke curl uncalled" 0 "$(calls)"

# two homes sharing one root, in the spec's order
newfh; default_home
shared_home other 'default-home\n'
put_tok "$dh/admin/acme/x/admin-token"
put_tok "$dh/tokens/x/admin-token"
put_tok "$dh/tokens/other/x/admin-token"
put_tok "$h/admin/other/x/admin-token"
q 204 401; STUB_BODY= revoke_in "$h" other/x
assert_eq "two homes: second home revoke rc" 0 "$rc"
assert_eq "two homes: revoke makes one DELETE and its confirming read (one token in both files)" 2 "$(calls)"
[ ! -e "$dh/tokens/other/x/admin-token" ] && ok || bad "two homes" "the legacy other/x kept"
[ ! -e "$h/admin/other/x/admin-token" ] && ok || bad "two homes" "the own other/x kept"
[ -e "$dh/admin/acme/x/admin-token" ] && ok || bad "two homes" "revoke removed acme/x"
[ -e "$dh/tokens/x/admin-token" ] && ok || bad "two homes" "revoke removed the leftover"
STUB_ACCT_LOGIN=other mint_in "$h" other/x
assert_eq "two homes: second home mint is not blocked by acme/x or the leftover: rc" 0 "$rc"
assert_eq "two homes: new other/x written to the second home's admin/" "$TOKEN" "$(sed -n 1p "$h/admin/other/x/admin-token")"
rm -f "$h/admin/other/x/admin-token"; put_tok "$h/admin/other/x/admin-token" "$TOKEN2"
q 204 401; STUB_BODY= revoke_in "$dh" acme/x
assert_eq "two homes: default home revoke rc" 0 "$rc"
[ ! -e "$dh/admin/acme/x/admin-token" ] && ok || bad "two homes" "acme/x kept"
assert_eq "two homes: the new other/x stays" "$TOKEN2" "$(sed -n 1p "$h/admin/other/x/admin-token")"

# the accepted and refused file contents
for form in 'default-home' 'default-home\n' 'default-home\r\n'; do
  newfh; shared_home accept "$form"
  mint_in "$h"
  assert_eq "tokens root accepted [$form] rc" 0 "$rc"
  assert_eq "tokens root accepted [$form] token" "$TOKEN" "$(sed -n 1p "$h/admin/acme/repo1/admin-token")"
done
for form in 'default-home\n\n' 'default-home\r\n\r\n' 'default-home\r' 'default-home x\n' 'Default-Home\n' '/abs/path\n' '' '\n' 'default-home\nmore\n'; do
  newfh; shared_home refuse "$form"
  mint_in "$h"
  assert_eq "tokens root refused [$form] mint rc" 1 "$rc"
  assert_eq "tokens root refused [$form] mint curl uncalled" 0 "$(calls)"
  revoke_in "$h"
  assert_eq "tokens root refused [$form] revoke rc" 1 "$rc"
  assert_eq "tokens root refused [$form] revoke curl uncalled" 0 "$(calls)"
  [ ! -e "$fh/.config" ] && ok || bad "tokens root refused [$form]" "created the default home"
done
for pair in 'nul-inside:default-\000home\n' 'nul-after:default-home\000' 'nul-before-LF:default-home\000\n'; do
  newfh; shared_home nul "${pair#*:}"
  mint_in "$h"
  assert_eq "tokens root [${pair%%:*}]: mint rc" 1 "$rc"
  assert_eq "tokens root [${pair%%:*}]: curl uncalled" 0 "$(calls)"
done
has_msg "tokens root refusal names the file and the word" "tokens-root must be a regular file holding exactly default-home"

# a link, a directory, an empty HOME, and the file in the default home itself
newfh; default_home
h=$(newhome tr-link); printf 'default-home\n' >"$tmp/tr-target"; ln -s "$tmp/tr-target" "$h/tokens-root"
for how in link; do
  mint_in "$h"; assert_eq "tokens root $how mint rc" 1 "$rc"; assert_eq "tokens root $how mint curl uncalled" 0 "$(calls)"
  revoke_in "$h"; assert_eq "tokens root $how revoke rc" 1 "$rc"; assert_eq "tokens root $how revoke curl uncalled" 0 "$(calls)"
done
h=$(newhome tr-dir); mkdir "$h/tokens-root"
mint_in "$h"; assert_eq "tokens root directory mint rc" 1 "$rc"; assert_eq "tokens root directory mint curl uncalled" 0 "$(calls)"
revoke_in "$h"; assert_eq "tokens root directory revoke rc" 1 "$rc"; assert_eq "tokens root directory revoke curl uncalled" 0 "$(calls)"
shared_home emptyhome 'default-home\n'
HOME= mint_in "$h"; assert_eq "tokens root empty HOME mint rc" 1 "$rc"; assert_eq "tokens root empty HOME mint curl uncalled" 0 "$(calls)"
HOME= revoke_in "$h"; assert_eq "tokens root empty HOME revoke rc" 1 "$rc"; assert_eq "tokens root empty HOME revoke curl uncalled" 0 "$(calls)"
HOME="$fh"; export HOME
printf 'default-home\n' >"$dh/tokens-root"
mint_in "$dh"; assert_eq "tokens root in the default home mint rc" 1 "$rc"; assert_eq "tokens root in the default home mint curl uncalled" 0 "$(calls)"
has_msg "tokens root in the default home message" "the default home itself takes no tokens-root file"
revoke_in "$dh"; assert_eq "tokens root in the default home revoke rc" 1 "$rc"; assert_eq "tokens root in the default home revoke curl uncalled" 0 "$(calls)"
# the default home itself through a link (last component, then a parent component), or in another letter case (#1571)
newfh; default_home
ln -s "$dh" "$tmp/tr-lnk"; ln -s "$fh" "$tmp/tr-parent"; mkdir -p "$fh/.config/GLUNK-identity"
cp "$home/apps.json" "$home/admin.enc.pem" "$home/review.pem" "$fh/.config/GLUNK-identity/"
for how in link parent case; do
  case "$how" in
    link) hv="$tmp/tr-lnk" ;;
    parent) hv="$tmp/tr-parent/.config/glunk-identity" ;;
    case) hv="$fh/.config/GLUNK-identity" ;;
  esac
  printf 'default-home\n' >"$hv/tokens-root"
  mint_in "$hv"; assert_eq "tokens root default home [$how] mint rc" 1 "$rc"; assert_eq "tokens root default home [$how] mint curl uncalled" 0 "$(calls)"
  has_msg "tokens root default home [$how] message" "the default home itself takes no tokens-root file"
  revoke_in "$hv"; assert_eq "tokens root default home [$how] revoke rc" 1 "$rc"; assert_eq "tokens root default home [$how] revoke curl uncalled" 0 "$(calls)"
  rm -f "$hv/tokens-root"
done
# the same case variant written with a trailing slash or a /./ component, with the default home absent
rm -rf "$fh/.config/glunk-identity"; printf 'default-home\n' >"$fh/.config/GLUNK-identity/tokens-root"
for hv in "$fh/.config/GLUNK-identity/" "$fh/./.config/GLUNK-identity" "$fh/././.config/GLUNK-identity"; do
  mint_in "$hv"; assert_eq "tokens root default home [$hv] mint rc" 1 "$rc"; assert_eq "tokens root default home [$hv] mint curl uncalled" 0 "$(calls)"
done


# sed shims (#1598): each runs the real sed by REAL_SED, captured before the shim exists; removed after its cases
real_sed=$(command -v sed); REAL_SED=$real_sed; export REAL_SED
# non-GNU emulation: refuses the ;-joined label forms
cat >"$tmp/bin/sed" <<'STUB'
#!/bin/sh
for a in "$@"; do
  case "$a" in *':a;'* | *'ta;'*) exit 1 ;; esac
done
exec "$REAL_SED" "$@"
STUB
chmod +x "$tmp/bin/sed"
newfh; default_home
shared_home nongnu 'default-home\n'
mint_in "$h"; assert_eq "tokens root non-GNU sed: a valid second home mints rc" 0 "$rc"
for how in file link parent slash dot case; do
  case "$how" in
    file) hv="$dh" ;;
    link) hv="$tmp/tr-lnk-ng$trn" ; ln -s "$dh" "$hv" ;;
    parent) hv="$tmp/tr-parent-ng$trn/.config/glunk-identity"; ln -s "$fh" "$tmp/tr-parent-ng$trn" ;;
    case) mkdir -p "$fh/.config/GLUNK-identity"; hv="$fh/.config/GLUNK-identity" ;;
    slash) hv="$dh/" ;;
    dot) hv="$fh/./.config/glunk-identity" ;;
  esac
  if [ "$how" = case ]; then rm -rf "$dh"; cp "$home/apps.json" "$home/admin.enc.pem" "$home/review.pem" "$hv/"; fi
  printf 'default-home\n' >"$hv/tokens-root"
  mint_in "$hv"; assert_eq "tokens root non-GNU sed [$how] rc" 1 "$rc"; assert_eq "tokens root non-GNU sed [$how] curl uncalled" 0 "$(calls)"
  has_msg "tokens root non-GNU sed [$how] message" "the default home itself takes no tokens-root file"
done
rm -f "$tmp/bin/sed"
# one-sided empty output: the shim prints nothing, exit 0, only for the named side's lowercased path
for side in b a; do
  newfh; default_home
  shared_home empty-$side 'default-home\n'
  if [ "$side" = b ]; then EMPTY_FOR=$(printf '%s' "$dh" | tr 'A-Z' 'a-z'); else EMPTY_FOR=$(printf '%s' "$h" | tr 'A-Z' 'a-z'); fi
  export EMPTY_FOR
  cat >"$tmp/bin/sed" <<'STUB'
#!/bin/sh
in=$(cat)
if [ "$in" = "$EMPTY_FOR" ]; then exit 0; fi
printf '%s\n' "$in" | "$REAL_SED" "$@"
STUB
  chmod +x "$tmp/bin/sed"
  mint_in "$h"; assert_eq "tokens root empty normalisation [lc_$side] rc" 1 "$rc"
  has_msg "tokens root empty normalisation [lc_$side] message" "could not be normalised"
  assert_eq "tokens root empty normalisation [lc_$side] curl uncalled" 0 "$(calls)"
  rm -f "$tmp/bin/sed"
done
unset EMPTY_FOR

# a home at the filesystem root (#1698): path_is_root_spelling at function level (a real home at / cannot be set up without root
# rights), then static checks that resolve_tokens_root asks it before the "could not be normalised" refusal and names the real cause
rs_get() { ( prog=t; . "$root_dir/scripts/identity/wow-common.sh"; if path_is_root_spelling "$1"; then echo true; else echo false; fi ); }
for rs in / // /. /./; do assert_eq "root spelling [$rs] is true" true "$(rs_get "$rs")"; done
for rs in /home/x '' . /.. /a/..; do assert_eq "root spelling [$rs] is false" false "$(rs_get "$rs")"; done
rs_fn=$(sed -n '/^resolve_tokens_root() {/,/^}/p' "$root_dir/scripts/identity/wow-common.sh")
rs_call=$(printf '%s\n' "$rs_fn" | grep -n 'path_is_root_spelling' | head -1 | cut -d: -f1)
rs_norm=$(printf '%s\n' "$rs_fn" | grep -n 'could not be normalised' | head -1 | cut -d: -f1)
if [ -n "$rs_call" ] && [ -n "$rs_norm" ] && [ "$rs_call" -lt "$rs_norm" ]; then ok; else bad "tokens root: resolve_tokens_root asks path_is_root_spelling before the normalisation refusal" "call line '$rs_call', refusal line '$rs_norm'"; fi
rs_die=$(printf '%s\n' "$rs_fn" | grep 'path_is_root_spelling' | head -1)
case "$rs_die" in
  *'die "$msg, and a home at the filesystem root takes no tokens-root file"'*) case "$rs_die" in *'could not be normalised'*) bad "tokens root: the root branch's message" "names a failed normalisation" ;; *) ok ;; esac ;;
  *) bad "tokens root: the root branch's message" "line is: $rs_die" ;;
esac


# -- never run from the cwd ---------------------------------------------------------------------
# A slash-less $0 could source a wow-common.sh a branch under review planted in the cwd.
mkdir "$tmp/plant-wow-admin"
cp "$root_dir/scripts/identity/wow-admin" "$tmp/plant-wow-admin/wow-admin"
printf '#!/bin/sh\ntouch "%s/marker"\necho reached\n' "$tmp/plant-wow-admin" >"$tmp/plant-wow-admin/wow-common.sh"
sl_rc=0
sl_out="$(cd "$tmp/plant-wow-admin" && sh wow-admin 2>"$tmp/plant-wow-admin.err")" || sl_rc=$?
assert_eq "wow-admin slash-less refuses (stdout)" "" "$sl_out"
assert_eq "wow-admin slash-less refuses (rc)" 2 "$sl_rc"
assert_eq "wow-admin slash-less never reached the planted wow-common.sh" no "$([ -e "$tmp/plant-wow-admin/marker" ] && echo yes || echo no)"
assert_eq "wow-admin slash-less stderr names the tool" "wow-admin: must be run by path or through PATH" "$(head -c 46 "$tmp/plant-wow-admin.err")"
# A slash-less $0 could source a wow-common.sh a branch under review planted in the cwd.
mkdir "$tmp/plant-wow-review-mint"
cp "$root_dir/scripts/identity/wow-review-mint" "$tmp/plant-wow-review-mint/wow-review-mint"
printf '#!/bin/sh\ntouch "%s/marker"\necho reached\n' "$tmp/plant-wow-review-mint" >"$tmp/plant-wow-review-mint/wow-common.sh"
sl_rc=0
sl_out="$(cd "$tmp/plant-wow-review-mint" && sh wow-review-mint 2>"$tmp/plant-wow-review-mint.err")" || sl_rc=$?
assert_eq "wow-review-mint slash-less refuses (stdout)" "" "$sl_out"
assert_eq "wow-review-mint slash-less refuses (rc)" 2 "$sl_rc"
assert_eq "wow-review-mint slash-less never reached the planted wow-common.sh" no "$([ -e "$tmp/plant-wow-review-mint/marker" ] && echo yes || echo no)"
assert_eq "wow-review-mint slash-less stderr names the tool" "wow-review-mint: must be run by path or through PATH" "$(head -c 52 "$tmp/plant-wow-review-mint.err")"

# A bare command name found through PATH runs with $0 as the full path, so the copy beside the tool is sourced, never the cwd's.
for pt in wow-admin wow-review-mint; do
  mkdir "$tmp/pathbin-$pt" "$tmp/pathcwd-$pt"
  cp "$root_dir/scripts/identity/$pt" "$tmp/pathbin-$pt/$pt"
  chmod +x "$tmp/pathbin-$pt/$pt"
  printf '#!/bin/sh\ntouch "%s/marker"\nexit 0\n' "$tmp/pathbin-$pt" >"$tmp/pathbin-$pt/wow-common.sh"
  printf '#!/bin/sh\ntouch "%s/marker"\nexit 0\n' "$tmp/pathcwd-$pt" >"$tmp/pathcwd-$pt/wow-common.sh"
  pr_rc=0
  (cd "$tmp/pathcwd-$pt" && PATH="$tmp/pathbin-$pt:$PATH" sh -c "$pt" >/dev/null 2>"$tmp/pathcwd-$pt.err") || pr_rc=$?
  assert_eq "$pt through PATH exits 0" 0 "$pr_rc"
  assert_eq "$pt through PATH: no must-be-run-by-path refusal" 0 "$(grep -c 'must be run by path' "$tmp/pathcwd-$pt.err" || true)"
  assert_eq "$pt through PATH sourced the wow-common.sh beside the tool" yes "$([ -e "$tmp/pathbin-$pt/marker" ] && echo yes || echo no)"
  assert_eq "$pt through PATH never sourced the cwd's wow-common.sh" no "$([ -e "$tmp/pathcwd-$pt/marker" ] && echo yes || echo no)"
done

HOME=$real_home; export HOME

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "identity-wow: $pass_count assertions passed"
