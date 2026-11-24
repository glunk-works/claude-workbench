#!/usr/bin/env bash
# Decide whether the pinned Claude Code is behind the latest release (#1677).
#
# Usage: bash scripts/claude-pin-check.sh FEED DOCKERFILE        (run from the repo root)
# Exit:  0 ok, 1 fail closed (nothing on stdout), 2 usage (not exactly two arguments).
#
# FEED is a file holding the release feed's response body; DOCKERFILE is the Dockerfile to
# read the pin from. A version is three dot-separated decimal components, each zero or one to
# nine digits with no leading zero, and nothing else (no leading v, no whitespace, no suffix).
#
# FEED is valid only when it is exactly one version, optionally followed by one newline,
# which may itself be preceded by one CR. The pin is the value of the one line of DOCKERFILE
# that starts with `ARG CLAUDE_VERSION=` (one trailing CR removed); no such line, more than
# one, or a value that is not a version fails.
#
# On success it prints exactly one line: `behind PIN LATEST` when the feed's version is newer
# than the pin (compared numerically, component by component), else `current PIN LATEST` (the
# pin equal to the feed or ahead of it).
#
# Fail closed: a bad feed or pin, or a missing or unreadable file, prints a fixed message on
# stderr that echoes neither the feed's text nor the pin, prints nothing on stdout and
# exits 1. It makes no network call, calls no tool that does, reads no token and writes no
# file: the workflow downloads the feed and passes it in.
set -u
export LC_ALL=C

die() { echo "claude-pin-check: $1" >&2; exit 1; }

[ "$#" -eq 2 ] || { echo "usage: bash scripts/claude-pin-check.sh FEED DOCKERFILE" >&2; exit 2; }
feed="$1"
dockerfile="$2"

comp='(0|[1-9][0-9]{0,8})'
re="^${comp}\\.${comp}\\.${comp}\$"

[ -f "$feed" ] && [ -r "$feed" ] || die "the feed file is unreadable"
[ -f "$dockerfile" ] && [ -r "$dockerfile" ] || die "the Dockerfile is unreadable"

# Feed: the whole file, byte for byte (the sentinel keeps trailing newlines). The printf is chained
# with && so the guard tests the read's own status, not the printf's.
content="$(cat -- "$feed" && printf x)" || die "the feed file is unreadable"
content="${content%x}"
[ "${#content}" -eq "$(wc -c <"$feed" | tr -d ' ')" ] || die "the feed is not plain text"
if [ "${content%$'\n'}" != "$content" ]; then
  content="${content%$'\n'}"
  content="${content%$'\r'}"
fi
[[ "$content" =~ $re ]] || die "the feed is not a version"
latest="$content"

# Pin: the one line starting `ARG CLAUDE_VERSION=`.
count=0
pin=""
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "ARG CLAUDE_VERSION="*)
      count=$((count + 1))
      pin="${line#ARG CLAUDE_VERSION=}"
      pin="${pin%$'\r'}"
      ;;
  esac
done <"$dockerfile"
[ "$count" -eq 1 ] || die "the Dockerfile does not hold exactly one CLAUDE_VERSION line"
[[ "$pin" =~ $re ]] || die "the pinned version is not a version"

IFS=. read -r l1 l2 l3 <<<"$latest"
IFS=. read -r p1 p2 p3 <<<"$pin"
state=current
if [ $((10#$l1)) -ne $((10#$p1)) ]; then
  [ $((10#$l1)) -gt $((10#$p1)) ] && state=behind
elif [ $((10#$l2)) -ne $((10#$p2)) ]; then
  [ $((10#$l2)) -gt $((10#$p2)) ] && state=behind
elif [ $((10#$l3)) -gt $((10#$p3)) ]; then
  state=behind
fi
echo "$state $pin $latest"
