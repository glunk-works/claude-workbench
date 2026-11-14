#!/bin/sh
# Does a drafted spec comment have the fixed shape? (#611, WB-D26, WB-D29)
#
# /way-of-working:spec-task drafts a task's spec comment, then posts or holds it once this says `ok`: a maintainer
# reacts, and the readers find it under a map (WB-D30; in a legacy repo /way-of-working:handoff anchors it). The drafter is a model writing prose, so the
# shape is checked here, not trusted, and the skill posts only on `ok`.
#
# Usage: spec-shape.sh check <file> [<project-file>]
# Prints exactly one of, and exits 0 (the caller decides policy):
#   ok                          -- every required section heading is present, in order, every
#                                  section has at least one non-blank line (`nothing` counts: it
#                                  is text), no line begins with either marker prefix, and any
#                                  optional `### Trailers` section is well formed (below)
#   has-marker                  -- a line begins with `spec-task:` or `spec-task-escalated:` (after
#                                  a trailing carriage return is stripped), the rule spec-post.sh
#                                  applies at the post, after the critic gate (it now stops such a
#                                  draft `bad-shape`, since it runs this script first); it takes
#                                  precedence over `missing`
#   missing <section>[,<section>...]
#                               -- the headings (comma-joined, in the required order) that are
#                                  absent, first appear before an earlier required heading, or
#                                  have an empty body
#   no-append <path>[,<path>...]
#                               -- only with a project file, after `has-marker`, `missing` and `bad-trailers`
#                                  (all win): the declared `append_only` paths (comma-joined, each once, in
#                                  the order of their first offending bullet) that have a Files touched
#                                  bullet whose closing backtick is not followed by exactly a space and
#                                  `**(append)**`, the only form spec-fresh.sh skips; fix each bullet to
#                                  read - `path` **(append)** ...
#   bad-trailers                -- only for an otherwise `ok` draft: the optional `### Trailers` section
#                                  is malformed (below). `has-marker` and `missing` win over it, and
#                                  it wins over every project-file result (`no-append` and the
#                                  project-file `unreadable`)
#   unreadable                  -- (project-file cases below apply only to an otherwise `ok` draft) the file does not exist, is not a regular file, is empty, or
#                                  cannot be read; with a project file, also when its `append_only` is
#                                  not null, absent or a list whose every entry is a path (the entry
#                                  rule schema-complete.sh applies), when the project file is missing, empty (zero-byte),
#                                  unparsable or holds more than one document, or when yq fails
#
# Required headings, in order, each a level-3 line (`### Goal`) -- the first line of a draft is
# free-form (a title line) except that it, like every line, never begins with a marker prefix
# (spec-post.sh writes the marker line itself), and the prose between a heading and the next heading of any level
# (`#` through `######`) is that section's body:
#   Goal | Files touched | Done when | Tests | Out of scope | Restated from the issue body
#
# Optional section: `### Trailers` carries the commit trailers a task's commit must carry beyond
# its closing reference (/way-of-working:ship writes them into the commit). A draft without the
# heading is judged as without this section (bar the look-alike rule below). When the whole line `### Trailers` (optional trailing
# blanks) is present it must appear exactly once, after the first `### Out of scope` heading and
# before the first `### Restated from the issue body` heading, and its body (up to the next
# heading of any level) must hold at least one non-blank line, every non-blank line being one
# trailer: a token of letters, digits and hyphens that starts with a letter, a colon, one space,
# then a value with at least one non-blank character (a trailing carriage return is stripped
# first). A trailer line holds no backtick, `$`, double quote, single quote or backslash, no
# GitHub closing keyword (close, closes, closed, fix, fixes, fixed, resolve, resolves, resolved)
# as a word (a word is a maximal run of ASCII letters, compared lowercased, so `(fixes` and
# `FIXES` both count), and its token is not `Co-authored-by` or `Signed-off-by` in any case.
# Any other line anywhere in the draft that starts with up to three spaces, hashes, a space or tab and
# `trailers` in any case (a heading with closing hashes, trailing text or another hash count;
# fenced code is not understood, so a line in a code block counts too), even in a draft with no
# exact `### Trailers` line, and a line of seven or more hashes inside the section, are also
# `bad-trailers`, so the validator and ship end the section at the same line.
#
# A heading counts only as a whole line, `### ` followed by exactly the name and optional
# trailing blanks; `### Goal and more` is not `Goal`. A heading that first appears before an
# earlier required one is reported missing: order is part of the shape, because the maintainer
# reads the draft top-down and a reaction approves the whole comment.
# A section is non-empty when its first occurrence has at least one non-blank line before the
# next heading or the end of the file. Fenced code blocks are not understood: a `#` line inside
# one reads as a heading.
#
# `append_only` (project-schema.md) lists repo-relative files every spec only appends to. With no
# project file, or the key null, absent or an empty list, no file is held to the rule and the result
# is as without the argument. An entry is a path as a Files touched bullet writes it (letters,
# digits, `.`, `_`, `-` and `/`, starting with a letter, digit, `.` or `_`, no empty, `.` or `..`
# segment), with no trailing `/`, and neither `.github` nor under `.github/`, which spec-fresh.sh
# never skips.
#
# Exit 2 on a usage error only. The draft is data: it is only read, never evaluated or passed
# to another command. The project file is read only by yq, never evaluated.
#
# Permitted toolset: POSIX sh + awk (+ yq, project-file form only).
set -eu

if { [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; } || [ "$1" != check ]; then
  echo "usage: spec-shape.sh check <file> [<project-file>]" >&2
  exit 2
fi

f="$2"
if [ ! -f "$f" ] || [ ! -r "$f" ] || [ ! -s "$f" ]; then
  echo unreadable
  exit 0
fi

base=$(LC_ALL=C awk '
  function trailer_ok(l,   q, tok, rest, k, t, w, nw, i) {
    q = sprintf("%c", 39)
    if (index(l, "`") || index(l, "$") || index(l, "\"") || index(l, q) || index(l, "\\")) return 0
    if (l !~ /^[A-Za-z][A-Za-z0-9-]*: /) return 0
    k = index(l, ":")
    tok = tolower(substr(l, 1, k - 1))
    if (tok == "co-authored-by" || tok == "signed-off-by") return 0
    rest = substr(l, k + 2)
    if (rest !~ /[^ \t]/) return 0
    t = tolower(l)
    gsub(/[^a-z]+/, " ", t)
    nw = split(t, w, " ")
    for (i = 1; i <= nw; i++) if (w[i] in kw) return 0
    return 1
  }
  BEGIN {
    split("close closes closed fix fixes fixed resolve resolves resolved", kws, " ")
    for (i in kws) kw[kws[i]] = 1

    n = split("Goal|Files touched|Done when|Tests|Out of scope|Restated from the issue body", want, "|")
    for (i = 1; i <= n; i++) idx[want[i]] = i
    last_body = 0
    marker = 0
  }
  {
    line = $0
    sub(/\r$/, "", line)
    if (line ~ /^spec-task:/ || line ~ /^spec-task-escalated:/) marker = 1
    lt = tolower(line)
    if (lt ~ /^ ? ? ?#+[ \t]+trailers/ && line !~ /^### Trailers[ \t]*$/) tother = 1
    if (line ~ /^#+ /) {
      if (intr && line ~ /^#######/) tbad = 1
      cur = 0
      intr = (line ~ /^### Trailers[ \t]*$/)
      if (intr) { tcount++; if (tcount == 1) tpos = NR }
      if (line ~ /^### /) {
        name = substr(line, 5)
        sub(/[ \t]+$/, "", name)
        cur = (name in idx) ? idx[name] : 0
        if (cur && !pos[cur]) { pos[cur] = NR; first[cur] = 1 } else if (cur) first[cur] = 0
      }
      next
    }
    if (cur && first[cur] && line ~ /[^ \t]/) body[cur]++
    if (intr && tcount == 1 && line ~ /[^ \t]/) { tbody++; if (!trailer_ok(line)) tbad = 1 }
  }
  END {
    if (marker) { print "has-marker"; exit }
    out = ""
    maxpos = 0
    for (i = 1; i <= n; i++) {
      if (!pos[i] || pos[i] < maxpos || !body[i]) { out = out (out == "" ? "" : ",") want[i]; continue }
      maxpos = pos[i]
    }
    if (out != "") { print "missing " out; exit }
    if (tother || tcount > 1 || (tcount == 1 && (tpos < pos[5] || tpos > pos[6] || !tbody || tbad))) print "bad-trailers"
    else print "ok"
  }
' <"$f")

if [ "$base" != ok ] || [ "$#" -ne 3 ]; then
  echo "$base"
  exit 0
fi

# The project file: `append_only` must be one value, null or a list, and every entry a path.
p="$3"
if [ ! -f "$p" ] || [ ! -r "$p" ] || [ ! -s "$p" ]; then
  echo unreadable
  exit 0
fi
entry_ok='(select(tag == "!!str") | (test("^[A-Za-z0-9._][A-Za-z0-9._/-]*$") and (test("//") | not) and (test("/$") | not) and (test("(^|/)[.][.]?(/|$)") | not) and (. != ".github") and (test("^[.]github/") | not))) // false'
kind=$(yq '.append_only | tag' "$p" 2>/dev/null) || { echo unreadable; exit 0; }
case "$kind" in
  '!!null') echo ok; exit 0 ;;
  '!!seq') ;;
  *) echo unreadable; exit 0 ;;
esac
good=$(yq ".append_only | explode(.) | [.[] | ($entry_ok)] | all" "$p" 2>/dev/null) || { echo unreadable; exit 0; }
if [ "$good" != true ]; then
  echo unreadable
  exit 0
fi
APPEND_ENTRIES=$(yq -r '.append_only | explode(.) | .[]' "$p" 2>/dev/null) || { echo unreadable; exit 0; }
if [ -z "$APPEND_ENTRIES" ]; then
  echo ok
  exit 0
fi
export APPEND_ENTRIES

awk '
  BEGIN {
    n = split(ENVIRON["APPEND_ENTRIES"], ent, "\n")
    for (i = 1; i <= n; i++) declared[ent[i]] = 1
  }
  {
    line = $0
    sub(/\r$/, "", line)
    if (line ~ /^#+ /) {
      sec = (line ~ /^### Files touched[ \t]*$/ && !done)
      if (sec) done = 1
      next
    }
    if (!sec || line !~ /^- `/) next
    s = substr(line, 4)
    k = index(s, "`")
    if (k == 0) next
    path = substr(s, 1, k - 1)
    rest = substr(s, k + 1)
    if (substr(path, length(path), 1) == "/") path = substr(path, 1, length(path) - 1)
    if (!(path in declared) || index(rest, " **(append)**") == 1 || (path in named)) next
    named[path] = 1
    out = out (out == "" ? "" : ",") path
  }
  END { if (out == "") print "ok"; else print "no-append " out }
' <"$f"
