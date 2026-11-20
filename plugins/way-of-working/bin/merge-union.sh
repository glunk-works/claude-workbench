#!/bin/sh
# Resolve the one merge conflict a lane may resolve for itself, by keeping both sides' lines (#1711).
# /way-of-working:lanes' `wow-driver: merge-base` pointer has a lane merge the PR base into its branch; a
# file every change only appends to (`append_only`, project-schema.md) conflicts there whenever two branches
# add a line under the same heading. This script resolves exactly that conflict and no other.
#
# Usage: merge-union.sh      (no argument; run in a lane's worktree while a merge is stopped on conflicts)
#
# It resolves only when ALL of these hold, in this order of checking:
#   a merge is in progress (MERGE_HEAD exists);
#   the default branch's committed .ai/project.yml, never the working tree's copy, holds `append_only` as a
#     list of valid entries (the entry rule spec-shape.sh applies);
#   exactly one path is unmerged, it equals an `append_only` entry byte for byte, and the index holds stages
#     1, 2 and 3 for it (a both-modified conflict: not add/add, modify/delete or a rename);
#   the conflicted file git itself wrote into the worktree holds at least one conflict region, every marker
#     line belongs to a complete region, and every region lies strictly inside the file's first level-2
#     section (after its first line that starts with two `#` and a space, before the next such line) and
#     holds no such line.
# It resolves each region by keeping its ours lines, then its theirs lines, dropping the marker lines and any
# diff3 base part, writes the result over the path and stages it. A region where both sides edited one line
# keeps both copies.
#
# It prints exactly one line on stdout and changes nothing in the worktree or the index unless that line is
# `resolved PATH` or `failed`. On `failed` the file may already hold the resolution; the caller's
# `git merge --abort` restores it. Any edit already made to the conflicted file is staged with the resolution.
#   resolved PATH    exit 0  the conflict was resolved and staged; the caller commits the merge
#   no-merge         exit 1  no merge in progress (or not in a git work tree)
#   unreadable       exit 1  the default-branch read failed or its shape check failed, or `append_only` is
#                            neither null nor a list of valid entries
#   other-path       exit 1  `append_only` is absent, null or empty; or the unmerged paths are not exactly
#                            one listed path with stages 1, 2 and 3
#   outside-section  exit 1  the worktree file is not a plain file, holds no region, an incomplete region or
#                            a region outside the first level-2 section
#   failed           exit 1  the write, the staging or the final unmerged check failed
# A bad argument prints a usage line on stderr, nothing on stdout, and exits 2 before any git or gh call.
# No stderr of git, gh or yq is shown. It never commits, aborts, pushes or calls the GitHub API beyond one
# `gh repo view` read, whose output is captured to a file first, never piped.
set -u

if [ "$#" -ne 0 ]; then
  echo "usage: merge-union.sh (no argument)" >&2
  exit 2
fi

TMP=$(mktemp -d 2>/dev/null) || { echo unreadable; exit 1; }
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM

stop() { echo "$1"; exit 1; }

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || stop no-merge
cd "$TOP" 2>/dev/null || stop no-merge
git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 || stop no-merge

# The default branch's committed project file.
url=$(git remote get-url origin 2>/dev/null) || stop unreadable
case "$url" in '' | -*) stop unreadable ;; esac
gh repo view "$url" --json defaultBranchRef --jq '.defaultBranchRef.name // ""' >"$TMP/db.txt" 2>/dev/null || stop unreadable
D=$(cat "$TMP/db.txt")
case "$D" in '' | -* | *[!A-Za-z0-9._/-]*) stop unreadable ;; esac
git fetch -q origin "+refs/heads/$D:refs/remotes/origin/$D" >/dev/null 2>&1 || stop unreadable
git show "refs/remotes/origin/$D:.ai/project.yml" >"$TMP/project.yml" 2>/dev/null || stop unreadable
[ -s "$TMP/project.yml" ] || stop unreadable

# `append_only`: the entry rule is spec-shape.sh's.
entry_ok='(select(tag == "!!str") | (test("^[A-Za-z0-9._][A-Za-z0-9._/-]*$") and (test("//") | not) and (test("/$") | not) and (test("(^|/)[.][.]?(/|$)") | not) and (. != ".github") and (test("^[.]github/") | not))) // false'
kind=$(yq '.append_only | tag' "$TMP/project.yml" 2>/dev/null) || stop unreadable
case "$kind" in
  '!!null') stop other-path ;;
  '!!seq') ;;
  *) stop unreadable ;;
esac
good=$(yq ".append_only | explode(.) | [.[] | ($entry_ok)] | all" "$TMP/project.yml" 2>/dev/null) || stop unreadable
[ "$good" = true ] || stop unreadable
yq -r '.append_only | explode(.) | .[]' "$TMP/project.yml" >"$TMP/entries.txt" 2>/dev/null || stop unreadable
[ -s "$TMP/entries.txt" ] || stop other-path

# Exactly one unmerged path, listed, with all three stages.
git diff --name-only --diff-filter=U -z >"$TMP/unmerged.z" 2>/dev/null || stop other-path
nul=$(tr -cd '\0' <"$TMP/unmerged.z" | wc -c | tr -d ' ')
[ "$nul" = 1 ] || stop other-path
P=$(tr '\0' '\n' <"$TMP/unmerged.z")
listed=0
while IFS= read -r e; do
  [ "$e" = "$P" ] && listed=1
done <"$TMP/entries.txt"
[ "$listed" = 1 ] || stop other-path
stages=$(git ls-files -u -- "$P" 2>/dev/null | awk '{ s = s $3 } END { print s }')
[ "$stages" = 123 ] || stop other-path

[ -f "$P" ] && [ ! -L "$P" ] || stop outside-section

# Read the regions git wrote; resolve them in memory.
verdict=$(awk -v out="$TMP/result.txt" '
  function mark(l, c,   m) {
    m = sprintf("%7s", ""); gsub(/ /, c, m)
    return substr(l, 1, 7) == m && (length(l) == 7 || substr(l, 8, 1) == " ")
  }
  { n++; line[n] = $0 }
  END {
    h1 = 0; h2 = n + 1
    for (i = 1; i <= n; i++) if (substr(line[i], 1, 3) == "## ") {
      if (!h1) h1 = i; else { h2 = i; break }
    }
    st = 0; regions = 0; o = 0
    for (i = 1; i <= n; i++) {
      l = line[i]
      if (st == 0) {
        if (mark(l, "<")) { st = 1; s = i; theirs = ""; base = 0; tn = 0; continue }
        if (mark(l, "|") || mark(l, "=") || mark(l, ">")) { print "bad"; exit }
        out_[++o] = l
      } else if (st == 1) {
        if (mark(l, "|") && !base) { st = 2; base = 1; continue }
        if (mark(l, "=")) { st = 3; continue }
        if (mark(l, "<") || mark(l, "|") || mark(l, ">")) { print "bad"; exit }
        out_[++o] = l
      } else if (st == 2) {
        if (mark(l, "=")) { st = 3; continue }
        if (mark(l, "<") || mark(l, "|") || mark(l, ">")) { print "bad"; exit }
      } else {
        if (mark(l, ">")) {
          if (!h1 || s <= h1 || i >= h2) { print "bad"; exit }
          for (k = 1; k <= tn; k++) out_[++o] = th[k]
          regions++; st = 0; continue
        }
        if (mark(l, "<") || mark(l, "|") || mark(l, "=")) { print "bad"; exit }
        th[++tn] = l
      }
      if (st != 0 && substr(l, 1, 3) == "## ") { print "bad"; exit }
    }
    if (st != 0 || regions == 0) { print "bad"; exit }
    for (k = 1; k <= o; k++) print out_[k] > out
    close(out)
    print "ok"
  }' "$P" 2>/dev/null) || stop failed
[ "$verdict" = ok ] || stop outside-section

# Write and stage the resolution.
cat "$TMP/result.txt" >"$P" 2>/dev/null || stop failed
git add -- "$P" >/dev/null 2>&1 || stop failed
left=$(git diff --name-only --diff-filter=U 2>/dev/null) || stop failed
[ -z "$left" ] || stop failed

printf 'resolved %s\n' "$P"
exit 0
