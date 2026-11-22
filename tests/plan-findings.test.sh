#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/plan-findings.sh.
#
# `gh` is stubbed as tests/plan-gather.test.sh stubs it: it ignores the --jq expression and
# prints FAKE_ROWS, so this suite tests what the script's own shell code does (the reviewer-id
# filter in awk, the sort, the failed-gh-is-not-zero-rows rule), not gh's pagination or filter.
# The rows the stub prints have the six fields the script's --jq projects: number, created_at,
# milestone, area labels, author id, pull-request flag. It answers the labels call
# (`repos/<repo>/labels`) by printing FAKE_LABELS, one name per line, and honours FAKE_FAIL for it too.
#
# Permitted toolset: POSIX sh, yq (mikefarah v4) and git. Without yq the suite skips itself, loudly.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
bindir="$root_dir/plugins/way-of-working/bin"
script="$bindir/plan-findings.sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "SKIP - yq not on PATH; plan-findings fixtures not run" >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
tab="$(printf '\t')"

assert_eq() {
  desc="$1"; expected="$2"; actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$expected], got [$actual]" >&2
    fail=1
  fi
}

# --- the fake gh -------------------------------------------------------
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
cat >"$fakebin/gh" <<'FAKE_GH'
#!/bin/sh
set -eu
[ "$1" = api ] || { echo "fake gh: unsupported command $1" >&2; exit 1; }
case "$*" in
  *"issues?state=open&per_page=100"*) want=rows ;;
  *"/labels?per_page=100"*) want=labels ;;
  *) echo "fake gh: unrecognised args $*" >&2; exit 1 ;;
esac
[ "${FAKE_FAIL:-0}" = 1 ] && { echo "fake gh: simulated failure" >&2; exit 1; }
if [ "$want" = labels ]; then printf '%s' "${FAKE_LABELS-}"; else printf '%s' "${FAKE_ROWS-}"; fi
FAKE_GH
chmod +x "$fakebin/gh"

# --- project.yml fixtures ----------------------------------------------
yml_good="$tmp/good.yml"
cat >"$yml_good" <<'EOF'
identities:
  maintainer:
    - { login: ann, id: 1001 }
  dev_app: { login: dev-bot, id: 2001 }
  reviewer_app: { login: rev-bot, id: 3001 }
  loop_app: null
EOF
yml_null="$tmp/null.yml"
printf 'identities: null\n' >"$yml_null"
yml_norev="$tmp/norev.yml"
cat >"$yml_norev" <<'EOF'
identities:
  maintainer:
    - { login: ann, id: 1001 }
  dev_app: { login: dev-bot, id: 2001 }
EOF
yml_nullrev="$tmp/nullrev.yml"
cat >"$yml_nullrev" <<'EOF'
identities:
  maintainer:
    - { login: ann, id: 1001 }
  reviewer_app: null
EOF
yml_bad="$tmp/bad.yml"
printf 'identities: [unclosed\n' >"$yml_bad"

status_of() { # status_of <cmd...> -- prints the exit status, discarding output
  _rc=0
  "$@" >/dev/null 2>&1 || _rc=$?
  printf '%s' "$_rc"
}

echo "# list"

rows="42${tab}2026-11-02T00:00:00Z${tab}none${tab}none${tab}3001${tab}false
7${tab}2026-11-01T00:00:00Z${tab}36${tab}area/ci,area/loop${tab}3001${tab}false
9${tab}2026-11-01T00:00:00Z${tab}none${tab}area/ai${tab}3001${tab}true
10${tab}2026-11-01T00:00:00Z${tab}none${tab}area/ai${tab}2001${tab}false
11${tab}2026-11-01T00:00:00Z${tab}none${tab}area/ai${tab}3002${tab}false
100${tab}2026-11-03T00:00:00Z${tab}5${tab}area/ai${tab}3001${tab}false"
expected="7${tab}2026-11-01T00:00:00Z${tab}36${tab}area/ci,area/loop
42${tab}2026-11-02T00:00:00Z${tab}none${tab}none
100${tab}2026-11-03T00:00:00Z${tab}5${tab}area/ai"
out="$(PATH="$fakebin:$PATH" FAKE_ROWS="$rows" "$script" list o/r "$yml_good")"
assert_eq "list keeps the reviewer App's true issues by id, sorted by number; pull request, dev App and other author dropped" "$expected" "$out"

PATH="$fakebin:$PATH" FAKE_ROWS="" "$script" list o/r "$yml_good" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "list: zero rows is empty output, exit 0" "0:" "$rc:$(cat "$tmp/out")"

PATH="$fakebin:$PATH" FAKE_FAIL=1 "$script" list o/r "$yml_good" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "list: a failed gh exits non-zero with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"

for c in null norev nullrev; do
  eval "y=\$yml_$c"
  PATH="$fakebin:$PATH" FAKE_ROWS="$rows" "$script" list o/r "$y" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
  assert_eq "list: config '$c' (no map or no reviewer App) exits 3 with nothing on stdout" "3:" "$rc:$(cat "$tmp/out")"
done
PATH="$fakebin:$PATH" FAKE_ROWS="$rows" "$script" list o/r "$yml_bad" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "list: config 'bad' exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
PATH="$fakebin:$PATH" FAKE_ROWS="$rows" "$script" list o/r "$tmp/missing.yml" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "list: a missing config exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"

# a stub declared-ids.sh beside a copy of the script
stubdir="$tmp/stub"
mkdir -p "$stubdir"
cp "$script" "$stubdir/plan-findings.sh"
printf '#!/bin/sh\nexit 3\n' >"$stubdir/declared-ids.sh"
PATH="$fakebin:$PATH" FAKE_ROWS="$rows" "$stubdir/plan-findings.sh" list o/r "$yml_good" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "list: a declared-ids.sh that exits non-zero exits 1, nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
printf '#!/bin/sh\nexit 0\n' >"$stubdir/declared-ids.sh"
PATH="$fakebin:$PATH" FAKE_ROWS="$rows" "$stubdir/plan-findings.sh" list o/r "$yml_good" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "list: a declared-ids.sh that prints nothing exits 1, nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"

# a stub yq that fails only on the reviewer App read (declared-ids.sh still gets the real yq)
realyq="$(command -v yq)"
yqbin="$tmp/yqbin"
mkdir -p "$yqbin"
printf '#!/bin/sh\nfor a in "$@"; do case "$a" in *reviewer_app*) exit 1 ;; esac; done\nexec "%s" "$@"\n' "$realyq" >"$yqbin/yq"
chmod +x "$yqbin/yq"
PATH="$yqbin:$fakebin:$PATH" FAKE_ROWS="$rows" "$script" list o/r "$yml_good" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "list: a failing yq read of the reviewer App id exits 1, nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"

echo "# unpack"

mkissue() { # mkissue <file> <number> <title> <body-with-\n-escapes>
  printf '{"number":%s,"title":"%s","body":"%s"}' "$2" "$3" "$4" >"$1"
}
T1="triage the non-blocking findings from the review of o/r#34 at abcdef012345"
fence='  ```'
good_body='Non-blocking findings from the automated architect review of o/r#34 at abcdef012345: https://example.invalid/r. Written by the review session.\n\n- [ ] Finding 1\n\n  ```\n  Title one\n\n  Body with `a/b.sh` and `c.sh`.\n  ```\n\n- [x] Finding 2\n\n  ````\n  Title two\n\n  Paths: `d/e-f_g.md`, `d/e-f_g.md`, `plugins/x/y.sh`\n  ````'
mkissue "$tmp/i1.json" 12 "$T1" "$good_body"
exp="source${tab}12${tab}34
finding${tab}12.1${tab}open${tab}Title one
path${tab}12.1${tab}a/b.sh
finding${tab}12.2${tab}ticked${tab}Title two
path${tab}12.2${tab}d/e-f_g.md
path${tab}12.2${tab}plugins/x/y.sh"
assert_eq "unpack: the file_findings layout gives source, finding and path rows (fence not the title, repeated path once)" "$exp" "$("$script" unpack "$tmp/i1.json")"

none_body='Non-blocking findings from a review.\n\n- [ ] Finding 1\n\n  ```\n  Title at #12 at x\n  ```'
mkissue "$tmp/i2.json" 12 "$T1" "$none_body"
assert_eq "unpack: a body whose first line has no 'review of <repo>#digits at ' part gives source N none, whatever the title says" "source${tab}12${tab}none" "$("$script" unpack "$tmp/i2.json" | sed -n 1p)"
assert_eq "unpack: a finding title holding '#12 at ' does not change the source" "source${tab}12${tab}none" "$("$script" unpack "$tmp/i2.json" | sed -n 1p)"
mkissue "$tmp/i2b.json" 12 "plain" "$good_body"
assert_eq "unpack: the source is read from the body, not the title" "source${tab}12${tab}34" "$("$script" unpack "$tmp/i2b.json" | sed -n 1p)"

mkissue "$tmp/i3.json" 5 "$T1" '- [ ] Finding 1\n\n  ```\n  T\n  - [ ] Finding 9\n  ```'
assert_eq "unpack: a look-alike finding line inside the indented block is not a finding" "1" "$("$script" unpack "$tmp/i3.json" | grep -c '^finding')"

mkissue "$tmp/i4.json" 5 "$T1" '- [ ] Finding 1\n\n  ```\n  One\n  ```\n\n- Finding 2: also reported in #8\n\n- [ ] Finding 3\n\n  ```\n  Three\n  ```'
assert_eq "unpack: findings 1 and 3 with an also-reported line 2 give rows 1 and 3 only" "5.1 5.3" "$("$script" unpack "$tmp/i4.json" | awk -F "$tab" '$1 == "finding" { printf "%s%s", sep, $2; sep = " " }')"

mkissue "$tmp/i4b.json" 5 "$T1" '- [ ] Finding 1\n\n  ```\n  One\n  ```\n\n- Finding 2: also reported in #8, #9\n\n- [ ] Finding 3\n\n  ```\n  Three\n  ```'
assert_eq "unpack: an also-reported line with comma-joined issues '#8, #9' gives rows 1 and 3 only" "5.1 5.3" "$("$script" unpack "$tmp/i4b.json" | awk -F "$tab" '$1 == "finding" { printf "%s%s", sep, $2; sep = " " }')"

mkissue "$tmp/i5a.json" 5 "$T1" '- [ ] Finding 1\n\n  Paths: `p/q.sh`\n\n  ```\n  The title\n\n  body\n  ```'
assert_eq "unpack: a Paths line before the fence is not the title; the title is the first line after the opening fence" "The title" "$("$script" unpack "$tmp/i5a.json" | awk -F "$tab" '$1 == "finding" { print $4 }')"

mkissue "$tmp/i5c.json" 5 "$T1" '- [ ] Finding 1\n\n  Paths: `p/q.sh`, `r/s.md`\n\n  ```\n  The title\n  ```\n\n- [ ] Finding 2\n\n  Paths: `t/u.sh`\n\n  ```\n  Second\n  ```'
assert_eq "unpack: Paths lines before the fence give each finding its path rows" "5.1:p/q.sh 5.1:r/s.md 5.2:t/u.sh" "$("$script" unpack "$tmp/i5c.json" | awk -F "$tab" '$1 == "path" { printf "%s%s:%s", sep, $2, $3; sep = " " }')"

mkissue "$tmp/i5.json" 5 "$T1" '- [ ] Finding 1\n\n  ```\n  One\n\n  Paths: `p/q.sh` and `r/s.md`\n  ```'
assert_eq "unpack: a Paths line's backtick spans give path rows" "p/q.sh r/s.md" "$("$script" unpack "$tmp/i5.json" | awk -F "$tab" '$1 == "path" { printf "%s%s", sep, $3; sep = " " }')"

crlf_body="$(printf '%s' "$good_body" | sed 's/\\n/\\r\\n/g')"
mkissue "$tmp/i6.json" 12 "$T1" "$crlf_body"
assert_eq "unpack: a CRLF body parses as its LF form" "$exp" "$("$script" unpack "$tmp/i6.json")"

unparsed() { # unparsed <desc> <body>
  mkissue "$tmp/u.json" 77 "$T1" "$2"
  assert_eq "unpack: $1 prints only 'unparsed 77'" "unparsed 77" "$("$script" unpack "$tmp/u.json")"
}
unparsed "a repeated finding number" '- [ ] Finding 1\n\n  ```\n  A\n  ```\n\n- [ ] Finding 1\n\n  ```\n  B\n  ```'
unparsed "a decreasing finding number" '- [ ] Finding 2\n\n  ```\n  A\n  ```\n\n- [ ] Finding 1\n\n  ```\n  B\n  ```'
unparsed "a Finding 0 line" '- [ ] Finding 0\n\n  ```\n  A\n  ```'
unparsed "a body with no finding line" 'Just prose.\n\n- Finding 3: also reported in #4'
unparsed "a column-0 [X] line between findings" '- [ ] Finding 1\n\n  ```\n  A\n  ```\n\n- [X] Finding 2\n\n  ```\n  B\n  ```\n\n- [ ] Finding 3\n\n  ```\n  C\n  ```'
unparsed "a column-0 Finding line not in the also-reported form" '- [ ] Finding 1\n\n  ```\n  A\n  ```\n\n- Finding 2\n\n- [ ] Finding 3\n\n  ```\n  C\n  ```'

mkissue "$tmp/i7.json" 5 "$T1" '- [ ] Finding 1\n\n  ```\n  One\n\n  `../x/y` `a//b` `./a/b` `/abs/p` `has space/x` `a b/c` `nodir` `ok/path.sh`\n  ```'
assert_eq "unpack: path spans with .., an empty segment, ., a leading slash, a space or no slash are not printed" "ok/path.sh" "$("$script" unpack "$tmp/i7.json" | awk -F "$tab" '$1 == "path" { printf "%s%s", sep, $3; sep = " " }')"

mkissue "$tmp/i8.json" 5 "$T1" '- [ ] Finding 1\n\n  ```\n  Tab\there and\u0001ctl\n  ```'
assert_eq "unpack: a tab and a control character in a finding's first line become spaces" "Tab here and ctl" "$("$script" unpack "$tmp/i8.json" | awk -F "$tab" '$1 == "finding" { print $4 }')"

echo "# exists"

repo="$tmp/repo"
mkdir -p "$repo/dir"
(
  cd "$repo"
  git init -q .
  git config user.email t@example.invalid
  git config user.name t
  echo x >dir/file.sh
  git add dir/file.sh
  git commit -q -m init
)
got="$(cd "$repo" && printf 'dir/file.sh\ndir/nope.sh\nnoslash\n../a/b\ndir\n' | "$script" exists HEAD)"
assert_eq "exists: present, absent and bad-name" "dir/file.sh${tab}present
dir/nope.sh${tab}absent
noslash${tab}bad-name
../a/b${tab}bad-name
dir${tab}bad-name" "$got"
assert_eq "exists: a bad ref exits 1" 1 "$(cd "$repo" && status_of "$script" exists no-such-ref </dev/null)"

echo "# screen"

scr() { printf '%s' "$1" >"$tmp/s.txt"; "$script" screen "$tmp/s.txt"; }
assert_eq "screen: plain text is ok" ok "$(scr 'Fold this into the task.')"
assert_eq "screen: an opening angle bracket and bang is refused" "refused hidden" "$(scr 'a <!-- b')"
assert_eq "screen: a numeric character reference is refused" "refused hidden" "$(scr 'a &#65; b')"
assert_eq "screen: a link definition line is refused" "refused hidden" "$(scr '[a]: http://x.invalid')"
assert_eq "screen: a zero-width space is refused" "refused hidden" "$(scr "$(printf 'a\342\200\213b')")"
assert_eq "screen: a drive-letter path is refused" "refused leak 1 drive" "$(scr 'see C:/x/y')"
assert_eq "screen: a home-directory path is refused" "refused leak 1 home" "$(scr 'see /home/me/x')"
assert_eq "screen: a mention is refused" "refused mention" "$(scr 'cc @someone')"
assert_eq "screen: an at sign before a space is ok" ok "$(scr 'a @ b')"
assert_eq "screen: a missing file is unreadable" unreadable "$("$script" screen "$tmp/none.txt")"

desc="HID is spec-fresh.sh's line, byte for byte"
assert_eq "$desc" "$(grep '^ *HID=' "$bindir/spec-fresh.sh" | sed 's/^ *//')" "$(grep '^ *HID=' "$script" | sed 's/^ *//')"
assert_eq "$desc (one line)" 1 "$(grep -c '^ *HID=' "$script")"
for k in HREF LDEF; do
  assert_eq "$k is spec-fresh.sh's line, byte for byte" "$(grep "^$k=" "$bindir/spec-fresh.sh")" "$(grep "^ *$k=" "$script" | sed 's/^ *//')"
  assert_eq "$k is one line" 1 "$(grep -c "^ *$k=" "$script")"
done
desc="the hidden-screen awk program is spec-issue.sh's, byte for byte"
scrbody() { awk '/SI_HID="\$HID"/ { on = 1 } on { print } on && /stop unreadable$/ { exit }' "$1"; }
assert_eq "$desc" "$(scrbody "$bindir/spec-issue.sh")" "$(scrbody "$script")"
assert_eq "$desc (found)" yes "$([ -n "$(scrbody "$script")" ] && echo yes || echo no)"

echo "# covers"

printf 'finding\t12.1\topen\tA\nfinding\t12.2\topen\tB\nfinding\t12.10\topen\tC\nunparsed 13\nfinding\t120.1\topen\tD\n' >"$tmp/rows"
printf 'Mapping: #12.1 -> #50, #12.2: declined, #12.10 folded.\n' >"$tmp/c1"
assert_eq "covers: every finding named is ok" ok "$("$script" covers 12 "$tmp/rows" "$tmp/c1")"
printf '#12.1 and #12.10\n' >"$tmp/c2"
assert_eq "covers: the absent numbers are named" "missing 2" "$("$script" covers 12 "$tmp/rows" "$tmp/c2")"
printf '#12.10 only\n' >"$tmp/c3"
assert_eq "covers: #12.10 does not cover #12.1" "missing 1,2" "$("$script" covers 12 "$tmp/rows" "$tmp/c3")"
assert_eq "covers: an unparsed issue is none" none "$("$script" covers 13 "$tmp/rows" "$tmp/c1")"
assert_eq "covers: an issue with no rows is none" none "$("$script" covers 99 "$tmp/rows" "$tmp/c1")"
printf '#12.1' >"$tmp/c4"
printf 'finding\t12.1\topen\tA\n' >"$tmp/rows4"
assert_eq "covers: a reference at the end of the file counts" ok "$("$script" covers 12 "$tmp/rows4" "$tmp/c4")"

echo "# label"

labels="area/ci
area/way-of-working
type/bug"
lab() { PATH="$fakebin:$PATH" FAKE_LABELS="$labels" "$script" label o/r "$1"; }
assert_eq "label: a listed value is ok" ok "$(lab 'area/ci')"
assert_eq "label: a listed value with hyphens is ok" ok "$(lab 'area/way-of-working')"
assert_eq "label: a well-formed value the list lacks is unknown" unknown "$(lab 'area/loop')"
assert_eq "label: a prefix of a listed name is unknown" unknown "$(lab 'area/way')"
assert_eq "label: an uppercase letter is bad-name" bad-name "$(lab 'area/CI')"
assert_eq "label: no area/ prefix is bad-name" bad-name "$(lab 'type/bug')"
assert_eq "label: a bare area/ is bad-name" bad-name "$(lab 'area/')"
assert_eq "label: a listed first line followed by a newline and more text is bad-name" bad-name "$(lab "area/ci
extra")"
PATH="$fakebin:$PATH" FAKE_FAIL=1 "$script" label o/r 'area/ci' >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "label: a failed gh exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"

echo "# filed"

mkfiled() { # mkfiled <file> <label-json-array> <body-with-\n-escapes>
  printf '{"number":5,"labels":%s,"body":"%s"}' "$2" "$3" >"$1"
}
printf 'The body.\nSecond line.\n' >"$tmp/body.txt"
mkfiled "$tmp/f1.json" '[{"name":"type/bug"},{"name":"area/ci"}]' 'The body.\nSecond line.'
assert_eq "filed: a matching label and body is ok" ok "$("$script" filed "$tmp/f1.json" 'area/ci' "$tmp/body.txt")"
mkfiled "$tmp/f1b.json" '[{"name":"area/ci"}]' 'The body.\nSecond line.\n\n\n'
assert_eq "filed: bodies differing only by trailing newlines are ok" ok "$("$script" filed "$tmp/f1b.json" 'area/ci' "$tmp/body.txt")"
mkfiled "$tmp/f2.json" '[{"name":"type/bug"}]' 'Another body.'
assert_eq "filed: an absent label is no-label, whatever the body" no-label "$("$script" filed "$tmp/f2.json" 'area/ci' "$tmp/body.txt")"
mkfiled "$tmp/f3.json" '[{"name":"area/ci"}]' 'Another body.'
assert_eq "filed: a different body is body-differs" body-differs "$("$script" filed "$tmp/f3.json" 'area/ci' "$tmp/body.txt")"
assert_eq "filed: a malformed value is bad-name" bad-name "$("$script" filed "$tmp/f1.json" 'Area/CI' "$tmp/body.txt")"
assert_eq "filed: a missing issue file exits 1" 1 "$(status_of "$script" filed "$tmp/none.json" 'area/ci' "$tmp/body.txt")"
printf 'not json {\n' >"$tmp/f4.json"
assert_eq "filed: a non-empty issue file that is not JSON exits 1" 1 "$(status_of "$script" filed "$tmp/f4.json" 'area/ci' "$tmp/body.txt")"
assert_eq "filed: a missing body file exits 1" 1 "$(status_of "$script" filed "$tmp/f1.json" 'area/ci' "$tmp/none.txt")"

echo "# held"

hl="$tmp/hl.tsv"
hk="$tmp/hk.txt"
printf '42\t2026-11-02T00:00:00Z\tnone\tnone\n7\t2026-11-01T00:00:00Z\t36\tarea/ci\n100\t2026-11-03T00:00:00Z\tnone\tarea/ai\n9\t2026-11-03T00:00:00Z\tnone\tarea/ai\n' >"$hl"
: >"$hk"
assert_eq "held: an empty kept file holds every unmilestoned row, a milestoned row never, in ascending order" "9
42
100" "$("$script" held "$hl" "$hk")"
printf '42\n' >"$hk"
assert_eq "held: a kept number is never printed" "9
100" "$("$script" held "$hl" "$hk")"
printf '\n42\n\n9\n' >"$hk"
assert_eq "held: a blank line in the kept file is ignored" "100" "$("$script" held "$hl" "$hk")"
printf '7\n' >"$hk"
assert_eq "held: keeping a milestoned row changes nothing" "9
42
100" "$("$script" held "$hl" "$hk")"
: >"$hl"
: >"$hk"
"$script" held "$hl" "$hk" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: an empty list file prints nothing, exit 0" "0:" "$rc:$(cat "$tmp/out")"

printf '42\t2026-11-02T00:00:00Z\tnone\tnone\n' >"$hl"
printf '4x\n' >"$hk"
"$script" held "$hl" "$hk" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: a non-digit kept line exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
: >"$hk"
printf '4x\t2026-11-02T00:00:00Z\tnone\tnone\n42\t2026-11-02T00:00:00Z\tnone\tnone\n' >"$hl"
"$script" held "$hl" "$hk" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: a list row whose number is not digits-only exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
printf '42\t2026-11-02T00:00:00Z\tnone\n9\t2026-11-02T00:00:00Z\tnone\tnone\n' >"$hl"
"$script" held "$hl" "$hk" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: a list row with other than four fields exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
printf '42\t2026-11-02T00:00:00Z\tnone\tnone\textra\n' >"$hl"
"$script" held "$hl" "$hk" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: a list row with five fields exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
"$script" held "$tmp/none.tsv" "$hk" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: a missing list file exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
printf '42\t2026-11-02T00:00:00Z\tnone\tnone\n' >"$hl"
"$script" held "$hl" "$tmp/none.txt" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: a missing kept file exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"

# a stub awk that fails only on the final program (the only one that uses getline)
realawk="$(command -v awk)"
awkbin="$tmp/awkbin"
mkdir -p "$awkbin"
printf '#!/bin/sh\nfor a in "$@"; do case "$a" in *getline*) exit 1 ;; esac; done\nexec "%s" "$@"\n' "$realawk" >"$awkbin/awk"
chmod +x "$awkbin/awk"
printf '42\t2026-11-02T00:00:00Z\tnone\tnone\n' >"$hl"
: >"$hk"
PATH="$awkbin:$PATH" "$script" held "$hl" "$hk" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
assert_eq "held: a failing final awk exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"

echo "# argument validation"

for args in "" "bogus" "list o/r" "list o/r y z" "unpack" "unpack a b" "exists" "exists a b" "screen" "covers 1 a" "covers x a b" "covers 01 a b" "label" "label o/r" "label o/r a b" "filed" "filed a" "filed a b" "filed a b c d" "held" "held a" "held a b c"; do
  # shellcheck disable=SC2086
  "$script" $args >"$tmp/out" 2>/dev/null </dev/null && rc=0 || rc=$?
  assert_eq "usage: '$args' exits 2 with nothing on stdout" "2:" "$rc:$(cat "$tmp/out")"
done

if [ "$fail" -ne 0 ]; then
  echo "plan-findings.test.sh: FAILURES" >&2
  exit 1
fi
echo "plan-findings.test.sh: all passed"
