#!/bin/sh
# workflow-gap.sh — list the workflow files a branch's changes name and the commit does not hold.
#
# A file under `.github/workflows/` that a tool cannot push is left uncommitted for a later,
# separate publish. A test the branch adds that reads such a file runs red until then. This
# script finds those paths so ship can say so up front (an `Expected red:` line).
#
# Usage: workflow-gap.sh BASE
#   Run inside a git work tree. BASE is a commit-ish naming the PR base (a fetched
#   remote-tracking ref). The script takes the merge base of BASE and HEAD, lists the paths the
#   branch adds or modifies (git diff-tree -r -z --no-renames --diff-filter=AM, so a rename
#   counts as an add and a delete is skipped), and reads each one's committed blob `HEAD:<path>`
#   only, never the working tree. It collects every `.github/workflows/<name>.yml` or `.yaml`
#   (<name> is letters, digits, `.`, `_`, `-`). A collected path is listed only when the HEAD
#   tree holds no blob at it and the working tree (under the top of the work tree, whatever
#   directory the script runs from) holds a regular file at it.
#
# Output, one line on stdout:
#   none                 no path is listed (exit 0)
#   missing P1 P2 ...    the listed paths, sorted bytewise, each once, single-space separated (exit 0)
#   unreadable           a git read failed: BASE not a commit, no merge base, not in a work tree (exit 1)
# A wrong argument count, or a BASE that is empty or starts with `-`, prints a usage line on
# stderr, nothing on stdout, and exits 2 before any git call. Git's stderr is never shown.
# Writes nothing: no index, ref or working-tree change, no network call.
#
# Permitted toolset: POSIX sh, git, grep (-a -o), sort, tr, mktemp, rm.

usage() { echo "usage: workflow-gap.sh BASE" >&2; exit 2; }
[ "$#" -eq 1 ] || usage
case "$1" in ''|-*) usage ;; esac
base=$1

unreadable() { echo unreadable; exit 1; }

top=$(git rev-parse --show-toplevel 2>/dev/null) && [ -n "$top" ] || unreadable
tmp=$(mktemp -d 2>/dev/null) || unreadable
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

bc=$(git rev-parse --verify --quiet "$base^{commit}" 2>/dev/null) || unreadable
mb=$(git merge-base "$bc" HEAD 2>/dev/null) || unreadable
[ -n "$mb" ] || unreadable
git diff-tree -r -z --no-renames --diff-filter=AM --raw "$mb" HEAD >"$tmp/raw" 2>/dev/null || unreadable

# --raw -z: ":<mode> <mode> <sha> <sha> <status>" NUL path NUL. Read the pairs.
: >"$tmp/names"
tr '\0' '\n' <"$tmp/raw" >"$tmp/lines"
while IFS= read -r meta && IFS= read -r path; do
  case "$meta" in
    :160000\ *|:*\ 160000\ *) continue ;;   # a submodule entry has no blob to read
  esac
  git cat-file blob "HEAD:$path" >"$tmp/blob" 2>/dev/null || unreadable
  grep -a -o '\.github/workflows/[A-Za-z0-9._-][A-Za-z0-9._-]*\.ya\{0,1\}ml' "$tmp/blob" >>"$tmp/names" 2>/dev/null
done <"$tmp/lines"

LC_ALL=C sort -u "$tmp/names" >"$tmp/uniq"
out=
while IFS= read -r p; do
  [ -n "$p" ] || continue
  git cat-file -e "HEAD:$p" 2>/dev/null && continue
  [ -f "$top/$p" ] || continue
  out="$out $p"
done <"$tmp/uniq"

if [ -z "$out" ]; then echo none; else echo "missing$out"; fi
exit 0
