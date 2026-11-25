#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/workflow-gap.sh: the check that lists the
# workflow files a branch's committed changes name, that the commit does not hold and that sit
# uncommitted in the working tree (#1815).
#
# Each case builds a fresh repository with a `main` base and a `work` branch cut from it.
# Permitted toolset: POSIX sh, plus git.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/workflow-gap.sh"

command -v git >/dev/null 2>&1 || { echo "SKIP - git not on PATH" >&2; exit 0; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

fail=0
assert_eq() { # <desc> <want> <got>
  if [ "$2" = "$3" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$2], got [$3]" >&2
    fail=1
  fi
}

n=0
fixture() { # sets $repo to a fresh repo on a work branch cut from main
  n=$((n + 1))
  repo="$tmp/r$n"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  echo base >"$repo/README"
  git -C "$repo" add README
  git -C "$repo" commit -q -m base
}
work() { git -C "$repo" checkout -q -b work; }
commit_all() { git -C "$repo" add -A && git -C "$repo" commit -q -m "$1"; }
untracked_wf() { # <name>...
  mkdir -p "$repo/.github/workflows"
  for f in "$@"; do echo "on: push" >"$repo/.github/workflows/$f"; done
}
run() { (cd "${2:-$repo}" && sh "$script" "$1" 2>"$tmp/err"); }

# 1. untracked workflow named by an added test: missing; then after commit: none
fixture; work
printf 'cat .github/workflows/x.yml\n' >"$repo/a.test.sh"; commit_all t
untracked_wf x.yml
assert_eq "added test names an uncommitted workflow" "missing .github/workflows/x.yml" "$(run main)"
mkdir "$repo/sub"
assert_eq "same from a subdirectory" "missing .github/workflows/x.yml" "$(run main "$repo/sub")"
commit_all wf
assert_eq "none once the workflow is committed" none "$(run main)"

# 2. named but absent everywhere
fixture; work
printf 'see .github/workflows/fixture.yml and https://example.com/o/r/.github/workflows/z.yml\n' >"$repo/a.txt"; commit_all t
assert_eq "name in neither HEAD nor the working tree" none "$(run main)"

# 3. committed on the base before the branch was cut
fixture; untracked_wf b.yml; commit_all wf; work
printf '.github/workflows/b.yml\n' >"$repo/a.txt"; commit_all t
assert_eq "workflow already on the base" none "$(run main)"

# 4. .yaml and trailing sentence period
fixture; work
printf 'Reads .github/workflows/c.yaml. Also .github/workflows/d.yml.\n' >"$repo/a.txt"; commit_all t
untracked_wf c.yaml d.yml
assert_eq "yaml and period" "missing .github/workflows/c.yaml .github/workflows/d.yml" "$(run main)"

# 5. two files, different orders: sorted, once each
fixture; work
printf '.github/workflows/q.yml\n.github/workflows/p.yml\n' >"$repo/a.txt"
printf '.github/workflows/p.yml .github/workflows/q.yml\n' >"$repo/b.txt"; commit_all t
untracked_wf p.yml q.yml
assert_eq "sorted, deduplicated" "missing .github/workflows/p.yml .github/workflows/q.yml" "$(run main)"

# 6. rename scanned as added
fixture
printf 'plain content that is long enough to be a rename candidate\n.github/workflows/r.yml\n' >"$repo/old.txt"; commit_all o
work
git -C "$repo" mv old.txt new.txt; commit_all mv
untracked_wf r.yml
assert_eq "renamed file listed" "missing .github/workflows/r.yml" "$(run main)"

# 7. unchanged and deleted files do not count
fixture
printf '.github/workflows/u.yml\n' >"$repo/keep.txt"
printf '.github/workflows/v.yml\n' >"$repo/gone.txt"; commit_all o
work
git -C "$repo" rm -q gone.txt; echo other >"$repo/o.txt"; commit_all d
untracked_wf u.yml v.yml
assert_eq "unchanged and deleted files are not scanned" none "$(run main)"

# 8. uncommitted edit of a changed file
fixture; work
echo plain >"$repo/a.txt"; commit_all t
printf '.github/workflows/w.yml\n' >>"$repo/a.txt"; untracked_wf w.yml
assert_eq "uncommitted edit is not read" none "$(run main)"

# 9. unreadable cases
fixture; work
echo x >"$repo/a.txt"; commit_all t
assert_eq "unresolvable base" unreadable "$(run nosuchref || true)"
run nosuchref >/dev/null || rc=$?; assert_eq "unresolvable base exits 1" 1 "${rc:-0}"; unset rc
assert_eq "unresolvable base: stderr empty" "" "$(cat "$tmp/err")"
git -C "$repo" checkout -q --orphan other; git -C "$repo" rm -rqf . ; echo o >"$repo/o"; git -C "$repo" add o; git -C "$repo" commit -q -m orphan
git -C "$repo" branch -q unrelated
git -C "$repo" checkout -q work
assert_eq "no merge base" unreadable "$(run unrelated || true)"
assert_eq "no merge base: stderr empty" "" "$(cat "$tmp/err")"
mkdir "$tmp/plain"
assert_eq "outside a work tree" unreadable "$(run main "$tmp/plain" || true)"
assert_eq "outside a work tree: stderr empty" "" "$(cat "$tmp/err")"

# 10. usage errors
fixture; work
for args in "" "a b" "''" "-x"; do
  out=$(cd "$repo" && eval "sh '$script' $args" 2>/dev/null) && rc=0 || rc=$?
  assert_eq "usage [$args]: exit 2" 2 "$rc"
  assert_eq "usage [$args]: stdout empty" "" "$out"
done

# 11. read only
fixture; work
printf '.github/workflows/s.yml\n' >"$repo/a.txt"; commit_all t; untracked_wf s.yml
before=$(git -C "$repo" status --porcelain; git -C "$repo" rev-parse HEAD; git -C "$repo" ls-files -s)
run main >/dev/null
after=$(git -C "$repo" status --porcelain; git -C "$repo" rev-parse HEAD; git -C "$repo" ls-files -s)
assert_eq "working tree and index unchanged" "$before" "$after"

exit "$fail"
