#!/bin/sh
# Fixture tests for scripts/identity/wow-admin and wow-review-mint (issue #374).
#
# A stub `curl` stands in for GitHub (as in identity-mint.test.sh): it records the config piped to
# it and answers with a canned body and status. A throwaway RSA key, encrypted for the admin App
# and plain for the reviewer App, lives under a throwaway $WOW_HOME laid out like the real one (apps.json); $WOW_TTY points at a file
# holding the passphrase.
#
#   admin mint       token + expires_at land in tokens/<repo>/admin-token; request carries the
#                    admin installation, the one repo and the default (or given) permissions
#   passphrase       wrong or empty: exit 1, curl never called, no token file
#   live token       refused while one is on file (curl uncalled); an expired one is replaced
#   revoke           DELETE /installation/token with the token as bearer; 204 and 401 remove the
#                    file, other statuses keep it, no file is an error
#   reviewer         reviewer installation, fixed permissions, written under review-tokens/ and never tokens/, --out or the default path
#   reviewer shapes  post (default) unchanged and non-strict; --read sends the six reads (--also adds a
#                    second repo to the same request, either flag order); --file sends issues write;
#                    both are strict (one extra permission, or a missing repo, exits 1 with no token
#                    file); every usage rule exits 2 before curl with a message naming it
#   broker.json      a bare-name entry writes only the bare file; an owner/name entry writes the same
#                    two lines to tokens/<owner>/<repo>/ too (one curl call), and either copy alone
#                    being live refuses a second mint; revoke sends one DELETE per distinct token and
#                    removes each copy on its own answer; a dangling bare symlink or a failed second
#                    write refuses/leaves a state --revoke clears; each malformed broker.json shape
#                    makes mint and revoke exit 1 before curl, with nothing written (#1340)
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
echo called >>"$STUB_DIR/calls"
printf '%s\n%s' "$STUB_BODY" "$STUB_STATUS"
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

tokfile="$home/tokens/repo1/admin-token"

# run <cmd...>: runs with the stub curl first on PATH; sets rc, out (stdout+stderr).
run() {
  rm -f "$tmp/stub/calls"
  rc=0
  out=$(PATH="$tmp/bin:$PATH" "$@" 2>&1) || rc=$?
}
calls() { if [ -f "$tmp/stub/calls" ]; then wc -l <"$tmp/stub/calls" | tr -d ' '; else echo 0; fi; }
sent() { sed -n 's/^data-binary = "\(.*\)"$/\1/p' "$tmp/stub/stdin" | sed 's/\\"/"/g'; }

# --- admin mint
WOW_TTY="$tmp/tty-good" run sh "$admin" repo1
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
WOW_TTY="$tmp/tty-good" run sh "$admin" repo1
assert_eq "live token rc" 1 "$rc"
assert_eq "live token curl uncalled" 0 "$(calls)"
printf '%s\n2000-01-01T00:00:00Z\n' "$TOKEN" >"$tokfile"
WOW_TTY="$tmp/tty-good" run sh "$admin" repo1 --perms contents=read
assert_eq "expired token replaced rc" 0 "$rc"
assert_eq "custom perms" '{"contents":"read"}' "$(sent | jq -c .permissions)"

# --- passphrase failures leave nothing behind
rm -f "$tokfile"
WOW_TTY="$tmp/tty-bad" run sh "$admin" repo1
assert_eq "wrong passphrase rc" 1 "$rc"
assert_eq "wrong passphrase curl uncalled" 0 "$(calls)"
[ ! -e "$tokfile" ] && ok || bad "wrong passphrase" "token file exists"
WOW_TTY="$tmp/tty-empty" run sh "$admin" repo1
assert_eq "empty passphrase rc" 1 "$rc"
assert_eq "empty passphrase stopped before unlocking" 1 "$(printf '%s' "$out" | grep -c 'empty passphrase' || true)"
assert_eq "empty passphrase curl uncalled" 0 "$(calls)"
[ ! -e "$tokfile" ] && ok || bad "empty passphrase" "token file exists"
WOW_TTY="$tmp/nonexistent" run sh "$admin" repo1
assert_eq "no terminal rc" 1 "$rc"
assert_eq "no terminal curl uncalled" 0 "$(calls)"

# --- revoke
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
STUB_BODY= STUB_STATUS=204 run sh "$admin" repo1 --revoke
assert_eq "revoke rc" 0 "$rc"
assert_eq "revoke method" 1 "$(grep -c '^request = "DELETE"' "$tmp/stub/stdin")"
assert_eq "revoke url" 1 "$(grep -c '^url = "https://api.github.com/installation/token"' "$tmp/stub/stdin")"
assert_eq "revoke bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $TOKEN\"" "$tmp/stub/stdin")"
assert_eq "revoke token not in argv" 0 "$(grep -c "$TOKEN" "$tmp/stub/argv" || true)"
[ ! -e "$tokfile" ] && ok || bad "revoke 204" "token file kept"

printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
STUB_BODY='{"message":"Bad credentials"}' STUB_STATUS=401 run sh "$admin" repo1 --revoke
assert_eq "revoke 401 rc" 0 "$rc"
[ ! -e "$tokfile" ] && ok || bad "revoke 401" "token file kept"

printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
STUB_BODY='{"message":"boom"}' STUB_STATUS=500 run sh "$admin" repo1 --revoke
assert_eq "revoke 500 rc" 1 "$rc"
[ -e "$tokfile" ] && ok || bad "revoke 500" "token file removed"

rm -f "$tokfile"
run sh "$admin" repo1 --revoke
assert_eq "revoke without a token rc" 1 "$rc"
assert_eq "revoke without a token curl uncalled" 0 "$(calls)"

# --- reviewer
rtok="$home/review-tokens/repo1/reviewer-token"
run sh "$review" repo1
assert_eq "reviewer rc" 0 "$rc"
[ ! -e "$home/tokens/repo1/reviewer-token" ] && ok || bad "reviewer token location" "written under the container-mounted tokens/"
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
assert_eq "new shapes wrote nothing under tokens/" "" "$(ls -A "$home/tokens/repo1" | grep -v '^admin-token$' || true)"
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
STUB_BODY= STUB_STATUS=204 run sh "$admin" repo1 --revoke
assert_eq "revoke JWT-format token rc" 0 "$rc"
assert_eq "revoke JWT-format bearer" 1 "$(grep -c "^header = \"Authorization: Bearer $JWT_TOKEN\"" "$tmp/stub/stdin")"
[ ! -e "$tokfile" ] && ok || bad "revoke JWT-format token" "token file kept"

# --- guards: malformed token file, concurrent run, a key that is not encrypted
printf 'bad token!\n' >"$tokfile"
WOW_TTY="$tmp/tty-good" run sh "$admin" repo1
assert_eq "malformed token file blocks mint rc" 1 "$rc"
assert_eq "malformed token file blocks mint curl uncalled" 0 "$(calls)"
run sh "$admin" repo1 --revoke
assert_eq "malformed token file revoke rc" 1 "$rc"
assert_eq "malformed token file revoke curl uncalled" 0 "$(calls)"
[ -e "$tokfile" ] && ok || bad "malformed token file" "removed"
rm -f "$tokfile"
mkdir "$home/tokens/repo1/.lock"
WOW_TTY="$tmp/tty-good" run sh "$admin" repo1
assert_eq "held lock rc" 1 "$rc"
assert_eq "held lock curl uncalled" 0 "$(calls)"
[ -d "$home/tokens/repo1/.lock" ] && ok || bad "held lock" "removed by the run that did not take it"
rmdir "$home/tokens/repo1/.lock"
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$tokfile"
mkdir "$home/tokens/repo1/.lock"
run sh "$admin" repo1 --revoke
assert_eq "revoke under a held lock rc" 1 "$rc"
assert_eq "revoke under a held lock curl uncalled" 0 "$(calls)"
[ -e "$tokfile" ] && ok || bad "revoke under a held lock" "token file removed"
rmdir "$home/tokens/repo1/.lock"
rm -f "$tokfile"
run sh "$admin" freshrepo --revoke
assert_eq "revoke of an unknown repo rc" 1 "$rc"
[ ! -e "$home/tokens/freshrepo" ] && ok || bad "revoke of an unknown repo" "created a tokens/ directory"
mv "$home/admin.enc.pem" "$tmp/admin.enc.bak"
cp "$tmp/key.pem" "$home/admin.enc.pem"
WOW_TTY="$tmp/tty-bad" run sh "$admin" repo1
assert_eq "plaintext admin key rc" 1 "$rc"
assert_eq "plaintext admin key curl uncalled" 0 "$(calls)"
mv "$tmp/admin.enc.bak" "$home/admin.enc.pem"
assert_eq "no unlocked key left after any admin run" 0 "$(ls -A "$home" | grep -c '^\.unlock' || true)"
[ ! -e "$home/tokens/repo1/.lock" ] && ok || bad "lock" "left behind after the runs"

# --- usage and config, all before any curl call
for args in "" "--revoke" "a b" "../x" "-x" "a/b" "repo1 --bogus" "repo1 --perms" "repo1 --revoke --perms contents=read" "repo1 --revoke --perms administration=write,contents=write,pull_requests=write"; do
  # shellcheck disable=SC2086
  run sh "$admin" $args
  assert_eq "admin usage rc [$args]" 2 "$rc"
  assert_eq "admin usage curl uncalled [$args]" 0 "$(calls)"
done
for args in "" "a b" ".." "repo1 --out" "repo1 --bogus"; do
  # shellcheck disable=SC2086
  run sh "$review" $args
  assert_eq "review usage rc [$args]" 2 "$rc"
  assert_eq "review usage curl uncalled [$args]" 0 "$(calls)"
done
assert_eq "usage curl uncalled" 0 "$(calls)"

# --- broker.json: the owner-qualified second copy (#1340)
TOKEN2=ghs_ZyXwVu9876543210ZyXwVu9876543210ZyXwVu
# newhome <name> [broker.json text]: a throwaway $WOW_HOME with the same apps.json and keys
newhome() {
  h="$tmp/h-$1"
  mkdir "$h"
  cp "$home/apps.json" "$home/admin.enc.pem" "$home/review.pem" "$h/"
  if [ $# -ge 2 ]; then printf '%s' "$2" >"$h/broker.json"; fi
  printf '%s' "$h"
}
mint_in() { WOW_HOME="$1" WOW_TTY="$tmp/tty-good" run sh "$admin" repo1; }
revoke_in() { WOW_HOME="$1" run sh "$admin" repo1 --revoke; }
only_admin() { assert_eq "$1" admin-token "$(ls -A "$2")"; }

# a bare-name entry: today's layout, no other directory under tokens/
h=$(newhome bare '{"repos": ["repo1"]}')
mint_in "$h"
assert_eq "bare entry mint rc" 0 "$rc"
assert_eq "bare entry token" "$TOKEN" "$(sed -n 1p "$h/tokens/repo1/admin-token")"
assert_eq "bare entry tokens/ holds only repo1" repo1 "$(ls -A "$h/tokens")"

# an owner/name entry: one curl call, the same two lines in both directories
h=$(newhome own '{"repos": ["acme/repo1", "acme/other"]}')
mint_in "$h"
assert_eq "owner mint rc" 0 "$rc"
assert_eq "owner mint one curl call" 1 "$(calls)"
assert_eq "owner mint one repo requested" '["repo1"]' "$(sent | jq -c .repositories)"
assert_eq "owner mint copies identical" "$(cat "$h/tokens/acme/repo1/admin-token")" "$(cat "$h/tokens/repo1/admin-token")"
assert_eq "owner mint token line" "$TOKEN" "$(sed -n 1p "$h/tokens/acme/repo1/admin-token")"
assert_eq "owner mint expiry line" "$EXPIRES" "$(sed -n 2p "$h/tokens/repo1/admin-token")"
assert_eq "owner mint output names the owner file" 1 "$(printf '%s' "$out" | grep -c "$h/tokens/acme/repo1/admin-token" || true)"
assert_eq "owner mint output names the bare file" 1 "$(printf '%s' "$out" | grep -c "$h/tokens/repo1/admin-token" || true)"
assert_eq "owner mint no token in output" 0 "$(printf '%s' "$out" | grep -c "$TOKEN" || true)"
assert_eq "owner mint no passphrase in output" 0 "$(printf '%s' "$out" | grep -c 'correct-horse' || true)"
assert_eq "owner mint no token in argv" 0 "$(grep -c "$TOKEN" "$tmp/stub/argv" || true)"
only_admin "owner mint owner dir holds only admin-token" "$h/tokens/acme/repo1"
only_admin "owner mint bare dir holds only admin-token" "$h/tokens/repo1"

# a live token in either copy alone refuses a second mint
mint_in "$h"
assert_eq "both live rc" 1 "$rc"
assert_eq "both live curl uncalled" 0 "$(calls)"
rm -f "$h/tokens/repo1/admin-token"
mint_in "$h"
assert_eq "owner copy alone live rc" 1 "$rc"
assert_eq "owner copy alone live curl uncalled" 0 "$(calls)"
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$h/tokens/repo1/admin-token"
rm -f "$h/tokens/acme/repo1/admin-token"
mint_in "$h"
assert_eq "bare copy alone live rc" 1 "$rc"
assert_eq "bare copy alone live curl uncalled" 0 "$(calls)"

# revoke of identical copies: one DELETE, both removed (204 and 401)
for st in 204 401; do
  printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$h/tokens/repo1/admin-token"
  printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$h/tokens/acme/repo1/admin-token"
  STUB_BODY= STUB_STATUS=$st revoke_in "$h"
  assert_eq "revoke identical $st rc" 0 "$rc"
  assert_eq "revoke identical $st one DELETE" 1 "$(calls)"
  [ ! -e "$h/tokens/repo1/admin-token" ] && [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke identical $st" "a copy was kept"
done

# differing copies: two DELETEs; a 500 keeps the copies and exits 1
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$h/tokens/repo1/admin-token"
printf '%s\n%s\n' "$TOKEN2" "$EXPIRES" >"$h/tokens/acme/repo1/admin-token"
STUB_BODY= STUB_STATUS=500 revoke_in "$h"
assert_eq "revoke differing 500 rc" 1 "$rc"
[ -e "$h/tokens/repo1/admin-token" ] && [ -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke differing 500" "a copy was removed"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke differing rc" 0 "$rc"
assert_eq "revoke differing two DELETEs" 2 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke differing" "a copy was kept"

# a bare-only copy is removed
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$h/tokens/repo1/admin-token"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke bare-only rc" 0 "$rc"
assert_eq "revoke bare-only one DELETE" 1 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && ok || bad "revoke bare-only" "copy kept"

# a malformed copy stops revoke before curl and keeps every file
printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$h/tokens/repo1/admin-token"
printf 'junk\n' >"$h/tokens/acme/repo1/admin-token"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke malformed copy rc" 1 "$rc"
assert_eq "revoke malformed copy curl uncalled" 0 "$(calls)"
[ -e "$h/tokens/repo1/admin-token" ] && [ -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke malformed copy" "a file was removed"

# revoke with nothing on file creates no directory
h=$(newhome nothing '{"repos": ["acme/repo1"]}')
revoke_in "$h"
assert_eq "revoke nothing rc" 1 "$rc"
[ ! -e "$h/tokens" ] && ok || bad "revoke nothing" "created tokens/"

# a dangling symlink at the bare path: refused before curl, nothing written through it
h=$(newhome link '{"repos": ["acme/repo1"]}')
mkdir -p "$h/tokens/repo1"
ln -s "$tmp/linktarget" "$h/tokens/repo1/admin-token"
mint_in "$h"
assert_eq "symlink rc" 1 "$rc"
assert_eq "symlink curl uncalled" 0 "$(calls)"
[ ! -e "$tmp/linktarget" ] && [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "symlink" "something was written"

# the second write fails: exit 1 naming the owner file, no staged file, --revoke clears both
mkdir "$tmp/mvbin"
real_mv=$(command -v mv)
cat >"$tmp/mvbin/mv" <<'STUB'
#!/bin/sh
for a; do last=$a; done
[ "$last" != "$STUB_FAIL_MV" ] || exit 1
exec "$REAL_MV" "$@"
STUB
chmod +x "$tmp/mvbin/mv"
REAL_MV=$real_mv; export REAL_MV
h=$(newhome mvfail '{"repos": ["acme/repo1"]}')
mkdir -p "$h/tokens/repo1"
printf '%s\n2000-01-01T00:00:00Z\n' "$TOKEN2" >"$h/tokens/repo1/admin-token"
STUB_FAIL_MV="$h/tokens/repo1/admin-token" PATH="$tmp/mvbin:$PATH" mint_in "$h"
assert_eq "second write fails rc" 1 "$rc"
assert_eq "second write fails names the owner file" 1 "$(printf '%s' "$out" | grep -c "$h/tokens/acme/repo1/admin-token" || true)"
assert_eq "second write fails names --revoke" 1 "$(printf '%s' "$out" | grep -c -e '--revoke' || true)"
assert_eq "second write fails leaves no .mint file (bare)" 0 "$(ls -A "$h/tokens/repo1" | grep -c '^\.mint' || true)"
assert_eq "second write fails leaves no .mint file (owner)" 0 "$(ls -A "$h/tokens/acme/repo1" | grep -c '^\.mint' || true)"
STUB_BODY= STUB_STATUS=204 revoke_in "$h"
assert_eq "revoke after failed second write rc" 0 "$rc"
assert_eq "revoke after failed second write two DELETEs" 2 "$(calls)"
[ ! -e "$h/tokens/repo1/admin-token" ] && [ ! -e "$h/tokens/acme/repo1/admin-token" ] && ok || bad "revoke after failed second write" "a copy was kept"

# every malformed broker.json refuses mint and revoke before curl: nothing written, no lock left
badcase() {
  name=$1 text=$2
  h=$(newhome "bad-$name" "$text")
  mint_in "$h"
  assert_eq "broker.json $name: mint rc" 1 "$rc"
  assert_eq "broker.json $name: mint curl uncalled" 0 "$(calls)"
  assert_eq "broker.json $name: mint names broker.json" 1 "$(printf '%s' "$out" | grep -c 'broker.json' || true)"
  revoke_in "$h"
  assert_eq "broker.json $name: revoke rc" 1 "$rc"
  assert_eq "broker.json $name: revoke curl uncalled" 0 "$(calls)"
  [ ! -e "$h/tokens" ] && ok || bad "broker.json $name" "created tokens/"
  # with a token on file, revoke must refuse on broker.json itself, not on "nothing on file"
  mkdir -p "$h/tokens/repo1"
  printf '%s\n%s\n' "$TOKEN" "$EXPIRES" >"$h/tokens/repo1/admin-token"
  STUB_BODY= STUB_STATUS=204 revoke_in "$h"
  assert_eq "broker.json $name: revoke with a token rc" 1 "$rc"
  assert_eq "broker.json $name: revoke with a token curl uncalled" 0 "$(calls)"
  assert_eq "broker.json $name: revoke with a token names broker.json" 1 "$(printf '%s' "$out" | grep -c 'broker.json' || true)"
  [ -e "$h/tokens/repo1/admin-token" ] && ok || bad "broker.json $name" "revoke removed the token"
}
badcase notjson 'not json'
badcase emptyrepos '{"repos": []}'
badcase nonstring '{"repos": ["repo1", 5]}'
badcase twoslashes '{"repos": ["a/b/repo1"]}'
badcase dotstart '{"repos": [".acme/repo1"]}'
badcase trailingnewline '{"repos": ["acme/repo1\n"]}'
badcase casevariant '{"repos": ["acme/repo1", "acme/REPO1"]}'
badcase twovalues '{"repos": ["acme/repo1"]} {"repos": []}'
badcase ownerisname '{"repos": ["repo1", "repo1/other"]}'

empty="$tmp/empty"
mkdir "$empty"
WOW_HOME="$empty" WOW_TTY="$tmp/tty-good" run sh "$admin" repo1
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
WOW_HOME="$oldkeys" WOW_TTY="$tmp/tty-good" run sh "$admin" repo1
assert_eq "admin old-keys config rc" 1 "$rc"
assert_eq "admin old-keys config curl uncalled" 0 "$(calls)"
assert_eq "admin old-keys config names the role keys" 1 "$(printf '%s' "$out" | grep -c 'keyed by role' || true)"
WOW_HOME="$oldkeys" run sh "$review" repo1
assert_eq "review old-keys config rc" 1 "$rc"
assert_eq "review old-keys config curl uncalled" 0 "$(calls)"
assert_eq "review old-keys config names the role keys" 1 "$(printf '%s' "$out" | grep -c 'keyed by role' || true)"

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "identity-wow: $pass_count assertions passed"
