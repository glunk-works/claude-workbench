#!/bin/sh
# Fixture tests for scripts/loop/inject.py's pure decisions (issue #345): which request targets
# are forwarded, and how the session's headers become the upstream's. No socket is opened.
#
# Permitted toolset: sh and python3 (the proxy's own dependency; skips if absent).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
inject="$root_dir/scripts/loop/inject.py"
# A Windows python cannot open an MSYS /c/... path; cygpath -m gives it one (absent elsewhere).
inject="$(cygpath -m "$inject" 2>/dev/null || printf %s "$inject")"

py=
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null; then
    py=$c
    break
  fi
done
if [ -z "$py" ]; then
  echo "SKIP - no python3 on PATH; loop-inject fixtures not run" >&2
  exit 0
fi

# MSYS rewrites a /v1/... argument into a Windows path; the fixtures pass paths as arguments.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

pass=0
fail=0

check() { # <expected> <method> <path>
  want=$1 method=$2 target=$3
  got=$("$py" "$inject" --check "$method" "$target")
  case "$got" in
    "$want"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL: --check $method $target: want '$want', got '$got'" >&2 ;;
  esac
}

# The only three requests inference needs: exact method and path, a query string allowed.
check allow POST /v1/messages
check allow POST '/v1/messages?beta=true'
check allow POST /v1/messages/count_tokens
check allow GET /v1/models
check allow POST '/v1/messages?x=../y'
# Same path, other method; other endpoints the key could reach (Files, Batches, Skills).
check deny GET /v1/messages
check deny DELETE /v1/messages
check deny PUT /v1/messages
check deny POST /v1/models
check deny POST /v1/files
check deny GET /v1/files/file_abc/content
check deny DELETE /v1/files/file_abc
check deny POST /v1/messages/batches
check deny POST /v1/skills
check deny POST /
check deny POST /etc/passwd
check deny POST /v1
check deny POST /v1/messages/
check deny POST /api/oauth/profile
check deny POST /v2/messages
check deny POST /v1/../etc/passwd
check deny POST /v1/messages/../files
check deny POST /v1/%2e%2e/etc
check deny POST /v1/%252e%252e/etc
check deny POST '/v1/messages%5c..'
check deny POST '/v1/messages b'
check deny POST '/v1/messages#x'
check deny POST 'http://evil.example/v1/messages'
check deny post /v1/messages
# Whitespace, fragment or backslash in the query is refused too.
check deny POST '/v1/messages?a=b c'
check deny POST '/v1/messages?a=b#c'


# upstream_headers: the session's auth is dropped and the real one set; hop-by-hop headers go.
out=$("$py" -B - "$inject" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("inject", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
sess = [("Host", "inject:8080"), ("Authorization", "Bearer dummy"), ("X-Api-Key", "dummy"),
        ("anthropic-version", "2023-06-01"), ("anthropic-beta", "oauth-2025-04-20"),
        ("Content-Type", "application/json"), ("Content-Length", "5"), ("Connection", "keep-alive"),
        ("Accept-Encoding", "br"), ("Proxy-Authorization", "Basic eA=="), ("Transfer-Encoding", "chunked")]
def names(h): return sorted(k.lower() for k, _ in h)
oauth = m.upstream_headers(sess, "CLAUDE_CODE_OAUTH_TOKEN", "REAL")
key = m.upstream_headers(sess, "ANTHROPIC_API_KEY", "REAL")
print("oauth-names", ",".join(names(oauth)))
print("oauth-auth", [v for k, v in oauth if k.lower() == "authorization"])
print("key-names", ",".join(names(key)))
print("key-key", [v for k, v in key if k.lower() == "x-api-key"])
print("dummy-leaked", any("dummy" in v for _, v in oauth + key))
PY
)
expect() { # <line>
  if printf '%s\n' "$out" | grep -qxF -- "$1"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: header fixture, wanted line: $1" >&2; fi
}
expect "oauth-names anthropic-beta,anthropic-version,authorization,content-type"
expect "oauth-auth ['Bearer REAL']"
expect "key-names anthropic-beta,anthropic-version,content-type,x-api-key"
expect "key-key ['REAL']"
expect "dummy-leaked False"

echo "loop-inject: $pass passed, $fail failed"
[ "$fail" = 0 ]
