#!/bin/sh
# Replace, or read back, the `## Critic pass` section of a PR body (WB-D22, `#230`).
#
# A no-op handoff skips the ledger PR, so the critic pass's record -- round count, stopping
# condition, model provenance, which no command can re-derive -- has nowhere on `main` to
# live. `/way-of-working:handoff` writes it into the work PR's body instead, and the next
# ordinary handoff reads it back as DATA into the ledger. The text surgery is a tested
# script rather than prose because the ways it goes wrong are quiet: a heading inside a code
# fence taken for the real one, a replacement that eats the section after it, a CRLF body.
#
# Usage:
#   <pr body> | critic-section.sh put <section-file>   -> the new body on stdout
#   <pr body> | critic-section.sh get                  -> the section's text on stdout
#
# The heading is exactly `## Critic pass` at the start of a line (trailing whitespace and a
# carriage return tolerated), outside a code fence. A fence opens and closes on a line
# starting with three or more backticks or tildes, indented by at most three spaces; the
# closing line must use the opening character, be at least as long, and carry no info string
# (CommonMark). A deeper heading (`### Critic pass`) is not
# it. Only the FIRST such heading counts: put replaces that one and leaves any later copy
# alone, and get reads that one -- one rule for choosing the heading on both paths (get does not
# refuse an open fence; put does). This is NOT a defence against an
# editor inserting a section above the real one; the record is as trustworthy as the body.
# Where this parser still differs from the renderer: an HTML comment hides text only on
# GitHub; a fence inside a blockquote or list item is not tracked; and a backtick opener whose
# info string contains a backtick opens a fence here though CommonMark says it is not one. A
# hostile edit can therefore make this read a section the page does not show. It reaches main
# only through a human-merged ledger PR, where the text shows up in the diff.
#
# put: the section runs from its heading up to, not including, the next line starting with
# `## ` outside a fence, or to the end of the body. It is replaced with <section-file>, whose
# first line must be the heading and which must carry no other `## ` heading outside a fence
# (a stray one would make get truncate the record). With no such section in the body, the new
# one is APPENDED after one blank line (none at all when the body is empty). The body's other
# lines are copied byte for byte, line endings included.
#
# get: prints the section's lines after the heading, without a trailing blank line, and
# exits 0; exits 3, printing nothing, when the body has no such section.
#
# Exits 2, printing NOTHING to stdout, on a malformed invocation or section file, and (put) when
# the PR body ends inside an open code fence. The body
# is DATA: it is only ever matched and copied, never executed or interpreted.
#
# Permitted toolset: POSIX sh + awk. No jq, no yq, no python.
set -eu

die() { echo "critic-section.sh: $*" >&2; exit 2; }

mode="${1:-}"
case "$mode" in
  put)
    [ "$#" -eq 2 ] || die "usage: <pr body> | critic-section.sh put <section-file>"
    sec="$2"
    [ -f "$sec" ] || die "no such section file: $sec"
    ;;
  get) [ "$#" -eq 1 ] || die "usage: <pr body> | critic-section.sh get" ;;
  *) die "usage: <pr body> | critic-section.sh put <section-file> | get" ;;
esac

# A fence-aware line classifier shared by both modes. `kind(line)` is, for a line seen with
# the current fence state: "fence" toggles it; "h2" is a `## ` heading outside a fence;
# "crit" is the exact Critic pass heading outside a fence; "text" is anything else.
common='
  function stripcr(s) { sub(/\r$/, "", s); return s }
  # CommonMark: a fence opens on 3+ backticks or tildes (indented at most three spaces) and
  # closes on a line of the SAME character, at least as long as the opener, with nothing but
  # whitespace after it -- an info string never closes one, and neither does a shorter line.
  # Update the fence state for line s; returns 1 when s itself is a fence line.
  function track(s,    t, k, c, len, rest) {
    t = s
    for (k = 0; k < 3 && substr(t, 1, 1) == " "; k++) t = substr(t, 2)
    c = substr(t, 1, 1)
    if (c != "`" && c != "~") return 0
    len = 0
    while (substr(t, len + 1, 1) == c) len++
    if (len < 3) return 0
    rest = substr(t, len + 1)
    if (fchar == "") { fchar = c; flen = len; return 1 }
    if (c == fchar && len >= flen && rest ~ /^[ 	]*$/) { fchar = ""; flen = 0; return 1 }
    return 0
  }
  function is_h2(s)   { return fchar == "" && s ~ /^## / }
  function is_crit(s) { return fchar == "" && s ~ /^## Critic pass[ \t]*$/ }
'

if [ "$mode" = put ]; then
  # Validate the section file first, with the same fence rules, so a bad file prints nothing.
  awk "$common"'
    BEGIN { fchar = ""; flen = 0; n = 0 }
    { line = stripcr($0); n++ }
    n == 1 { if (line !~ /^## Critic pass[ \t]*$/) { bad = "first line is not the ## Critic pass heading"; exit } }
    n > 1 { if (track(line)) next; if (is_h2(line)) { bad = "carries another ## heading: " line; exit } }
    END {
      if (bad != "") { print "critic-section.sh: section file " bad > "/dev/stderr"; exit 2 }
      if (n == 0) { print "critic-section.sh: section file is empty" > "/dev/stderr"; exit 2 }
      if (fchar != "") { print "critic-section.sh: section file leaves a code fence open" > "/dev/stderr"; exit 2 }
    }
  ' "$sec" || exit 2

  # The section file travels through a file, not `-v`, which would run escape processing.
  out="$(mktemp)" || exit 2
  trap 'rm -f "$out"' EXIT INT TERM
  CS_SEC="$sec" awk "$common"'
    BEGIN {
      fchar = ""; flen = 0; replaced = 0; skipping = 0; any = 0
      while ((getline l < ENVIRON["CS_SEC"]) > 0) { sec[++ns] = l }
    }
    function emit_section(    i) { for (i = 1; i <= ns; i++) print sec[i] }
    {
      raw = $0; line = stripcr(raw); any = 1
      if (skipping) {
        if (track(line)) next
        if (is_h2(line)) { skipping = 0; print ""; any = 1 } else next
      } else {
        if (!replaced && is_crit(line)) {
          # the heading itself is not a fence line, so track() is not needed for it
          replaced = 1; skipping = 1; emit_section(); next
        }
        track(line)
      }
      print raw
      last_blank = (line == "")
    }
    END {
      # A body that ends inside an open fence would swallow an appended section (nothing could
      # find it again, and GitHub renders it as code) or the sections after a replaced one.
      if (fchar != "") { print "critic-section.sh: the PR body ends inside an open code fence" > "/dev/stderr"; exit 2 }
      if (!replaced) {
        if (any && !last_blank) print ""
        emit_section()
      }
    }
  ' >"$out" || exit 2
  cat "$out"
  exit 0
fi

# get
awk "$common"'
  BEGIN { fchar = ""; flen = 0; inside = 0; found = 0; nb = 0 }
  {
    line = stripcr($0)
    if (inside) {
      if (track(line)) { buf[++nb] = line; next }
      if (is_h2(line)) { inside = 0; done = 1; next }
      buf[++nb] = line; next
    }
    if (done) next
    if (is_crit(line)) { inside = 1; found = 1; next }
    track(line)
  }
  END {
    if (!found) exit 3
    while (nb > 0 && buf[nb] == "") nb--
    for (i = 1; i <= nb; i++) print buf[i]
  }
'
