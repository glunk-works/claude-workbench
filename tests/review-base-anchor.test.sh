#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/review-base-anchor.sh.
#
# Each fixture is a throwaway pair of real git repos (a "remote" and a checkout cloned
# from it) built in a tempdir, driven through the real script -- the bug class this
# guards against (issue #126: four hand-verified critic rounds on the ~20-line chain PR
# #123 first wrote inline, each round finding a NEW edge case) is git plumbing behaving
# unexpectedly under a specific ref shape, which only real git plumbing can catch. `gh`
# is the one dependency this suite stubs, through $REVIEW_BASE_ANCHOR_GH -- the git-level
# cases need a real repo, but nothing here needs a real GitHub, and a fixture that hit the
# network would not be a fixture.
#
# core.autocrlf: pinned to false on every repo BEFORE the first commit or clone reaches
# it, never after. This machine's system-wide git config ships core.autocrlf=true; a repo
# that inherits it converts LF to CRLF the moment a file is checked out, and disabling
# autocrlf AFTER that point stops git from normalising the comparison it was already
# doing -- so the *dirty .ai/project.yml* fixture below would false-positive on every
# other fixture too, on this very machine, if the pin came a step too late. Confirmed by
# doing it wrong first: `git clone` with no `-c` reproduces exactly that failure.
#
# Permitted toolset: git, POSIX sh, real `yq` (mikefarah's, matched by the script's own
# `-er` flags) on PATH -- the one fixture below that needs it ABSENT hides it via a
# PATH-scoped shim directory rather than uninstalling anything. No jq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/review-base-anchor.sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "skip - review-base-anchor.sh fixtures: no yq on PATH" >&2
  exit 0
fi

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

# --- the gh stub -------------------------------------------------------------------
#
# Honors exactly the three calls the script makes (repo view --json nameWithOwner,
# repo view --json defaultBranchRef, pr view --json baseRefName) by reading the value
# after `--json` and answering from FAKE_GH_REPO / FAKE_GH_DEFAULT / FAKE_GH_BASE. It
# ALSO validates the positional argument each call carries -- an architect finding from
# this extraction's own pre-handoff pass: a stub that ignores its own arguments cannot
# catch a regression that, say, drops `--repo "$R"` from the `pr view` call (which
# SKILL.md's own "syncs from origin itself, not gh's default-remote guess" claim
# depends on) or replaces `"$U"` with an empty string. `repo view`'s third argument (the
# URL) must be non-empty (an empty-string prefix match is fragile across platforms --
# `git remote get-url` prints a drive-letter Windows path here, not the POSIX-style
# `mktemp -d` path this suite's own $tmp holds, so a literal-prefix check would be
# checking the wrong thing rather than nothing); `pr view`'s `--repo` must equal the
# same value this stub itself hands back for `nameWithOwner`, closing that loop exactly.
gh_stub="$tmp/fake-gh.sh"
cat > "$gh_stub" <<'STUB'
#!/bin/sh
set -eu
sub="$1 $2"
arg3="$3"
shift 2
json=""
repo_flag=""
prev=""
for a in "$@"; do
  if [ "$prev" = "--json" ]; then json="$a"; fi
  if [ "$prev" = "--repo" ]; then repo_flag="$a"; fi
  prev="$a"
done
case "$sub" in
  "repo view")
    if [ -z "$arg3" ]; then
      echo "fake-gh: repo view got an empty URL" >&2
      exit 1
    fi
    case "$json" in
      nameWithOwner) printf '%s\n' "${FAKE_GH_REPO:?}" ;;
      defaultBranchRef) printf '%s\n' "${FAKE_GH_DEFAULT-}" ;;
      *) echo "fake-gh: unexpected repo view --json $json" >&2; exit 1 ;;
    esac
    ;;
  "pr view")
    if [ "$repo_flag" != "${FAKE_GH_REPO:?}" ]; then
      echo "fake-gh: pr view --repo was [$repo_flag], expected [$FAKE_GH_REPO]" >&2
      exit 1
    fi
    case "$arg3" in
      *[!0-9]*|"") echo "fake-gh: pr view got a non-numeric PR argument: $arg3" >&2; exit 1 ;;
    esac
    case "$json" in
      baseRefName) printf '%s\n' "${FAKE_GH_BASE:?}" ;;
      *) echo "fake-gh: unexpected pr view --json $json" >&2; exit 1 ;;
    esac
    ;;
  *) echo "fake-gh: unexpected invocation: $sub" >&2; exit 1 ;;
esac
STUB
chmod +x "$gh_stub"

# --- repo builders -------------------------------------------------------------------

# new_origin <name> [branch] [migration_base] -- a "remote" repo, HEAD on its own
# default branch, with an .ai/project.yml carrying `repo:` and, when given, a
# `migration_base:` key. Echoes the repo's path.
new_origin() {
  name="$1"; branch="${2:-main}"; mb="${3-}"
  dir="$tmp/$name"
  git init -q "$dir"
  (
    cd "$dir"
    git symbolic-ref HEAD "refs/heads/$branch"
    git config user.email t@example.com
    git config user.name t
    git config core.autocrlf false
    mkdir -p .ai
    {
      echo "repo: acme/repo"
      [ -n "$mb" ] && echo "migration_base: $mb"
    } > .ai/project.yml
    git add -A
    git commit -qm init
  )
  printf '%s' "$dir"
}

# clone_checkout <origin-dir> <name> -- a checkout cloned from it, autocrlf pinned off
# from the clone itself (see the header note), identity configured for local commits.
clone_checkout() {
  origin_dir="$1"; name="$2"
  dir="$tmp/$name"
  git clone -q -c core.autocrlf=false "$origin_dir" "$dir"
  (
    cd "$dir"
    git config user.email t@example.com
    git config user.name t
  )
  printf '%s' "$dir"
}

# --- assertion helpers -----------------------------------------------------------------

# assert_success <desc> <checkout-dir> <default> <base> <want-base>
# Runs the script (PR number is always 7 -- the stub checks only that it's numeric,
# never a specific value) and asserts a
# clean success naming <want-base> as the synced base. Stderr is captured but not
# gated on: git itself prints a benign `warning: refname '<x>' is ambiguous.` when a
# tag shares a branch's name (the tag-hijack fixture below), which is exactly the
# noisy-but-correct shape this predicate has to tolerate -- the real assertion is that
# the RESOLVED base is still right despite it.
assert_success() {
  desc="$1"; dir="$2"; default="$3"; base="$4"; want_base="$5"
  out="" st=0
  out="$(cd "$dir" && REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo \
    FAKE_GH_DEFAULT="$default" FAKE_GH_BASE="$base" "$script" 7 2>"$tmp/stderr")" || st=$?
  want="repo=acme/repo default=$default base=$want_base"
  if [ "$st" = 0 ] && [ "$out" = "$want" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$want]/exit 0, got [$out]/exit $st/stderr=[$(cat "$tmp/stderr")]" >&2
    fail=1
  fi
}

# assert_stop <desc> <checkout-dir> <default> <base> [extra env assignments...]
# Runs the script and asserts a STOP: nothing on stdout, exit 1, and a stderr LINE
# (not necessarily the first -- a failing step like `yq` or `git merge` prints its own
# diagnostic to the same stream first) matching the fixed
# `STOP repo=... default=... base=... migration_base=...` shape.
assert_stop() {
  desc="$1"; dir="$2"; default="$3"; base="$4"; shift 4
  out="" st=0
  out="$(cd "$dir" && env "$@" REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo \
    FAKE_GH_DEFAULT="$default" FAKE_GH_BASE="$base" "$script" 7 2>"$tmp/stderr")" || st=$?
  err="$(cat "$tmp/stderr")"
  if grep -q '^STOP repo=' "$tmp/stderr"; then shape_ok=1; else shape_ok=0; fi
  if [ "$st" = 1 ] && [ -z "$out" ] && [ "$shape_ok" = 1 ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected []/exit 1/stderr containing a line starting 'STOP repo=', got [$out]/exit $st/stderr=[$err]" >&2
    fail=1
  fi
}

# =========================================================================================
# --- usage: bad arity is a malformed invocation, not a STOP -----------------------------
# =========================================================================================

out="" st=0
out="$("$script" 2>"$tmp/stderr")" || st=$?
assert_eq "no argument: exit 2, nothing on stdout" "/2" "$out/$st"
case "$(cat "$tmp/stderr")" in
  "usage: review-base-anchor.sh"*) echo "ok - no argument: usage message" ;;
  *) echo "FAIL - no argument: expected a usage message" >&2; fail=1 ;;
esac

out="" st=0
out="$("$script" "" 2>/dev/null)" || st=$?
assert_eq "empty argument: exit 2" "/2" "$out/$st"

# A non-numeric <N> is also a malformed invocation, not a STOP: `gh pr view` accepts a
# branch name or a full URL in place of a PR number, and a URL resolves ITS OWN repo,
# silently ignoring --repo -- so a caller that passes anything but a plain PR number
# must be refused before it ever reaches gh, not merely "happen to fail" once it gets
# there. `N` is only ever supplied by the human/skill invoking this script, never PR
# content, so this is a usage guard, not a trust boundary -- but a cheap one.
out="" st=0
out="$("$script" 7abc 2>/dev/null)" || st=$?
assert_eq "non-numeric argument: exit 2" "/2" "$out/$st"

out="" st=0
out="$("$script" https://github.com/acme/repo/pull/7 2>/dev/null)" || st=$?
assert_eq "a PR URL in place of a number: exit 2" "/2" "$out/$st"

# =========================================================================================
# --- the happy paths ----------------------------------------------------------------------
# =========================================================================================

o="$(new_origin base-default main)"
c="$(clone_checkout "$o" base-default-checkout)"
assert_success "base is the default branch" "$c" main main main

o="$(new_origin base-migration main legacy)"
(cd "$o" && git checkout -qb legacy && echo x >note.txt && git add -A && git commit -qm legacy && git checkout -q main)
c="$(clone_checkout "$o" base-migration-checkout)"
assert_success "a legitimate migration_base base" "$c" main legacy legacy

# Invoked from a SUBDIRECTORY of the checkout, not its root -- an architect AND a
# security-critic finding, independently, from this extraction's own pre-handoff pass:
# `git show refs/remotes/origin/$D:./.ai/project.yml` resolves the leading `./` relative
# to the CURRENT directory, not the repo root (unlike the `:/` pathspec used later in
# this same script). Reproduced live before the fix: run from a subdirectory, the same
# legitimate migration_base declaration reads as absent, and a real base wrongly stops.
# The fix makes the script `cd` to `git rev-parse --show-toplevel` before touching
# anything, so it no longer matters where inside the checkout it was invoked from.
o="$(new_origin base-migration-subdir main legacy)"
(cd "$o" && git checkout -qb legacy && echo x >note.txt && git add -A && git commit -qm legacy && git checkout -q main)
c="$(clone_checkout "$o" base-migration-subdir-checkout)"
mkdir -p "$c/sub/deeper"
out="" st=0
out="$(cd "$c/sub/deeper" && REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo \
  FAKE_GH_DEFAULT=main FAKE_GH_BASE=legacy "$script" 7 2>"$tmp/stderr")" || st=$?
assert_eq "invoked from a subdirectory, a legitimate migration_base base still resolves" \
  "repo=acme/repo default=main base=legacy/0" "$out/$st"

# =========================================================================================
# --- undeclared base: the default branch's migration_base does not vouch for it ---------
# =========================================================================================

# `some-other-branch` is a REAL, fetchable branch in origin here -- deliberately, not
# a name that doesn't exist. A comparison bug that is too permissive (accepts a base
# migration_base never declared) would otherwise be masked: the fetch of a genuinely
# nonexistent branch fails on its own regardless of the comparison, so a STOP would
# still appear for the wrong reason and the fixture would prove nothing. With a real
# branch behind it, a permissive bug lets the sync actually SUCCEED -- which is what
# must never happen, and is what assert_stop below is actually pinning.
o="$(new_origin undeclared-differs main legacy)"
(cd "$o" && git checkout -qb some-other-branch && echo x >note.txt && git add -A && git commit -qm real && git checkout -q main)
c="$(clone_checkout "$o" undeclared-differs-checkout)"
assert_stop "undeclared base: migration_base names a different (also real) branch" "$c" main some-other-branch

o="$(new_origin undeclared-absent main)"
(cd "$o" && git checkout -qb some-other-branch && echo x >note.txt && git add -A && git commit -qm real && git checkout -q main)
c="$(clone_checkout "$o" undeclared-absent-checkout)"
assert_stop "undeclared base: migration_base is not set at all, base is a real branch" "$c" main some-other-branch

# --- the human override: REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE -----------------------
#
# The one escape hatch the chain this replaces already had, in prose: a human, having
# seen an unmodified run's STOP line, re-runs deliberately accepting an undeclared base.
# Unset (every fixture above), it never fires -- that is the default-deny this whole gate
# exists for. It is pinned to the EXACT `repo#N:base` string, not a bare base name and not
# a boolean -- two security-critic findings during this extraction's own pre-handoff pass,
# fixed in the same round the second was raised in (the pass's own 2-round cap was crossed
# with the human's explicit go-ahead, per the *Convergence* section's own rule that going
# past it is their call to make): a bare on/off switch would accept WHATEVER base is
# current at rerun time, since a PR's base is editable by its own author at any point
# between the STOP a human read and the deliberate rerun; a bare base-NAME match, even
# pinned exactly, would still let one human decision for ONE review silently re-authorize
# ANY OTHER pr in ANY OTHER repo whose base happens to share that name -- a stale `export`
# left over from an approved review, and a long-lived branch name like `release/2` is easy
# to guess. Set to the right value, the same undeclared base that just stopped now
# succeeds, and the success line itself says so (`override=1`) -- an overridden success
# must not read identically to a declared one.
o="$(new_origin override main)"
(cd "$o" && git checkout -qb some-other-branch && echo x >note.txt && git add -A && git commit -qm real && git checkout -q main)
c="$(clone_checkout "$o" override-checkout)"
out="" st=0
out="$(cd "$c" && REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE='acme/repo#7:some-other-branch' \
  REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo FAKE_GH_DEFAULT=main \
  FAKE_GH_BASE=some-other-branch "$script" 7 2>"$tmp/stderr")" || st=$?
assert_eq "override: an undeclared base is accepted when set to the exact repo#N:base string" \
  "repo=acme/repo default=main base=some-other-branch override=1/0" "$out/$st"

# A boolean-shaped value (`1`) does NOT authorize a base named anything else -- the
# regression this fixture pins directly: the FIRST version of this override accepted any
# non-empty value, so `REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE=1` (or `=0`, `=false`, a
# stale inherited `export`) silently authorized an undeclared base of ANY name.
o="$(new_origin override-boolean main)"
(cd "$o" && git checkout -qb some-other-branch && echo x >note.txt && git add -A && git commit -qm real && git checkout -q main)
c="$(clone_checkout "$o" override-boolean-checkout)"
assert_stop "override: a boolean-shaped value (1) does not authorize a differently-named base" \
  "$c" main some-other-branch REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE=1

# A PR author retargeting the base between the STOP and the rerun: the override pinned
# to the OLD base name does not authorize the NEW one.
o="$(new_origin override-retarget main)"
(cd "$o" && git checkout -qb old-base && echo x >note.txt && git add -A && git commit -qm real && git checkout -qb new-base && git checkout -q main)
c="$(clone_checkout "$o" override-retarget-checkout)"
assert_stop "override: pinned to the base a human saw, not whatever base is current now" \
  "$c" main new-base REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE='acme/repo#7:old-base'

# A bare base-name match (the FIRST fix's own format, round 2's residual finding): an
# override approved for one PR must not silently re-authorize a DIFFERENT pr whose base
# happens to share that exact name.
o="$(new_origin override-wrong-pr main)"
(cd "$o" && git checkout -qb some-other-branch && echo x >note.txt && git add -A && git commit -qm real && git checkout -q main)
c="$(clone_checkout "$o" override-wrong-pr-checkout)"
assert_stop "override: a base name alone (no repo#N:) does not authorize any PR" \
  "$c" main some-other-branch REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE=some-other-branch

o="$(new_origin override-wrong-pr-number main)"
(cd "$o" && git checkout -qb some-other-branch && echo x >note.txt && git add -A && git commit -qm real && git checkout -q main)
c="$(clone_checkout "$o" override-wrong-pr-number-checkout)"
assert_stop "override: approved for a DIFFERENT PR number does not authorize this one" \
  "$c" main some-other-branch REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE='acme/repo#99:some-other-branch'

o="$(new_origin override-wrong-repo main)"
(cd "$o" && git checkout -qb some-other-branch && echo x >note.txt && git add -A && git commit -qm real && git checkout -q main)
c="$(clone_checkout "$o" override-wrong-repo-checkout)"
assert_stop "override: approved for a DIFFERENT repo does not authorize this one" \
  "$c" main some-other-branch REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE='other/repo#7:some-other-branch'

# =========================================================================================
# --- yq missing: an ordinary STOP, reached only when a non-default base needs it --------
# =========================================================================================

# Shadow ONLY `yq`, by prepending a directory that shadows it ahead of the real PATH --
# rather than building an isolated PATH containing just symlinks to git/sh/awk. The
# latter was tried and breaks git.exe on Windows: it depends on DLLs alongside its own
# real install directory, so a bare symlink to the .exe elsewhere fails to load with an
# unrelated "zlib1.dll not found" error that has nothing to do with yq and would have
# misreported every fixture below it as a script defect.
fakeyq="$tmp/fake-yq-path"
mkdir -p "$fakeyq"
cat > "$fakeyq/yq" <<'EOF'
#!/bin/sh
echo "yq: not found (test stub)" >&2
exit 127
EOF
chmod +x "$fakeyq/yq"

# The script never calls yq when the PR's base IS the default branch -- unchanged from
# the chain it replaces -- so that path must still succeed with yq hidden.
o="$(new_origin noyq-default main)"
c="$(clone_checkout "$o" noyq-default-checkout)"
out="" st=0
out="$(cd "$c" && PATH="$fakeyq:$PATH" REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo \
  FAKE_GH_DEFAULT=main FAKE_GH_BASE=main "$script" 7 2>"$tmp/stderr")" || st=$?
assert_eq "yq missing but unneeded: base is the default branch, still succeeds" \
  "repo=acme/repo default=main base=main/0" "$out/$st"

o="$(new_origin noyq-needed main legacy)"
(cd "$o" && git checkout -qb legacy && echo x >note.txt && git add -A && git commit -qm legacy && git checkout -q main)
c="$(clone_checkout "$o" noyq-needed-checkout)"
out="" st=0
out="$(cd "$c" && PATH="$fakeyq:$PATH" REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo \
  FAKE_GH_DEFAULT=main FAKE_GH_BASE=legacy "$script" 7 2>"$tmp/stderr")" || st=$?
if grep -q '^STOP repo=' "$tmp/stderr"; then shape_ok=1; else shape_ok=0; fi
if [ "$st" = 1 ] && [ -z "$out" ] && [ "$shape_ok" = 1 ]; then
  echo "ok - yq missing and needed: a non-default base stops"
else
  echo "FAIL - yq missing and needed: expected []/exit 1/stderr with a STOP line, got [$out]/exit $st/stderr=[$(cat "$tmp/stderr")]" >&2
  fail=1
fi

# =========================================================================================
# --- the four #123 critic-round edge cases, as positive controls: each must still ------
# --- resolve to the RIGHT base, not merely fail to crash --------------------------------
# =========================================================================================

# A tag named `origin/<branch>` shadows the remote-tracking ref on a naive short-name
# lookup. The script fetches into refs/remotes/origin/<branch> by full refspec.
o="$(new_origin tag-origin-shadow main)"
c="$(clone_checkout "$o" tag-origin-shadow-checkout)"
(cd "$c" && git tag "origin/main")
assert_success "a tag named origin/<branch> does not shadow the remote-tracking ref" \
  "$c" main main main

# A tag named `<branch>` hijacks a short-name fetch or blocks `git switch`. The script
# tracks and switches by full refspec/ref, never the bare short name alone.
o="$(new_origin tag-branch-hijack main)"
c="$(clone_checkout "$o" tag-branch-hijack-checkout)"
(cd "$c" && git tag main)
assert_success "a tag named <branch> does not hijack the switch" "$c" main main main

# A PR base named `-Cmain` would reach `git switch` as an option if ever passed
# positionally without a guard. Two fixtures: the base equal to the default branch
# (B never leaves the migration_base gate, so this alone would stop for an unrelated
# reason -- an undeclared base -- even with the guard removed, which mutation testing
# against this suite confirmed) and, separately, migration_base ITSELF declared as
# `-Cmain` so B reaches every later step that touches T (fetch, branch --track,
# switch) as this exact string. Both must stop either way.
o="$(new_origin dash-base main)"
c="$(clone_checkout "$o" dash-base-checkout)"
assert_stop "a PR base named -Cmain is rejected (base == default)" "$c" main -Cmain

o="$(new_origin dash-base-migration main -Cmain)"
c="$(clone_checkout "$o" dash-base-migration-checkout)"
assert_stop "a PR base named -Cmain is rejected (declared as migration_base, reaches fetch/switch)" \
  "$c" main -Cmain

# Neither fixture above can tell a REMOVED check-ref-format guard from git's own
# refspec validation failing safe further down for a branch that was never validly
# CREATABLE through ordinary git commands in the first place -- confirmed by
# deliberately removing the guard and re-running this suite unmodified: every
# fixture above still passed. `refs/heads/-Cmain` is, however, a legal ref: it can be
# created directly with `git update-ref`, bypassing porcelain commands' own argument
# parsing (which itself rejects `-Cmain` as a flag, not a branch name -- a second,
# accidental layer of protection this fixture must not rely on). With the guard
# removed and BOTH the local branch and origin's copy already at that name, `T`
# becomes the literal string `-Cmain`, and `git switch -q "$T"` reaches real git as
# `git switch -q -Cmain` -- reproduced live while writing this fixture: git parses
# that as `-C main`, a FORCE-RESET of whatever branch is named `main` to current
# HEAD, not a switch to a branch actually named `-Cmain`. On an unrelated checkout
# this silently discards `main`'s real history.
#
# HEAD is deliberately put on a DIFFERENT branch (`other`, one extra commit) before
# the run -- an architect finding against this fixture's own first version, which
# left HEAD on `main` itself: `-C main` then resets `main` to the commit it is
# ALREADY on, a same-commit no-op that leaves `main_before = main_after` true
# whether the guard fires or not, so removing the guard was never actually caught
# by the equality check, only by the script then going on to print a success line.
# With HEAD on `other`, a force-reset lands `main` on `other`'s tip -- a different
# commit -- so the equality check is now the thing doing the catching, confirmed by
# deliberately removing the guard and re-running: `main` moves, this fixture fails.
o="$(new_origin dash-base-real main)"
(cd "$o" && git update-ref refs/heads/-Cmain HEAD)
c="$(clone_checkout "$o" dash-base-real-checkout)"
main_before="$(cd "$c" && git rev-parse main)"
(cd "$c" && git update-ref refs/heads/-Cmain HEAD &&
  git switch -qc other && git commit -q --allow-empty -m other)
out="" st=0
out="$(cd "$c" && REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo \
  FAKE_GH_DEFAULT='-Cmain' FAKE_GH_BASE='-Cmain' "$script" 7 2>"$tmp/stderr")" || st=$?
main_after="$(cd "$c" && git rev-parse main)"
if grep -q '^STOP repo=' "$tmp/stderr"; then shape_ok=1; else shape_ok=0; fi
if [ "$st" = 1 ] && [ -z "$out" ] && [ "$shape_ok" = 1 ] && [ "$main_before" = "$main_after" ]; then
  echo "ok - a real refs/heads/-Cmain is still rejected, main's tip is untouched"
else
  echo "FAIL - a real refs/heads/-Cmain: expected a stop with main untouched, got [$out]/exit $st/main $main_before -> $main_after/stderr=[$(cat "$tmp/stderr")]" >&2
  fail=1
fi

# A fork with two remotes carrying the same branch name: only `origin`'s content may
# ever be synced onto, whatever a same-named branch on another remote carries.
o="$(new_origin fork-origin main)"
u="$(new_origin fork-upstream main)"
(cd "$u" && printf 'repo: acme/repo\nnote: upstream-differs\n' > .ai/project.yml && git add -A && git commit -qm "upstream diverges")
c="$(clone_checkout "$o" fork-checkout)"
(cd "$c" && git remote add upstream "$u" && git fetch -q upstream)
assert_success "a same-named branch on a second remote is never the source" "$c" main main main
content="$(cat "$c/.ai/project.yml")"
if [ "$content" = "repo: acme/repo" ]; then
  echo "ok - fork: synced content came from origin, not upstream"
else
  echo "FAIL - fork: synced content came from upstream, not origin: [$content]" >&2
  fail=1
fi

# =========================================================================================
# --- a diverged local branch: --ff-only must refuse, not silently rewrite history -------
# =========================================================================================

o="$(new_origin diverged main)"
c="$(clone_checkout "$o" diverged-checkout)"
(cd "$c" && echo local-only >diverge.txt && git add diverge.txt && git commit -qm "local-only commit")
(cd "$o" && echo origin-only >diverge2.txt && git add diverge2.txt && git commit -qm "origin-only commit")
assert_stop "a diverged local branch is not force-synced" "$c" main main

# =========================================================================================
# --- a local branch AHEAD of origin: --ff-only alone is not "verified synced" -----------
# =========================================================================================
#
# `git merge --ff-only` succeeds as a silent NO-OP when the local branch already contains
# everything origin has, plus more -- a security-critic finding from this extraction's own
# pre-handoff pass, reproduced live: a checkout with one extra local commit on `main`
# (nothing to do with the PR at all -- an artifact of whatever the reviewer had open
# before) passed with exit 0 and HEAD still carrying that extra commit, contradicting the
# "now verified synced" claim SKILL.md makes about this script's output. The fix is an
# explicit post-merge equality check: HEAD must land on EXACTLY origin's tip, byte for
# byte, not merely "at least as far along".
o="$(new_origin local-ahead main)"
c="$(clone_checkout "$o" local-ahead-checkout)"
(cd "$c" && echo local-only >ahead.txt && git add ahead.txt && git commit -qm "local-only commit, ahead of origin")
assert_stop "a local branch ahead of origin is not accepted as 'synced'" "$c" main main

# =========================================================================================
# --- a dirty .ai/project.yml: the post-sync content check refuses a local override ------
# =========================================================================================

o="$(new_origin dirty main)"
c="$(clone_checkout "$o" dirty-checkout)"
(cd "$c" && echo "# local edit" >>.ai/project.yml)
assert_stop "a dirty local .ai/project.yml is not silently accepted" "$c" main main

# =========================================================================================
# --- regression: a stale value from the CALLING shell's environment must never leak -----
# --- onto the STOP line (the #123 critic round that found exactly this) -----------------
# =========================================================================================

o="$(new_origin env-leak main)"
c="$(clone_checkout "$o" env-leak-checkout)"
assert_stop "an inherited \$M from the caller's environment does not leak onto STOP" \
  "$c" main -Cmain M=env-leak-should-not-appear R=env-leak D=env-leak B=env-leak T=env-leak
if grep -q "env-leak-should-not-appear" "$tmp/stderr" 2>/dev/null; then
  echo "FAIL - env-leak: the stale environment value reached the STOP line" >&2
  fail=1
else
  echo "ok - env-leak: the stale environment value did not reach the STOP line"
fi

# The same question for OVERRODE, the flag that puts ` override=1` on a SUCCESS line:
# an inherited OVERRODE=1 from the caller's environment must not make a plain,
# declared-base success print ` override=1` -- that would misreport an ordinary,
# non-overridden sync as one that needed the human escape hatch.
o="$(new_origin overrode-leak main)"
c="$(clone_checkout "$o" overrode-leak-checkout)"
out="" st=0
out="$(cd "$c" && OVERRODE=1 REVIEW_BASE_ANCHOR_GH="$gh_stub" FAKE_GH_REPO=acme/repo \
  FAKE_GH_DEFAULT=main FAKE_GH_BASE=main "$script" 7 2>"$tmp/stderr")" || st=$?
assert_eq "an inherited \$OVERRODE from the caller's environment does not leak onto a plain success" \
  "repo=acme/repo default=main base=main/0" "$out/$st"

if [ "$fail" -ne 0 ]; then
  echo "review-base-anchor.sh fixtures: FAILED" >&2
  exit 1
fi
echo "review-base-anchor.sh fixtures: all passed"
