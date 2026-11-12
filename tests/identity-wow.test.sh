#!/bin/sh
# Fixture tests for scripts/identity/wow-admin and wow-review-mint (issue #374).
#
# A stub `curl` stands in for GitHub (as in identity-mint.test.sh): it records the config piped to
# it and answers with a canned body and status. A throwaway RSA key, encrypted for the admin App
# and plain for the reviewer App, lives under a throwaway $WOW_HOME laid out like the real one (apps.json); $WOW_TTY points at a file
# holding the passphrase.
#
#   admin mint       token + expires_at land in tokens/<owner>/<name>/admin-token and nowhere else; request
#                    carries the admin installation, the one repo and the default (or given) permissions
#   passphrase       wrong or empty: exit 1, curl never called, no token file
#   live token       refused while one is on file (curl uncalled); an expired one is replaced
#   revoke           DELETE /installation/token with the token as bearer; 204 and 401 remove the
#                    file, other statuses keep it, no file is an error
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
#                    admin-token for the repo, found by a scan that runs under set -f; a live leftover
#                    tokens/<name>/admin-token blocks too; revoke reads no broker.json, takes a token under
#                    any owner by naming it, takes a leftover bare copy and an owner-only copy, and for two
#                    differing tokens removes what each answer allows (204 then 500: leftover gone, owner
#                    kept, exit 1) (#1340, #1348)
#   owner check      a mint reads the admin installation's account login once, after the unlock, and refuses
#                    (exit 1, no POST, no tokens/ entry, no unlock directory) an owner that differs from it
#                    ignoring case, a failed read (HTTP 500) and a login of the wrong shape; ACME/repo1
#                    mints into tokens/ACME; --revoke makes no read; acme/.hidden and acme/repo1. are usage
#                    errors for mint and revoke (#1425, #1428)
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
st=$STUB_STATUS
if [ -s "$STUB_DIR/statuses" ]; then
  st=$(sed -n 1p "$STUB_DIR/statuses")
  sed 1d "$STUB_DIR/statuses" >"$STUB_DIR/statuses.new"
  mv "$STUB_DIR/statuses.new" "$STUB_DIR/statuses"
fi
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

tokfile="$home/tokens/acme/repo1/admin-token"

# run <cmd...>: runs with the stub curl first on PATH; sets rc, out (stdout+stderr).
run() {
  rm -f "$tmp/stub/calls" "$tmp/stub/acct"
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
  '{"administration":"write","contents":"write","pull_requests":"write"}' "$(sent | jq -c .permissions)"
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

# --- revoke
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
STUB_BODY= STUB_STATUS=204 run sh "$admin" acme/repo1 --revoke
assert_eq "revoke rc" 0 "$rc"
assert_eq "revoke method" 1 "$(grep -c '^request = "DELETE"' "$tmp/stub/stdin")"
assert_eq "revoke url" 1 "$(grep -c '^url = "https://api.github.com/installation/token"' "$tmp/stub/stdin")"
assert_eq "revoke bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $TOKEN\"" "$tmp/stub/stdin")"
assert_eq "revoke token not in argv" 0 "$(grep -c "$TOKEN" "$tmp/stub/argv" || true)"
[ ! -e "$tokfile" ] && ok || bad "revoke 204" "token file kept"

printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
STUB_BODY='{"message":"Bad credentials"}' STUB_STATUS=401 run sh "$admin" acme/repo1 --revoke
assert_eq "revoke 401 rc" 0 "$rc"
[ ! -e "$tokfile" ] && ok || bad "revoke 401" "token file kept"

printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
STUB_BODY='{"message":"boom"}' STUB_STATUS=500 run sh "$admin" acme/repo1 --revoke
assert_eq "revoke 500 rc" 1 "$rc"
[ -e "$tokfile" ] && ok || bad "revoke 500" "token file removed"

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
assert_eq "new shapes wrote nothing under tokens/" "" "$(ls -A "$home/tokens/acme/repo1" | grep -v '^admin-token$' || true)"
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
STUB_BODY= STUB_STATUS=204 run sh "$admin" acme/repo1 --revoke
assert_eq "revoke JWT-format token rc" 0 "$rc"
assert_eq "revoke JWT-format bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $JWT_TOKEN\"" "$tmp/stub/stdin")"
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
  [ ! -e "$1/tokens" ] && ok || bad "$2" "created tokens/"
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
  assert_eq "mint [$case_name] token line" "$TOKEN" "$(sed -n 1p "$h/tokens/acme/repo1/admin-token")"
  assert_eq "mint [$case_name] expiry line" "$EXPIRES" "$(sed -n 2p "$h/tokens/acme/repo1/admin-token")"
  assert_eq "mint [$case_name] tokens/ holds only the owner directory" acme "$(ls -A "$h/tokens")"
  assert_eq "mint [$case_name] owner directory holds only the repo" repo1 "$(ls -A "$h/tokens/acme")"
  only_admin() { assert_eq "$1" admin-token "$(ls -A "$2")"; }
  only_admin "mint [$case_name] repo directory holds only admin-token" "$h/tokens/acme/repo1"
  assert_eq "mint [$case_name] output names the owner file" 1 "$(printf '%s' "$out" | grep -c "$h/tokens/acme/repo1/admin-token" || true)"
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
assert_eq "acme/acme: token written" "$TOKEN" "$(sed -n 1p "$h/tokens/acme/acme/admin-token")"
assert_eq "acme/acme: tokens/acme holds only the repo directory" acme "$(ls -A "$h/tokens/acme")"

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
  put_tok "$h/tokens/acme/repo1/admin-token"
  STUB_BODY= STUB_STATUS=204 revoke_in "$h"
  assert_eq "revoke [$1] rc" 0 "$rc"
  assert_eq "revoke [$1] one DELETE" 1 "$(calls)"
  [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke [$1]" "token kept"
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
  put_tok "$h/tokens/acme/repo1/admin-token"
  STUB_BODY= STUB_STATUS=204 revoke_in "$h"
  assert_eq "broker.json $name: revoke rc" 0 "$rc"
  assert_eq "broker.json $name: revoke one DELETE" 1 "$(calls)"
  [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "broker.json $name" "revoke kept the token"
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
# owner/name are the proof that it expanded tokens/*/repo1/admin-token.
for bj in none present; do
  if [ "$bj" = none ]; then h=$(newhome "oo-$bj"); else h=$(newhome "oo-$bj" '{"repos": ["acme/repo1"]}'); fi
  put_tok "$h/tokens/beta/repo1/admin-token"
  put_tok "$h/tokens/gamma/unrelated/admin-token"
  mint_in "$h"
  assert_eq "other owner live [$bj] rc" 1 "$rc"
  assert_eq "other owner live [$bj] curl uncalled" 0 "$(calls)"
  has_msg "other owner live [$bj] names owner/name" "beta/repo1 --revoke"
  [ ! -e "$h/tokens/acme" ] && ok || bad "other owner live [$bj]" "created tokens/acme"
  assert_eq "other owner live [$bj] no unlocked key left" 0 "$(ls -A "$h" | grep -c '^\.unlock' || true)"
  # revoking the owner it names clears the block, and the mint then goes through
  STUB_BODY= STUB_STATUS=204 revoke_in "$h" beta/repo1
  assert_eq "other owner live [$bj] revoke by naming that owner rc" 0 "$rc"
  [ ! -e "$h/tokens/beta/repo1/admin-token" ] && ok || bad "other owner live [$bj]" "revoke kept the token"
  mint_in "$h"
  assert_eq "other owner live [$bj] mint after the revoke rc" 0 "$rc"
done
# a token for another repo under another owner, an expired one for this repo and the repo's own
# directory under a different owner's name do not block; an unreadable expiry does
h=$(newhome oo-other-repo)
put_tok "$h/tokens/beta/repo2/admin-token"
mint_in "$h"
assert_eq "another owner's token for another repo does not block: rc" 0 "$rc"
h=$(newhome oo-expired)
put_tok "$h/tokens/beta/repo1/admin-token" "$TOKEN" 2000-01-01T00:00:00Z
mint_in "$h"
assert_eq "another owner's expired token does not block: rc" 0 "$rc"
h=$(newhome oo-unreadable)
mkdir -p "$h/tokens/beta/repo1"; printf 'junk\n' >"$h/tokens/beta/repo1/admin-token"
mint_in "$h"
assert_eq "another owner's unreadable token blocks: rc" 1 "$rc"
assert_eq "another owner's unreadable token blocks: curl uncalled" 0 "$(calls)"
has_msg "another owner's unreadable token names owner/name" "beta/repo1 --revoke"
# a second live owner among several still blocks (the scan reads every match, not the first)
h=$(newhome oo-several)
put_tok "$h/tokens/aaa/repo1/admin-token" "$TOKEN" 2000-01-01T00:00:00Z
put_tok "$h/tokens/zzz/repo1/admin-token"
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
[ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "leftover bare copy live" "wrote the owner file"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke of a leftover bare copy rc" 0 "$rc"
assert_eq "revoke of a leftover bare copy one DELETE" 1 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && ok || bad "revoke of a leftover bare copy" "copy kept"
[ -d "$h/tokens/repo1" ] && ok || bad "revoke of a leftover bare copy" "removed the leftover directory itself"
[ ! -e "$h/.admin-lock.repo1" ] && ok || bad "revoke of a leftover bare copy" "left a lock"

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
put_tok "$h/tokens/typo/repo1/admin-token"
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
[ ! -e "$h/tokens/typo" ] && ok || bad "leftover live, typo owner" "created tokens/typo"

# revoke of identical copies: one DELETE, both removed (204 and 401)
h=$(newhome revoke-copies)
for st in 204 401; do
  put_tok "$h/tokens/repo1/admin-token"
  put_tok "$h/tokens/acme/repo1/admin-token"
  STUB_BODY= STUB_STATUS=$st revoke_in "$h"
  assert_eq "revoke identical $st rc" 0 "$rc"
  assert_eq "revoke identical $st one DELETE" 1 "$(calls)"
  [ ! -e "$h/tokens/repo1/admin-token" ] && [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke identical $st" "a copy was kept"
done

# #1348 finding 3: only the owner copy on file
h=$(newhome owner-only)
put_tok "$h/tokens/acme/repo1/admin-token"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke owner copy only rc" 0 "$rc"
assert_eq "revoke owner copy only one DELETE" 1 "$(calls)"
[ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke owner copy only" "copy kept"
[ ! -e "$h/tokens/repo1" ] && ok || bad "revoke owner copy only" "created tokens/repo1"

h=$(newhome differing)
# #1348 finding 3: two differing tokens, the first DELETE answers 204 and the second 500. The
# leftover copy is revoked first: it is removed, the owner copy is kept, the exit is 1.
put_tok "$h/tokens/repo1/admin-token" "$TOKEN"
put_tok "$h/tokens/acme/repo1/admin-token" "$TOKEN2"
printf '204\n500\n' >"$tmp/stub/statuses"
STUB_BODY= revoke_in "$h"
rm -f "$tmp/stub/statuses"
assert_eq "revoke differing 204 then 500 rc" 1 "$rc"
assert_eq "revoke differing 204 then 500 two DELETEs" 2 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && ok || bad "revoke differing 204 then 500" "the leftover copy was kept"
[ -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke differing 204 then 500" "the owner copy was removed"
assert_eq "revoke differing 204 then 500 kept the owner token" "$TOKEN2" "$(sed -n 1p "$h/tokens/acme/repo1/admin-token")"
# all 500: both kept
put_tok "$h/tokens/repo1/admin-token" "$TOKEN"
STUB_BODY= STUB_STATUS=500 revoke_in "$h"
assert_eq "revoke differing 500 rc" 1 "$rc"
[ -e "$h/tokens/repo1/admin-token" ] && [ -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke differing 500" "a copy was removed"
# both answer 204: both removed, two DELETEs
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke differing rc" 0 "$rc"
assert_eq "revoke differing two DELETEs" 2 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke differing" "a copy was kept"

# a malformed copy stops revoke before curl and keeps every file
put_tok "$h/tokens/repo1/admin-token"
mkdir -p "$h/tokens/acme/repo1"; printf 'junk\n' >"$h/tokens/acme/repo1/admin-token"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke malformed copy rc" 1 "$rc"
assert_eq "revoke malformed copy curl uncalled" 0 "$(calls)"
[ -e "$h/tokens/repo1/admin-token" ] && [ -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke malformed copy" "a file was removed"

# revoke with nothing on file creates no directory
h=$(newhome nothing '{"repos": ["acme/repo1"]}')
revoke_in "$h"
assert_eq "revoke nothing rc" 1 "$rc"
untouched "$h" "revoke nothing"

# a dangling symlink at the owner path: refused before curl, nothing written through it
h=$(newhome link)
mkdir -p "$h/tokens/acme/repo1"
ln -s "$tmp/linktarget" "$h/tokens/acme/repo1/admin-token"
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
assert_eq "owner case token written under the typed owner" "$TOKEN" "$(sed -n 1p "$h/tokens/ACME/repo1/admin-token")"
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
put_tok "$h/tokens/typo/repo1/admin-token"
STUB_BODY= STUB_STATUS=204 revoke_in "$h" typo/repo1
assert_eq "revoke under a mistyped owner rc" 0 "$rc"
assert_eq "revoke makes no account read" 0 "$(acct_reads)"
assert_eq "revoke makes one DELETE" 1 "$(calls)"

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "identity-wow: $pass_count assertions passed"
