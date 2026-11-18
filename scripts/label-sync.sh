#!/usr/bin/env bash
# Work out which GitHub labels this repo declares and which of them are missing (#1566).
#
# Usage: bash scripts/label-sync.sh declared        (run from the repo root)
#        bash scripts/label-sync.sh plan FILE
# Exit:  0 ok, 1 fail closed (nothing on stdout), 2 usage (an unknown or missing
#        subcommand, `declared` with an argument, `plan` without exactly one FILE).
#
# The labels are configuration, declared in two committed sources:
#   - the areas of CLAUDE.md's `## Areas` section, each as `area/<area>`, read exactly as
#     scripts/pr-title-check.sh reads them (the first backtick span of each top-level `- `
#     bullet between the `## Areas` heading and the next level-2 heading);
#   - .github/labels.txt, every other label, one name per line; blank lines and lines
#     whose first character is the hash sign are ignored.
#
# `declared` prints every declared label, one per line, sorted and unique.
#
# `plan FILE` reads FILE as the repo's current label names, one per line (a trailing CR
# removed), and prints, for each declared label: nothing when FILE holds it exactly;
# `case-mismatch NAME` (the declared spelling) when FILE holds it only in another letter
# case, since GitHub label names are unique regardless of case and a create would be
# refused; else `create NAME`. Then, for each name in FILE that no declared label matches
# case-insensitively, `undeclared NAME`; a name outside `[A-Za-z0-9._/ -]` is printed as the
# bare word `undeclared-unprintable`, never echoed, so no label name can start a workflow
# command in the job log. It prints no other line, and no line that would delete or change a
# label.
#
# Fail closed (a message on stderr, exit 1, nothing on stdout): CLAUDE.md missing, with no
# `## Areas` heading or yielding no area; an area outside `[a-z0-9][a-z0-9-]*`; the list file
# missing; a list entry that is not a whole line matching
# `[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)?`; a list entry starting with `area/` (areas have
# one source only); for `plan`, a missing FILE. No message echoes an area, a list entry or a
# label name.
#
# This script makes no network call and holds no token. The workflow that uses it
# (.github/workflows/label-sync.yml) lists the labels and creates the missing ones.
set -eu
export LC_ALL=C

usage() {
  echo "label-sync: usage: bash scripts/label-sync.sh declared | plan FILE" >&2
  exit 2
}

[ "$#" -ge 1 ] || usage
cmd="$1"
case "$cmd" in
  declared) [ "$#" -eq 1 ] || usage ;;
  plan) [ "$#" -eq 2 ] || usage ;;
  *) usage ;;
esac

die() {
  echo "label-sync: $1" >&2
  exit 1
}

# declared_labels: set the array `declared` (sorted, unique) or exit 1.
declared_labels() {
  local areas=() in_areas=0 line a entries=() out
  [ -f CLAUDE.md ] || die "CLAUDE.md is missing"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_areas" = 0 ]; then
      [ "$line" = "## Areas" ] && in_areas=1
      continue
    fi
    case "$line" in "## "*) break ;; esac
    if [[ "$line" =~ ^-\ [^\`]*\`([^\`]+)\` ]]; then
      areas+=("${BASH_REMATCH[1]}")
    fi
  done <CLAUDE.md
  [ "${#areas[@]}" -gt 0 ] || die "could not read the area list from the '## Areas' section of CLAUDE.md"
  for a in "${areas[@]}"; do
    [[ "$a" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
      die "an area in the '## Areas' section of CLAUDE.md is not valid (lowercase letters, digits and hyphens, not starting with a hyphen)"
    entries+=("area/$a")
  done
  [ -f .github/labels.txt ] || die ".github/labels.txt is missing"
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    case "$line" in "#"*) continue ;; esac
    [[ "$line" =~ ^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)?$ ]] ||
      die "an entry of .github/labels.txt is not a valid label name"
    case "$line" in area/*) die "an entry of .github/labels.txt starts with area/ (areas come from CLAUDE.md only)" ;; esac
    entries+=("$line")
  done <.github/labels.txt
  out="$(printf '%s\n' "${entries[@]}" | sort -u)"
  declared=()
  while IFS= read -r line; do declared+=("$line"); done <<<"$out"
}

declared=()
if [ "$cmd" = declared ]; then
  declared_labels
  printf '%s\n' "${declared[@]}"
  exit 0
fi

file="$2"
[ -f "$file" ] || die "the label file is missing"
declared_labels

existing=()
while IFS= read -r line || [ -n "$line" ]; do
  existing+=("${line%$'\r'}")
done <"$file"

printable='^[A-Za-z0-9._/ -]+$'
out=""
declared_lower=()
for d in "${declared[@]}"; do
  dl="${d,,}"
  declared_lower+=("$dl")
  exact=0 folded=0
  for e in ${existing[@]+"${existing[@]}"}; do
    [ "$e" = "$d" ] && exact=1
    [ "${e,,}" = "$dl" ] && folded=1
  done
  if [ "$exact" = 1 ]; then
    :
  elif [ "$folded" = 1 ]; then
    out+="case-mismatch $d"$'\n'
  else
    out+="create $d"$'\n'
  fi
done
for e in ${existing[@]+"${existing[@]}"}; do
  el="${e,,}"
  known=0
  for dl in "${declared_lower[@]}"; do
    [ "$dl" = "$el" ] && known=1
  done
  [ "$known" = 1 ] && continue
  if [[ "$e" =~ $printable ]]; then
    out+="undeclared $e"$'\n'
  else
    out+="undeclared-unprintable"$'\n'
  fi
done
printf '%s' "$out"
