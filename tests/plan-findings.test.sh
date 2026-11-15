#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/plan-findings.sh.
#
# `gh` is stubbed as tests/plan-gather.test.sh stubs it: it ignores the --jq expression and
# prints FAKE_ROWS, so this suite tests what the script's own shell code does (the reviewer-id
# filter in awk, the sort, the failed-gh-is-not-zero-rows rule), not gh's pagination or filter.
# The rows the stub prints have the six fields the script's --jq projects: number, created_at,
# milestone, area labels, author id, pull-request flag.
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
  *"issues?state=open"*) ;;
  *) echo "fake gh: unrecognised args $*" >&2; exit 1 ;;
esac
[ "${FAKE_FAIL:-0}" = 1 ] && { echo "fake gh: simulated failure" >&2; exit 1; }
printf '%s' "${FAKE_ROWS-}"
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

for c in null norev nullrev bad; do
  eval "y=\$yml_$c"
  PATH="$fakebin:$PATH" FAKE_ROWS="$rows" "$script" list o/r "$y" >"$tmp/out" 2>/dev/null && rc=0 || rc=$?
  assert_eq "list: config '$c' exits 1 with nothing on stdout" "1:" "$rc:$(cat "$tmp/out")"
done
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

echo "# argument validation"

for args in "" "bogus" "list o/r" "list o/r y z" "unpack" "unpack a b" "exists" "exists a b" "screen" "covers 1 a" "covers x a b" "covers 01 a b"; do
  # shellcheck disable=SC2086
  "$script" $args >"$tmp/out" 2>/dev/null </dev/null && rc=0 || rc=$?
  assert_eq "usage: '$args' exits 2 with nothing on stdout" "2:" "$rc:$(cat "$tmp/out")"
done

if [ "$fail" -ne 0 ]; then
  echo "plan-findings.test.sh: FAILURES" >&2
  exit 1
fi
echo "plan-findings.test.sh: all passed"
