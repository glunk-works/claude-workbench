#!/bin/sh
# Fixture tests for scripts/loop/proxy.py's allow/deny decision (issue #317).
#
# `--check` runs the pure decision with no network I/O, so nothing here resolves a name or
# opens a socket. The DNS-rebinding refusal (an allowlisted name resolving to a non-global
# address, proxy.py's resolve_global) needs a resolver and no test covers it yet; the attack
# pass (#318) is where it belongs.
#
# Permitted toolset: sh (plus `env -u`) and python3 (the proxy's own dependency; skips if absent).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
proxy="$root_dir/scripts/loop/proxy.py"

py=
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null; then
    py=$c
    break
  fi
done
if [ -z "$py" ]; then
  echo "SKIP - no python3 on PATH; loop-proxy fixtures not run" >&2
  exit 0
fi

pass=0
fail=0

check() { # <expected> <target> [allow-hosts]
  want=$1 target=$2
  if [ "$#" -ge 3 ]; then
    got=$(LOOP_ALLOW_HOSTS=$3 "$py" "$proxy" --check "$target")
  else
    got=$(env -u LOOP_ALLOW_HOSTS "$py" "$proxy" --check "$target")
  fi
  case "$got" in
    "$want"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL: --check $target: want '$want', got '$got'" >&2 ;;
  esac
}

# The four default hosts on 443, in any case, with or without a trailing dot.
check allow api.anthropic.com
check allow claude.ai:443
check allow claude.com
check allow platform.claude.com
check allow API.Anthropic.COM
check allow api.anthropic.com.

# Not on the default list: GitHub (off the coder's list), the update hosts, anything else.
check "deny not on the allowlist" github.com
check "deny not on the allowlist" api.github.com
check "deny not on the allowlist" downloads.claude.ai
check "deny not on the allowlist" example.com

# Port: only 443.
check "deny port is not 443" api.anthropic.com:80
check "deny port is not 443" api.anthropic.com:22
check "deny port is not 443" api.anthropic.com:4430

# IP literals, in every spelling, refused even when the allowlist names them.
check "deny ip literal" 1.2.3.4
check "deny ip literal" 1.2.3.4:443 1.2.3.4
check "deny ip literal" 127.0.0.1:443
check "deny ip literal" 2130706433:443
check "deny ip literal" 0x7f.1:443
check "deny ip literal" 127.1:443
check "deny ip literal" "[::1]:443"
check "deny ip literal" "[2606:4700::1111]:443"
check "deny ip literal" 169.254.169.254:443

# Internal names, refused even when allowlisted.
check "deny internal name" host.docker.internal
check "deny internal name" host.docker.internal:443 host.docker.internal
check "deny internal name" gateway.docker.internal
check "deny internal name" localhost
check "deny internal name" evil.localhost:443 evil.localhost
check "deny internal name" loop-proxy.internal:443 loop-proxy.internal

# Malformed targets.
check "deny empty host" :443
check "deny not a dns name" "api.anthropic.com/x:443" "api.anthropic.com/x"
check "deny not a dns name" "a b.example.com:443" "a b.example.com"
check "deny not a dns name" singlelabel:443 singlelabel

# A per-repo widening works for exactly the names it lists.
check allow pypi.org:443 "api.anthropic.com,pypi.org"
check "deny not on the allowlist" files.pythonhosted.org:443 "api.anthropic.com,pypi.org"

echo "loop-proxy: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
