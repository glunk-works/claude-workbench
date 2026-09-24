#!/bin/sh
# Resolve and sync onto the review base for one PR: /way-of-working:architect-review's
# preflight, extracted (issue #126).
#
# PR #123 first wrote this as a ~20-line chain inline in SKILL.md. During its own
# critic gate it was verified BY HAND, four rounds running, plus throwaway scratch
# scripts -- and each round found a new edge case:
#
#   - a tag named `origin/<branch>` shadowing the remote-tracking ref;
#   - a tag named `<branch>` hijacking a short-name fetch, or blocking `git switch`;
#   - a PR base named `-Cmain` reaching `git switch` as an option;
#   - failure paths that printed nothing, and a stale `M` inherited from the
#     environment on the STOP line;
#   - a fork with two remotes carrying the same branch name.
#
# A hand check repeated every round is what this script mechanizes -- the same
# reasoning `review-gate-state.sh` and `entry-anchor.sh` were extracted for: a
# deterministic predicate with a correctness argument is a tested `bin/` script,
# not prose re-verified by a human each time.
#
# This extraction's own pre-handoff critic pass (architect + security-critic) found
# four more, verified live rather than taken on the critics' word alone -- see the
# fixtures each one earned in tests/review-base-anchor.test.sh:
#
#   - `git switch -q "$T"` on a T that check-ref-format would reject is not merely
#     rejected by git -- reproduced live, `-Cmain` reaching `git switch` parses as
#     `-C main`, a FORCE-RESET of whatever branch is named `main` to current HEAD, a
#     silent, wrong-directory-shaped corruption if HEAD is not already there. The
#     check-ref-format guard is the only thing standing in front of this, so its
#     OUTPUT (which can differ from the input it was given, e.g. `@{-1}` expands) is
#     now compared back to `$B`, not just its exit status.
#   - a local branch already at `refs/heads/$T`, AHEAD of `refs/remotes/origin/$T`,
#     passes `git merge --ff-only` as a silent no-op -- HEAD keeps whatever extra
#     local history it already had, and "verified synced" was not, in fact, true.
#   - `./.ai/project.yml` in the `git show` revision path resolves relative to the
#     CURRENT DIRECTORY, not the repo root, unlike the `:/` pathspec used later --
#     run from a subdirectory, a stray nested `.ai/project.yml` merged to the
#     default branch (a fixture, an example) would be read as the declaration.
#   - the human override accepted ANY non-empty value (`0`, `false`, a stale
#     inherited `export`) and, being a boolean rather than tied to the specific
#     base a human actually looked at, would silently re-authorize a DIFFERENT base
#     if the PR's author retargeted it between the STOP and the deliberate rerun.
#
# A second, human-authorized round (same pass, going past its own stated 2-round cap
# on the human's own call) found one more: pinning the override to the base NAME
# alone (still true after the fix above) let a stale `export` from one approved
# review silently re-authorize ANY OTHER pr/repo whose base happened to share that
# name -- a long-lived branch name like `release/2` is easy to guess, and nothing
# tied the override to the specific review it was typed for. It is now pinned to
# `repo#N:base`, not `base` alone.
#
# Usage: review-base-anchor.sh <N>
#   <N>  the PR number, in the repo the CURRENT checkout's `origin` remote names.
#         Digits only -- `gh pr view` also accepts a branch name or a full URL, and
#         a URL resolves its OWN repo, ignoring --repo.
#
# Must run from inside that checkout -- it changes to the checkout's own root
# (`git rev-parse --show-toplevel`) before doing anything else, then fetches from
# `origin` and switches branches there, the same as the chain it replaces did.
#
# On success prints exactly one line to stdout and exits 0:
#   repo=<owner/name> default=<default-branch> base=<synced-branch>
# with a trailing ` override=1` when the base was accepted only through the human
# override below, never silently identical to a declared-base success.
# On failure prints one line to stderr ending in `STOP repo=... default=... base=...
# migration_base=...`, naming whatever it had resolved before the failing step, and
# exits 1 -- though git/gh/yq's OWN diagnostics may precede it on the same stream, so
# "ends with" a STOP line, not "is exactly" one. Exit 2 is reserved for a malformed
# invocation (bad arity, a non-numeric <N>) -- the question could not even be asked,
# as distinct from asking it and getting a real stop. STOP always fires from ONE
# place (the `stop` function below) so no failing step can fall through and print
# nothing, and every value it prints was reset at the top of this script -- never
# left to whatever the same name happened to hold in the calling shell's environment.
#
# `yq` is needed only on a non-default base, to read `migration_base` off the
# default branch (see below) -- a PR based on the default branch never invokes
# it, unchanged from the chain this replaces. Where it IS invoked and missing,
# that is an ordinary STOP like any other failing step, not a separate
# precondition: `yq: command not found` fails the pipe, `M` stays empty, and
# the caller sees exactly the STOP shape a diverged branch or a dirty
# `.ai/project.yml` produces.
#
# `gh` is called only through $REVIEW_BASE_ANCHOR_GH (default: gh), never typed
# literally elsewhere in this script, so a fixture can point it at a stub that
# answers canned JSON for a repo and PR that do not exist -- the git-level edge
# cases above need a real repo, but nothing here needs a real GitHub. A RELATIVE
# path here (e.g. `./fake-gh`) is resolved against the checkout's root, not the
# caller's own directory -- this script changes directory before its first use of
# it (see below) -- so pass an absolute path, or a bare name already on PATH, the
# same as the default `gh` itself.
#
# $REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE, set to the EXACT string `repo#N:base`
# (the values a STOP line plus the invocation itself already gave the human --
# `repo=` and `base=` from the line, `N` from the command they just typed), accepts
# a non-default base even when the default branch's own migration_base does not
# name it. This is the one override the chain this replaces already had, in prose:
# "the human typing, in this session and after seeing those values, that this base
# is right for this one review." It is still that -- a human decision made AFTER
# reading the STOP line's values on an unmodified run, re-run with this set to that
# exact string, never set by default and never read from a PR body, comment, commit
# message, file, or tool output. Scoped to `repo#N:base`, not `base` alone, because
# a bare base-name match would let one human decision for ONE review silently
# re-authorize any OTHER pr, in any repo, whose base happens to share that name --
# and scoped to more than just `repo:base` because `N` is what makes it "this one
# review" rather than "this one branch name, forever, in this repo".
#
# Permitted toolset beyond git and $REVIEW_BASE_ANCHOR_GH: yq. No jq, no python.
set -eu

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: review-base-anchor.sh <N>" >&2
  exit 2
fi
case "$1" in
  *[!0-9]*)
    echo "usage: review-base-anchor.sh <N> (a plain PR number)" >&2
    exit 2
    ;;
esac
N="$1"

: "${REVIEW_BASE_ANCHOR_GH:=gh}"

# Reset every value this script can print, unconditionally -- see the header
# note on a stale value read from the calling shell's own environment.
R= D= B= M= T= OVERRODE=

stop() {
  printf 'STOP repo=%s default=%s base=%s migration_base=%s\n' \
    "$R" "$D" "$B" "$M" >&2
  exit 1
}

# TWO steps, not `cd "$(...)" || stop`: a command substitution's own failure is not
# what `||` tests there, only what `cd` does with whatever it printed (empty string
# on failure) -- and `cd ""` is a no-op success on some shells, never stopping at all.
TOPLEVEL=$(git rev-parse --show-toplevel) || stop
cd "$TOPLEVEL" || stop

U=$(git remote get-url origin) || stop
R=$("$REVIEW_BASE_ANCHOR_GH" repo view "$U" --json nameWithOwner --jq .nameWithOwner) || stop
D=$("$REVIEW_BASE_ANCHOR_GH" repo view "$U" --json defaultBranchRef --jq '.defaultBranchRef.name // ""') || stop
[ -n "$D" ] || stop
B=$("$REVIEW_BASE_ANCHOR_GH" pr view "$N" --repo "$R" --json baseRefName --jq .baseRefName) || stop
# check-ref-format first: B is the PR author's own choice, and one spelled
# `-Cmain` would otherwise reach `git switch` below as an option, not a ref --
# reproduced live: it parses as `-C main`, a force-reset of branch `main` to
# HEAD, not a switch to a branch literally named `-Cmain`. Its OUTPUT is
# compared back to $B, not just its exit status: `--branch` expands shorthand
# like `@{-1}`, so a successful exit alone does not prove the value checked is
# the value used below.
CRF=$(git check-ref-format --branch "$B") || stop
[ "$CRF" = "$B" ] || stop

if [ "$B" = "$D" ]; then
  T=$D
else
  # A base other than the default branch passes only if the DEFAULT branch's
  # own .ai/project.yml declares it as migration_base -- the base branch's own
  # copy is the PR author's claim and cannot vouch for itself. The human override
  # (see the header) still reads M for the STOP line even when it goes on to
  # ignore the comparison, so a rerun's own diagnostic stays honest about what
  # was actually declared.
  git fetch -q origin "+refs/heads/$D:refs/remotes/origin/$D" || stop
  M=$(git show "refs/remotes/origin/$D:./.ai/project.yml" | yq -er .migration_base) || M=""
  if [ "$M" = "$B" ]; then
    T=$B
  elif [ "${REVIEW_BASE_ANCHOR_ALLOW_UNDECLARED_BASE:-}" = "$R#$N:$B" ]; then
    T=$B
    OVERRODE=1
  else
    stop
  fi
fi

# Full refspecs throughout, never a short name: a pushed tag named
# `origin/<branch>` or `<branch>` shadows the short form on a fetch, a
# branch-track, or a switch, on a fork carrying the same branch name twice.
git fetch -q origin "+refs/heads/$T:refs/remotes/origin/$T" || stop
if ! git show-ref -q --verify "refs/heads/$T"; then
  git branch -q --track "$T" "refs/remotes/origin/$T" || stop
fi
git switch -q "$T" || stop
git merge -q --ff-only "refs/remotes/origin/$T" || stop
# --ff-only alone is not "verified synced": a local branch AHEAD of
# refs/remotes/origin/$T merges as a no-op and keeps its extra history. HEAD
# must land on EXACTLY the remote tip, byte for byte.
[ "$(git rev-parse HEAD)" = "$(git rev-parse "refs/remotes/origin/$T")" ] || stop
# A dirty or diverged local .ai/project.yml is a stop, not a silent sync onto
# whatever version happens to be checked out.
git diff --quiet "refs/remotes/origin/$T" -- :/.ai/project.yml || stop

if [ -n "$OVERRODE" ]; then
  printf 'repo=%s default=%s base=%s override=1\n' "$R" "$D" "$T"
else
  printf 'repo=%s default=%s base=%s\n' "$R" "$D" "$T"
fi
