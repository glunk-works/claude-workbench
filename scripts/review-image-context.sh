#!/bin/sh
# Assemble the App-mode review image's build context (#1398) the way
# scripts/identity/install-host-tools.ps1 exports it to bin/review/: each source in its
# `,@('<source>', 'review/<name>')` list, as committed at this checkout's HEAD, written to
# <dest-dir>/<name>. The review-image workflow and tests/review-image.test.sh both run it, so
# they share one reading of the list.
#
# Usage: sh scripts/review-image-context.sh <dest-dir>
#
# Refuses (exit 1, one stderr line, nothing written) on: not exactly one argument; an empty
# <dest-dir> argument; a <dest-dir> that exists and is not a directory; a <dest-dir> directory that
# is not empty; the ps1 unreadable at HEAD; the ps1 at HEAD holding no build-context entries; a listed
# source that is not a blob at HEAD. Limit: for the ps1-unreadable refusal, other stderr output comes
# before the script's line.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
ps1='scripts/identity/install-host-tools.ps1'

die() { echo "review-image-context.sh: $1" >&2; exit 1; }

[ "$#" -eq 1 ] || die "usage: review-image-context.sh <dest-dir>"
dest=$1
[ -n "$dest" ] || die "usage: review-image-context.sh <dest-dir>"
if [ -e "$dest" ] || [ -L "$dest" ]; then
  [ -d "$dest" ] || die "destination exists and is not a directory"
  [ -z "$(ls -A "$dest")" ] || die "destination is not empty"
fi

list="$(git -C "$root" cat-file blob "HEAD:$ps1")" || die "cannot read $ps1 at HEAD"
pairs="$(printf '%s\n' "$list" | sed -n "s/^  ,@('\\([^']*\\)', 'review\\/\\([^']*\\)')\$/\\1|\\2/p")"
[ -n "$pairs" ] || die "no build-context entries in $ps1"

# Check every source before anything is written.
printf '%s\n' "$pairs" | while IFS="|" read -r src name; do
  [ "$(git -C "$root" cat-file -t "HEAD:$src" 2>/dev/null || true)" = blob ] || die "not a committed file: $src"
done

mkdir -p "$dest"
printf '%s\n' "$pairs" | while IFS="|" read -r src name; do
  git -C "$root" cat-file blob "HEAD:$src" >"$dest/$name"
done
