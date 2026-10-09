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

empty="$tmp/empty"
mkdir "$empty"
WOW_HOME="$empty" WOW_TTY="$tmp/tty-good" run sh "$admin" repo1
assert_eq "admin missing config rc" 1 "$rc"
assert_eq "admin missing config curl uncalled" 0 "$(calls)"
WOW_HOME="$empty" run sh "$review" repo1
assert_eq "review missing config rc" 1 "$rc"
assert_eq "missing config curl uncalled" 0 "$(calls)"

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "identity-wow: $pass_count assertions passed"
