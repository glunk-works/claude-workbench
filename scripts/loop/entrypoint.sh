#!/bin/sh
# Loop session entrypoint: make the config directory and exec `claude`.
#
# The session holds no credential (issue #345). It carries a dummy token in the variable
# LOOP_CREDENTIAL_ENV names and ANTHROPIC_BASE_URL pointing at the credential-injecting proxy
# (inject.py, its own container), which swaps in the real one. Nothing is read from stdin: the
# real credential is piped to the proxy container, never to this one, so there is nothing here
# for `/proc/<pid>/environ`, an environment dump or a file read to leak.
set -eu

[ -z "${CLAUDE_CONFIG_DIR:-}" ] || mkdir -p "$CLAUDE_CONFIG_DIR"

# `claude -p` waits on a non-tty stdin.
exec claude "$@" </dev/null
