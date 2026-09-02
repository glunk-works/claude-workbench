#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/entry-anchor.sh.
#
# The bug class this guards against is a rule that is wrong about a real ledger
# SHAPE, so every fixture is a real ledger line written out to a real file and
# fed to the real script -- not a mock of the matcher's internals. Every attempt
# at this predicate before the current one was wrong, each in a new direction and
# each about a shape nobody had written down. This file writes them down. See
# issue #66 and docs/decisions.md WB-D11 for the full sequence.
#
# The shape table below is the one in #66, reproduced row for row, plus the two
# citation collisions that issue mandates, plus every false-match class the earlier
# revisions of this script carried: markup before the id on a wrapped continuation
# line, the same thing inside a block quote, a citation the CONTAINING structure
# marks as subordinate (nested, quoted, fenced, commented, front matter), and a
# container closed early by a delimiter that should not have closed it.
#
# Every fixture here should FAIL if a rule it names is removed from the script.
# Several early ones did not -- they passed because a DIFFERENT rule happened to
# catch the same input, so deleting the rule they claimed to test left the suite
# green. That is only ever found by mutation, never by reading, so this suite is
# checked by deleting each guard in turn and confirming it goes red.
#
# FIVE things here are not pinned by a fixture, and a line-deletion sweep cannot
# establish that on its own. Both facts are re-derived by RUNNING the sweep, never
# carried forward: every previous version of this note was wrong, with a different
# count each time and a procedure that could not have measured what it claimed.
#
# THE UNIT IS A SUB-EXPRESSION, NOT A LINE. Deleting a whole line answers a
# different question whenever the line carries more than the guard. Of the four
# guards below, line deletion reports one green, one red for removing the
# assignment around it, one red for no longer parsing, and one hang -- four
# outcomes, none of them evidence about the guard. Mutate each on its own. Same
# for every compound condition: the fence-closer rule, the marker alternation,
# rule 4's own three conjuncts, the four-column threshold and the tab arithmetic
# were each measured a sub-expression at a time -- sixteen variants, all red.
#
# A RED CAN BE VACUOUS. 22 of the 69 reds are mutants that no longer run at all,
# as shell or as awk. Those say nothing about the line that was deleted, so line
# deletion leaves those guards untested and the sub-expression pass above is what
# actually covers them. Check runnability before counting a red as a pin.
#
# AND BOUND EACH RUN. Six deletions make the script NON-TERMINATING rather than
# wrong: the empty-id guard's exit, the comment loop's branch dispatch, the
# whitespace loop's initialiser and its advance, and the match loop's position and
# advance. (Not "every loop's advance" -- three other advances go red.) This suite
# has no timeout, so such a mutant hangs it forever instead of failing it, which
# is how an earlier attempt at this sweep stranded partway and left the count
# below asserted rather than measured. Count a hang as DETECTED, never as green.
#
# Four guards no fixture here can reach:
#   * the BEGIN probe for POSIX bracket classes, which needs an awk that lacks
#     them (mawk 1.3.3);
#   * the `(pos > 1) ? substr(...) : ""` guard on the `before` character, since a
#     conforming awk already returns "" for substr(s, 0, 1);
#   * `exit rc` rather than a bare `exit` in BEGIN, which only shows up on an awk
#     that skips END. Deleting that line OUTRIGHT is a different mutation and does
#     not go green -- it hangs, because the match loop's termination argument
#     assumes a non-empty id;
#   * the `[ ! -r "$file" ]` half of the readability check -- a PLATFORM limit,
#     not an awk one: on a Windows checkout `chmod 000` does not deny the owner a
#     read, so an unreadable-but-existing file cannot be constructed here.
#
# The fifth is not a guard at all: the `exit` after `found = 1` in the match loop.
# It short-circuits the rest of the file and cannot change the answer, so a
# contract that is exit status only can never pin it. It is named rather than
# deleted because the short-circuit is worth keeping.
#
# Measured. Candidates are every line that is not blank, not a comment, and not
# brace-only: 86 of the script's 417. Deleting each in turn gives 69 red (47 of
# them substantive, 22 vacuous), 6 hang, 11 green. The 11 are two lines of the
# bracket-class probe block, that `exit`, `set -eu`, five stderr diagnostics this
# suite deliberately never asserts, one initialiser awk supplies anyway
# (`found = 0`), and an optional `;;`. The other three guards go green only under
# sub-expression mutation.
#
# `col = 0` used to be in that green list, filed as a second harmless initialiser.
# It is not harmless: `col` is an awk global, so without the reset the previous
# fence line's column count carries into the next one and a 2-space-indented fence
# pair accumulates to 4, the closer reads as indented code, and the file goes dark
# from there. A live guard sat in this note as covered until a critic re-ran the
# sweep and asked what the "initialisers" actually did. It has a fixture now.
# Checked by doing it, not by believing it.
#
# Permitted toolset: POSIX sh + awk. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/entry-anchor.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

# The script's whole contract is its exit status, so that is what is asserted --
# never its stdout, which it does not have.
status_of() {
  st=0
  "$script" "$1" "$2" >/dev/null 2>&1 || st=$?
  echo "$st"
}

assert_eq_status() { # assert_eq_status <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected exit [$2], got [$3]" >&2
    fail=1
  fi
}

assert_status() { # assert_status <desc> <expected> <id> <file>
  assert_eq_status "$1" "$2" "$(status_of "$3" "$4")"
}

# One line, one file, one assertion -- the shape table's natural unit.
assert_line() { # assert_line <desc> <expected> <id> <line>
  printf '%s\n' "$4" >"$tmp/line.md"
  assert_status "$1" "$2" "$3" "$tmp/line.md"
}

echo "# the #66 shape table -- every row, matching on BL-3"

assert_line "plain bullet"            0 BL-3 '- BL-3 the item'
assert_line "bold run inside bullet"  0 BL-3 '- **BL-3** — the item'
assert_line "ordered list"            0 BL-3 '1. BL-3 the item'
assert_line "table row, first column" 0 BL-3 '| BL-3 | open |'
assert_line "code span"               0 BL-3 '- `BL-3` the item'
assert_line "task list checkbox"      0 BL-3 '- [ ] BL-3 the item'
assert_line "wrapped citation at column 0 is NOT an entry" \
                                      1 BL-3 'BL-3 did not hold, per the note.'

echo "# rule 1: the line must open an ENTRY (the regression class)"

# The first implementation asked only "is there non-whitespace before the id?",
# so every row below answered 0 -- a false match on a citation, which is the
# direction that drops a live item out of a ledger. They fire on this repo's own
# docs/decisions.md, where ids are cited in exactly these shapes.
assert_line "a BOLDED id on a continuation line"        1 BL-30 '  **BL-30**, which is still open.'
assert_line "a BACKTICKED id on a continuation line"    1 BL-30 '  `BL-30` is still open.'
assert_line "a LINKED id on a continuation line"        1 BL-30 '  [BL-30](#bl-30), still open.'
assert_line "an ITALICISED id on a continuation line"   1 BL-30 '  *BL-30* for the reason given above.'
assert_line "a PARENTHESISED id on a continuation line" 1 BL-30 '  (BL-30).'
assert_line "a QUOTED id on a continuation line"        1 BL-30 '  "BL-30" and others.'
assert_line "an em-dashed id on a continuation line"    1 BL-30 '  — BL-30 for the reason given above.'
assert_line "a bare id on an indented continuation line" 1 BL-3 '  BL-3 is the blocker.'

# CommonMark's own bullet rule is what separates `* item` from `*italics*`, and
# it is the whole reason the italic row above answers 1. If the entry-marker test
# ever stops requiring whitespace after the marker, this pair breaks apart.
assert_line "an asterisk followed by SPACE opens a list" 0 BL-3 '* BL-3 the item'
assert_line "an asterisk followed by TEXT does not"      1 BL-3 '*BL-3* the item'
# The bullet clause is not the only one that requires whitespace after the marker.
# These two pin the ordered-list and heading clauses, which the pair above does
# not reach -- deleting either clause's whitespace requirement left the suite
# green until these were added.
assert_line "a date is not an ordered-list marker" 1 BL-3 '2026.08.31 — BL-3 — 2'
assert_line "a hash with no space is not a heading" 1 BL-3 '#BL-3 — the item'

# Being QUOTED says nothing about whether the quoted line opens an entry. A rule
# phrased as "the line opens a block" admits every line of a blockquote, because
# `>` is unimpeachably a block start -- and the whole class above returns. Each
# row here is one of the rows above with `> ` in front of it.
assert_line "a bolded id inside a blockquote"        1 BL-3 '> **BL-3** for the reason given above.'
assert_line "a backticked id inside a blockquote"    1 BL-3 '> `BL-3` is still open.'
assert_line "a linked id inside a blockquote"        1 BL-3 '> [BL-3](#bl-3), still open.'
assert_line "an italicised id inside a blockquote"   1 BL-3 '> *BL-3* for the reason given above.'
assert_line "a parenthesised id inside a blockquote" 1 BL-3 '> (BL-3).'
assert_line "a bare id inside a blockquote"          1 BL-3 '>   BL-3 is the blocker.'
assert_line "a bare id inside an indented blockquote" 1 BL-3 '  > BL-3 is the blocker.'
assert_line "a bolded id inside a nested blockquote" 1 BL-3 '> > **BL-3**, which is still open.'

# The rows below asserted the DEFECT until the third revision. A quoted entry is
# someone else's ledger reproduced inside this one, and a nested entry is
# subordinate to the entry above it -- neither is a top-level entry of THIS file,
# which is the question the caller asked. Both are now misses, and a miss is
# recoverable. An earlier revision peeled the `>` and answered 0 to every row here.
assert_line "a quoted bullet entry is not this file's entry"  1 BL-3 '> - BL-3 the item'
assert_line "a quoted table row is not this file's entry"     1 BL-3 '> | BL-3 | open |'
assert_line "a doubly-quoted bullet entry"                    1 BL-3 '> > - BL-3 the item'
assert_line "a nested bullet is subordinate, not an entry"    1 BL-3 '  - BL-3 the nested item'
assert_line "a nested ordered item is subordinate"            1 BL-3 '  1. BL-3 the nested item'

echo "# rule 1: entry markers in combinations this suite never enumerated"

assert_line "plus bullet"             0 BL-3 '+ BL-3 the item'
assert_line "heading"                 0 BL-3 '### BL-3 — a heading-shaped entry'
assert_line "asterisk bullet + bold"  0 BL-3 '* **BL-3**'
assert_line "paren-style ordered list" 0 BL-3 '1) BL-3 the item'
assert_line "numbered + bold + span"  0 BL-3 '12. **`BL-3`** — the item'

echo "# rule 1's stated cost: an entry with no marker is a MISS"

# Documented in the script header, and deliberate: keep-both is recoverable.
# Pinned so the cost stays a known quantity rather than a surprise.
assert_line "a bold entry with no marker is not seen" 1 BL-3 '**BL-3** — the item'
assert_line "a bare entry at column 0 is not seen"    1 BL-3 'BL-3 — the item'

echo "# rule 2: the character BEFORE the id (no other rule catches these)"

# `12` is letter-free, so rule 4 lets it through and only the `before` guard
# rejects it. The original suite had no such row: its `XBL-3` case was caught by
# rule 4 instead, so deleting the `before` guard left the suite green.
assert_line "BL-3 must not fire inside 12BL-3"  1 BL-3 '- 12BL-3 the item'
assert_line "BL-3 must not fire inside 12.BL-3" 1 BL-3 '- 12.BL-3 the item'
assert_line "BL-3 must not fire inside 7-BL-3"  1 BL-3 '| 42 | 7-BL-3 |'

echo "# rule 3: the character AFTER the id"

assert_line "BL-3 must not fire inside BL-30"  1 BL-3 '- BL-30 the item'
assert_line "BL-1 must not fire inside BL-14"  1 BL-1 '- BL-14 the item'
assert_line "BL-3 must not fire inside BL-3.1" 1 BL-3 '- BL-3.1 the item'

echo "# rule 4: no letters between the entry marker and the id"

assert_line "a same-line citation is not an anchor" \
  1 BL-3 '- **BL-20** — the replacement item, which supersedes BL-3.'
assert_line "BL-3 must not fire inside XBL-3"  1 BL-3 '- XBL-3 the item'
# Bracketed spans are dropped before the letter test, so a CHECKED task box
# anchors like an unchecked one. Without this an _archive of CLOSED items -- the
# likeliest place `- [x]` appears -- would silently stop resolving.
assert_line "a checked task box"        0 BL-3 '- [x] BL-3 the item'
assert_line "a checked task box, caps"  0 BL-3 '- [X] BL-3 the item'
assert_line "a bracketed status marker" 0 BL-3 '- [WIP] BL-3 the item'
# The strip is narrow ON PURPOSE. A span containing whitespace is a sentence, not
# a status marker, and removing it deletes the citing entry's own words -- which
# is the exact thing rule 4 tests for. These three anchored before the strip was
# narrowed to whitespace-free spans.
assert_line "a link label must not be stripped away"   1 BL-3 '- [the note about this](#BL-3) says otherwise'
assert_line "a bracketed sentence must not be stripped away"   1 BL-3 '- [see the earlier discussion] BL-3 was closed there'
assert_line "a task box does not license stripping the rest"   1 BL-3 '- [x] [superseded by] BL-3'
# Its stated cost: a letter-bearing decoration that is NOT a bracketed span, and
# a table column sitting after one that contains letters. Both are misses.
assert_line "a parenthesised status marker is a miss" 1 BL-3 '- (draft) BL-3 the item'
assert_line "a table column after a lettered one is a miss" 1 BL-3 '| open | BL-3 |'
assert_line "a table column after a letter-free one anchors" \
  0 BL-3 '| 2026-08-31 | BL-3 | note |'

echo "# the id is matched as a LITERAL, never compiled as a pattern"

# `.` compiled as an ERE matches any character, so an interpolating matcher says
# yes to AX1 here. It must say no.
assert_line "A.1 must not match AX1"   1 'A.1' '- AX1 the item'
assert_line "A.1 matches A.1"          0 'A.1' '- A.1 the item'
# An id holding `[` makes an interpolating matcher ERROR, and a surrounding `if`
# reads that error as a clean "no match" -- the worst way for this to fail. Both
# rows below must be ordinary answers (0 and 1), never the 2 that means "could
# not tell".
assert_line "a bracket in the id matches, and does not error" \
                                       0 'A[1]' '- A[1] the item'
assert_line "a bracket in the id answers no, rather than erroring" \
                                       1 'A[1]' '- some other item entirely'
assert_line "a backslash in the id survives the crossing into awk" \
                                       0 'A\1' '- A\1 the item'

echo "# citation collision 1 -- a LIVE ledger citing the id it supersedes"

cat >"$tmp/live.md" <<'EOF'
# Backlog

- **BL-20** — the replacement item, which supersedes BL-3.
- **BL-21** — an unrelated item, which supersedes
  **BL-4** for the reason given above.
EOF
assert_status "BL-3 is cited on one line, never anchored" 1 BL-3 "$tmp/live.md"
assert_status "BL-4 is cited across a wrap, never anchored" 1 BL-4 "$tmp/live.md"
assert_status "BL-20 is a real entry" 0 BL-20 "$tmp/live.md"
assert_status "BL-21 is a real entry" 0 BL-21 "$tmp/live.md"

echo "# citation collision 2 -- an ARCHIVE citing an id that is still live"

# This is the unrecoverable direction: a false anchor here reports a live item as
# already archived, and the caller drops it from the live file.
cat >"$tmp/archive.md" <<'EOF'
# Backlog — archive

- BL-0 — closed; it was blocked on BL-30 for most of its life.
- BL-1 — closed; superseded by
  [BL-31](#bl-31), which is still open.
EOF
assert_status "BL-30 is cited in an archive, never anchored" 1 BL-30 "$tmp/archive.md"
assert_status "BL-31 is cited across a wrap in an archive, never anchored" \
  1 BL-31 "$tmp/archive.md"
assert_status "BL-0 is a real archive entry" 0 BL-0 "$tmp/archive.md"
assert_status "BL-1 is a real archive entry" 0 BL-1 "$tmp/archive.md"

echo "# containment: a citation the CONTAINING structure marks as subordinate"

# The third false-match class, and the one no single-line fixture could catch:
# every line below opens a block on its own terms. What makes each a citation is
# the structure it sits inside -- a parent entry, a quote, a fence -- which the
# line itself does not carry. This is the shape /way-of-working:retro's
# "cite the id you supersede" mandate actually produces.
cat >"$tmp/nested-citations.md" <<'EOF'
- **BL-20** — the replacement item. Supersedes:
  - BL-3
  - BL-4

- **BL-21** — closed. Blocked by, at the time:
  1. BL-30
EOF
assert_status "a sub-bullet citation list, first id"  1 BL-3 "$tmp/nested-citations.md"
assert_status "a sub-bullet citation list, second id" 1 BL-4 "$tmp/nested-citations.md"
assert_status "a nested ordered citation"             1 BL-30 "$tmp/nested-citations.md"
assert_status "the parent entries still anchor"       0 BL-20 "$tmp/nested-citations.md"
assert_status "the second parent entry still anchors" 0 BL-21 "$tmp/nested-citations.md"

cat >"$tmp/quoted-list.md" <<'EOF'
- BL-0 — closed; the reasoning is quoted from the retro:

  > We closed BL-0 because the follow-up work moved to a new item:
  >
  > - BL-30 — carries the remaining scope; still open, must not be dropped.
  > - BL-31 — the second half.
EOF
assert_status "a quoted LIST, not just a quoted paragraph" 1 BL-30 "$tmp/quoted-list.md"
assert_status "the second quoted list item"                1 BL-31 "$tmp/quoted-list.md"
assert_status "the quoting entry still anchors"            0 BL-0 "$tmp/quoted-list.md"

# A fence is a CONTEXT marker: the lines inside it are examples of entries, not
# entries. Nothing on the fenced line itself says so, which is why the fence has
# to be tracked across lines rather than tested per line.
cat >"$tmp/fenced.md" <<'EOF'
# Backlog — archive

- BL-9 — closed.

The ledger format looks like this:

```markdown
- BL-3 — an example entry, never a real one
```

or, indented:

    - BL-7 — another example

- BL-8 — a real entry after the fence closed.
EOF
assert_status 'an entry shape inside a fenced block' 1 BL-3 "$tmp/fenced.md"
assert_status "an entry shape in indented code"     1 BL-7 "$tmp/fenced.md"
assert_status "a real entry before the fence"       0 BL-9 "$tmp/fenced.md"
# Proves the fence toggles OFF again: a matcher that skipped to end of file after
# the opening fence would also answer 1 to BL-3 and BL-7, for the wrong reason.
assert_status "a real entry after the fence closed" 0 BL-8 "$tmp/fenced.md"

# The closing delimiter must match the opening one, or a ~~~ inside a ``` block
# closes it early and exposes the rest of the block.
cat >"$tmp/mixed-fence.md" <<'EOF'
```markdown
Here is a nested fence marker:
~~~
- BL-5 — still inside the outer fence
~~~
```
EOF
assert_status "a mismatched inner fence does not end the outer one" \
  1 BL-5 "$tmp/mixed-fence.md"

# Closing is STRICT and opening is PERMISSIVE, and the asymmetry is the point: a
# missed OPEN exposes content (false match, unrecoverable), a missed CLOSE only
# skips more of the file (miss, recoverable). An earlier revision had it backwards
# and closed on any ``` line, so each row below exposed the entries inside.
cat >"$tmp/long-fence.md" <<'EOF'
````markdown
The format is:
```
- BL-3 — an example entry, never a real one
````
EOF
assert_status "a shorter inner run does not close a longer fence" \
  1 BL-3 "$tmp/long-fence.md"

cat >"$tmp/info-fence.md" <<'EOF'
```
Write the ledger like this:
```markdown
- BL-3 — an example
```
EOF
assert_status "a closer carrying an info string is not a closer" \
  1 BL-3 "$tmp/info-fence.md"

cat >"$tmp/indented-closer.md" <<'EOF'
```markdown
Nested example, indented for readability:
    ```
- BL-3 — still inside the outer fence
```
EOF
assert_status "a closer indented four spaces is content, not a closer" \
  1 BL-3 "$tmp/indented-closer.md"

# The indent is measured per line, and `col` is an awk GLOBAL, so it has to be
# reset before each measurement. Without the reset the previous fence line's
# column count carries into the next one: two 2-space-indented fences accumulate
# to 4, the closer reads as indented code, the fence never closes, and the rest
# of the file goes dark. An indented fence pair under a list item is an ordinary
# ledger shape, so this is a live path, not a contrivance.
cat >"$tmp/indent-carryover.md" <<'EOF'
  ```
  ```
- BL-3 — a real entry, after the indented fence closed
EOF
assert_status "a second indented fence is measured from zero, not cumulatively" \
  0 BL-3 "$tmp/indent-carryover.md"

# ...and the mirror: a fence-looking line inside INDENTED code must not open a
# fence, or every entry after it is silently lost for the rest of the file.
cat >"$tmp/indented-code.md" <<'EOF'
    $ cat ledger.md
    ```markdown

- BL-8 — a real entry, after the indented block
EOF
assert_status "a fence marker inside indented code does not open a fence" \
  0 BL-8 "$tmp/indented-code.md"

echo "# containment: blocks that are not code at all"

# Both of these present their contents at column 0, so the column-0 rule alone
# does not reach them. A commented-out entry is a plausible archive shape.
cat >"$tmp/comment.md" <<'EOF'
<!--
- BL-3 — parked; commented out rather than deleted so the id is preserved.
-->

- BL-8 — a real entry after the comment.
EOF
assert_status "an entry inside an HTML comment"     1 BL-3 "$tmp/comment.md"
assert_status "a real entry after the comment ends" 0 BL-8 "$tmp/comment.md"

cat >"$tmp/frontmatter.md" <<'EOF'
---
supersedes:
- BL-3
---

- BL-8 — a real entry after the front matter.
EOF
assert_status "a list item inside YAML front matter" 1 BL-3 "$tmp/frontmatter.md"
assert_status "a real entry after the front matter"  0 BL-8 "$tmp/frontmatter.md"

# Front matter is only front matter at the top of the file. A `---` elsewhere is a
# thematic break or a setext underline, and must not open a skip that eats the
# rest of the ledger.
cat >"$tmp/thematic-break.md" <<'EOF'
- BL-1 — the first entry.

---

- BL-8 — a real entry after a thematic break.
EOF
assert_status "a mid-file --- does not open front matter" 0 BL-8 "$tmp/thematic-break.md"

echo "# containment: a FENCE or COMMENT opener is recognised loosely on purpose"

# Fence and comment openers are matched at any indentation and, for comments,
# anywhere on the line. (Front matter is the exception -- line 1 only, pinned by
# the thematic-break row above.)
# Each row below was a false match until that was so: the opener went unrecognised,
# so the container never opened and its contents read as entries at column 0.
cat >"$tmp/indented-fence.md" <<'EOF'
 ```markdown
- BL-3 — an example entry, never a real one
 ```
EOF
assert_status "a one-space-indented fence still opens" 1 BL-3 "$tmp/indented-fence.md"

cat >"$tmp/indented-comment.md" <<'EOF'
  <!--
- BL-3 — parked; commented out rather than deleted.
  -->
EOF
assert_status "a two-space-indented comment still opens" 1 BL-3 "$tmp/indented-comment.md"

cat >"$tmp/midline-comment.md" <<'EOF'
Parked for now. <!-- revive these when the upstream lands:
- BL-3 — parked; commented out rather than deleted so the id is preserved.
-->

- BL-8 — a real entry after the comment.
EOF
assert_status "a comment opened mid-line still opens"  1 BL-3 "$tmp/midline-comment.md"
assert_status "and still closes"                       0 BL-8 "$tmp/midline-comment.md"

# ...but a comment opener inside a FENCE is an example of one, not one. Matching it
# there opened a comment that swallowed the closing delimiter of that very fence,
# and the file went dark to end of file.
cat >"$tmp/comment-in-fence.md" <<'EOF'
# Backlog

```js
const parked = "<!--";
```

- BL-8 — a real entry after the fence
EOF
assert_status "a comment opener inside a fence is inert" 0 BL-8 "$tmp/comment-in-fence.md"

# The commented SPANS are removed and what remains is judged normally. Skipping
# the whole line instead cost an ordinary annotated entry...
assert_line "an entry carrying an inline comment still anchors" \
  0 BL-3 '- BL-3 — the item <!-- closed 2026-01 -->'
# The marker must sit OUTSIDE the comment for this to pin anything. With `<!--` at
# column 0 the entry-marker rule answers 1 on its own, and the row passed against a
# build with the comment scanner deleted entirely.
assert_line "an entry that is entirely commented does not" \
  1 BL-3 '- <!-- BL-3 — parked -->'
# ...and, worse, ate a fence OPENER that carried a comment, so the example entries
# inside that fence were never skipped at all -- a false match, in a container the
# header calls tracked.
cat >"$tmp/fence-opener-comment.md" <<'EOF'
```markdown <!-- illustrative -->
- BL-3 — an example entry
```
EOF
assert_status "a fence opener carrying a comment still opens the fence" \
  1 BL-3 "$tmp/fence-opener-comment.md"

cat >"$tmp/comment-closing-on-opener.md" <<'EOF'
<!-- note
--> ```markdown
- BL-3 — an example entry
```
EOF
assert_status "a comment closing on a fence-opening line" \
  1 BL-3 "$tmp/comment-closing-on-opener.md"

# The scan must ADVANCE past an opener it consumed. Without that, the search for a
# closer runs back over the `<!--` it just matched, so `<!-->` closes the comment it
# should have opened and everything under it reads as entries at column 0.
cat >"$tmp/empty-comment.md" <<'EOF'
<!-->
- BL-3 — inside the comment
-->
EOF
assert_status "an empty comment opener does not close itself" \
  1 BL-3 "$tmp/empty-comment.md"

# One line can CLOSE a comment and OPEN another. A one-shot open-or-close test
# reads that line as ordinary text, and every commented-out entry under it is
# exposed -- a false match, the direction that matters.
cat >"$tmp/comment-reopen.md" <<'EOF'
<!--
- BL-1 — parked
--> live text here <!--
- BL-3 — parked in the SECOND comment
-->

- BL-8 — a real entry
EOF
assert_status "an entry in the first comment"          1 BL-1 "$tmp/comment-reopen.md"
assert_status "an entry in a comment reopened on the closing line" \
                                                       1 BL-3 "$tmp/comment-reopen.md"
assert_status "a real entry after both comments close" 0 BL-8 "$tmp/comment-reopen.md"

# The indent scan must consume exactly the whitespace class the fence pattern
# admits. Consuming only " " and "\t" let a form feed pass the pattern unconsumed
# and become the fence CHARACTER, after which no real delimiter could close it.
printf '\f```markdown\n- BL-3 — example\n```\n\n- BL-8 — real\n' >"$tmp/formfeed.md"
assert_status "an exotic whitespace fence still closes" 0 BL-8 "$tmp/formfeed.md"

# The fence pattern is anchored. Unanchored, an inline ``` in an entry makes `-` the
# fence character, opens a bogus fence, and the rest of the file goes dark.
cat >"$tmp/inline-fence.md" <<'EOF'
- BL-9 mentions ```fenced``` inline
- BL-8 a real entry after it
EOF
assert_status "an inline fence marker does not open a fence" 0 BL-8 "$tmp/inline-fence.md"
assert_status "and the entry carrying it still anchors"      0 BL-9 "$tmp/inline-fence.md"

# Indentation is measured in COLUMNS. One tab is already four columns, so a
# tab-indented closer is content -- counting characters ended the fence here and
# exposed the entries inside it.
printf '%s\n' '```markdown' 'Nested example, indented with a TAB:' "$(printf '\t')\`\`\`" \
  '- BL-3 — still inside the outer fence' '```' >"$tmp/tab-closer.md"
assert_status "a TAB-indented closer is content, not a closer" \
  1 BL-3 "$tmp/tab-closer.md"

echo "# rule 1: the marker set is capped where CommonMark caps it"

assert_line "six hashes is a heading"        0 BL-3 '###### BL-3 — the item'
assert_line "seven hashes is a paragraph"    1 BL-3 '####### BL-3 is mentioned here'

echo "# KNOWN false matches, pinned so they stay known"

# These are documented in the script header's cost section, NOT fixed. Telling a
# lazy paragraph continuation from a new block needs CommonMark block-level state
# (was the previous line an open paragraph?), which this deliberately does not
# carry. They are pinned at their CURRENT answer so the cost section cannot drift
# away from the behaviour, and so a later fix shows up here as a failing row
# rather than as a silent improvement nobody records. Each row says which way a
# fix should move it, so a maintainer seeing one go red can tell "I fixed it"
# from "I broke it" without leaving this file.
cat >"$tmp/lazy-ordered.md" <<'EOF'
- BL-20 — the replacement item, which supersedes items
2. BL-3 and others were folded into it.
EOF
assert_status "KNOWN false match (fix => expect 1): lazy ordered continuation" \
  0 BL-3 "$tmp/lazy-ordered.md"

cat >"$tmp/lazy-pipe.md" <<'EOF'
- BL-0 — closed; the table of blockers at close was
|BL-30| open | which we tracked separately.
EOF
assert_status "KNOWN false match (fix => expect 1): lazy pipe continuation" \
  0 BL-30 "$tmp/lazy-pipe.md"

cat >"$tmp/pre-block.md" <<'EOF'
<pre>
- BL-3 — an example entry inside an untracked HTML block
</pre>
EOF
assert_status "KNOWN false match (fix => expect 1): an untracked HTML block" \
  0 BL-3 "$tmp/pre-block.md"

# Not a containment defect at all -- this one comes from rule 4. A hyphenated
# bracketed citation is whitespace-free, so it is stripped like a status marker
# and the letters that would have rejected the line go with it. The cost section
# names it; without a row here it could change answer silently.
assert_line "KNOWN false match (fix => expect 1): a hyphenated bracketed citation" \
  0 BL-3 '- [see-the-earlier-note] BL-3 was closed there'

# A BOM before line 1 defeats the front-matter opener, exposing the YAML body.
# Named in the cost section rather than fixed: normalising encodings is a larger
# question than a hint in a human-read report warrants.
# OCTAL, not \x: dash is /bin/sh on CI, and its printf renders \xef as the
# two-byte UTF-8 encoding of U+00EF rather than the single byte a BOM needs.
# The row would still have passed there -- for the wrong reason, and a real fix
# would then not have turned it red.
printf '\357\273\277---\nsupersedes:\n- BL-3\n---\n' >"$tmp/bom-frontmatter.md"
assert_status "KNOWN false match (fix => expect 1): a BOM before front matter" \
  0 BL-3 "$tmp/bom-frontmatter.md"

# CommonMark caps an ordered-list marker at nine digits; `[0-9]+` does not. The
# second admit-side precision cost, alongside the lazy continuations above.
assert_line "KNOWN false match (fix => expect 1): a ten-digit ordered marker" \
  0 BL-3 '1234567890. BL-3 mentioned in prose'

# Removing a commented span joins what is left, and the join can manufacture a
# marker neither side had. Needs no space between the comment and the marker, so no
# hand-written ledger produces it -- but it is a mechanism of its own, so it is
# named in the cost section and pinned here.
assert_line "KNOWN false match (fix => expect 1): a marker made by joining round a comment" \
  0 BL-3 '-<!-- x --> BL-3 the item'

echo "# a rejected occurrence must not end the search"

# The citation comes FIRST here. A matcher that stops at its first hit -- or at
# its first REJECTED hit -- answers no, and the caller keeps an item that really
# was archived, undoing a close.
cat >"$tmp/cited-then-entered.md" <<'EOF'
- BL-9 — closed; this one was always confused with BL-3.
- BL-3 — closed as well.
EOF
assert_status "an id cited above its own entry still anchors" \
  0 BL-3 "$tmp/cited-then-entered.md"

# Same, within a single line: the first occurrence is a citation, the second
# cannot anchor either (its prefix carries the citing entry's words). The line
# must be scanned to its end and still answer no.
assert_line "two rejected occurrences on one line still answer no" \
  1 BL-3 '- **BL-20** — supersedes BL-3, which itself replaced BL-3.'

# The row above CANNOT fail from a truncated scan -- abandoning the line after the
# first rejected occurrence also answers 1, so it pinned nothing. This one does:
# `1-1` is rejected inside `41-1` by rule 2, then anchors in the next column, so
# the answer flips to 1 the moment the intra-line advance stops.
assert_line "the scan resumes after a rejected occurrence on the same line" \
  0 '1-1' '| 41-1 | 1-1 | open |'

echo "# a CRLF checkout answers the same as an LF one"

# No line of the script is dedicated to this any more -- an earlier revision
# stripped a trailing CR, and removing that strip left the whole suite green,
# because a CR can only ever land in the `after` position where it already passes
# the id-continuation test. These rows assert the OUTCOME, which is what the
# caller depends on, rather than the existence of a mechanism.
printf -- '- BL-3 the item\r\n- BL-4 the item\r\n' >"$tmp/crlf.md"
assert_status "CRLF, id mid-line"       0 BL-3 "$tmp/crlf.md"
assert_status "CRLF, id at end of line" 0 BL-4 "$tmp/crlf.md"
printf -- '  **BL-30**, still open.\r\n' >"$tmp/crlf-cite.md"
assert_status "CRLF, a cited id is still not anchored" 1 BL-30 "$tmp/crlf-cite.md"

echo "# 'could not tell' is exit 2, and is never folded into 'no'"

assert_status "a file that does not exist" 2 BL-3 "$tmp/no-such-file.md"
# A directory is readable, and awk skips it and reports a clean end of input --
# which END would otherwise turn into a confident "no".
assert_status "a directory instead of a file" 2 BL-3 "$tmp"
printf '%s\n' '- BL-3 the item' >"$tmp/line.md"
assert_status "an empty id" 2 '' "$tmp/line.md"

# Misuse must not answer "no" either. `${1:?...}` exits 1, which IS this script's
# word for "not anchored", so a caller that forgot an argument would read a
# confident negative -- the same conflation the exception exists to avoid.
arity=0
"$script" BL-3 >/dev/null 2>&1 || arity=$?
assert_eq_status "one argument instead of two" 2 "$arity"
arity=0
"$script" >/dev/null 2>&1 || arity=$?
assert_eq_status "no arguments at all" 2 "$arity"
arity=0
"$script" BL-3 "$tmp/line.md" extra >/dev/null 2>&1 || arity=$?
assert_eq_status "three arguments" 2 "$arity"

# Nothing in the fixtures above can make awk exit outside {0,1,2}, so the shell
# `case` mapping everything else to 2 was unpinned -- the very conflation that
# case exists to prevent went untested. A stub `awk` earlier on PATH supplies it.
mkdir -p "$tmp/fakebin"
printf '#!/bin/sh\nexit 3\n' >"$tmp/fakebin/awk"
chmod +x "$tmp/fakebin/awk"
awkfail=0
PATH="$tmp/fakebin:$PATH" "$script" BL-3 "$tmp/line.md" >/dev/null 2>&1 || awkfail=$?
assert_eq_status "an awk that fails outright is 'could not tell', not 'no'" 2 "$awkfail"

echo "# an empty file is a clean no, not an error"

: >"$tmp/empty.md"
assert_status "an empty ledger" 1 BL-3 "$tmp/empty.md"

exit "$fail"
