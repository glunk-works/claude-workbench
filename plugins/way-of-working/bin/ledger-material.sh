#!/bin/sh
# Did the regenerated .ai/next-steps.md change on a line the next session acts on?
#
# Issue #1376: every /way-of-working:handoff that was not a no-op opened its own docs-only
# cursor-sync PR, and /way-of-working:resume waited on it, so the maintainer merged a ledger
# PR before each next session could start. Most of those syncs changed only narrative
# (Just done bullets, pointers, the critic record). This is the deterministic predicate
# handoff's *Commit* step runs to tell a material change from a narrative one -- a tested
# script, not skill prose, the same shape as cursor-drift.sh and cursor-sync-pr.sh.
#
# Usage: ledger-material.sh OLD NEW   (two ledger files; OLD is HEAD's committed copy)
# Prints exactly one line, to stdout, and always exits 0 (the caller decides policy):
#   same        -- every material line kind is byte-for-byte equal in both files
#   changed     -- at least one material line kind differs (a kind present in one file
#                  only is a difference)
#   unreadable  -- wrong argument count, an empty argument, a missing or unreadable file,
#                  or a file lacking a column-0 Now, Next or HITL Gate line, so a ledger
#                  in another shape never reads `same`. The caller treats it as `changed`.
#
# The material kinds, and why each is the one it is:
#   - the column-0 line starting `**Now:**` -- what the cursor says is happening;
#   - the column-0 line starting `**Next:**` -- what the next session does, and (per
#     handoff) which model runs it;
#   - the HITL Gate text, from the column-0 line starting `**HITL Gate` through the line
#     before the next blank line or the end of the file -- the gate resume's auto-start
#     reads, wrapped over continuation lines;
#   - the line starting `**Milestone close:**`, at column 0 or after a leading `- `, as
#     milestone-close-line.sh accepts it -- the outcome a planning cursor carries.
# For each kind the lines of the two files are compared byte for byte, in file order. Every
# other line is ignored, an indented line that starts with a marker included.
#
# Permitted toolset: POSIX sh and its standard utilities (cat, cmp, mktemp, rm, printf).
# No jq, no yq, no python, no awk.
set -u

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "ledger-material.sh: usage: ledger-material.sh OLD NEW" >&2
  echo unreadable
  exit 0
fi
old="$1"; new="$2"
[ -f "$old" ] && [ -r "$old" ] && [ -f "$new" ] && [ -r "$new" ] || {
  echo "ledger-material.sh: a ledger file is missing or unreadable" >&2
  echo unreadable
  exit 0
}

tmp="$(mktemp -d)" || { echo unreadable; exit 0; }
trap 'rm -rf "$tmp"' EXIT

# split FILE TAG: writes FILE's material lines to $tmp/<kind>.<tag>, one file per kind.
split() {
  : >"$tmp/now.$2"; : >"$tmp/next.$2"; : >"$tmp/hitl.$2"; : >"$tmp/close.$2"
  in_hitl=0
  # `|| [ -n "$line" ]` keeps a final line that lacks a trailing newline.
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_hitl" -eq 1 ]; then
      case "$line" in
        *[![:space:]]*) printf '%s\n' "$line" >>"$tmp/hitl.$2"; continue ;;
        *) in_hitl=0 ;;
      esac
    fi
    case "$line" in
      '**Now:**'*) printf '%s\n' "$line" >>"$tmp/now.$2" ;;
      '**Next:**'*) printf '%s\n' "$line" >>"$tmp/next.$2" ;;
      '**HITL Gate'*) in_hitl=1; printf '%s\n' "$line" >>"$tmp/hitl.$2" ;;
      '**Milestone close:**'* | '- **Milestone close:**'*) printf '%s\n' "$line" >>"$tmp/close.$2" ;;
    esac
  done <"$1"
}

split "$old" a
split "$new" b

# A ledger without the three required column-0 lines is another shape: never `same`.
for k in now next hitl; do
  for w in a b; do
    [ -s "$tmp/$k.$w" ] || { echo unreadable; exit 0; }
  done
done

for k in now next hitl close; do
  cmp -s "$tmp/$k.a" "$tmp/$k.b" || { echo changed; exit 0; }
done
echo same
exit 0
