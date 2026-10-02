#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/cursor-sync-pr.sh.
#
# Issue #215: /way-of-working:resume offers to merge a forgotten handoff cursor-sync
# PR. This predicate decides which PR, if any, may be offered -- and whether HEAD is
# on a sync branch nobody merged.
#
# `gh` is stubbed the same way tests/plan-gather.test.sh stubs it: it does NOT
# interpret --jq, it returns pre-formed TSV standing in for what the real --jq
# would emit. So this suite tests the script's own shell code -- the shape checks,
# the candidate count, each refusal, the local-branch binding -- not GitHub's field
# semantics. The stub does assert the call's own arguments (the repo, the base, the
# state, and the exact --jq projection, whose column order the parser depends on),
# so a regression there fails a fixture instead of passing silently.
#
# The local-branch binding needs a real checkout, so each case runs inside a
# throwaway repo (the same setup tests/cursor-drift.test.sh uses).
#
# Permitted toolset: POSIX sh and its standard utilities (sed, tr, mktemp), git. No jq,
# no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/cursor-sync-pr.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

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
[ "$1" = pr ] && [ "$2" = list ] || { echo "fake gh: unsupported command $*" >&2; exit 1; }
args=" $* "
case "$args" in *" --base $FAKE_BASE "*) ;; *) echo "fake gh: base not $FAKE_BASE: $*" >&2; exit 1 ;; esac
case "$args" in *" --repo $FAKE_REPO "*) ;; *) echo "fake gh: repo not $FAKE_REPO: $*" >&2; exit 1 ;; esac
case "$args" in
  *" --state open "*)
    case "$args" in
      *'select(.headRefName | startswith("docs/sync-cursor-"))'*) ;;
      *) echo "fake gh: prefix filter missing" >&2; exit 1 ;;
    esac
    case "$args" in
      *'[.number, .headRefName, .headRefOid, .isCrossRepository, .mergeStateStatus,'*'(.files | length), (.files[0].path // "")]'*) ;;
      *) echo "fake gh: projection changed -- update the parser and this stub together" >&2; exit 1 ;;
    esac
    case "$args" in *"--jq length, "*) ;; *) echo "fake gh: total count missing" >&2; exit 1 ;; esac
    [ -z "${FAKE_FAIL:-}" ] || { echo "fake gh: HTTP 502" >&2; exit 1; }
    cat "$FAKE_ROWS"
    ;;
  *" --state merged "*)
    case "$args" in *" --head $FAKE_HEAD "*) ;; *) echo "fake gh: head not $FAKE_HEAD: $*" >&2; exit 1 ;; esac
    [ -z "${FAKE_MERGED_FAIL:-}" ] || { echo "fake gh: HTTP 502" >&2; exit 1; }
    cat "$FAKE_MERGED"
    ;;
  *) echo "fake gh: unexpected state: $*" >&2; exit 1 ;;
esac
FAKE_GH
chmod +x "$fakebin/gh"

export FAKE_REPO=acme/widgets FAKE_BASE=main FAKE_HEAD=unset

# --- a throwaway checkout with a local sync branch ---------------------
repo="$tmp/repo"
git init -q "$repo"
cd "$repo"
git config user.email test@example.com
git config user.name test
git config core.autocrlf false
echo a >a.txt && git add a.txt && git commit -qm initial
git checkout -q -b docs/sync-cursor-x
mkdir -p .ai && echo cursor >.ai/next-steps.md && git add .ai && git commit -qm "cursor sync"
oid_a="$(git rev-parse HEAD)"
git checkout -q -
other=89abcdef0123456789abcdef0123456789abcdef   # a head no local branch carries

# rows <total> then one candidate row per remaining group of six args
rows() {
  printf '%s\n' "$1"; shift
  while [ "$#" -ge 7 ]; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7"
    shift 7
  done
}

run() { FAKE_ROWS="$1" PATH="$fakebin:$PATH" sh "$script" acme/widgets main 2>/dev/null; }

good="docs/sync-cursor-x $oid_a false"

rows 0 >"$tmp/empty"
assert_eq "no open PRs -> none" "none" "$(run "$tmp/empty")"

rows 4 >"$tmp/nocand"
assert_eq "open PRs, none of them sync branches -> none" "none" "$(run "$tmp/nocand")"

rows 1 210 $good CLEAN 1 .ai/next-steps.md >"$tmp/clean"
assert_eq "one same-repo, one-file, local, CLEAN PR -> offer with its branch" \
  "offer 210 $oid_a docs/sync-cursor-x" "$(run "$tmp/clean")"

{ printf '1\n'; printf '210\tdocs/sync-cursor-x\t%s\tfalse\tCLEAN\t1\t.ai/next-steps.md' "$oid_a"; } >"$tmp/nonl"
assert_eq "a last row with no trailing newline is still read" \
  "offer 210 $oid_a docs/sync-cursor-x" "$(run "$tmp/nonl")"

rows 1 210 docs/sync-cursor-x "$oid_a" true CLEAN 1 .ai/next-steps.md >"$tmp/fork"
assert_eq "a fork PR is refused, whatever else it passes" \
  "refuse 210 cross-repository" "$(run "$tmp/fork")"

rows 1 210 $good CLEAN 2 .ai/next-steps.md >"$tmp/twofiles"
assert_eq "a PR touching more than the cursor (e.g. park/unpark) is refused" \
  "refuse 210 files" "$(run "$tmp/twofiles")"

rows 1 210 $good CLEAN 1 docs/decisions.md >"$tmp/otherfile"
assert_eq "a one-file PR on some other file is refused" \
  "refuse 210 files" "$(run "$tmp/otherfile")"

rows 1 210 docs/sync-cursor-x "$other" false CLEAN 1 .ai/next-steps.md >"$tmp/moved"
assert_eq "the local branch exists but its tip is not the PR head -> not-local" \
  "refuse 210 not-local" "$(run "$tmp/moved")"

rows 1 210 docs/sync-cursor-revived "$other" false CLEAN 1 .ai/next-steps.md >"$tmp/stale"
assert_eq "no local branch of that name (a revived stale remote branch) -> not-local" \
  "refuse 210 not-local" "$(run "$tmp/stale")"

for st in BEHIND BLOCKED DIRTY DRAFT UNSTABLE UNKNOWN HAS_HOOKS; do
  lower="$(printf '%s' "$st" | tr 'A-Z' 'a-z')"
  rows 1 210 $good "$st" 1 .ai/next-steps.md >"$tmp/state"
  assert_eq "$st is refused with its name -- only CLEAN is offered" \
    "refuse 210 state-$lower" "$(run "$tmp/state")"
done

rows 2 205 $good CLEAN 1 .ai/next-steps.md 210 docs/sync-cursor-y "$other" false CLEAN 1 .ai/next-steps.md >"$tmp/two"
assert_eq "two candidates -> ambiguous, neither offered" \
  "ambiguous 205 210" "$(run "$tmp/two")"

assert_eq "gh failure -> unreadable, never none" "unreadable" \
  "$(FAKE_FAIL=1 run "$tmp/clean")"

rows 200 >"$tmp/limit"
assert_eq "the open-PR list hit its fetch limit -> unreadable, never none" \
  "unreadable" "$(run "$tmp/limit")"

: >"$tmp/nothing"
assert_eq "no count line at all -> unreadable" "unreadable" "$(run "$tmp/nothing")"

rows 0 210 $good CLEAN 1 .ai/next-steps.md >"$tmp/countlies"
assert_eq "more candidate rows than the count line claims -> unreadable" \
  "unreadable" "$(run "$tmp/countlies")"

rows 1 21 $good CLEAN 1 .ai/next-steps.md | sed 1d >"$tmp/nocount"
assert_eq "a candidate row where the count line belongs -> unreadable" \
  "unreadable" "$(run "$tmp/nocount")"

rows 1 210 docs/sync-cursor-x gggggggggggggggggggggggggggggggggggggggg false CLEAN 1 .ai/next-steps.md >"$tmp/badhex"
assert_eq "a 40-character non-hex head oid -> unreadable" "unreadable" "$(run "$tmp/badhex")"

rows 1 210 docs/sync-cursor-x 0123456789abcdef false CLEAN 1 .ai/next-steps.md >"$tmp/shortoid"
assert_eq "a short hex head oid -> unreadable" "unreadable" "$(run "$tmp/shortoid")"

rows 1 21x $good CLEAN 1 .ai/next-steps.md >"$tmp/badnum"
assert_eq "a non-numeric PR number -> unreadable" "unreadable" "$(run "$tmp/badnum")"

rows 1 210 docs/sync-cursor-x "$oid_a" maybe CLEAN 1 .ai/next-steps.md >"$tmp/badcross"
assert_eq "a non-boolean isCrossRepository -> unreadable" "unreadable" "$(run "$tmp/badcross")"

rows 1 210 $good CLEAN one .ai/next-steps.md >"$tmp/badnfiles"
assert_eq "a non-numeric file count -> unreadable" "unreadable" "$(run "$tmp/badnfiles")"

rows 1 210 feat/other "$oid_a" false CLEAN 1 .ai/next-steps.md >"$tmp/badbranch"
assert_eq "a row whose branch lacks the prefix -> unreadable" "unreadable" "$(run "$tmp/badbranch")"

{ printf '1\n'; printf '210\tdocs/sync-cursor-x\t%s\tfalse\tCLEAN\t1\t.ai/next-steps.md\textra\n' "$oid_a"; } >"$tmp/extra"
assert_eq "an extra field -> unreadable" "unreadable" "$(run "$tmp/extra")"

assert_eq "no arguments -> unreadable" "unreadable" \
  "$(PATH="$fakebin:$PATH" sh "$script" 2>/dev/null)"

FAKE_BASE=develop
assert_eq "the base argument reaches gh (stub expects develop, script given main)" \
  "unreadable" "$(run "$tmp/clean")"
FAKE_BASE=main

assert_eq "outside a git checkout -> unreadable" "unreadable" \
  "$(cd "$tmp" && FAKE_ROWS="$tmp/clean" PATH="$fakebin:$PATH" sh "$script" acme/widgets main 2>/dev/null)"

# --- HEAD on a sync branch, no open candidate ---------------------------
git checkout -q docs/sync-cursor-x
export FAKE_HEAD=docs/sync-cursor-x

: >"$tmp/merged-none"
assert_eq "on a sync branch no merged PR carries (push failed / PR closed) -> unmerged" \
  "unmerged docs/sync-cursor-x" "$(FAKE_MERGED="$tmp/merged-none" run "$tmp/empty")"

printf '%s\n' "$other" >"$tmp/merged-other"
assert_eq "a merged PR on that branch, but not at this tip -> unmerged" \
  "unmerged docs/sync-cursor-x" "$(FAKE_MERGED="$tmp/merged-other" run "$tmp/empty")"

git tag docs/sync-cursor-x
assert_eq "a same-named tag does not hide the unmerged branch (no --short ambiguity)" \
  "unmerged docs/sync-cursor-x" "$(FAKE_MERGED="$tmp/merged-none" run "$tmp/empty")"
git tag -d docs/sync-cursor-x >/dev/null

printf '%s\n%s\n' "$other" "$oid_a" >"$tmp/merged-tip"
assert_eq "this tip was merged (the human merged on GitHub) -> none" \
  "none" "$(FAKE_MERGED="$tmp/merged-tip" run "$tmp/empty")"

assert_eq "the merged-PR lookup fails -> unreadable, never none" "unreadable" \
  "$(FAKE_MERGED="$tmp/merged-tip" FAKE_MERGED_FAIL=1 run "$tmp/empty")"

git checkout -q -
export FAKE_HEAD=unset
assert_eq "back on the base branch, nothing open -> none (no merged-PR lookup made)" \
  "none" "$(run "$tmp/empty")"

if [ "$fail" -ne 0 ]; then
  echo "cursor-sync-pr.test.sh: FAILED" >&2
  exit 1
fi
echo "cursor-sync-pr.test.sh: all passed"
