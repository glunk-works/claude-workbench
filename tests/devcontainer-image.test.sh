#!/bin/sh
# Static fixtures for the dev container (#1226, WB-D42): .devcontainer/Dockerfile and
# .devcontainer/devcontainer.json, which are the 603-Identity/devcontainers dev-App template
# plus this repo's four per-repo surfaces (the token mount, the FROM, the root-run pwsh extras
# (#893), and no appPort). Nothing the image sets is checked here: the flavour is reviewed in
# that repo and `verify / verify` compares these two files with its template.
#
#   Dockerfile          the template's shape (header of the Dockerfile): one `# syntax=` line, one
#                       plain tag-and-digest FROM first, a devcontainer-devapp image, no ARG before
#                       it, no COPY --from, RUN --mount from= or ONBUILD, ASCII, LF; no instruction
#                       naming the app user's home directory, no npm or node, nothing masking a
#                       failure; the instructions between the FROM and the last one, USER 1000:1000,
#                       are exactly USER 0 and the pinned pwsh block (version and hash ARGs, the
#                       ENV line, the install RUN pinned line by line, the version assertion)
#   devcontainer.json   read with grep, not jq, after its `//` comment lines are removed (as
#                       tests/ai-cursor-banner.test.sh does): the owner-qualified token mount, the
#                       .gitconfig.d source from USERPROFILE only, the -node_modules and -venv
#                       volumes, the start and attach commands, no containerEnv, remoteEnv or
#                       customizations key, no build args, no `devcontainer exec`
#   .devcontainer/      holds exactly Dockerfile and devcontainer.json
#
# Negative cases run the same file against scratch copies through DEVCONTAINER_DIR; the guard
# variable keeps the inner run from recursing.
#
# Permitted toolset: POSIX sh and its standard utilities (awk, grep, sed, mktemp), plus cmp for the
# pwsh install RUN. A fixture that needs a tool the runner lacks would skip loudly; none does
# beyond these (without cmp, only the pwsh install RUN check fails).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
dc="${DEVCONTAINER_DIR:-$root_dir/.devcontainer}"

for t in awk grep sed; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "SKIP - $t not on PATH; devcontainer-image fixtures not run" >&2
    exit 0
  fi
done

fail=0
ok() { printf 'ok - %s\n' "$1"; }
bad() { printf 'FAIL - %s\n' "$1" >&2; fail=1; }
check() { # check <label> <command...>
  l=$1; shift
  if "$@"; then ok "$l"; else bad "$l"; fi
}
assert_eq() { # assert_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected [$2], got [$3]"; fi
}

df="$dc/Dockerfile"
dj="$dc/devcontainer.json"
[ -f "$df" ] && [ -f "$dj" ] || { echo "FAIL - $df or $dj is missing" >&2; exit 1; }

dfcode=$(mktemp); want=$(mktemp); dfstrip=$(mktemp); djc=$(mktemp); got=$(mktemp)
trap 'rm -f "$dfcode" "$want" "$dfstrip" "$djc" "$got"' EXIT

# --- .devcontainer/: exactly two files -----------------------------------------------------
assert_eq ".devcontainer/ holds exactly Dockerfile and devcontainer.json" "Dockerfile devcontainer.json" "$(ls -A "$dc" | tr '\n' ' ' | sed 's/ $//')"

# --- Dockerfile: the template's shape ----------------------------------------------------
check "Dockerfile: the first line is a # syntax= directive" sh -c 'head -1 "$1" | grep -Eq "^# syntax=docker/dockerfile:[0-9.]+@sha256:[0-9a-f]{64}$"' _ "$df"
check "Dockerfile: line 2 is not a parser directive" test -z "$(sed -n 2p "$df" | grep -Ei '^#[[:space:]]*[a-z][a-z0-9]*[[:space:]]*=' || true)"
assert_eq "Dockerfile: exactly one # syntax= line" 1 "$(grep -ci '^#[[:space:]]*syntax[[:space:]]*=' "$df" || true)"
first_instr=$(grep -n '^[A-Za-z]' "$df" | head -1)
case $first_instr in *:FROM\ *) ok "Dockerfile: FROM is the first instruction (no ARG before it)" ;; *) bad "Dockerfile: the first instruction is [$first_instr]" ;; esac
assert_eq "Dockerfile: exactly one FROM" 1 "$(grep -Eci '^[[:space:]]*FROM[[:space:]]' "$df" || true)"
from=$(grep '^FROM ' "$df" | head -1)
case $from in *'$'*|*' AS '*|*--platform*) bad "Dockerfile: the FROM line is not plain: $from" ;; *) ok "Dockerfile: the FROM line is plain" ;; esac
printf '%s\n' "$from" | grep -Eq '^FROM [a-z0-9./-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$' && ok "Dockerfile: the FROM line is tag-and-digest pinned" || bad "Dockerfile: FROM is not tag-and-digest pinned: $from"
printf '%s\n' "$from" | grep -Eq '^FROM ghcr\.io/603-identity/devcontainer-devapp:' && ok "Dockerfile: the FROM is a devcontainer-devapp image" || bad "Dockerfile: FROM is not a ghcr.io/603-identity/devcontainer-devapp image: $from"
assert_eq "Dockerfile: no ARG before FROM" 0 "$(sed -n '1,/^FROM /p' "$df" | grep -Eci '^[[:space:]]*ARG[[:space:]]' || true)"
check "Dockerfile: no COPY --from, RUN --mount from= or ONBUILD" test -z "$(grep -v '^#' "$df" | grep -Ei -e 'COPY +(--[^ ]+ +)*--from' -e '--mount[^ ]*from=' -e '^[[:space:]]*ONBUILD' || true)"
check "Dockerfile: ASCII only" test -z "$(LC_ALL=C grep -n '[^ -~	]' "$df" | grep -v '^[0-9]*:$' || true)"
check "Dockerfile: LF line endings only" test -z "$(grep -c "$(printf '\r')" "$df" | grep -v '^0$' || true)"

# The instruction checks read the file with comment lines removed, so a commented-out one fails.
grep -v '^[[:space:]]*#' "$df" >"$dfcode"
# Leading whitespace removed and blank lines dropped: one entry per instruction line.
sed 's/^[[:space:]]*//' "$dfcode" | grep -v '^$' >"$dfstrip"
arg() { sed -n "s/^ARG $2=//p" "$1"; }
check "Dockerfile: nothing masks a failure (no || true)" test -z "$(grep -F -e '|| true' -e '; true' "$dfcode" || true)"
check "devcontainer.json: no build args override the pin" test -z "$(grep -E -e '"args"[[:space:]]*:' -e '--build-arg' "$dj" || true)"
assert_eq "Dockerfile: USER 1000:1000 is the last instruction" "USER 1000:1000" "$(tail -1 "$dfstrip")"
code=$(cat "$dfcode")
check "Dockerfile: no instruction names the app user's home directory" test -z "$(printf '%s\n' "$code" | grep -e '/home/app' -e '~/' -e '\$HOME' || true)"
check "Dockerfile: no instruction names npm or node" test -z "$(printf '%s\n' "$code" | grep -Ewi -e 'npm' -e 'node' -e 'nodejs' || true)"

# --- Dockerfile: the extras are USER 0 and the pinned PowerShell (#893) --------------------
pwsh_ver=$(arg "$dfcode" PWSH_VERSION)
pwsh_sha=$(arg "$dfcode" PWSH_SHA256)
check "Dockerfile: PWSH_VERSION is a plain x.y.z, 7.2 or later" sh -c 'printf "%s\n" "$1" | grep -Eq "^([89]|[1-9][0-9]+)\.[0-9]+\.[0-9]+\$|^7\.([2-9]|[1-9][0-9]+)\.[0-9]+\$"' _ "$pwsh_ver"
check "Dockerfile: PWSH_SHA256 is 64 lowercase hex" sh -c 'printf "%s\n" "$1" | grep -Eq "^[0-9a-f]{64}\$"' _ "$pwsh_sha"
# The install RUN is pinned line by line: set -e, download, checksum before extract, extract
# without owner, group/other write dropped, mode, link. The ARG values are masked, since a bump
# changes them (their shape is checked above).
cat >"$want" <<'EOT'
USER 0
ARG PWSH_VERSION=@
ARG PWSH_SHA256=@
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 POWERSHELL_TELEMETRY_OPTOUT=1
RUN set -eu; \
curl -fsSL --retry 3 -o /tmp/pwsh.tar.gz \
"https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz"; \
echo "${PWSH_SHA256}  /tmp/pwsh.tar.gz" | sha256sum -c -; \
mkdir -p /opt/microsoft/powershell/7; \
tar --no-same-owner -xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7; \
rm -f /tmp/pwsh.tar.gz; \
chmod -R go-w /opt/microsoft/powershell/7; \
chmod 0755 /opt/microsoft/powershell/7/pwsh; \
ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
RUN [ "$(pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()')" = "$PWSH_VERSION" ]
EOT
# Everything after the FROM line and before the last instruction.
from_n=$(grep -n '^FROM ' "$dfstrip" | head -1 | cut -d: -f1)
last_n=$(wc -l <"$dfstrip" | tr -d ' ')
if [ -n "$from_n" ] && [ "$last_n" -gt "$from_n" ]; then
  sed -n "$((from_n + 1)),$((last_n - 1))p" "$dfstrip" | sed -e 's/^ARG PWSH_VERSION=.*/ARG PWSH_VERSION=@/' -e 's/^ARG PWSH_SHA256=.*/ARG PWSH_SHA256=@/' >"$got"
else
  : >"$got"
fi
check "Dockerfile: between the FROM and the last USER are exactly USER 0 and the pinned pwsh block" cmp -s "$got" "$want"

# --- devcontainer.json -------------------------------------------------------------------
# Minus its comment lines (first non-blank characters `//`), so a commented-out key counts for nothing.
sed '/^[[:space:]]*\/\//d' "$dj" >"$djc"
mount='"source=${localEnv:USERPROFILE}/.config/glunk-identity/tokens/glunk-works/claude-workbench,target=/run/wow,type=bind,readonly"'
check "devcontainer.json: the token mount is the owner-qualified directory, read-only, at /run/wow" grep -qxF "    $mount" "$djc"
assert_eq "devcontainer.json: exactly one /run/wow mount" 1 "$(grep -c 'target=/run/wow' "$djc" || true)"
check "devcontainer.json: .gitconfig.d comes from USERPROFILE only" grep -qF '"source=${localEnv:USERPROFILE}/.gitconfig.d,target=/home/app/.gitconfig.d,type=bind,readonly"' "$djc"
check "devcontainer.json: the -node_modules volume" grep -qF '"source=${localWorkspaceFolderBasename}-node_modules,target=/workspace/node_modules,type=volume"' "$djc"
check "devcontainer.json: the -venv volume" grep -qF '"source=${localWorkspaceFolderBasename}-venv,target=/workspace/.venv,type=volume"' "$djc"
check "devcontainer.json: remoteUser is app" grep -q '"remoteUser": "app"' "$djc"
check "devcontainer.json: postStartCommand is the narrowed removal, the three checks and plugin-install last" \
  grep -qxF '  "postStartCommand": "rm -f /tmp/vscode-remote-containers-*.js; sh /usr/local/share/devc/owner-check.sh; sh /usr/local/share/devc/devapp-check.sh; sh /usr/local/share/devc/git-identity.sh; sh /usr/local/share/devc/plugin-install.sh",' "$djc"
check "devcontainer.json: postAttachCommand only warns" sh -c 'l=$(grep "\"postAttachCommand\"" "$1"); case $l in *\"echo\ *) ! printf "%s\n" "$l" | grep -qE "rm |docker|;" ;; *) false ;; esac' _ "$djc"
check "devcontainer.json: runArgs keep the hardening flags" \
  grep -qxF '    "--cap-drop=ALL", "--security-opt=no-new-privileges",' "$djc"
check "devcontainer.json: runArgs keep the read-only root and tmpfs mounts" \
  grep -qxF '    "--read-only", "--tmpfs=/run", "--tmpfs=/var/tmp"' "$djc"
assert_eq "devcontainer.json: exactly six mounts entries" 6 "$(grep -c '^[[:space:]]*"source=' "$djc" || true)"
check "devcontainer.json: no appPort" test -z "$(grep -E '"appPort"[[:space:]]*:' "$djc" || true)"
check "devcontainer.json: no containerEnv, remoteEnv or customizations key" test -z "$(grep -E '"(containerEnv|remoteEnv|customizations)"[[:space:]]*:' "$djc" || true)"
check "devcontainer.json: no devcontainer exec anywhere" test -z "$(grep -F 'devcontainer exec' "$dj" || true)"

[ "$fail" -eq 0 ] || exit 1

# --- negative cases: scratch copies of the pair, each of which the checks above must refuse ----
if [ -z "${DEVCONTAINER_IMAGE_TEST_INNER:-}" ]; then
  scratch=$(mktemp -d); trap 'rm -rf "$scratch"; rm -f "$dfcode" "$want" "$dfstrip" "$djc" "$got"' EXIT
  neg_fail=0
  refuses() { # refuses <label> <mutation function>
    d="$scratch/case"; rm -rf "$d"; mkdir -p "$d"; cp "$df" "$d/Dockerfile"; cp "$dj" "$d/devcontainer.json"
    "$2" "$d"
    if DEVCONTAINER_IMAGE_TEST_INNER=1 DEVCONTAINER_DIR="$d" sh "$0" >/dev/null 2>&1; then
      printf 'FAIL - negative case not refused: %s\n' "$1" >&2; neg_fail=1
    else
      printf 'ok - refused: %s\n' "$1"
    fi
  }
  m_second_from() { { sed '$d' "$1/Dockerfile"; printf 'FROM scratch\nUSER 1000:1000\n'; } >"$1/D" && mv "$1/D" "$1/Dockerfile"; }
  m_base_from() { sed 's|devcontainer-devapp:|devcontainer-base:|' "$1/Dockerfile" >"$1/D" && mv "$1/D" "$1/Dockerfile"; }
  m_last_user() { { sed '$d' "$1/Dockerfile"; printf 'USER 0\n'; } >"$1/D" && mv "$1/D" "$1/Dockerfile"; }
  m_extra_instr() { { sed '$d' "$1/Dockerfile"; printf 'RUN echo extra\nUSER 1000:1000\n'; } >"$1/D" && mv "$1/D" "$1/Dockerfile"; }
  m_container_env() { sed 's|^{$|{ "containerEnv": {},|' "$1/devcontainer.json" >"$1/j" && mv "$1/j" "$1/devcontainer.json"; }
  m_extra_mount() { sed 's|^\(  "mounts": \[\)$|\1\n    "source=/h,target=/host,type=bind",|' "$1/devcontainer.json" >"$1/j" && mv "$1/j" "$1/devcontainer.json"; }
  m_third_file() { echo x >"$1/dev-token"; }
  refuses "a second FROM" m_second_from
  refuses "a devcontainer-base FROM" m_base_from
  refuses "a last instruction other than USER 1000:1000" m_last_user
  refuses "an extra instruction among the extras" m_extra_instr
  refuses "a containerEnv key" m_container_env
  refuses "an extra mount" m_extra_mount
  refuses "a third file in .devcontainer/" m_third_file
  [ "$neg_fail" -eq 0 ] || exit 1
fi

echo "all devcontainer-image fixtures passed"
