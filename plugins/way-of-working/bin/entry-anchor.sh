#!/bin/sh
# Does <file> carry ledger item <id> at its OWN entry anchor?
#
# One question, one answer. A ledger-conflict resolver needs to tell "this file
# lists <id> as an entry of its own" from "this file mentions <id> in the body of
# some other entry" -- and the second shape is ordinary content, not an edge case:
# a retro mandates that a new item cite the id of the one it supersedes, so live
# ledgers and their _archive siblings both carry foreign ids as prose.
#
# This is a deterministic predicate with a correctness argument, so it is a tested
# script the skill invokes rather than a regex described in skill prose. The
# repo's own decision log has the reasoning; the short version is that prose
# shipped a wrong regex for this three consecutive critic rounds, each time in a
# new direction.
#
# Usage: entry-anchor.sh <id> <file>
# Exit:
#   0 -- <file> carries <id> at an entry anchor
#   1 -- it does not
#   2 -- the question could not be answered (bad arity, empty id, unreadable file,
#        an awk without POSIX bracket classes, or any other awk error).
#        The CALLER decides policy for 2. For a ledger-conflict resolver the policy
#        is the same as for 1: fall through to the keep-both default. This script
#        never guesses on the caller's behalf.
#
# Permitted toolset: POSIX sh + awk. No jq, no yq, no python -- this must run on
# any maintainer machine without an extra interpreter installed.
#
#
# --- What counts as an anchor -----------------------------------------------
#
# An occurrence of <id> on a line anchors an entry when all four hold:
#
#   1. The line OPENS AN ENTRY -- see the section below. This is the load-bearing
#      rule, and the one every earlier revision got wrong.
#   2. The character immediately BEFORE the id is not one an id could continue
#      through ([[:alnum:]._-]) -- so a search for `A-1` does not fire inside
#      `XA-1` or `12A-1`.
#   3. The character immediately AFTER it is likewise not one -- so `A-1` does not
#      fire inside `A-14`, which a bare substring search gets wrong.
#   4. Everything between the entry marker and the id contains NO letter, once
#      bracket-delimited, whitespace-free spans are removed. That is the "arbitrary
#      inline markup" rule, and it is a shape, not a list: `**`, backticks, `[ ]`,
#      `[x]` and any combination of them pass without being named, while
#      `- **A-20** -- superseded by ` fails, because a citation inside an entry is
#      preceded by that entry's own words.
#
#      The span removal is deliberately narrow. It exists so a CHECKED task box
#      (`- [x] A-3`) anchors like an unchecked one -- an _archive of closed items,
#      the likeliest place `- [x]` appears, would otherwise silently stop
#      resolving. Removing spans that CONTAIN WHITESPACE would instead delete the
#      citing entry's own words, which is the exact thing rule 4 tests for:
#      `- [the note about this](#A-3) says otherwise` would anchor `A-3`. A status
#      marker does not contain whitespace; a sentence in brackets does. That is a
#      heuristic, not a law: a hyphenated bracketed citation (`[superseded-by-A-20]`)
#      is whitespace-free too, and is stripped like a status marker. It is a
#      false-match path, narrow but real, and named here rather than implied.
#
#
# --- Rule 1: the line must open an entry -------------------------------------
#
# A wrapped continuation line and an entry line are not separable by asking
# whether markup precedes the id, because inline markup precedes it in both:
#
#     - **A-20** -- the replacement item, which supersedes
#       **A-3** for the reason given above.     <- a citation, must NOT anchor
#
#     - **A-3** -- an entry                     <- an entry, must anchor
#
# The first revision asked "is there non-whitespace before the id?" and so said
# YES to both, false-matching a **bolded**, `backticked`, [linked], *italicised*
# or (parenthesised) id on a continuation line -- which is precisely how a ledger
# cites an id, making the false match the common case rather than the exotic one,
# in the direction that loses data.
#
# So rule 1 asks a structural question instead: does this line open a TOP-LEVEL
# ENTRY OF THIS FILE? It does when it begins, at COLUMN 0, with one of:
#
#     -  *  +   followed by whitespace      (bullet list)
#     1.  1)    followed by whitespace      (ordered list)
#     #  ##     followed by whitespace      (heading)
#     |                                     (table row)
#
# ...and is not inside a container (fenced code, an HTML comment, front matter).
#
# **Position, not appearance, and every earlier revision died learning why.** Each
# asked whether the line LOOKED like an entry and got a per-line answer that a
# CONTAINING structure invalidated:
#
#     - A-20 -- the replacement item. Supersedes:      <- the entry
#       - A-3                                          <- a citation, indented
#
#     - A-0 -- closed; quoted from the retro:
#       > - A-30 -- carries the remaining scope        <- a citation, quoted
#
#     ```
#     - A-7 -- an example entry                        <- not an entry at all
#     ```
#
# Every one of those lines "opens a block", and every one false-matched.
# Indentation, quoting, fencing, commenting and front matter are all ways markdown
# says *this line belongs to something else* -- and none is visible in the line's
# own marker. So the rule stops asking and requires the entry to be where a
# top-level entry necessarily is: column 0, outside every container it tracks.
# Nested means subordinate to the entry above it; quoted means someone else's
# ledger is being reproduced; fenced or commented means it is an example. None of
# them is *this file's own* entry, which is the exact question the caller asked.
#
# **The marker list is an enumeration, and enumeration is what failed the three
# prose rounds -- so why is this one different?** Not because a specification closes it.
# It is not CommonMark's block-start set (that also holds paragraphs, setext
# headings, HTML blocks and thematic breaks), and spec membership is not what
# makes a member safe -- `>` is unimpeachably a CommonMark block start, and
# admitting it is exactly what caused the second revision's bug. What matters is
# the direction a wrong member fails in. Every marker OMITTED from this list makes
# an entry invisible, never spurious, so omissions can only cost recall. What the
# list ADMITS is a separate question and does cost precision -- a lazy paragraph
# continuation beginning with a marker, and an over-long ordered marker, are both
# in the cost section below. The earlier rounds enumerated markers to decide a
# match on a line whose context they never established, which is why an unlisted
# one lost an entry silently and the next reset the clock.
#
#
# --- The cost -----------------------------------------------------------------
#
# Rule 1 makes invisible: an entry not at column 0 (nested under another entry,
# inside a block quote, or indented for any other reason), and an entry that
# begins with no marker at all (`A-3 -- the item`, `**A-3** -- the item`).
# Rule 4 adds its own: an id preceded on the line by a letter-bearing decoration
# that is not a bracket-delimited whitespace-free span (`- (draft) A-3`), or
# sitting in a table column after one that contains letters (`| open | A-3 |`).
#
# Rule 1 also makes invisible **everything after a container that never closes**:
# an unterminated fence, comment or front matter skips to end of file. That is the
# deliberate direction (see below), but it is unbounded, so it is named.
#
# --- The known false matches, and why the list is a floor -------------------
#
# Two mechanisms produce them, and both are named because a cost section listing
# only misses is what every earlier revision offered while carrying one.
#
#   1. **A container whose contents sit at column 0 and whose opener is not
#      tracked.** Tracked: fenced code, HTML comments, YAML front matter.
#      Untracked, and therefore false-matching: an HTML block such as <pre> or
#      <textarea>. (Indented code needs no tracking -- its contents are not at
#      column 0.) The FENCE and COMMENT openers are matched loosely on purpose --
#      at any indentation, and for a comment anywhere on the line -- because a
#      missed OPEN exposes content while a missed CLOSE only skips more of the
#      file. Front matter is the exception and is deliberately the strictest test
#      in this script: line 1 only, column 0 only, nothing else on the line. A
#      `---` anywhere else is a thematic break or a setext underline, and treating
#      one as front matter would blank the rest of the ledger.
#   2. **A lazy paragraph continuation that begins with a marker.** `2. A-3 ...`
#      or `|A-30| ...` at column 0, directly under an entry whose text wraps, is a
#      continuation of that entry rather than a new block -- but telling the two
#      apart needs CommonMark block-level state (was the previous line an open
#      paragraph?), which this deliberately does not carry. Only `1.` may
#      interrupt a paragraph, and no ordered marker at all may in a lazy
#      continuation, so this over-accepts.
#
# Rule 4 adds one more, unrelated to containment: a hyphenated bracketed citation
# (`[superseded-by-A-20]`) is whitespace-free, so it is stripped like a status
# marker. See rule 4 above.
#
# Two more admit-side costs, both narrow and both pinned as fixtures: front matter
# behind a UTF-8 BOM is not recognised, so its column-0 sequence items read as
# entries; and an ordered marker longer than nine digits is accepted where
# CommonMark stops at nine.
#
# A third, from removing commented spans rather than whole lines: the text before
# `<!--` is joined to the text after `-->`, and the join can MANUFACTURE a marker
# that exists on neither side (`-<!-- x --> A-3` reads as `- A-3`). It needs no
# space between the comment and the marker, so no hand-written ledger produces it,
# but it is a third mechanism rather than an instance of the two above.
#
# The matching recall cost is NOT that a line carrying a comment marker is missed
# -- an annotated entry (`- A-3 -- the item <!-- closed -->`) is seen normally.
# It is that an entry whose text quotes an unterminated `<!--` opens a comment that
# runs to end of file, taking every later entry with it. That is the unclosed-
# container case named above, reached through ordinary prose.
#
# **This list is a floor, not a proof.** Every revision of rule 1 before this one
# claimed a complete cost and every one turned out to carry an unlisted false
# match -- so the honest general statement is: any containment or continuation
# this does not model presents its lines as if they were entries.
#
# **Therefore exit 0 is strong evidence, never proof, and no caller should hang an
# unrecoverable action on it.** The one caller in this plugin does not: it reports
# a 0 as "probably moved" and still keeps both sides, leaving the deletion to a
# human who is already present at a merge conflict.
#
# Everything else above is a MISS, and that is chosen, not conceded, because the
# two errors are not symmetric:
#
#   * A miss says "not here" about an entry that is here. The caller falls through
#     to its keep-both default, and a resurrected entry can be removed again by
#     hand. Recoverable.
#   * A false match says "it is here" about a citation. In an _archive sibling
#     that means a live item is reported as already archived and dropped from the
#     live file -- on a branch that is then squash-merged and pruned, leaving its
#     own commits unreachable. Not recoverable from anywhere.
set -eu

# Arity is checked by hand rather than with `${1:?...}`, which exits 1 -- and 1 is
# this predicate's word for "no". A misuse that answers "no" is exactly the
# failure this script exists to prevent, one level up. Every way of not being
# asked a well-formed question leaves here as 2.
if [ "$#" -ne 2 ]; then
  echo "usage: entry-anchor.sh <id> <file>" >&2
  exit 2
fi

id="$1"
file="$2"

# An empty id is rejected inside awk, not here. A second guard at this level would
# be redundant -- and worse, it would SHADOW the awk one, leaving that one's
# `rc`/END interaction unexecuted by every fixture while looking covered.

# `-f` before `-r`: a DIRECTORY is readable, and awk then skips it and reports a
# clean end-of-input, which END would turn into a confident "no".
if [ ! -f "$file" ] || [ ! -r "$file" ]; then
  echo "entry-anchor.sh: not a readable file: $file" >&2
  exit 2
fi

# The id crosses into awk through the ENVIRONMENT, never through `-v` and never
# spliced into the program text. Two distinct reasons, both already observed:
#
#   * `-v name=value` runs escape processing on the value, so an id containing a
#     backslash arrives as something else. ENVIRON does not.
#   * The id is then only ever used with index() and substr(), which are LITERAL.
#     It is never compiled as a pattern. An id interpolated into an ERE turns
#     `A.1` into a pattern that also matches `AX1`, and an id holding `[` makes
#     the matcher ERROR -- which a surrounding `if` reads as a clean "no match",
#     the worst possible way for this predicate to fail.
status=0
WOW_ENTRY_ANCHOR_ID="$id" awk '
BEGIN {
  rc = -1
  id = ENVIRON["WOW_ENTRY_ANCHOR_ID"]
  n = length(id)
  # `exit rc`, not a bare `exit`: END is relied on to supply the status, and a
  # bare exit on an awk that skipped END would yield 0 -- which the caller reads
  # as "anchored", the worst of the three answers to arrive at by accident.
  if (n == 0) {
    print "entry-anchor.sh: <id> is empty -- cannot answer" > "/dev/stderr"
    rc = 2
    exit rc
  }
  # Every rule below is expressed with POSIX bracket classes. An awk that does not
  # support them (mawk 1.3.3, still the default `awk` on some older distributions)
  # treats [[:alpha:]] as a literal character set, which makes rule 4 pass for
  # almost every prefix -- it fails OPEN, in the false-match direction. Probe for
  # it and answer "could not tell" rather than answering wrongly.
  if ("a" !~ /[[:alpha:]]/ || "9" !~ /[[:alnum:]]/ || " " !~ /[[:space:]]/) {
    print "entry-anchor.sh: this awk lacks POSIX bracket classes -- cannot answer" > "/dev/stderr"
    rc = 2
    exit rc
  }
  found = 0
}
# Rule 1, in two steps. First skip CONTAINERS: a line inside one of these is
# content or an example, never an entry of this file, and nothing on the line
# itself says so. Three are tracked -- YAML front matter, HTML comments, fenced
# code. Indented code needs no tracking: its contents are not at column 0.
#
# **For a fence or a comment, closing is strict and opening is permissive, and the
# asymmetry is the point.** (Front matter is the exception, and the strictest test
# here: line 1 and column 0 only. A `---` anywhere else is a thematic break, and
# treating one as a container would blank the rest of the ledger.)
# A missed OPEN exposes content (false match, unrecoverable); a missed CLOSE only
# skips more of the file (miss, recoverable). An earlier revision had this
# backwards -- it closed a fence on any ``` line, so a longer opening run, an
# info string, or an indented inner fence each ended the block early and exposed
# the entries inside it.
NR == 1 && /^---[[:space:]]*$/ { front = 1; next }
front { if ($0 ~ /^---[[:space:]]*$/) { front = 0 } next }
# HTML comments, scanned marker by marker, and only outside a fence. Two things
# this has to get right that a pair of open/close pattern rules did not:
#
#   * It must not fire inside a fence. A `<!--` in a fenced markdown EXAMPLE
#     otherwise opens a comment that swallows the closing delimiter of that very
#     fence, and the file goes dark to end of file.
#   * One line can close a comment and open another (`--> text <!--`). A one-shot
#     open-or-close test reads that line as ordinary text and leaves every
#     commented-out entry under it exposed -- a false match, the direction that
#     matters.
!fence {
  keep = ""
  scan = $0
  while (1) {
    if (!comment) {
      k = index(scan, "<!--")
      if (k == 0) { keep = keep scan; break }
      keep = keep substr(scan, 1, k - 1)
      comment = 1
      scan = substr(scan, k + 4)
    } else {
      k = index(scan, "-->")
      if (k == 0) { break }
      comment = 0
      scan = substr(scan, k + 3)
    }
  }
  # The commented SPANS are removed and what remains is judged normally. An earlier
  # revision skipped the whole line instead, which cost two things: an ordinary
  # annotated entry (`- A-3 -- the item <!-- closed 2026-01 -->`) went unseen, and
  # a fence OPENER carrying a comment was consumed here before the fence rule
  # below could see it, so the example entries inside that fence were never
  # skipped at all -- a false match, in a container the header calls tracked.
  #
  # No explicit "skip if nothing is left" test: a blank remainder cannot match the
  # entry-marker rule below, so one would be redundant -- and a redundant guard is
  # indistinguishable from a live one under mutation, which is how two earlier
  # revisions of this file came to claim coverage they did not have.
  $0 = keep
}
/^[[:space:]]*(```|~~~)/ {
  # Indentation is measured in COLUMNS, not characters: a tab advances to the next
  # 4-column stop, so one tab is already the 4 columns that make a line indented
  # code rather than a fence marker. Counting characters let a tab-indented closer
  # end a fence early and expose the example entries inside it.
  # The loop consumes exactly the class the pattern above allows. When it consumed
  # only " " and "\t", a form feed or vertical tab passed the pattern, was not
  # consumed, and became the fence CHARACTER -- after which no real delimiter
  # could ever close the block.
  i = 1
  col = 0
  while (substr($0, i, 1) ~ /[[:space:]]/) {
    col = (substr($0, i, 1) == "\t") ? col + 4 - (col % 4) : col + 1
    i++
  }
  # Four or more columns of indent is indented code, not a fence marker -- so it
  # neither opens nor closes. Falling through is safe: the column-0 test below
  # rejects it for being indented.
  if (col < 4) {
    d = substr($0, i, 1)
    run = 0
    while (substr($0, i + run, 1) == d) run++
    rest = substr($0, i + run)
    if (!fence) { fence = 1; fchar = d; flen = run; next }
    # The CommonMark closer rule: same character, a run at least as long as the
    # opener, and nothing after it. Anything else is content inside the block.
    if (d == fchar && run >= flen && rest ~ /^[[:space:]]*$/) { fence = 0; next }
  }
}
fence { next }
# Then require an entry marker AT COLUMN 0 -- see the header. Anything indented,
# quoted or otherwise contained belongs to something else, and no occurrence on
# such a line can anchor, so do not even scan it. `[-*+]`, `[.)]` and `[|]` keep
# every metacharacter inside a bracket expression, where it is literal, rather
# than relying on backslashes surviving three levels of quoting. `#+` rather than
# `#{1,6}`: interval expressions are the other thing older awks do not have.
# `#######` (seven or more) is a paragraph in CommonMark, not a heading, so the
# hash run is capped at six. Spelled out rather than written `#{1,6}` because
# interval expressions are the other thing older awks do not have.
$0 !~ /^([-*+][[:space:]]|[0-9]+[.)][[:space:]]|##?#?#?#?#?[[:space:]]|[|])/ { next }
{
  line = $0
  start = 1
  # No `start <= length(line)` test: substr() past the end returns "", and index()
  # of a non-empty id in "" is 0, which ends the loop anyway. A redundant guard is
  # indistinguishable from a live one under mutation -- two have already been
  # deleted from this file for that reason.
  while ((p = index(substr(line, start), id)) > 0) {
    pos = start + p - 1
    prefix = substr(line, 1, pos - 1)
    before = (pos > 1) ? substr(line, pos - 1, 1) : ""
    after = substr(line, pos + n, 1)
    # Rule 4. Only whitespace-FREE bracketed spans are dropped -- see the header:
    # a wider strip deletes the words of the citing entry and reopens rule 4.
    probe = prefix
    gsub(/\[[^][:space:]]*\]/, "", probe)
    if (before !~ /[[:alnum:]._-]/ &&
        after  !~ /[[:alnum:]._-]/ &&
        probe  !~ /[[:alpha:]]/) {
      found = 1
      exit
    }
    # Advance past this occurrence and keep scanning the SAME line: a rejected
    # occurrence must not end the search, or an entry that cites another id
    # before its own anchor is missed.
    start = pos + 1
  }
}
END {
  if (rc >= 0) { exit rc }
  if (found == 1) { exit 0 }
  exit 1
}
' "$file" || status=$?

# 0 and 1 are this predicate answering. Anything else is awk failing to run it,
# which is "could not tell" -- never silently folded into "no".
case "$status" in
  0|1) exit "$status" ;;
  *)
    echo "entry-anchor.sh: awk exited $status -- that is an error, not a 'no'" >&2
    exit 2
    ;;
esac
