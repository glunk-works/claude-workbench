#!/bin/sh
# Loop container entrypoint: read the credential from stdin, hand it to the `claude` process
# only, and exec. (plan v9 § 7.2: "pass it only to the claude process".)
#
# The driver pipes the credential on stdin (only its first line is read) (`docker run -i`). It is never on disk
# in the container, never in `docker inspect`'s Env (an -e flag would be), and never in a path
# a Read deny has to name. LOOP_CREDENTIAL_ENV names the variable that carries it
# (CLAUDE_CODE_OAUTH_TOKEN for a `claude setup-token` credential, ANTHROPIC_API_KEY for a
# Console key): M2a is credential-agnostic (docs/proposals/orchestrator-m2-decisions.md, decision 4).
#
# Residual, not closed here: a Bash tool call is a child of `claude`, so whether it inherits
# the variable is the plan's untested § 9 item for this container, and /proc/<pid>/environ is
# readable by the same uid. The attack pass (#318) tests both.
set -eu

: "${LOOP_CREDENTIAL_ENV:?LOOP_CREDENTIAL_ENV must name the credential variable}"
case "$LOOP_CREDENTIAL_ENV" in
  CLAUDE_CODE_OAUTH_TOKEN|ANTHROPIC_API_KEY) ;;
  *) echo "entrypoint: LOOP_CREDENTIAL_ENV must be CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY" >&2; exit 64 ;;
esac

IFS= read -r cred || true
cred=$(printf '%s' "$cred" | tr -d '\r')   # a Windows-written file ends in CRLF
[ -n "$cred" ] || { echo "entrypoint: no credential on stdin" >&2; exit 64; }

[ -z "${CLAUDE_CONFIG_DIR:-}" ] || mkdir -p "$CLAUDE_CONFIG_DIR"

name=$LOOP_CREDENTIAL_ENV
unset LOOP_CREDENTIAL_ENV
# `claude -p` waits on a non-tty stdin, so it gets /dev/null after the credential is read.
export "$name=$cred"
unset cred
exec claude "$@" </dev/null
