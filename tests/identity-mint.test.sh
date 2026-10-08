#!/bin/sh
# Fixture tests for scripts/identity/mint.sh (issue #373).
#
# A stub `curl` stands in for GitHub: it records its argv and the config piped to it on stdin,
# prints a canned body and status on stdout as `curl -w` would (or exits non-zero, as on a
# transport failure). A throwaway RSA key signs the
# JWT, and the public half verifies it, so the signature is checked and not just its shape.
#
#   success          token + expires_at land in --out (two lines), mode 600
#   request          POST to /app/installations/<id>/access_tokens with the repositories and
#                    permissions subset, and the JWT in the config, never in argv
#   jwt              RS256, verifies against the public key, iss = client id, exp - iat <= 10 min
#   secrecy          neither the token nor the JWT reaches stdout, stderr or argv
#   API failure      non-201, and a 201 with no token: exit 1, no --out file left behind
#   usage            missing/odd arguments exit 2 before curl is ever called
#
# Permitted toolset: POSIX sh, its standard utilities, openssl and jq (the script's own
# dependencies).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/identity/mint.sh"

for tool in openssl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP - $tool not on PATH; identity-mint fixtures not run" >&2
    exit 0
  fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"

openssl genrsa -out "$tmp/key.pem" 2048 >/dev/null 2>&1
openssl rsa -in "$tmp/key.pem" -pubout -out "$tmp/pub.pem" >/dev/null 2>&1

cat >"$tmp/bin/curl" <<'STUB'
#!/bin/sh
# Records what mint.sh sent; answers on stdout as curl -w does: body, newline, status.
printf '%s\n' "$@" >"$STUB_DIR/argv"
cat >"$STUB_DIR/stdin"
echo called >>"$STUB_DIR/calls"
sed -n 's/^data-binary = "\(.*\)"$/\1/p' "$STUB_DIR/stdin" | sed 's/\\"/"/g' >"$STUB_DIR/sent-body"
[ -z "${STUB_MKDIR:-}" ] || mkdir "$STUB_MKDIR" # --out turns into a directory mid-request
[ "${STUB_RC:-0}" -eq 0 ] || exit "$STUB_RC" # a transport failure: curl exits non-zero, prints nothing
printf '%s\n%s' "$STUB_BODY" "$STUB_STATUS"
STUB
chmod +x "$tmp/bin/curl"

fail=0
pass_count=0

ok() { pass_count=$((pass_count + 1)); }
bad() { echo "FAIL: $1 -- $2" >&2; fail=1; }

assert_eq() {
  if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$2', got '$3'"; fi
}

assert_contains() { # desc haystack needle
  case "$2" in *"$3"*) ok ;; *) bad "$1" "'$3' not found in: $2" ;; esac
}

assert_absent() { # desc haystack needle
  case "$2" in *"$3"*) bad "$1" "'$3' leaked into: $2" ;; *) ok ;; esac
}

TOKEN=ghs_faketoken0123456789
EXPIRES=2026-10-09T01:00:00Z
GOOD_BODY="{\"token\":\"$TOKEN\",\"expires_at\":\"$EXPIRES\"}"

# run <status> <body> <args...> -> sets rc, so, se; resets the stub's recordings
run() {
  STUB_STATUS=$1 STUB_BODY=$2
  shift 2
  rm -f "$tmp/argv" "$tmp/stdin" "$tmp/calls"
  rc=0
  STUB_DIR=$tmp STUB_STATUS=$STUB_STATUS STUB_BODY=$STUB_BODY STUB_RC=${STUB_RC:-0} \
  STUB_MKDIR=${STUB_MKDIR:-} PATH="$tmp/bin:$PATH" \
    sh "$script" "$@" >"$tmp/so" 2>"$tmp/se" || rc=$?
  so=$(cat "$tmp/so")
  se=$(cat "$tmp/se")
}

good_args() {
  echo --client-id Iv23liTestClient0001 --installation-id 678 --key "$tmp/key.pem" \
       --repos claude-workbench,devcontainers --perms contents=write,pull_requests=write \
       --out "$tmp/token"
}

# --- success ---------------------------------------------------------------------------------
rm -f "$tmp/token"
t_before=$(date +%s)
# shellcheck disable=SC2046
run 201 "$GOOD_BODY" $(good_args)
t_after=$(date +%s)
assert_eq "success exits 0" 0 "$rc"
assert_eq "token file line 1" "$TOKEN" "$(sed -n 1p "$tmp/token")"
assert_eq "token file line 2" "$EXPIRES" "$(sed -n 2p "$tmp/token")"
assert_eq "token file has exactly two lines" 2 "$(wc -l <"$tmp/token" | tr -d ' ')"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ok ;; # NTFS has no POSIX modes; the umask is still set in the script
  *) assert_eq "token file mode" "-rw-------" "$(ls -l "$tmp/token" | cut -c1-10)" ;;
esac
# the staged temp file is renamed away, not left beside the output
assert_eq "no staging file left behind" "" "$(ls -A "$tmp" | grep '^\.mint\.' || true)"

# --- request shape ---------------------------------------------------------------------------
cfg=$(cat "$tmp/stdin")
assert_contains "POSTs to the installation's token endpoint" "$cfg" \
  'url = "https://api.github.com/app/installations/678/access_tokens"'
assert_contains "request is POST" "$cfg" 'request = "POST"'
assert_contains "sends a bearer header" "$cfg" 'header = "Authorization: Bearer '
assert_contains "body is inline in the config" "$cfg" 'data-binary = "{'
assert_absent "config names no file for curl to open (native Windows curl cannot read /tmp)" "$cfg" '"@'
assert_absent "curl is given no -o file" "$(cat "$tmp/argv")" '-o'
assert_eq "curl ignores ambient ~/.curlrc (-q first)" "-q" "$(sed -n 1p "$tmp/argv")"
# The exact line: the stub's greedy capture would still yield valid JSON if the quote
# escaping were dropped, but real curl would then read the value as a bare `{`.
assert_contains "body line is quote-escaped for curl's config parser" "$cfg" \
  'data-binary = "{\"repositories\":[\"claude-workbench\",\"devcontainers\"],\"permissions\":{\"contents\":\"write\",\"pull_requests\":\"write\"}}"'
assert_eq "body repositories" '["claude-workbench","devcontainers"]' \
  "$(jq -c .repositories "$tmp/sent-body")"
assert_eq "body permissions" '{"contents":"write","pull_requests":"write"}' \
  "$(jq -c .permissions "$tmp/sent-body")"

# --- JWT -------------------------------------------------------------------------------------
jwt=$(sed -n 's/^header = "Authorization: Bearer \(.*\)"$/\1/p' "$tmp/stdin")
h=${jwt%%.*}; rest=${jwt#*.}; c=${rest%%.*}; s=${rest#*.}

unb64() { # base64url on stdin -> bytes on stdout
  v=$(cat | tr '_-' '/+')
  case $((${#v} % 4)) in 2) v="$v==" ;; 3) v="$v=" ;; esac
  printf '%s' "$v" | openssl base64 -d -A
}

assert_eq "JWT header" '{"alg":"RS256","typ":"JWT"}' "$(printf '%s' "$h" | unb64)"
claims=$(printf '%s' "$c" | unb64)
assert_eq "JWT iss is the client id" Iv23liTestClient0001 "$(printf '%s' "$claims" | jq -r .iss)"
iat=$(printf '%s' "$claims" | jq '.iat')
exp=$(printf '%s' "$claims" | jq '.exp')
# GitHub's rules: iat not in the future, exp at most ten minutes ahead of the request.
if [ "$iat" -le "$t_after" ] && [ "$exp" -le "$((t_after + 600))" ] && [ "$exp" -gt "$t_before" ]
then ok; else bad "JWT lifetime" "iat=$iat exp=$exp, run was between $t_before and $t_after"; fi
printf '%s' "$s" | unb64 >"$tmp/sig.bin"
if printf '%s.%s' "$h" "$c" | openssl dgst -sha256 -verify "$tmp/pub.pem" -signature "$tmp/sig.bin" >/dev/null 2>&1
then ok; else bad "JWT signature" "does not verify against the public key"; fi

# --- secrecy ---------------------------------------------------------------------------------
argv=$(cat "$tmp/argv")
assert_absent "JWT not in curl argv" "$argv" "$jwt"
assert_absent "token not in stdout" "$so" "$TOKEN"
assert_absent "token not in stderr" "$se" "$TOKEN"
assert_absent "JWT not in stdout" "$so" "$jwt"
assert_absent "JWT not in stderr" "$se" "$jwt"

# --- API failures leave nothing behind -------------------------------------------------------
rm -f "$tmp/token"
# shellcheck disable=SC2046
run 401 '{"message":"A JSON web token could not be decoded"}' $(good_args)
assert_eq "401 exits 1" 1 "$rc"
assert_contains "401 reports the status" "$se" "HTTP 401"
assert_contains "401 reports the message" "$se" "could not be decoded"
[ ! -e "$tmp/token" ] && ok || bad "401 leaves no out file" "$tmp/token exists"

# shellcheck disable=SC2046
run 201 '{"expires_at":"2026-10-09T01:00:00Z"}' $(good_args)
assert_eq "201 without a token exits 1" 1 "$rc"
[ ! -e "$tmp/token" ] && ok || bad "tokenless 201 leaves no out file" "$tmp/token exists"

# shellcheck disable=SC2046
run 201 'not json' $(good_args)
assert_eq "non-JSON 201 exits 1" 1 "$rc"
[ ! -e "$tmp/token" ] && ok || bad "non-JSON 201 leaves no out file" "$tmp/token exists"

# A response is never trusted to shape a credential file the host may later source.
# shellcheck disable=SC2046
run 201 '{"token":"x\nrm -rf ~","expires_at":"2026-10-09T01:00:00Z"}' $(good_args)
assert_eq "non-token-shaped token exits 1" 1 "$rc"
[ ! -e "$tmp/token" ] && ok || bad "non-token-shaped token leaves no out file" "$tmp/token exists"

# shellcheck disable=SC2046
run 201 '{"token":"ghs_ok","expires_at":"soon; reboot"}' $(good_args)
assert_eq "non-timestamp expires_at exits 1" 1 "$rc"
[ ! -e "$tmp/token" ] && ok || bad "non-timestamp expires_at leaves no out file" "$tmp/token exists"

# Terminal escapes in an error message are stripped before they reach stderr. The escape is
# sent as a JSON \u001b so jq decodes it; a raw ESC byte is invalid JSON and would be dropped
# before the stripping ever mattered.
# shellcheck disable=SC2046
run 500 '{"message":"bad\u001b[31mred"}' $(good_args)
assert_contains "the message still reaches stderr" "$se" "red"
assert_absent "control characters stripped from the API message" "$se" "$(printf '\033')"

# The status is split from the last line only: multi-line replies must not move it.
# shellcheck disable=SC2046
run 201 "{
  \"token\": \"$TOKEN\",
  \"expires_at\": \"$EXPIRES\"
}" $(good_args)
assert_eq "pretty-printed 201 exits 0" 0 "$rc"
assert_eq "pretty-printed 201 token lands in the file" "$TOKEN" "$(sed -n 1p "$tmp/token")"
rm -f "$tmp/token"
# shellcheck disable=SC2046
run 401 '{
  "message": "Bad credentials",
  "status": "401"
}' $(good_args)
assert_eq "pretty-printed 401 exits 1" 1 "$rc"
assert_contains "pretty-printed 401 reports status and message" "$se" "HTTP 401: Bad credentials"

# If --out becomes a directory during the round-trip, mv would drop the token inside it.
mkdir "$tmp/racedir"
STUB_MKDIR=$tmp/racedir/token
run 201 "$GOOD_BODY" --client-id 1 --installation-id 2 --key "$tmp/key.pem" --repos a \
  --perms contents=read --out "$tmp/racedir/token"
unset STUB_MKDIR
assert_eq "out turning into a directory exits 1" 1 "$rc"
assert_contains "out race is reported" "$se" "became a directory"
assert_eq "nothing left inside the raced directory" "" "$(ls -A "$tmp/racedir/token")"
assert_eq "no staging file left beside it" "" "$(ls -A "$tmp/racedir" | grep '^\.mint\.' || true)"

# A transport failure (curl exits non-zero) is a failed mint, not a parsed reply.
STUB_RC=7
# shellcheck disable=SC2046
run 000 '' $(good_args)
unset STUB_RC
assert_eq "curl failure exits 1" 1 "$rc"
assert_contains "curl failure is reported" "$se" "curl failed"
[ ! -e "$tmp/token" ] && ok || bad "curl failure leaves no out file" "$tmp/token exists"

# A failed mint leaves the previous token in place rather than a partial one.
printf 'old\n2026-01-01T00:00:00Z\n' >"$tmp/token"
# shellcheck disable=SC2046
run 401 '{"message":"nope"}' $(good_args)
assert_eq "failed mint keeps the old out file" "old" "$(sed -n 1p "$tmp/token")"
rm -f "$tmp/token"

# --- usage messages read cleanly (no stray exit code appended) -------------------------------
run 201 "$GOOD_BODY" --client-id "a b" --installation-id 1 --key "$tmp/key.pem" --repos a --perms contents=read --out "$tmp/token"
assert_eq "usage message has no stray exit code" "mint.sh: --client-id must be the App's Client ID (letters and digits)" "$se"

# --- a glob in --repos is a bad name, never expanded against the working directory -----------
mkdir "$tmp/globdir" && : >"$tmp/globdir/other-repo"
(cd "$tmp/globdir" && STUB_DIR=$tmp STUB_STATUS=201 STUB_BODY=$GOOD_BODY PATH="$tmp/bin:$PATH" \
  sh "$script" --client-id 1 --installation-id 2 --key "$tmp/key.pem" --repos '*' \
    --perms contents=read --out "$tmp/token" >/dev/null 2>&1) && globrc=0 || globrc=$?
assert_eq "--repos '*' exits 2" 2 "$globrc"

# --- usage errors exit 2 and never call curl -------------------------------------------------
usage_case() { # desc <args...>
  desc=$1; shift
  run 201 "$GOOD_BODY" "$@"
  assert_eq "$desc exits 2" 2 "$rc"
  [ ! -e "$tmp/calls" ] && ok || bad "$desc never calls curl" "curl was called"
}

base="--client-id Iv23liTestClient0001 --installation-id 678 --key $tmp/key.pem --out $tmp/token"
# shellcheck disable=SC2086
{
  usage_case "no repos"            $base --perms contents=write
  usage_case "no perms"            $base --repos a
  usage_case "empty repos"         $base --repos "" --perms contents=write
  usage_case "repo with a slash"   $base --repos "o/r" --perms contents=write
  usage_case "repo with a quote"   $base --repos 'a"b' --perms contents=write
  usage_case "perm without level"  $base --repos a --perms contents
  usage_case "perm bad level"      $base --repos a --perms contents=owner
  usage_case "perm bad name"       $base --repos a --perms 'Contents=write'
  usage_case "client id with a symbol" --client-id "Iv23li-x" --installation-id 678 --key "$tmp/key.pem" --repos a --perms contents=read --out "$tmp/token"
  usage_case "client id with a non-ASCII letter" --client-id "Iv23liCaf$(printf '\303\251')" --installation-id 678 --key "$tmp/key.pem" --repos a --perms contents=read --out "$tmp/token"
  usage_case "non-numeric install" --client-id 1 --installation-id x --key "$tmp/key.pem" --repos a --perms contents=read --out "$tmp/token"
  usage_case "missing key file"    --client-id 1 --installation-id 2 --key "$tmp/nope.pem" --repos a --perms contents=read --out "$tmp/token"
  usage_case "--api-url is gone"   $base --repos a --perms contents=read --api-url https://attacker.example
  usage_case "unknown flag"        $base --repos a --perms contents=read --bogus x
  usage_case "dangling flag"       $base --repos a --perms contents=read --out
  usage_case "duplicate perm"      $base --repos a --perms contents=read,contents=admin
  usage_case "out is a directory"  --client-id 1 --installation-id 2 --key "$tmp/key.pem" --repos a --perms contents=read --out "$tmp"
  usage_case "out dir is missing"  --client-id 1 --installation-id 2 --key "$tmp/key.pem" --repos a --perms contents=read --out "$tmp/nodir/token"
}

if [ "$fail" -eq 0 ]; then
  echo "identity-mint: $pass_count assertions passed"
else
  echo "identity-mint: FAILED" >&2
  exit 1
fi
