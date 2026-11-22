#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/merge-union.sh: resolve the one conflict a lane may resolve itself (#1711).
#
# Each case builds a scratch repository with a local bare `origin` (no network). Its default branch commits an
# .ai/project.yml whose `append_only` lists a changelog-shaped markdown file (CL.md: a title, a first level-2
# section with a level-3 sub-heading, a later level-2 section). A stub `gh` goes first on PATH and answers
# `gh repo view` with the default branch's name (FX_DB), or fails (FX_GHFAIL). The case merges main into a
# `lane` branch, then runs the script in the lane's worktree and asserts the printed word and exit status.
# A stub `gh` and a git wrapper write a sentinel to stderr; no case's output may carry it. A git wrapper can
# also fail `add` (FX_ADDFAIL) to force the `failed` word.
# Needs git, yq and jq; skips, loudly, without any of them.
# Permitted toolset: POSIX sh, plus git, yq, sed, awk, grep, cmp and tr as the cases need.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/merge-union.sh"

for tool in git yq jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP - $tool not on PATH; merge-union.test.sh needs it" >&2
    exit 0
  fi
done
real_git="$(command -v git)"

tmp="$(cd -P "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
SENT=SENTINEL-merge-union-stderr

fail=0
assert_eq() { # <desc> <want> <got>
  if [ "$2" = "$3" ]; then
    echo "ok - $1"
  else
    echo "FAIL - $1: expected [$2], got [$3]" >&2
    fail=1
  fi
}

mkdir "$tmp/stub"
cat >"$tmp/stub/gh" <<EOF
#!/bin/sh
echo "$SENT" >&2
[ -z "\${FX_GHFAIL:-}" ] || exit 1
printf '%s\n' "\${FX_DB:-main}"
EOF
cat >"$tmp/stub/git" <<EOF
#!/bin/sh
echo "$SENT" >&2
if [ -n "\${FX_ADDFAIL:-}" ] && [ "\$1" = add ]; then exit 1; fi
exec "$real_git" "\$@"
EOF
chmod 755 "$tmp/stub/gh" "$tmp/stub/git"

cnt=0
G() { "$real_git" "$@"; }
edit() { # <sed expr> <file>
  sed "$1" "$2" >"$2.n" && mv "$2.n" "$2"
}
base_cl() {
  cat <<'EOF'
# Changelog

Intro.

## [Unreleased]

### Added

- base

## [1.0.0]

- old
EOF
}
# new <append_only yaml line> : builds $W (worktree on branch lane) and the origin
new() {
  cnt=$((cnt + 1))
  R="$tmp/c$cnt"
  mkdir -p "$R"
  G init -q --bare "$R/origin.git"
  G init -q -b main "$R/w"
  W="$R/w"
  (
    cd "$W"
    G config user.email t@example.invalid
    G config user.name t
    mkdir .ai
    printf 'repo: x/y\n%s\n' "$1" >.ai/project.yml
    if [ -n "${BASEFILE:-}" ]; then printf '%s' "$BASEFILE" >CL.md; else base_cl >CL.md; fi
    printf 'a\n' >other.md
    G add -A
    G commit -q -m base
    G remote add origin "$R/origin.git"
    G push -q origin main
    G checkout -q -b lane
  )
}
# onmain / onlane <shell command run in the worktree>: edit, commit
onmain() { (cd "$W" && G checkout -q main && eval "$1" && G add -A && G commit -q -m m && G push -q origin main && G checkout -q lane); }
onlane() { (cd "$W" && eval "$1" && G add -A && G commit -q -m l); }
domerge() { (cd "$W" && G merge -q --no-edit main >/dev/null 2>&1) || :; }
LIST='append_only: [CL.md]'

# run <desc> <want word> <want rc>: runs the script, checks word and status, and that the worktree and index are unchanged.
# The snapshot holds CL.md, other.md, the unmerged index entries, and every unmerged path's own bytes (or a fixed marker when
# the path is not a file in the worktree), so a conflicted file other than CL.md is compared too.
snap() {
  (cd "$W" && {
    cat CL.md other.md 2>/dev/null || :
    G ls-files -u
    G diff --name-only --diff-filter=U | sort -u | while IFS= read -r up; do
      printf 'path: %s\n' "$up"
      if [ -f "$up" ]; then cat "$up"; else echo "<absent>"; fi
    done
  }) >"$1" 2>/dev/null || :
}
run() {
  desc=$1 want=$2 wrc=$3
  snap "$R/before"
  set +e
  out=$(cd "$W" && PATH="$tmp/stub:$PATH" sh "$script" 2>"$R/err")
  rc=$?
  set -e
  assert_eq "$desc: word" "$want" "$out"
  assert_eq "$desc: exit" "$wrc" "$rc"
  assert_eq "$desc: no stderr" "" "$(cat "$R/err")"
  if [ "$want" != failed ] && [ "${want%% *}" != resolved ]; then
    snap "$R/after"
    if cmp -s "$R/before" "$R/after"; then echo "ok - $desc: worktree and index unchanged"; else echo "FAIL - $desc: the worktree or index changed" >&2; fail=1; fi
  fi
}
no_markers() { if grep -E '^(<{7}|={7}|>{7}|\|{7})( |$)' "$W/CL.md" >/dev/null; then echo yes; else echo no; fi; }
unmerged() { (cd "$W" && G diff --name-only --diff-filter=U); }

# ---- resolved ---------------------------------------------------------------------------------
for style in merge diff3; do
  new "$LIST"
  (cd "$W" && G config merge.conflictStyle "$style")
  onmain "sed 's/^- base\$/- base\n- from-main/' CL.md >CL.n && mv CL.n CL.md"
  onlane "sed 's/^- base\$/- base\n- from-lane/' CL.md >CL.n && mv CL.n CL.md"
  domerge
  run "resolved ($style): both add under the sub-heading" "resolved CL.md" 0
  assert_eq "resolved ($style): both lines kept" "2" "$(grep -c -e '^- from-main$' -e '^- from-lane$' "$W/CL.md")"
  assert_eq "resolved ($style): no marker line" no "$(no_markers)"
  assert_eq "resolved ($style): nothing unmerged" "" "$(unmerged)"
done
new "$LIST"
(cd "$W" && G config merge.conflictStyle diff3)
onmain "sed 's/^- base\$/- main-edit/' CL.md >CL.n && mv CL.n CL.md"
onlane "sed 's/^- base\$/- lane-edit/' CL.md >CL.n && mv CL.n CL.md"
domerge
run "resolved (diff3): both edit one line" "resolved CL.md" 0
assert_eq "resolved (diff3): the base part is gone" 0 "$(grep -c '^- base$' "$W/CL.md")"
assert_eq "resolved (diff3): both copies kept" 2 "$(grep -c -e '^- main-edit$' -e '^- lane-edit$' "$W/CL.md")"

# ---- outside-section --------------------------------------------------------------------------
new "$LIST"
onmain "sed 's/^- old\$/- old-main/' CL.md >CL.n && mv CL.n CL.md"
onlane "sed 's/^- old\$/- old-lane/' CL.md >CL.n && mv CL.n CL.md"
domerge
run "outside-section: a conflict in the later section" "outside-section" 1

new "$LIST"
onmain "sed -e 's/^- old\$/- old-main/' -e 's/^- base\$/- b-main/' CL.md >CL.n && mv CL.n CL.md"
onlane "sed -e 's/^- old\$/- old-lane/' -e 's/^- base\$/- b-lane/' CL.md >CL.n && mv CL.n CL.md"
domerge
run "outside-section: conflicts in both sections" "outside-section" 1

new "$LIST"
onmain "sed 's/^- base\$/- y/' CL.md >CL.n && mv CL.n CL.md"
onlane "sed 's/^- base\$/## H1\n- x/' CL.md >CL.n && mv CL.n CL.md"
domerge
run "outside-section: a region holding a level-2 heading" "outside-section" 1

BASEFILE='# Title

- base
'
new "$LIST"
onmain "sed 's/^- base\$/- m/' CL.md >CL.n && mv CL.n CL.md"
onlane "sed 's/^- base\$/- l/' CL.md >CL.n && mv CL.n CL.md"
domerge
run "outside-section: a listed file with no level-2 heading" "outside-section" 1
BASEFILE=

new "$LIST"
onmain "sed 's/^- base\$/- m/' CL.md >CL.n && mv CL.n CL.md"
onlane "sed 's/^- base\$/- l/' CL.md >CL.n && mv CL.n CL.md"
domerge
(cd "$W" && sed '/^>\{7\}/d' CL.md >CL.n && mv CL.n CL.md)
run "outside-section: an incomplete region" "outside-section" 1

new "$LIST"
onmain "sed 's/^- base\$/- m/' CL.md >CL.n && mv CL.n CL.md"
onlane "sed 's/^- base\$/- l/' CL.md >CL.n && mv CL.n CL.md"
domerge
(cd "$W" && sed '/^[<=>]\{7\}/d' CL.md >CL.n && mv CL.n CL.md)
run "outside-section: still unmerged in the index, no marker line in the file" "outside-section" 1

# ---- other-path -------------------------------------------------------------------------------
new "$LIST"
onmain "sed 's/^- base\$/- m/' CL.md >CL.n && mv CL.n CL.md; printf 'm\n' >other.md"
onlane "sed 's/^- base\$/- l/' CL.md >CL.n && mv CL.n CL.md; printf 'l\n' >other.md"
domerge
run "other-path: two conflicted files" "other-path" 1

new "$LIST"
onmain "printf 'm\n' >other.md"
onlane "printf 'l\n' >other.md"
domerge
run "other-path: one conflicted file, not listed" "other-path" 1

new 'append_only: [NEW.md]'
onmain "printf 'm\n' >NEW.md"
onlane "printf 'l\n' >NEW.md"
domerge
run "other-path: add/add on the listed file" "other-path" 1

new "$LIST"
onmain "sed 's/^- base\$/- m/' CL.md >CL.n && mv CL.n CL.md"
onlane "G rm -q CL.md"
domerge
run "other-path: modify/delete on the listed file" "other-path" 1

for v in 'x: 1' 'append_only: null' 'append_only: []'; do
  new "$v"
  onmain "sed 's/^- base\$/- m/' CL.md >CL.n && mv CL.n CL.md"
  onlane "sed 's/^- base\$/- l/' CL.md >CL.n && mv CL.n CL.md"
  domerge
  run "other-path: [$v]" "other-path" 1
done

# ---- no-merge ---------------------------------------------------------------------------------
new "$LIST"
run "no-merge: no merge in progress" "no-merge" 1

# ---- unreadable -------------------------------------------------------------------------------
conflict() {
  onmain "sed 's/^- base\$/- m/' CL.md >CL.n && mv CL.n CL.md"
  onlane "sed 's/^- base\$/- l/' CL.md >CL.n && mv CL.n CL.md"
  domerge
}
new "$LIST"; conflict
FX_GHFAIL=1 && export FX_GHFAIL
run "unreadable: gh fails" unreadable 1
unset FX_GHFAIL
FX_DB=-bad && export FX_DB
run "unreadable: a branch name starting with a dash" unreadable 1
FX_DB='a b' && export FX_DB
run "unreadable: a branch name with a space" unreadable 1
FX_DB=nobranch && export FX_DB
run "unreadable: the fetch fails (no such branch)" unreadable 1
unset FX_DB
for v in 'append_only: CL.md' 'append_only: [../x]' 'append_only: [{a: b}]'; do
  new "$v"; conflict
  run "unreadable: [$v]" unreadable 1
done
new "$LIST"; conflict
(cd "$W" && G config remote.origin.url "$R/nowhere.git")
run "unreadable: origin is gone" unreadable 1
cnt=$((cnt + 1)); R="$tmp/c$cnt"; mkdir -p "$R"
G init -q --bare "$R/origin.git"; G init -q -b main "$R/w"; W="$R/w"
(cd "$W" && G config user.email t@example.invalid && G config user.name t && printf 'a\n' >f && G add f && G commit -q -m b \
  && G remote add origin "$R/origin.git" && G push -q origin main && G checkout -q -b lane && printf 'l\n' >f && G commit -qam l \
  && G checkout -q main && printf 'm\n' >f && G commit -qam m && G push -q origin main && G checkout -q lane && { G merge -q --no-edit main >/dev/null 2>&1 || :; })
run "unreadable: the default branch has no project file" unreadable 1

# ---- failed -----------------------------------------------------------------------------------
new "$LIST"; conflict
FX_ADDFAIL=1 && export FX_ADDFAIL
run "failed: git add fails" failed 1
unset FX_ADDFAIL

# ---- usage ------------------------------------------------------------------------------------
set +e
uo=$(cd "$W" && PATH="$tmp/stub:$PATH" sh "$script" extra 2>"$tmp/uerr")
urc=$?
set -e
assert_eq "usage: nothing on stdout" "" "$uo"
assert_eq "usage: exit 2" 2 "$urc"
case $(cat "$tmp/uerr") in usage:*) echo "ok - usage: a usage line on stderr" ;; *) echo "FAIL - usage: no usage line" >&2; fail=1 ;; esac

# ---- the stub's stderr sentinel never reaches the output -------------------------------------
new "$LIST"; conflict
all=$(cd "$W" && PATH="$tmp/stub:$PATH" sh "$script" 2>&1) || :
case $all in *"$SENT"*) echo "FAIL - the stderr sentinel leaked" >&2; fail=1 ;; *) echo "ok - no stderr of git or gh reaches the output" ;; esac

# ---- the script names no repo-specific value -------------------------------------------------
if grep -E 'CHANGELOG|Unreleased' "$script" >/dev/null; then echo "FAIL - the script names a repo-specific value" >&2; fail=1; else echo "ok - the script names no changelog or heading"; fi

exit "$fail"
