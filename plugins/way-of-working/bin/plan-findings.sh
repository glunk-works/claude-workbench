#!/bin/sh
# The mechanical half of /way-of-working:plan-sprint's `findings` mode: which open issues are the
# declared reviewer App's grouped review-finding issues, how one issue's body unpacks into findings,
# whether a cited path still exists, whether a composed text passes the screens, whether a
# mapping comment names every finding, and which findings issues a planning pass has left
# unresolved (the placement guard, `held`). The judgment (the table, the destinations, the dialogue) stays
# in the skill body, as for the rest of plan-sprint; this script only reads, parses and screens.
#
# Usage:
#   plan-findings.sh list <repo> <project.yml>
#   plan-findings.sh unpack <issue.json>
#   plan-findings.sh exists <ref>                      (paths one per line on stdin)
#   plan-findings.sh screen <file>
#   plan-findings.sh covers <N> <rows-file> <comment-file>
#   plan-findings.sh label <repo> <value>
#   plan-findings.sh filed <issue.json> <value> <body-file>
#   plan-findings.sh held <list-file> <kept-file>
#
#   list      <project.yml> is the DEFAULT branch's committed copy, already written to a file. The
#             sibling declared-ids.sh runs on it (as `sh`, found only beside this script) and its line
#             must start with `ok `; then `.identities.reviewer_app.id` is read with yq. `no-map`
#             (no identities map) and a missing or null reviewer App exit 3 with a stderr line and
#             nothing on stdout: the repo declares no reviewer App, so there are no findings issues
#             to read. `unreadable`, or a non-zero exit or empty output from declared-ids.sh, a
#             missing yq or an unreadable project file exits 1 with a stderr line and nothing on
#             stdout. Fetches every open
#             issue of <repo> (paginated, to a file by direct redirection, the way plan-gather.sh
#             fetches), keeps true issues (pull requests dropped) whose author's NUMERIC ID equals
#             that id (a login is never compared), and prints TSV: number, created_at, milestone
#             number or `none`, comma-joined `area/` labels or `none`. Sorted ascending by number
#             under LC_ALL=C. A failed `gh` call exits non-zero, never reads as zero rows; empty stdout
#             with exit 0 legitimately means none.
#   unpack    No `gh` call. <issue.json> is the caller's own fetch of ONE issue. The body is split on
#             LF only and one trailing CR is removed from each line before matching. For issue N it
#             prints TSV rows: `source`, N, the source PR number parsed from the `review of <repo>#digits at `
#             part of the body's first line (or `none` when that line has no such part); then per finding `finding`, `N.k`, `open` or `ticked`, the finding's
#             title (tabs and control characters replaced by a space); then one `path`, `N.k`, <path>
#             row per distinct backtick span in that finding's block that has a slash, uses only
#             letters, digits, `.`, `_`, `-` and `/`, and has no empty, `.` or `..` segment.
#             A finding is a column-0 `- [ ] Finding k` or `- [x] Finding k` line, the layout
#             `file_findings` in scripts/identity/wow-review writes (each finding's text indented two
#             spaces inside a fence of three or more backticks, its title the first non-blank line after the
#             opening fence line), so a look-alike line inside the indented block is never a finding. A
#             finding's block runs from its finding line to the next non-blank column-0 line (a line of
#             spaces only is blank). The title is the first non-blank line after the opening fence line
#             (the first line of backticks only in the block; a `Paths:` line before it is never the
#             title), its two-space indent removed; fence lines are never part of a backtick span. Finding numbers must each be at least 1 and strictly increasing, gaps
#             allowed. A column-0 `- Finding K: also reported in #M` line, `#M` one or more `#digits` joined by a comma and a space, is accepted: it is never a
#             finding, its number is not checked and it adds no row. Any other column-0 line that
#             starts with `- [` or `- Finding`, a body with no finding line, and a repeated or
#             decreasing finding number make it print only `unparsed N` (a space, not a tab), exit 0.
#   exists    Reads paths one per line on stdin; prints `path`, a tab, then `present`, `absent` or
#             `bad-name` per line: `bad-name` fails the `path` row's character rule above, `absent` is
#             no such path in the tree at <ref> (read in the current directory's git repository), else
#             `present`. No `gh` call. <ref> must resolve to a commit, else exit 1.
#   screen    One word on stdout, exit 0: `ok`, `refused <reason>` or `unreadable`. Refuses the forms
#             spec-issue.sh's hidden-text screen refuses (its HID, HREF and LDEF lines, copied byte for
#             byte from spec-fresh.sh, and its awk program, copied byte for byte from spec-issue.sh;
#             tests/plan-findings.test.sh pins both), then any shape the sibling leak-screen.sh reports
#             (its verdict passed through as the reason), then any `@` followed by a letter or digit
#             (a mention). Never prints matched text.
#   covers    `none` when <rows-file> (the concatenated `unpack` output) has no `finding` row for issue
#             <N> (an `unparsed N` issue included); else `ok` when <comment-file> names every `N.k` the
#             rows list for <N> (each as `#N.k` followed by a non-digit or the end of a line), else
#             `missing k1,k2,...`.
#   label     <value> is well formed when the whole value is `area/` followed by one or more of
#             `a-z`, `0-9` and `-`, and nothing else (a newline anywhere fails it); a value that is
#             not prints `bad-name`. Fetches the names of <repo>'s labels (paginated, to a file in
#             the script's own temp directory by direct redirection); a failed `gh` call exits 1 with
#             a stderr line and nothing on stdout, never reads as no labels. Prints `ok` when one
#             fetched name equals <value> exactly as a whole line, else `unknown`.
#   filed     No `gh` call. <issue.json> is the caller's own fetch of ONE issue, <body-file> the
#             body that was sent. Either file that is not a readable file, or an issue file yq cannot
#             read as JSON, exits 1 with a stderr line. <value> is checked as for `label`
#             (`bad-name`). Prints `no-label` when no entry of the issue's labels has a name equal to
#             <value>, else `body-differs` when the issue's body and <body-file> differ once trailing
#             newlines are dropped from each, else `ok`.
#   held      No `gh` call. The placement guard. <list-file> is the `list` subcommand's output (four TSV
#             fields per row). <kept-file> holds issue numbers one per line, and may be empty; a blank
#             line in it is ignored. Prints, one per line in ascending number order, the number of each
#             row whose milestone field is `none` and whose number is not a whole line of <kept-file>.
#             Empty stdout with exit 0 means nothing is held. Either file not readable, a list row with
#             other than four TSV fields, a list row whose number is not digits-only, or a non-blank
#             kept line that is not digits-only exits 1 with a stderr line and nothing on stdout.
#
# Exit codes: a wrong argument count, an unknown subcommand or a non-digit <N> prints a usage line on
# stderr, nothing on stdout, and exits 2. `list` exits 3 (stderr line, nothing on stdout) when the repo
# declares no identities map or no reviewer App. Every other failure exits 1 with a stderr line. The
# verdict words of screen, covers, label and filed, and the numbers `held` prints, go on stdout with
# exit 0.
#
# Permitted toolset: POSIX sh, awk, grep, sed, sort, tr, mktemp, git (exists only), yq (mikefarah v4;
# list, unpack and filed), `gh` using only its own embedded --jq (list and label only), and the siblings
# declared-ids.sh and leak-screen.sh, run as `sh` and found only as $(dirname "$0")/<name>.
set -eu
LC_ALL=C
export LC_ALL

tab="$(printf '\t')"

usage() {
  echo "plan-findings.sh: usage: plan-findings.sh list <repo> <project.yml>" >&2
  echo "                         plan-findings.sh unpack <issue.json>" >&2
  echo "                         plan-findings.sh exists <ref>   (paths on stdin)" >&2
  echo "                         plan-findings.sh screen <file>" >&2
  echo "                         plan-findings.sh covers <N> <rows-file> <comment-file>" >&2
  echo "                         plan-findings.sh label <repo> <value>" >&2
  echo "                         plan-findings.sh filed <issue.json> <value> <body-file>" >&2
  echo "                         plan-findings.sh held <list-file> <kept-file>" >&2
}

mode="${1:-}"
case "$mode" in
  list) [ "$#" -eq 3 ] || { usage; exit 2; } ;;
  unpack | exists | screen) [ "$#" -eq 2 ] || { usage; exit 2; } ;;
  label) [ "$#" -eq 3 ] || { usage; exit 2; } ;;
  covers | filed) [ "$#" -eq 4 ] || { usage; exit 2; } ;;
  held) [ "$#" -eq 3 ] || { usage; exit 2; } ;;
  *) usage; exit 2 ;;
esac

tmp="$(mktemp -d)" || { echo "plan-findings.sh: could not create a temp dir" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT

is_digits() { # true iff $1 is one or more ASCII digits
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

good_area() { # true iff $1 is `area/` then one or more of a-z, 0-9 and `-`, nothing else
  case "$1" in
    area/*) _r="${1#area/}" ;;
    *) return 1 ;;
  esac
  case "$_r" in
    '' | *[!a-z0-9-]*) return 1 ;;
    *) return 0 ;;
  esac
}

sibling() { # sibling <name> -- the path of a script beside this one, or exit 1
  case "$0" in
    */*) _s="$(dirname "$0")/$1" ;;
    *) echo "plan-findings.sh: must be run by path (a slash-less \$0 cannot locate $1)" >&2; exit 1 ;;
  esac
  [ -f "$_s" ] || { echo "plan-findings.sh: $1 not beside this script" >&2; exit 1; }
  printf '%s' "$_s"
}

# =============================================================================
if [ "$mode" = list ]; then
  repo="$2"; yml="$3"
  di="$(sibling declared-ids.sh)"
  [ -f "$yml" ] && [ -r "$yml" ] || { echo "plan-findings.sh: list: project file is not a readable file" >&2; exit 1; }
  command -v yq >/dev/null 2>&1 || { echo "plan-findings.sh: list: yq not on PATH" >&2; exit 1; }
  line=""
  if ! line="$(sh "$di" "$yml" 2>/dev/null)"; then
    echo "plan-findings.sh: list: declared-ids.sh failed on the project file" >&2
    exit 1
  fi
  case "$line" in
    "ok "*) ;;
    "no-map") echo "plan-findings.sh: list: no identities map is declared" >&2; exit 3 ;;
    *) echo "plan-findings.sh: list: the identities map is unreadable (declared-ids.sh did not print ok)" >&2; exit 1 ;;
  esac
  rid="$(yq -r 'explode(.) | .identities.reviewer_app | select(tag == "!!map") | .id' "$yml" 2>/dev/null)" || rid=""
  case "$rid" in
    '' | 0* | *[!0-9]*) echo "plan-findings.sh: list: no reviewer_app is declared" >&2; exit 3 ;;
  esac
  # The author's numeric id and the pull-request flag are projected and compared HERE, in awk, so
  # the filter is the script's own shell code and a fixture can exercise it.
  if ! gh api --paginate "repos/$repo/issues?state=open&per_page=100" --jq \
       '.[] | [.number, .created_at, (.milestone.number // "none" | tostring),
               ([.labels[].name | select(startswith("area/"))] | join(",") | if . == "" then "none" else . end),
               (.user.id | tostring), (has("pull_request") | tostring)] | @tsv' \
       >"$tmp/rows" 2>"$tmp/err"; then
    echo "plan-findings.sh: gh api failed fetching open issues for $repo:" >&2
    cat "$tmp/err" >&2
    exit 1
  fi
  awk -F "$tab" -v rid="$rid" 'NF == 6 && $5 == rid && $6 == "false" { print $1 "\t" $2 "\t" $3 "\t" $4 }' "$tmp/rows" >"$tmp/kept"
  sort -t "$tab" -k1,1n "$tmp/kept"
  exit 0
fi

# =============================================================================
if [ "$mode" = held ]; then
  lf="$2"; kf="$3"
  [ -f "$lf" ] && [ -r "$lf" ] || { echo "plan-findings.sh: held: list file is not a readable file" >&2; exit 1; }
  [ -f "$kf" ] && [ -r "$kf" ] || { echo "plan-findings.sh: held: kept file is not a readable file" >&2; exit 1; }
  # Every check runs before anything is printed, so a failure leaves stdout empty.
  if ! awk 'NF == 0 { next } /[^0-9]/ { exit 1 }' "$kf" 2>/dev/null; then
    echo "plan-findings.sh: held: a kept line is not digits-only" >&2
    exit 1
  fi
  if ! awk -F "$tab" 'NF != 4 || $1 !~ /^[0-9]+$/ { exit 1 }' "$lf" 2>/dev/null; then
    echo "plan-findings.sh: held: a list row does not have four fields or its number is not digits-only" >&2
    exit 1
  fi
  # The kept file is read in BEGIN, so an empty one cannot be mistaken for the list's first lines.
  awk -F "$tab" -v kf="$kf" 'BEGIN { while ((getline k < kf) > 0) if (k != "") kept[k] = 1 }
    $3 == "none" && !($1 in kept) { print $1 }' "$lf" | sort -n
  exit 0
fi

# =============================================================================
if [ "$mode" = unpack ]; then
  f="$2"
  [ -f "$f" ] && [ -r "$f" ] || { echo "plan-findings.sh: unpack: not a readable file" >&2; exit 1; }
  command -v yq >/dev/null 2>&1 || { echo "plan-findings.sh: unpack: yq not on PATH" >&2; exit 1; }
  num="$(yq -p=json -r '.number' "$f" 2>/dev/null)" || num=""
  case "$num" in
    '' | 0* | *[!0-9]*) echo "plan-findings.sh: unpack: the issue number is not a positive integer" >&2; exit 1 ;;
  esac
  yq -p=json -r '.body // ""' "$f" >"$tmp/body" 2>/dev/null || { echo "plan-findings.sh: unpack: no body" >&2; exit 1; }
  pr="$(sed -n 1p "$tmp/body" | tr -d '\r' | awk '{ if (match($0, /review of [^ ]+#[0-9]+ at /)) { s = substr($0, RSTART, RLENGTH); sub(/ at $/, "", s); sub(/^.*#/, "", s); print s } else print "none" }')"
  awk -v n="$num" -v pr="$pr" '
    function ctl(s) { gsub(/[\001-\037\177]/, " ", s); return s }
    # good_path -- the path row rule
    function good_path(p,    k, parts, i) {
      if (p !~ /\//) return 0
      if (p !~ /^[A-Za-z0-9._\/-]+$/) return 0
      k = split(p, parts, "/")
      for (i = 1; i <= k; i++) if (parts[i] == "" || parts[i] == "." || parts[i] == "..") return 0
      return 1
    }
    function add_path(p) {
      if (cur == "" || !good_path(p)) return
      if ((cur SUBSEP p) in seen) return
      seen[cur SUBSEP p] = 1
      out = out "path\t" n "." cur "\t" p "\n"
    }
    # spans -- every single-backtick span of one line
    function spans(s,    i, j, c, r, len) {
      len = length(s)
      i = 1
      while (i <= len) {
        if (substr(s, i, 1) != "`") { i++; continue }
        r = 0
        while (substr(s, i + r, 1) == "`") r++
        if (r != 1) { i += r; continue }
        j = i + 1
        while (j <= len && substr(s, j, 1) != "`") j++
        if (j > len) return
        r = 0
        while (substr(s, j + r, 1) == "`") r++
        if (r == 1) { add_path(substr(s, i + 1, j - i - 1)); i = j + 1 }
        else i = j + r
      }
    }
    BEGIN { bad = 0; last = 0; nf = 0; cur = ""; out = ""; havetitle = 1 }
    {
      line = $0
      sub(/\r$/, "", line)
      blank = (line ~ /^ *$/)
      col0 = (!blank && line !~ /^[ \t]/)
      if (col0) {
        cur = ""
        if (line ~ /^- \[[ x]\] Finding [0-9]+$/) {
          k = line
          sub(/^- \[[ x]\] Finding /, "", k)
          if (k !~ /^[1-9][0-9]*$/ || length(k) > 9 || k + 0 <= last) bad = 1
          else {
            last = k + 0; nf++; cur = k
            state = (line ~ /^- \[x\]/) ? "ticked" : "open"
            out = out "finding\t" n "." k "\t" state "\t\n"
            havetitle = 0; fenced = 0
            titles[k] = ""
          }
        } else if (line ~ /^- Finding [0-9]+: also reported in #[0-9]+(, #[0-9]+)*$/) {
          # accepted, no row
        } else if (line ~ /^- \[/ || line ~ /^- Finding/) {
          bad = 1
        }
        next
      }
      if (cur == "" || blank) next
      t = line
      gsub(/ /, "", t)
      if (length(t) >= 3 && t ~ /^`+$/) { fenced = 1; next }
      if (fenced && !havetitle) {
        t = line
        sub(/^  /, "", t)
        titles[cur] = ctl(t)
        havetitle = 1
      }
      spans(line)
    }
    END {
      if (bad || nf == 0) { print "unparsed " n; exit 0 }
      # rebuild the finding rows with their titles, keeping each finding followed by its paths
      print "source\t" n "\t" pr
      m = split(out, rows, "\n")
      for (i = 1; i < m; i++) {
        r = rows[i]
        if (r ~ /^finding\t/) {
          split(r, p, "\t")
          kk = p[2]; sub(/^[0-9]+\./, "", kk)
          print "finding\t" p[2] "\t" p[3] "\t" titles[kk]
        } else print r
      }
    }
  ' "$tmp/body"
  exit 0
fi

# =============================================================================
if [ "$mode" = exists ]; then
  ref="$2"
  case "$ref" in '' | -*) echo "plan-findings.sh: exists: bad ref" >&2; exit 1 ;; esac
  git rev-parse --verify -q "$ref^{commit}" >/dev/null 2>&1 || { echo "plan-findings.sh: exists: ref does not resolve to a commit" >&2; exit 1; }
  while IFS= read -r p || [ -n "$p" ]; do
    word=present
    case "$p" in
      */*) ;;
      *) word=bad-name ;;
    esac
    case "$p" in
      *[!A-Za-z0-9._/-]*) word=bad-name ;;
      /* | */ | *//* | ./* | */./* | */. | . | ../* | */../* | */..) word=bad-name ;;
    esac
    if [ "$word" = present ]; then
      git cat-file -e "$ref:$p" >/dev/null 2>&1 || word=absent
    fi
    printf '%s\t%s\n' "$p" "$word"
  done
  exit 0
fi

# =============================================================================
if [ "$mode" = screen ]; then
  file="$2"
  stop() {
    case "$1" in
      hidden) echo "refused hidden" ;;
      *) echo "$1" ;;
    esac
    exit 0
  }
  [ -f "$file" ] && [ -r "$file" ] || stop unreadable
  # HID, HREF, LDEF: spec-fresh.sh's three lines, byte for byte, and the awk program below spec-issue.sh's (the hidden-text screen)
  HID="$(printf '\302\255|\315\217|\330\234|\341\205[\237-\240]|\341\236[\264-\265]|\341\240[\213-\217]|\342\200[\213-\217]|\342\200[\252-\256]|\342\201[\240-\257]|\343\205\244|\357\270[\200-\217]|\357\273\277|\357\276\240|\357\277[\260-\270]|\360\233\262[\240-\243]|\360\235\205[\263-\272]|\363\240[\200-\277][\200-\277]')"
  HREF='&#[0-9xX]|&shy|&(zwnj|zwj|lrm|rlm|ZeroWidthSpace|NegativeVeryThinSpace|NegativeThinSpace|NegativeMediumSpace|NegativeThickSpace|NoBreak|ApplyFunction|af|InvisibleTimes|it|InvisibleComma|ic);'
  LDEF='^ ? ? ?\[[^]]+\]:'
  for f in "$file"; do
    hid_word="$(LC_ALL=C SI_HID="$HID" SI_HREF="$HREF" SI_LDEF="$LDEF" awk '
      BEGIN { hid = ENVIRON["SI_HID"]; href = ENVIRON["SI_HREF"]; ldef = ENVIRON["SI_LDEF"]; bad = 0 }
      {
        line = $0
        sub(/\r$/, "", line)
        if (line ~ /<[!?]/ || line ~ /<\/[^A-Za-z]/ || line ~ /<\/$/) bad = 1
        if (index(line, "\r") > 0) bad = 1
        if (line ~ hid) bad = 1
        if (line ~ href) bad = 1
        if (line ~ ldef) bad = 1
      }
      END { print (bad ? "hidden" : "clean") }
    ' "$f" 2>/dev/null)" || stop unreadable
    case "$hid_word" in
      clean) : ;;
      hidden) stop hidden ;;
      *) stop unreadable ;;
    esac
  done
  ls_script="$(sibling leak-screen.sh)"
  lrc=0
  lverdict="$(sh "$ls_script" "$file" 2>/dev/null)" || lrc=$?
  case "$lverdict" in
    ok) ;;
    "leak "*) echo "refused $lverdict"; exit 0 ;;
    *) stop unreadable ;;
  esac
  grep -q -E -e '@[A-Za-z0-9]' -- "$file" >/dev/null 2>&1 && rc=0 || rc=$?
  case "$rc" in
    0) echo "refused mention"; exit 0 ;;
    1) ;;
    *) stop unreadable ;;
  esac
  stop ok
fi

# =============================================================================
if [ "$mode" = label ]; then
  repo="$2"; val="$3"
  good_area "$val" || { echo bad-name; exit 0; }
  if ! gh api --paginate "repos/$repo/labels?per_page=100" --jq '.[].name' >"$tmp/labels" 2>"$tmp/err"; then
    echo "plan-findings.sh: label: gh api failed fetching the labels of $repo:" >&2
    cat "$tmp/err" >&2
    exit 1
  fi
  if grep -q -x -F -e "$val" -- "$tmp/labels" >/dev/null 2>&1; then echo ok; else echo unknown; fi
  exit 0
fi

# =============================================================================
if [ "$mode" = filed ]; then
  f="$2"; val="$3"; bf="$4"
  [ -f "$f" ] && [ -r "$f" ] || { echo "plan-findings.sh: filed: issue file is not a readable file" >&2; exit 1; }
  [ -f "$bf" ] && [ -r "$bf" ] || { echo "plan-findings.sh: filed: body file is not a readable file" >&2; exit 1; }
  command -v yq >/dev/null 2>&1 || { echo "plan-findings.sh: filed: yq not on PATH" >&2; exit 1; }
  yq -p=json -r '(.labels // [])[] | .name' "$f" >"$tmp/names" 2>/dev/null || { echo "plan-findings.sh: filed: the issue file is not readable JSON" >&2; exit 1; }
  yq -p=json -r '.body // ""' "$f" >"$tmp/body" 2>/dev/null || { echo "plan-findings.sh: filed: the issue file has no readable body" >&2; exit 1; }
  good_area "$val" || { echo bad-name; exit 0; }
  if ! grep -q -x -F -e "$val" -- "$tmp/names" >/dev/null 2>&1; then echo no-label; exit 0; fi
  a="$(cat "$tmp/body")"; b="$(cat "$bf")"
  if [ "$a" = "$b" ]; then echo ok; else echo body-differs; fi
  exit 0
fi

# =============================================================================
# mode = covers
n="$2"; rows="$3"; comment="$4"
is_digits "$n" && [ "${n#0}" = "$n" ] || { usage; exit 2; }
[ -f "$rows" ] && [ -r "$rows" ] || { echo "plan-findings.sh: covers: rows file is not a readable file" >&2; exit 1; }
[ -f "$comment" ] && [ -r "$comment" ] || { echo "plan-findings.sh: covers: comment file is not a readable file" >&2; exit 1; }
awk -F "$tab" -v n="$n" '$1 == "finding" { split($2, p, "."); if (p[1] == n && p[2] ~ /^[0-9]+$/) print p[2] }' "$rows" >"$tmp/ks"
if [ ! -s "$tmp/ks" ]; then
  echo none
  exit 0
fi
miss=""
while IFS= read -r k; do
  if ! grep -q -E -e "#$n\\.$k([^0-9]|\$)" -- "$comment" >/dev/null 2>&1; then
    miss="${miss:+$miss,}$k"
  fi
done <"$tmp/ks"
if [ -z "$miss" ]; then echo ok; else echo "missing $miss"; fi
exit 0
