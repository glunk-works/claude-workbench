#!/usr/bin/env bash
# One scripted build-and-launch of the whole plan v9 § 7.3 loop container (issue #317).
#
#   verify base provenance -> build the loop image -> create the isolated internal network ->
#   start the allowlisting proxy and the credential-injecting proxy -> seed a work volume -> preflight, from outside and from
#   inside -> run the coder launch line on a trivial task -> check the result -> clean up
#
# This is the assembled container, not the driver: the clone, the post-exit checks, the push
# and the PR belong to the driver-core issues. It refuses to run the session if any preflight
# check fails (plan v9 § 7.3, "The driver's preflight").
#
# Needs on PATH: docker, gh, jq, bash. Configuration, all environment:
#   LOOP_CREDENTIAL_FILE     (required) host file whose first line is the credential; it is piped
#                            to the stdin of the credential-injecting proxy container (inject.py)
#                            and nowhere else: the session container never holds it (#345), and it
#                            is never mounted, never in `docker inspect`
#   LOOP_CREDENTIAL_ENV      CLAUDE_CODE_OAUTH_TOKEN (default) or ANTHROPIC_API_KEY
#   LOOP_VERIFY_GH_TOKEN     token for `gh attestation verify` on the base image, when the
#                            ambient gh identity cannot read that package; used for that one
#                            command only, never passed on to docker
#   LOOP_MODEL               default sonnet           LOOP_MAX_TURNS   default 8
#   LOOP_MAX_BUDGET_USD      default 1                LOOP_ALLOW_HOSTS replaces the proxy list
#                            (comma-separated; name api.anthropic.com and the other defaults too)
#   LOOP_ID                  default <epoch>-<pid>; names every resource this run creates
#   LOOP_PREFLIGHT_ONLY=1    stop after the preflight (no credential, no model call)
#
# On this host, run it under Git Bash: the MSYS path conversion is switched off below, since it
# rewrites `/tmp` in a docker argument into a Windows path.
set -euo pipefail
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

here="$(cd "$(dirname "$0")" && pwd)"
id="${LOOP_ID:-$(date +%s)-$$}"
cred_env="${LOOP_CREDENTIAL_ENV:-CLAUDE_CODE_OAUTH_TOKEN}"
model="${LOOP_MODEL:-sonnet}"
max_turns="${LOOP_MAX_TURNS:-8}"
max_budget="${LOOP_MAX_BUDGET_USD:-1}"
preflight_only="${LOOP_PREFLIGHT_ONLY:-}"

net="wow-loop-net-$id"
ext="wow-loop-ext-$id"
proxy="wow-loop-proxy-$id"
inj="wow-loop-inject-$id"
vol="wow-loop-work-$id"
sess="wow-loop-session-$id"
out_dir="$(mktemp -d)"

fail() { echo "launch: $*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }
ok() { echo "  ok   $*"; }
bad() { echo "  FAIL $*" >&2; failed=1; }

cleanup() {
  docker rm -f "$sess" "$proxy" "$inj" >/dev/null 2>&1 || true
  docker network rm "$net" "$ext" >/dev/null 2>&1 || true
  docker volume rm -f "$vol" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for c in docker gh jq; do command -v "$c" >/dev/null 2>&1 || fail "$c is not on PATH"; done
case "$cred_env" in CLAUDE_CODE_OAUTH_TOKEN | ANTHROPIC_API_KEY) ;; *) fail "LOOP_CREDENTIAL_ENV must be CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY" ;; esac
# The session gets a placeholder in the credential variable; the injecting proxy swaps in the real one.
dummy="loop-dummy-credential-not-real"
cred="preflight-only-not-a-credential"
if [ -z "$preflight_only" ]; then
  [ -n "${LOOP_CREDENTIAL_FILE:-}" ] || fail "LOOP_CREDENTIAL_FILE is required (or LOOP_PREFLIGHT_ONLY=1)"
  [ -s "$LOOP_CREDENTIAL_FILE" ] || fail "LOOP_CREDENTIAL_FILE is empty or unreadable"
  cred="$(head -n 1 "$LOOP_CREDENTIAL_FILE" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"   # the same strip inject.py's .strip() does
  [ -n "$cred" ] || fail "LOOP_CREDENTIAL_FILE has no credential on its first line"
fi

# ---------------------------------------------------------------------------------------------
step "Base image provenance"
base_ref="$(sed -n 's/^ARG BASE_IMAGE=//p' "$here/Dockerfile" | tr -d '\r')"   # a CRLF checkout must not reach the digest check
claude_version="$(sed -n 's/^ARG CLAUDE_VERSION=//p' "$here/Dockerfile" | tr -d '\r')"
case "$base_ref" in
  ghcr.io/603-identity/devcontainer-base:*@sha256:????????????????????????????????????????????????????????????????) ;;
  *) fail "Dockerfile BASE_IMAGE is not <tag>@<digest> of ghcr.io/603-identity/devcontainer-base: $base_ref" ;;
esac
base_digest="${base_ref##*@}"
# The same verification the devcontainers consumers' own check runs (its build.yml).
GH_TOKEN="${LOOP_VERIFY_GH_TOKEN:-${GH_TOKEN:-}}" gh attestation verify \
  "oci://ghcr.io/603-identity/devcontainer-base@$base_digest" \
  --repo 603-Identity/devcontainers \
  --cert-identity "https://github.com/603-Identity/devcontainers/.github/workflows/build.yml@refs/heads/main" \
  --cert-oidc-issuer https://token.actions.githubusercontent.com \
  --source-ref refs/heads/main --deny-self-hosted-runners >/dev/null 2>&1 \
  || fail "gh attestation verify failed for $base_digest; refusing to build on an unverified base"
ok "base $base_digest verified against 603-Identity/devcontainers' build provenance"

# ---------------------------------------------------------------------------------------------
step "Build the loop image"
image="wow-loop:$claude_version"
ctx="$(cygpath -m "$here" 2>/dev/null || printf %s "$here")"   # a Windows docker needs a Windows path
docker build -q -t "$image" "$ctx" >/dev/null || fail "docker build failed"
ok "built $image"

# ---------------------------------------------------------------------------------------------
step "Network and proxy"
docker network create --internal \
  -o com.docker.network.bridge.gateway_mode_ipv4=isolated \
  "$net" >/dev/null
ok "network $net: internal, gateway_mode_ipv4=isolated"
# The proxy's way out is its own network, not the default bridge, so no other container on the
# host's default bridge can tunnel through it.
docker network create "$ext" >/dev/null

harden=(--read-only --cap-drop ALL --security-opt no-new-privileges --pids-limit 512)
docker run -d --name "$proxy" --network "$net" "${harden[@]}" --memory 256m \
  --tmpfs /tmp:rw,nosuid,size=16m \
  -e "LOOP_ALLOW_HOSTS=${LOOP_ALLOW_HOSTS:-api.anthropic.com,claude.ai,claude.com,platform.claude.com}" \
  --entrypoint python3 "$image" /opt/loop/proxy.py >/dev/null
docker network connect "$ext" "$proxy"
sleep 2
[ "$(docker inspect -f '{{.State.Running}}' "$proxy")" = true ] || { docker logs "$proxy" >&2; fail "proxy is not running"; }
proxy_ip="$(docker inspect -f "{{(index .NetworkSettings.Networks \"$net\").IPAddress}}" "$proxy")"
[ -n "$proxy_ip" ] || fail "no proxy address on $net"
ok "proxy $proxy up at $proxy_ip on $net, also on the external network $ext"

# The credential-injecting proxy: its own container, so the credential sits in a process the
# session cannot reach. It reads the credential from stdin once (docker start -ai below);
# preflight-only mode hands it a placeholder, and no probe sends a request upstream.
docker create -i --name "$inj" --network "$net" "${harden[@]}" --memory 256m \
  --tmpfs /tmp:rw,nosuid,size=16m -e "LOOP_CREDENTIAL_ENV=$cred_env" \
  --entrypoint python3 "$image" /opt/loop/inject.py >/dev/null
docker network connect "$ext" "$inj"
printf '%s\n' "$cred" | docker start -ai "$inj" >/dev/null 2>&1 &   # a pipe from a builtin: never a host temp file or a command line
for _ in 1 2 3 4 5 6 7 8 9 10; do
  docker logs "$inj" 2>&1 | grep -q '^inject up' && break
  sleep 1
done
docker logs "$inj" 2>&1 | grep -q '^inject up' || { docker logs "$inj" >&2; fail "injecting proxy did not start"; }
ok "injecting proxy $inj up on $net and $ext"

# The session container is described once, in this array, and used both for the real run and
# for the probe containers, so a probe sees exactly the network and hardening the session gets.
session_args=(
  --network "$net" "${harden[@]}" --memory 2g
  --tmpfs /tmp:rw,nosuid,size=512m
  --tmpfs /home/app:rw,nosuid,uid=1000,gid=1000,mode=0700,size=256m
  --tmpfs /run/loop:rw,nosuid,uid=1000,gid=1000,mode=0700,size=64m
  -v "$vol:/work"
  -e HOME=/home/app -e CLAUDE_CONFIG_DIR=/run/loop/config
  -e "HTTPS_PROXY=http://$proxy:3128" -e "HTTP_PROXY=http://$proxy:3128" -e "NO_PROXY=$inj" -e "no_proxy=$inj"
  -e "ANTHROPIC_BASE_URL=http://$inj:8080" -e "$cred_env=$dummy"
  -e GIT_CONFIG_GLOBAL=/dev/null -e GIT_CONFIG_NOSYSTEM=1
  -e GIT_AUTHOR_NAME=loop-session -e GIT_AUTHOR_EMAIL=loop-session@invalid
  -e GIT_COMMITTER_NAME=loop-session -e GIT_COMMITTER_EMAIL=loop-session@invalid
)

# ---------------------------------------------------------------------------------------------
step "Work volume"
docker volume create "$vol" >/dev/null
# A new volume is root-owned; hand it to uid 1000, then seed a one-commit repo as that user.
docker run --rm --network none --read-only --cap-drop ALL --cap-add CHOWN --security-opt no-new-privileges \
  --user 0:0 -v "$vol:/work" --entrypoint sh "$image" -c 'chown 1000:1000 /work'
docker run --rm --network none "${harden[@]}" --tmpfs /home/app:rw,uid=1000,gid=1000,mode=0700 \
  -v "$vol:/work" -e HOME=/home/app \
  -e GIT_AUTHOR_NAME=loop-seed -e GIT_AUTHOR_EMAIL=loop-seed@invalid \
  -e GIT_COMMITTER_NAME=loop-seed -e GIT_COMMITTER_EMAIL=loop-seed@invalid \
  --entrypoint sh "$image" -c 'git init -q -b main . && echo seed > README && git add README && git commit -q -m "chore: seed"'
ok "seeded $vol with a one-commit repository"

# ---------------------------------------------------------------------------------------------
step "Preflight, from outside (docker inspect)"
failed=0
# docker create gives an inspectable container with the real session's flags, never started.
docker create --name "$sess" "${session_args[@]}" "$image" --version >/dev/null
sj="$(docker inspect "$sess")"
user="$(jq -r '.[0].Config.User' <<<"$sj")"
case "$user" in "" | root | 0 | 0:*) bad "User is root ('$user')" ;; *) ok "User is non-root ($user)" ;; esac
[ "$(jq -r '.[0].HostConfig.ReadonlyRootfs' <<<"$sj")" = true ] && ok "ReadonlyRootfs" || bad "root filesystem is writable"
[ "$(jq -r '.[0].HostConfig.NetworkMode' <<<"$sj")" = "$net" ] && ok "NetworkMode is $net" || bad "NetworkMode is not $net"
[ "$(jq -r '.[0].HostConfig.CapDrop | index("ALL") != null' <<<"$sj")" = true ] && ok "all capabilities dropped" || bad "capabilities not dropped"
[ "$(jq -r '.[0].HostConfig.Privileged' <<<"$sj")" = false ] && ok "not privileged" || bad "privileged"
# Bind mounts: none at all here; a named volume has Type volume. Refuse any bind, any /mnt or
# drive-letter source, anything naming a docker socket.
badmounts="$(jq -r '.[0].Mounts[] | select(.Type == "bind" or (.Source | test("^/mnt/|^/run/desktop/mnt|^[A-Za-z]:|docker\\.sock"))) | .Source' <<<"$sj")"
[ -z "$badmounts" ] && ok "no bind, /mnt, drive-letter or docker.sock mounts" || bad "forbidden mounts: $badmounts"
nj="$(docker network inspect "$net")"
[ "$(jq -r '.[0].EnableIPv6' <<<"$nj")" = false ] && ok "IPv6 is off on the network" || bad "IPv6 is enabled on the network (it needs the _ipv6 isolated twin)"
[ "$(jq -r '.[0].Internal' <<<"$nj")" = true ] && ok "network is Internal" || bad "network is not Internal"
[ "$(jq -r '.[0].Options["com.docker.network.bridge.gateway_mode_ipv4"]' <<<"$nj")" = isolated ] && ok "gateway_mode_ipv4=isolated" || bad "gateway_mode_ipv4 is not isolated"
# An isolated network has no gateway; Docker gives the subnet's .1 to a container, so no probe
# may derive one from the subnet.
[ "$(jq -r '[.[0].IPAM.Config[]? | select(.Gateway != null and .Gateway != "")] | length' <<<"$nj")" = 0 ] && ok "no Gateway in IPAM" || bad "IPAM has a Gateway"
[ "$(jq -r '.[0].Containers | length' <<<"$nj")" = 2 ] && ok "only the two proxies are on the network (the session is created, not started)" || bad "unexpected members on the network"
[ "$(docker inspect -f '{{.State.Running}}' "$proxy")" = true ] && ok "proxy running" || bad "proxy not running"
[ "$(docker inspect -f '{{.State.Running}}' "$inj")" = true ] && ok "injecting proxy running" || bad "injecting proxy not running"
# The credential is in no inspectable field of the session or the CONNECT proxy: not Env, not Cmd, not a label.
# The pattern goes in by process substitution and the haystack by file, so the credential is never on a command line.
printf '%s\n%s\n' "$sj" "$(docker inspect "$proxy" "$inj")" >"$out_dir/inspect.json"
if grep -qF -f <(printf '%s\n' "$cred") -- "$out_dir/inspect.json"; then bad "the credential appears in docker inspect output"; else ok "no credential in docker inspect of the session, the proxy or the injecting proxy"; fi
[ "$(jq -r '.[0].Config.Env | map(select(startswith("'"$cred_env"'="))) | .[0]' <<<"$sj")" = "$cred_env=$dummy" ] && ok "$cred_env in the session is the placeholder" || bad "$cred_env in the session is not the placeholder"

step "Preflight, from inside (probes by IP, in a throwaway container with the session's network and flags)"
# One python probe run in the session's netns. It prints one line per check.
probe_py='
import os, socket, sys
def reach(ip, port):
    s = socket.socket(); s.settimeout(3)
    try:
        s.connect((ip, port)); return True
    except ConnectionRefusedError:
        return True  # refused means routable with no listener: the address is reachable
    except OSError:
        return False  # timeout, ENETUNREACH, EHOSTUNREACH
    finally:
        s.close()
def connect_via_proxy(proxy, target):
    s = socket.socket(); s.settimeout(10)
    try:
        s.connect((proxy, 3128))
        s.sendall(("CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n" % (target, target)).encode())
        return s.recv(256).split(b"\r\n", 1)[0].decode("latin-1")
    except OSError as e:
        return "error %s" % e
    finally:
        s.close()
def inject_status(host, path):
    s = socket.socket(); s.settimeout(10)
    try:
        s.connect((host, 8080))
        s.sendall(("GET %s HTTP/1.0\r\nHost: x\r\n\r\n" % path).encode())
        return s.recv(256).split(b"\r\n", 1)[0].decode("latin-1")
    except OSError as e:
        return "error %s" % e
    finally:
        s.close()
proxy, vm_ips = sys.argv[1], sys.argv[2:]
print("env credential-looking:", sorted(k for k in os.environ if "TOKEN" in k or "KEY" in k or "CRED" in k))
for p in ("/etc/passwd", "/api/oauth/profile", "/v1/../etc/passwd"):
    print("inject", p, inject_status(os.environ["INJ_HOST"], p))
print("direct 1.1.1.1:443", "REACHED" if reach("1.1.1.1", 443) else "unreachable")
for ip in vm_ips:
    for port in (80, 443, 2375, 2376):
        print("direct %s:%d" % (ip, port), "REACHED" if reach(ip, port) else "unreachable")
try:
    socket.getaddrinfo("example.com", 443); print("dns example.com RESOLVED")
except OSError:
    print("dns example.com unresolvable")
for t in ("api.anthropic.com:443", "1.1.1.1:443", "host.docker.internal:443", "github.com:443", "api.anthropic.com:80"):
    print("proxy", t, connect_via_proxy(proxy, t))
'
# The VM's addresses: the default bridge's gateway, and host.docker.internal's address read from
# a non-internal network (the name does not resolve on internal networks).
vm_ips="$(docker network inspect bridge "$ext" | jq -r '.[].IPAM.Config[]?.Gateway // empty' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)"
hdi="$(docker run --rm --network bridge --cap-drop ALL --read-only --entrypoint getent "$image" ahostsv4 host.docker.internal 2>/dev/null | awk '{print $1; exit}')" || hdi=
[ -n "$hdi" ] || bad "host.docker.internal did not resolve on a non-internal network, so its address was not probed"
# shellcheck disable=SC2086
probe_out="$(docker run --rm -e "INJ_HOST=$inj" "${session_args[@]}" --entrypoint python3 "$image" -c "$probe_py" "$proxy_ip" $vm_ips $hdi)"
printf '%s\n' "$probe_out" | sed 's/^/       /'
grep -q 'REACHED' <<<"$probe_out" && bad "a direct connection left the isolated network" || ok "no direct connection to a public host, the VM's addresses (${vm_ips:-none} ${hdi:-no host.docker.internal address}) or the Docker API ports"
grep -q 'RESOLVED' <<<"$probe_out" && bad "an external name resolved on the internal network" || ok "no external DNS on the internal network"
grep -q '^proxy api.anthropic.com:443 HTTP/1.1 200' <<<"$probe_out" && ok "proxy tunnels api.anthropic.com:443" || bad "proxy does not tunnel api.anthropic.com:443"
for p in /etc/passwd /api/oauth/profile /v1/../etc/passwd; do
  grep -q "^inject $p HTTP/1.[01] 403" <<<"$probe_out" && ok "injecting proxy refuses $p" || bad "injecting proxy does not refuse $p"
done
grep -qF "env credential-looking: ['$cred_env']" <<<"$probe_out" && ok "the session's only credential-named variable is $cred_env (the placeholder)" || bad "unexpected credential-named variables in the session environment"
for t in 1.1.1.1:443 host.docker.internal:443 github.com:443 api.anthropic.com:80; do
  grep -q "^proxy $t HTTP/1.1 403" <<<"$probe_out" && ok "proxy refuses $t" || bad "proxy does not refuse $t"
done

[ "$failed" = 0 ] || fail "preflight failed; the session was not started"
[ -z "$preflight_only" ] || { echo; echo "launch: preflight passed (LOOP_PREFLIGHT_ONLY=1, no session run)"; exit 0; }

# ---------------------------------------------------------------------------------------------
step "Coder session (trivial task)"
prompt='Create a file named hello.txt in the current directory containing exactly the single word ok. Then commit it with the git_add tool (paths: hello.txt) and then the git_commit tool (message: feat: add hello.txt). Finally reply with the stop schema: status done, a one-line summary, and the commit message you used. If a tool is denied, reply with status blocked and say which one.'
# The § 7.3 coder launch line, minus two things (#345). Bash is out of --tools: no Bash allow rule
# exists, so every call would only cost a turn until a driver issue adds one. --strict-mcp-config is
# out: claude refuses it ("cannot use --strict-mcp-config when an enterprise MCP config is present")
# beside the managed-mcp.json that carries the loopgit server; allowManagedMcpServersOnly and the
# .mcp.json write denies hold that line instead. No Agent tool and no --plugin-dir: the coder spawns nothing and
# loads no plugin. --settings is inline JSON and carries no permission keys (the managed file
# holds every allow and deny rule).
settings='{"env":{"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":"1"}}'
schema="$(cat "$here/stop-schema.json")"
set +e
docker rm -f "$sess" >/dev/null 2>&1
docker run --name "$sess" "${session_args[@]}" "$image" \
  -p --restricted --tools "Read,Edit,Write,Glob,Grep" --add-dir /tmp \
  --model "$model" --max-turns "$max_turns" --max-budget-usd "$max_budget" --autocompact 100k \
  --permission-mode dontAsk --permission-prompts none \
  --settings "$settings" \
  --output-format json --json-schema "$schema" "$prompt" \
  >"$out_dir/result.json" 2>"$out_dir/stderr.txt"
rc=$?
set -e
echo "  claude exit code: $rc (result: $out_dir/result.json)"
[ "$rc" = 0 ] || { head -c 2000 "$out_dir/stderr.txt" >&2; fail "session exited $rc"; }

step "Result"
jq -e '.is_error == false' >/dev/null <"$out_dir/result.json" || fail "result is_error is not false"
jq -r '"  terminal_reason: \(.terminal_reason // "-")  turns: \(.num_turns // "-")  cost_usd: \(.total_cost_usd // "-")"' <"$out_dir/result.json"
jq -r '"  structured_output: \(.structured_output // "none" | tostring)"' <"$out_dir/result.json"
jq -e '.structured_output.status == "done"' >/dev/null <"$out_dir/result.json" || fail "stop schema status is not done"
# The driver runs no git in a clone the session touched, so read the tree, not the repo. The one
# git read below is the test's own, in a --network none, read-only, credential-free container, with
# fsmonitor and hooks overridden and no global or system config.
got="$(docker run --rm --network none --read-only --cap-drop ALL -v "$vol:/work:ro" --entrypoint cat "$image" /work/hello.txt)"
[ "$got" = ok ] || fail "hello.txt is '$got', expected 'ok'"
ok "hello.txt contains ok"
n="$(docker run --rm --network none --read-only --cap-drop ALL -v "$vol:/work:ro" -e GIT_CONFIG_GLOBAL=/dev/null -e GIT_CONFIG_NOSYSTEM=1 --entrypoint git "$image" -c safe.directory=/work -c core.fsmonitor=false -c core.hooksPath=/dev/null -C /work log -n 1 --format=%s)"
[ "$n" = "feat: add hello.txt" ] && ok "the git_commit tool made the commit" || bad "last commit is '$n'"
if grep -qF -f <(printf '%s\n' "$cred") -- "$out_dir/result.json" "$out_dir/stderr.txt"; then bad "the credential appears in the session's output"; else ok "no credential in the session's stdout or stderr"; fi
[ "$failed" = 0 ] || fail "post-run checks failed"
echo
echo "launch: the assembled container ran a trivial task"
