#!/bin/sh
# Prepare, report on and clean up coder lanes, and show which tasks can run as parallel lanes: a worktree under the lanes directory
# (`lanes.dir`) and the prompt file its session reads. Wrapped by /way-of-working:lanes. Issue #715.
# It runs only from the installed plugin, never as a working-tree copy by path: its siblings
# (spec-find.sh, gh-identity.sh, prune-verdict.sh, lane-state.sh, lane-groups.sh) are found
# beside it through $0.
#
# Usage:
#   lane.sh prep N M BRANCH CRITICS [ALSO]
#   lane.sh status
#   lane.sh done N
#   lane.sh groups M
#
#   N        the task issue number, digits with no leading zero
#   M        the milestone number the driver expects the task to be on (the driver's own
#            anchored milestone); the container clone has no .ai/state.json to name it. For
#            groups, the milestone whose open tasks are grouped
#   BRANCH   TYPE/SLUG: TYPE a commit type of reference/conventions.md, SLUG one or more of
#            a-z, 0-9 and `-`, starting with a letter or digit
#   CRITICS  a comma list of architect, security-critic, docs-consistency; no repeats
#   ALSO     optional: a comma list of the issue numbers folded into N, each digits with no
#            leading zero, none empty, none repeated, none equal to N; each is checked like N
#            and the prompt tells the lane its PR closes them too
#
# The lanes directory is `lanes.dir` of the default branch's committed .ai/project.yml
# (project-schema.md, `lanes`): an absolute path of A-Za-z0-9._/-, with no `//`, no `.` or
# `..` component and no trailing slash. The default-branch read runs first in every mode.
#
# Output. Every stop prints exactly one line on stdout and exits 1; a bad argument, a slash-less
# $0 or a missing sibling prints a usage line on stderr, nothing on stdout, and exits 2, before
# any git or gh call. No stderr of git or gh is ever shown: the origin URL and gh's error text
# never print.
#   not-main         every mode: not run from the main worktree (a linked worktree, a lane's
#                    own tree, inside the lanes directory, or outside a git work tree)
#   no-lanes         every mode: the default branch's `lanes` is absent, null, not a map, or its
#                    `dir` fails the rule above
#   unsafe-dir       the lanes directory (or its resolved path) is a link, not a directory,
#                    not owned by this user, or could not be made
#   unreadable       a read failed or had an unexpected shape (the default-branch read, the
#                    existence probes, the verdict inputs, groups: lane-state.sh's list or
#                    lane-groups.sh's output), or this script sits inside the main
#                    worktree or the lanes directory instead of the installed plugin
#   repo-mismatch    the default branch's .repo is not the origin's nameWithOwner
#   backlog-case     every mode: the default branch's backlog.repo names the origin's repository in
#                    different letter case; set it to the origin's nameWithOwner, or null
#   unreached        prep: the installation token's repositories do not list origin's repository
#   not-map          `identities` is not a map; lanes rely on the finder
#   exists           prep: the worktree path, prompt file, branch or branch config is taken
#   finder: WORD     prep: the finder printed WORD (none, unreacted, escalated, ambiguous,
#                    moved or unreadable) instead of `found`
#   bad-issue        prep: the task or a folded (ALSO) issue is closed, a pull request, off
#                    milestone M, or not the number asked for
#   failed           prep: a step from the base fetch on (or a signal from the lanes
#                    directory step on) failed and what this run did was
#                    undone as far as it could be; done: the branch config probe or removal,
#                    or the prompt file removal, failed (after the branch was deleted)
#   no-lane          done: no worktree LANES/N on a branch that is neither BASE nor the
#                    default branch
#   missing          done: the lane's worktree is listed but its directory is gone; run
#                    `git worktree prune --dry-run -v` first
#   not-merged       done: no same-repository PR from that branch merged into BASE
#   ambiguous        done: more than one such PR
#   kept X WORD      done: prune-verdict.sh said WORD (not `delete`), or WORD is `moved` or
#                    `checked-out`; the branch is kept. `checked-out` stops before anything is
#                    removed unless the checkout appears between the pre-removal re-read and
#                    the post-removal re-read; then, and always for `moved`, the worktree is
#                    already gone and the prompt file stays. An `unreadable` from the
#                    post-removal re-read leaves the same state (worktree gone, branch, config
#                    and prompt file kept; finish by hand)
#   dirty            done: git refused to remove the worktree (unclean or locked)
# Success. prep prints worktree=, branch=, found=ID UP, milestone=, prompt= and
# prompt-sha256= lines; done prints removed-worktree PATH, deleted-branch X, then
# removed-prompt PATH or no-prompt, then `next` lines. status prints one TSV row per lane,
# ordered by issue: origin's nameWithOwner, `<backlog repo>#<N>`, branch, PR (`#P STATE`, `-`
# for none, `ambiguous`), checks (`-` unless the PR is open, else fail, pending, pass, none or
# unreadable; a display summary only, /way-of-working:pr-checks is the merge verdict), spec
# (`found` or the finder's word); `none` for no lanes or no lanes directory.
# done's `next <group> #a #b` lines come from lane-groups.sh, minus the issues of live lanes and
# the issues whose `shared` field names one; `next none` or `next unreadable` otherwise. A live
# lane is a lane worktree lane-state.sh lists (not a directory), and stays live until its own
# `done`, merged or not. It is checked for path overlap whatever its issue's milestone, but only
# when lane-groups.sh could read its spec paths. A lane-state.sh list that fails or prints
# `unreadable` makes the result `next unreadable`. The lines never change done's exit status.
# groups M prints, on exit 0, the lines lane-groups.sh printed for milestone M, verbatim (one row
# per open issue, then one `group` line each, or `group none`), then `live #a #b` (ascending, the
# live lanes' issues as `done` takes them) or `live none`. The groups ignore live lanes: the issues
# of live lanes are passed to lane-groups.sh only for its path overlap, and none is dropped. It
# stops `unreadable`, printing nothing else, when lane-state.sh's list fails or has an unexpected
# shape, when lane-groups.sh exits non-zero or prints a line outside the row and group shapes
# `done` accepts (its own `unreadable` included), or when it prints no `group` line and not
# `group none`. A missing lanes directory means no live lanes; a present one that fails the
# checks above stops `unsafe-dir`.
#
# GitHub host. The script unsets GH_HOST and GH_ENTERPRISE_TOKEN once at the top. Each gh call
# names its host or repository explicitly (--hostname github.com, --repo, a repos/ path);
# GH_CONFIG_DIR still selects which config and token gh reads.
#
# Trust. The project file is read from the default branch's committed copy, resolved ONCE to
# an oid, never from the working tree. The scripts that decide are the installed plugin's own
# bin/, beside this one: same-user-writable on the home volume, so a same-user process can edit
# them, and a same-user lane.sh earlier on PATH can shadow this one.
#
# Residuals (stated, not fixed):
#   - Every lane runs as the same user in the same lanes directory. Once a lane has checked the
#     hash and read its copy, another same-user process can still change that lane's worktree.
#   - A post-checkout hook that fails makes `git worktree add` exit non-zero with the worktree
#     still registered; rollback then removes nothing and prep prints `failed`, so a re-run
#     stops with `exists`. A branch checked out between done's last re-read and its
#     `update-ref -d` is deleted, since update-ref has no checked-out guard.
#   - Every lane session is such a same-user process, and the least trusted one.
#   - The main worktree's .git, and the git config on the home volume (~/.gitconfig,
#     ~/.config/git/), are also this script's trust root. A same-user process can
#     edit it: its config (insteadOf, the remote URL), its hooks (a reference-transaction
#     hook runs during the driver's fetch), info/attributes and core.attributesFile, and its
#     refs. That is outside what this script can guard.
#   - /way-of-working:ship never sets a PR's milestone. The lane sets it to M after ship when
#     the backlog is the repo and M is still open; the driver confirms it.
#   - The M the driver types ties the task to the driver's milestone. Whether that milestone
#     is the active sprint stays the driver's call.
#
# Permitted toolset: POSIX sh plus `test -O` and `-ef`, git 2.36 or later (lane-state.sh's
# floor), gh (with its own --jq), yq (mikefarah v4), sha256sum, awk, cut, sed, tr, grep, mktemp,
# mkdir, ln, chmod, rm, rmdir, dirname, cat.
set -eu
set -f
umask 077
LC_ALL=C
GIT_TERMINAL_PROMPT=0
GCM_INTERACTIVE=never
export LC_ALL GIT_TERMINAL_PROMPT GCM_INTERACTIVE
unset GH_HOST GH_ENTERPRISE_TOKEN

TMP=
trap '[ -z "$TMP" ] || rm -rf "$TMP"' EXIT
# dash does not run the EXIT trap on a signal; exiting from a signal trap does.
trap 'exit 1' INT TERM HUP

usage() {
  echo "usage: lane.sh prep N M BRANCH CRITICS [ALSO] | lane.sh status | lane.sh done N | lane.sh groups M" >&2
  exit 2
}

stop() {
  printf '%s\n' "$*"
  exit 1
}

# ---- argument checks (whole-string `case`, so a value carrying a newline fails) ----------

num_ok() { # digits with no leading zero
  case "$1" in
    '' | 0* | *[!0-9]*) return 1 ;;
  esac
  return 0
}

hex40() {
  case "$1" in
    *[!0-9a-f]*) return 1 ;;
  esac
  [ "${#1}" -eq 40 ]
}

branch_ok() { # TYPE/SLUG
  case "$1" in
    */*) ;;
    *) return 1 ;;
  esac
  b_type=${1%%/*}
  b_slug=${1#*/}
  case "$b_type" in
    feat | fix | docs | test | refactor | perf | chore | ci | revert) ;;
    *) return 1 ;;
  esac
  case "$b_slug" in
    '' | -* | *[!a-z0-9-]*) return 1 ;;
  esac
  return 0
}

critics_ok() {
  case "$1" in
    *[!a-z,-]*) return 1 ;;
  esac
  c_list="$1,"
  c_seen=,
  while [ -n "$c_list" ]; do
    c_item=${c_list%%,*}
    c_list=${c_list#*,}
    case "$c_item" in
      architect | security-critic | docs-consistency) ;;
      *) return 1 ;;
    esac
    case "$c_seen" in
      *,"$c_item",*) return 1 ;;
    esac
    c_seen="$c_seen$c_item,"
  done
  return 0
}

also_ok() { # a comma list of issue numbers: no empty item, no repeat, none equal to N
  case "$1" in
    *[!0-9,]*) return 1 ;;
  esac
  a_list="$1,"
  a_seen=,
  while [ -n "$a_list" ]; do
    a_item=${a_list%%,*}
    a_list=${a_list#*,}
    num_ok "$a_item" || return 1
    [ "$a_item" != "$N" ] || return 1
    case "$a_seen" in
      *,"$a_item",*) return 1 ;;
    esac
    a_seen="$a_seen$a_item,"
  done
  return 0
}

lanes_shape_ok() { # an absolute path of A-Za-z0-9._/-, no //, no . or .. component, no trailing /
  case "$1" in
    /*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *[!A-Za-z0-9._/-]* | *// | */) return 1 ;;
  esac
  case "$1/" in
    *//* | */./* | */../*) return 1 ;;
  esac
  return 0
}

ref_shape_ok() { # a branch name as spec-find.sh's pr_base rule has it
  case "$1" in
    '' | -* | *[!A-Za-z0-9._/-]*) return 1 ;;
  esac
  return 0
}

repo_shape_ok() { # owner/name, no . or .. part
  case "$1" in
    '' | /* | */ | */*/* | *[!A-Za-z0-9._/-]*) return 1 ;;
    */*) ;;
    *) return 1 ;;
  esac
  r_owner=${1%%/*}
  r_name=${1#*/}
  case "$r_owner" in '' | . | ..) return 1 ;; esac
  case "$r_name" in '' | . | ..) return 1 ;; esac
  return 0
}

[ "$#" -ge 1 ] || usage
MODE=$1
case "$MODE" in
  prep)
    [ "$#" -eq 5 ] || [ "$#" -eq 6 ] || usage
    N=$2
    M=$3
    BRANCH=$4
    CRITICS=$5
    ALSO=
    num_ok "$N" && num_ok "$M" && branch_ok "$BRANCH" && critics_ok "$CRITICS" || usage
    if [ "$#" -eq 6 ]; then
      ALSO=$6
      also_ok "$ALSO" || usage
    fi
    ;;
  status)
    [ "$#" -eq 1 ] || usage
    ;;
  done)
    [ "$#" -eq 2 ] || usage
    N=$2
    num_ok "$N" || usage
    ;;
  groups)
    [ "$#" -eq 2 ] || usage
    M=$2
    num_ok "$M" || usage
    ;;
  *) usage ;;
esac

# The siblings are found beside this script through $0, as lane-state.sh finds spec-find.sh: a
# slash-less $0 would resolve to the current directory, where a branch under review could supply
# them.
case "$0" in
  */*) ;;
  *) usage ;;
esac
BIN=$(cd -P "$(dirname -- "$0")" 2>/dev/null && pwd -P) || usage
for sib in spec-find.sh gh-identity.sh prune-verdict.sh lane-state.sh lane-groups.sh; do
  [ -f "$BIN/$sib" ] || usage
done
LANES=

# ---- the main worktree --------------------------------------------------------------------

TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null) || stop not-main
[ -n "$TOPLEVEL" ] || stop not-main
dirs=$(git -C "$TOPLEVEL" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null) || stop not-main
gd=$(printf '%s\n' "$dirs" | awk 'NR==1')
gc=$(printf '%s\n' "$dirs" | awk 'NR==2')
[ -n "$gd" ] && [ "$gd" = "$gc" ] || stop not-main

TMP=$(mktemp -d) || stop unreadable

# ---- the lanes directory -------------------------------------------------------------------

LANES_RESOLVED=

# lanes_check: LANES exists as a plain directory this user owns, and its resolved path is
# safe to put in a prompt. Sets LANES to the resolved value and returns 1 on any failure.
lanes_check() {
  [ ! -L "$LANES" ] || return 1
  [ -d "$LANES" ] || return 1
  [ -O "$LANES" ] || return 1
  lc_res=$(cd -P "$LANES" 2>/dev/null && pwd -P) || return 1
  lanes_shape_ok "$lc_res" || return 1
  if [ -n "$LANES_RESOLVED" ] && [ "$lc_res" != "$LANES_RESOLVED" ]; then
    return 1
  fi
  LANES=$lc_res
  LANES_RESOLVED=$lc_res
  return 0
}

# ---- the default-branch read ---------------------------------------------------------------

NAME= D= DOID= DEFFILE= BACKLOG= BASE=

read_default() {
  rd_url=$(git -C "$TOPLEVEL" remote get-url origin 2>/dev/null) || stop unreadable
  case "$rd_url" in '' | -*) stop unreadable ;; esac
  gh repo view "$rd_url" --json nameWithOwner,defaultBranchRef \
    --jq '[.nameWithOwner, (.defaultBranchRef.name // "")] | @tsv' >"$TMP/rv.tsv" 2>/dev/null || stop unreadable
  awk -F'\t' 'NR>1 {bad=1} NF!=2 || $1=="" || $2=="" {bad=1} END {exit (bad || NR!=1)}' "$TMP/rv.tsv" || stop unreadable
  NAME=$(cut -f1 "$TMP/rv.tsv")
  D=$(cut -f2 "$TMP/rv.tsv")
  repo_shape_ok "$NAME" || stop unreadable
  ref_shape_ok "$D" || stop unreadable
  git -C "$TOPLEVEL" fetch -q origin "+refs/heads/$D:refs/remotes/origin/$D" >/dev/null 2>&1 || stop unreadable
  DOID=$(git -C "$TOPLEVEL" rev-parse --verify -q "refs/remotes/origin/$D^{commit}" 2>/dev/null) || stop unreadable
  hex40 "$DOID" || stop unreadable
  DEFFILE=$TMP/project.yml
  git -C "$TOPLEVEL" show "$DOID:.ai/project.yml" >"$DEFFILE" 2>/dev/null || stop unreadable
  rd_repo=$(yq -r '.repo' "$DEFFILE" 2>/dev/null) || stop unreadable
  [ "$rd_repo" = "$NAME" ] || stop repo-mismatch
  rd_id=$(yq -r 'has("identities"), (.identities | tag)' "$DEFFILE" 2>/dev/null) || stop unreadable
  rd_id=$(printf '%s' "$rd_id" | tr '\n' ' ')
  [ "$rd_id" = "true !!map" ] || stop not-map
  rd_lanes=$(yq -r 'explode(.) | (.lanes | tag) as $t | if $t == "!!map" then (.lanes.dir | tag) else "absent" end' "$DEFFILE" 2>/dev/null) || stop unreadable
  [ "$rd_lanes" = "!!str" ] || stop no-lanes
  LANES=$(yq -r 'explode(.) | .lanes.dir' "$DEFFILE" 2>/dev/null) || stop unreadable
  lanes_shape_ok "$LANES" || stop no-lanes
  rd_tags=$(yq -r 'explode(.) | [(.pr_base | tag), ((.backlog.repo // .repo) | tag)] | join(" ")' "$DEFFILE" 2>/dev/null) || stop unreadable
  [ "$rd_tags" = "!!str !!str" ] || stop unreadable
  BASE=$(yq -r 'explode(.) | .pr_base' "$DEFFILE" 2>/dev/null) || stop unreadable
  BACKLOG=$(yq -r 'explode(.) | (.backlog.repo // .repo)' "$DEFFILE" 2>/dev/null) || stop unreadable
  ref_shape_ok "$BASE" || stop unreadable
  repo_shape_ok "$BACKLOG" || stop unreadable
  if [ "$BACKLOG" != "$NAME" ]; then
    rd_bl=$(printf '%s' "$BACKLOG" | tr 'A-Z' 'a-z') || stop unreadable
    rd_nm=$(printf '%s' "$NAME" | tr 'A-Z' 'a-z') || stop unreadable
    [ "$rd_bl" != "$rd_nm" ] || stop backlog-case
  fi
}

# probe_branch_config: 0 when branch.X.* keys exist, 1 when none, 2 on any other exit.
probe_branch_config() {
  pc_rc=0
  git -C "$TOPLEVEL" config --get-regexp "^branch\\.$1\\." >/dev/null 2>&1 || pc_rc=$?
  case "$pc_rc" in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

# wt_state: print the worktree list for LANES/N as `none`, `detached` or `branch REF`.
wt_state() {
  git -C "$TOPLEVEL" worktree list --porcelain >"$TMP/wt.txt" 2>/dev/null || return 1
  awk -v w="$LANES/$N" '
    $0 == "worktree " w { listed = 1; found = 1; next }
    /^worktree / { listed = 0 }
    listed && /^branch / { br = substr($0, 8) }
    END {
      if (!found) print "none"
      else if (br == "") print "detached"
      else print "branch " br
    }
  ' "$TMP/wt.txt"
}

read_default

# The main worktree may not sit inside the lanes directory.
if [ -d "$LANES" ]; then
  lanes_phys=$(cd -P "$LANES" 2>/dev/null && pwd -P) || lanes_phys=$LANES
else
  lanes_phys=$LANES
fi
case "$TOPLEVEL/" in
  "$lanes_phys"/*) stop not-main ;;
esac
# The scripts that decide are the installed plugin's: a copy run by path from the main worktree or a
# lane would make its own siblings the deciders.
case "$BIN/" in
  "$TOPLEVEL"/* | "$lanes_phys"/*) stop unreadable ;;
esac

# ---- prep -----------------------------------------------------------------------------------

WT_ATTEMPTED= WT_ADDED= CREATED_LANES= TMPNAME= PROMPT_MADE= BOID=

rollback() {
  trap '' INT TERM HUP
  # The prompt name is ours when the link to the temp name exists, even if a signal came
  # between `ln` and the flag.
  if [ -n "$TMPNAME" ] && [ "$LANES/$N-prompt.md" -ef "$TMPNAME" ]; then
    rm -f "$LANES/$N-prompt.md" 2>/dev/null || true
  fi
  [ -z "$TMPNAME" ] || rm -f "$TMPNAME" 2>/dev/null || true
  [ -z "$PROMPT_MADE" ] || rm -f "$LANES/$N-prompt.md" 2>/dev/null || true
  rb_gone=1
  if [ -n "$WT_ADDED" ]; then
    git -C "$TOPLEVEL" worktree remove --force "$LANES/$N" >/dev/null 2>&1 || rb_gone=
  fi
  # Another prep with the same BRANCH may have won the race and have it checked out: update-ref
  # has no checked-out guard, so look first.
  rb_listed=
  if [ -n "$WT_ATTEMPTED" ] && [ -n "$rb_gone" ] \
    && git -C "$TOPLEVEL" worktree list --porcelain >"$TMP/rb.txt" 2>/dev/null \
    && ! grep -Fx -- "branch refs/heads/$BRANCH" "$TMP/rb.txt" >/dev/null; then
    if [ -n "$(git -C "$TOPLEVEL" for-each-ref --format=x "refs/heads/$BRANCH" 2>/dev/null)" ]; then
      if git -C "$TOPLEVEL" update-ref -d "refs/heads/$BRANCH" "$BOID" >/dev/null 2>&1; then
        pb_rc=0
        probe_branch_config "$BRANCH" || pb_rc=$?
        [ "$pb_rc" -ne 0 ] || git -C "$TOPLEVEL" config --remove-section "branch.$BRANCH" >/dev/null 2>&1 || true
      fi
    fi
  fi
  [ -z "$CREATED_LANES" ] || rmdir "$LANES" 2>/dev/null || true
}

# Undo what this run did, then stop; stdout is fd 3 because a signal can land inside a redirect.
on_signal() {
  rollback
  trap - EXIT
  [ -z "$TMP" ] || rm -rf "$TMP"
  echo failed >&3
  exit 1
}

fail() {
  rollback
  stop failed
}

emit_prompt_sed() {
  sed -e "s#@BACKLOG@#$BACKLOG#g" -e "s#@N@#$N#g" -e "s#@M@#$M#g" \
    -e "s#@ID@#$FID#g" -e "s#@UP@#$FUP#g" -e "s#@LANES@#$LANES#g" \
    -e "s#@CRITICS@#$CRITICS#g" -e "s#@BIN@#$BIN#g" -e "s#@CODER@#$CODER#g" \
    -e "s#@TOPLEVEL@#$TOPLEVEL#g"
}

# The prompt is three quoted heredocs, each through the same sed expressions, the fifth step chosen
# in between: the chosen text is sed's input like the rest of the template, never a replacement
# string. The closes line (ALSO given) is printed, never a sed replacement string, since `#` is
# sed's delimiter. Every part must succeed (the caller's `||` turns set -e off), so a failed early part
# cannot leave a truncated prompt that reads as success.
emit_prompt() {
  emit_prompt_sed <<'PROMPT' || return 1
# Lane prompt: @BACKLOG@#@N@

You are a **lane**. For this one task you act as the `coder` defined in `@CODER@`. The driver session that ran `lane.sh prep` is your spawner.

## Task

- **Task:** `@BACKLOG@#@N@`, on milestone `@M@`.
- **Missing state file:** this worktree has no `.ai/state.json`. Wherever `coder.md` refers to `plan_anchor.task_issue`, use `@N@`. Wherever it refers to the anchor's milestone, use `@M@`.
- **Mode:** `map`.
- **Spec:** the spawner names the found pair `found @ID@ @UP@`. The pin is `PIN_ID='@ID@'` and `PIN_UP='@UP@'`.

## PATH: on every Bash call that runs a plugin script

A Bash tool call does not keep exports from earlier calls. So every Bash call that runs a plugin `bin/` script (`spec-find.sh`, `spec-comment.sh`, `spec-fresh.sh`, `gh-identity.sh`, `spec-reaction.sh` and the rest) starts with this line, which also checks that the installed plugin's scripts are the ones found:

    export PATH='@BIN@':"$PATH" && [ "$(command -v spec-find.sh)" = @BIN@/spec-find.sh ] || { echo "PATH check failed"; exit 1; }

If that check fails, stop and report.

## Order of work

1. Build the task per `coder.md`.
2. Run every `gates.green` entry in `.ai/project.yml`, each from its `cwd` (the repo root when absent) in its own Bash call with the tool's maximum timeout (600000 ms); if one times out, stop and report.
3. Run `/way-of-working:critic-gate` with no names on its invocation line. The driver's critics are `@CRITICS@`, given here as names this session holds: when critic-gate selects its critics by rule it unions them with its set and asks nothing; when it proposes, show both lists to the human in the pick-list, as before. That list is not the explicit-names shortcut, which only names the human types count for.
4. Commit and open the PR with `/way-of-working:ship`. This is the explicit instruction to commit and push that `coder.md` asks for.
PROMPT
  if [ -n "$ALSO" ]; then
    ep_list="Closes $BACKLOG#$N"
    ep_rest="$ALSO,"
    while [ -n "$ep_rest" ]; do
      ep_list="$ep_list, Closes $BACKLOG#${ep_rest%%,*}"
      ep_rest=${ep_rest#*,}
    done
    printf '   The PR body closes each of these issues: %s.\n' "$ep_list" || return 1
  fi
  if [ "$BACKLOG" = "$NAME" ]; then
    emit_prompt_sed <<'MILESTONEWRITE' || return 1
5. Set this PR's milestone, only when ship's author check passed and ship reported the PR URL; `P` is the number at the end of that URL. In one Bash call, capture each value into a variable, check it is non-empty and chain with `&&`: require `P` to be digits with no leading zero; require `gh api repos/@BACKLOG@/pulls/$P --jq '.head.repo.full_name + " " + .head.ref'` to print `@BACKLOG@`, one space, then what `git branch --show-current` prints; require `gh api repos/@BACKLOG@/milestones/@M@ --jq .state` to print `open`; then run `gh api -X PATCH repos/@BACKLOG@/issues/$P -F milestone=@M@ --jq .milestone.number`, setting no other field. The milestone is set only when that last call prints `@M@`. Any other outcome (a `P` that is not digits, a head repository or branch mismatch, a closed milestone, a failed read, a PATCH that failed or the session refused, another number printed) is no further write. Report the outcome in your final message either way, and never retry with another value or another command.
MILESTONEWRITE
  else
    emit_prompt_sed <<'NOMILESTONE' || return 1
5. Make no milestone write: milestone `@M@` is in the backlog repository, not this PR's. Say so in your final message.
NOMILESTONE
  fi
  emit_prompt_sed <<'PROMPT' || return 1

## Lane rules

- Never run `/way-of-working:resume`, `/way-of-working:handoff`, `/way-of-working:plan-sprint` or `/way-of-working:archive-sprint`. Never write the `.ai/` cursor: `.ai/state.json`, `.ai/next-steps.md`, `.ai/parked/` or `.ai/archive/`. Write any other path under `.ai/` only when the spec's *Files touched* lists it.
- Never merge, approve or force-push.
- Work only in `@LANES@/@N@`, never in `@TOPLEVEL@`'s working tree.
- A session that read the issue body or drafted the spec never builds the issue.

## Identity

- Do not prefix commands with `GH_TOKEN`.
PROMPT
}

prep() {
  # 1. the paths the prompt names: the installed plugin's bin/ and coder definition, and the
  # main worktree
  CODER=$(cd -P "$BIN/../agents" 2>/dev/null && pwd -P) || stop unreadable
  CODER=$CODER/coder.md
  lanes_shape_ok "$BIN" && lanes_shape_ok "$CODER" && lanes_shape_ok "$TOPLEVEL" \
    && [ -f "$CODER" ] && [ ! -L "$CODER" ] || stop unreadable
  # 2. the lanes directory, if it exists
  if [ -e "$LANES" ] || [ -L "$LANES" ]; then
    lanes_check || stop unsafe-dir
  fi
  # 3. exists
  [ ! -e "$LANES/$N" ] && [ ! -L "$LANES/$N" ] && [ ! -e "$LANES/$N-prompt.md" ] && [ ! -L "$LANES/$N-prompt.md" ] || stop exists
  git -C "$TOPLEVEL" worktree list --porcelain >"$TMP/wt.txt" 2>/dev/null || stop unreadable
  wt_rc=0
  grep -Fx -- "worktree $LANES/$N" "$TMP/wt.txt" >/dev/null 2>&1 || wt_rc=$?
  case "$wt_rc" in 0) stop exists ;; 1) ;; *) stop unreadable ;; esac
  refs=$(git -C "$TOPLEVEL" for-each-ref --format=x "refs/heads/$BRANCH" "refs/remotes/origin/$BRANCH" 2>/dev/null) || stop unreadable
  [ -z "$refs" ] || stop exists
  pb_rc=0
  probe_branch_config "$BRANCH" || pb_rc=$?
  case "$pb_rc" in 0) stop exists ;; 1) ;; *) stop unreadable ;; esac
  lsr=$(git -C "$TOPLEVEL" ls-remote --heads origin "refs/heads/$BRANCH" 2>/dev/null) || stop unreadable
  [ -z "$lsr" ] || stop exists
  # 4. the token's reach: an installation token that lists origin's repository
  gh api --hostname github.com --paginate installation/repositories \
    --jq '.repositories[].full_name' >"$TMP/reach.txt" 2>/dev/null || stop unreadable
  [ -s "$TMP/reach.txt" ] || stop unreadable
  rc_rc=0
  rc_word=$(sh "$BIN/gh-identity.sh" reach "$NAME" <"$TMP/reach.txt" 2>/dev/null) || rc_rc=$?
  [ "$rc_rc" -eq 0 ] || stop unreadable
  case "$rc_word" in
    reached) ;;
    unreached) stop unreached ;;
    *) stop unreadable ;;
  esac
  # 5. the finder
  fd_rc=0
  fd_out=$(sh "$BIN/spec-find.sh" find "$N" "$DEFFILE" 2>/dev/null) || fd_rc=$?
  [ "$fd_rc" -eq 0 ] || stop "finder: unreadable"
  case "$fd_out" in
    *'
'*) stop "finder: unreadable" ;;
  esac
  case "$fd_out" in
    found\ *)
      fd_rest=${fd_out#found }
      case "$fd_rest" in *\ *) ;; *) stop "finder: unreadable" ;; esac
      FID=${fd_rest%% *}
      FUP=${fd_rest#* }
      num_ok "$FID" || stop "finder: unreadable"
      case "$FUP" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
        *) stop "finder: unreadable" ;;
      esac
      ;;
    *)
      fd_w=${fd_out%% *}
      case "$fd_w" in
        none | unreacted | escalated | ambiguous | moved) stop "finder: $fd_w" ;;
        *) stop "finder: unreadable" ;;
      esac
      ;;
  esac
  # 6. the task issue
  gh api "repos/$BACKLOG/issues/$N" \
    --jq '[(.number|tostring), .state, (if has("pull_request") then "1" else "0" end), ((.milestone.number // 0)|tostring)] | @tsv' \
    >"$TMP/issue.tsv" 2>/dev/null || stop unreadable
  awk -F'\t' 'NR>1 {bad=1} NF!=4 {bad=1} END {exit (bad || NR!=1)}' "$TMP/issue.tsv" || stop unreadable
  is_n=$(cut -f1 "$TMP/issue.tsv")
  is_state=$(cut -f2 "$TMP/issue.tsv")
  is_pr=$(cut -f3 "$TMP/issue.tsv")
  is_ms=$(cut -f4 "$TMP/issue.tsv")
  [ "$is_n" = "$N" ] && [ "$is_state" = open ] && [ "$is_pr" = 0 ] && [ "$is_ms" = "$M" ] || stop bad-issue
  # 6b. the folded issues, read and checked like the task
  if [ -n "$ALSO" ]; then
    al_rest="$ALSO,"
    while [ -n "$al_rest" ]; do
      al_n=${al_rest%%,*}
      al_rest=${al_rest#*,}
      gh api "repos/$BACKLOG/issues/$al_n" \
        --jq '[(.number|tostring), .state, (if has("pull_request") then "1" else "0" end), ((.milestone.number // 0)|tostring)] | @tsv' \
        >"$TMP/also.tsv" 2>/dev/null || stop unreadable
      awk -F'\t' 'NR>1 {bad=1} NF!=4 {bad=1} END {exit (bad || NR!=1)}' "$TMP/also.tsv" || stop unreadable
      [ "$(cut -f1 "$TMP/also.tsv")" = "$al_n" ] && [ "$(cut -f2 "$TMP/also.tsv")" = open ] \
        && [ "$(cut -f3 "$TMP/also.tsv")" = 0 ] && [ "$(cut -f4 "$TMP/also.tsv")" = "$M" ] || stop bad-issue
    done
  fi
  # 7. the worktree
  # From here on a signal undoes what this run did, then stops.
  exec 3>&1
  trap on_signal INT TERM HUP
  prev_resolved=$LANES_RESOLVED
  if [ ! -e "$LANES" ] && [ ! -L "$LANES" ]; then
    mkdir -m 700 "$LANES" >/dev/null 2>&1 || stop unsafe-dir
    CREATED_LANES=1
  else
    lanes_check || stop unsafe-dir
    chmod 700 "$LANES" >/dev/null 2>&1 || stop unsafe-dir
  fi
  if ! lanes_check; then
    [ -z "$CREATED_LANES" ] || rmdir "$LANES" 2>/dev/null || true
    stop unsafe-dir
  fi
  if [ -n "$prev_resolved" ] && [ "$prev_resolved" != "$LANES_RESOLVED" ]; then
    stop unsafe-dir
  fi
  git -C "$TOPLEVEL" fetch -q origin "+refs/heads/$BASE:refs/remotes/origin/$BASE" >/dev/null 2>&1 || fail
  BOID=$(git -C "$TOPLEVEL" rev-parse --verify -q "refs/remotes/origin/$BASE^{commit}" 2>/dev/null) || fail
  hex40 "$BOID" || fail
  [ ! -e "$LANES/$N" ] && [ ! -L "$LANES/$N" ] || fail
  WT_ATTEMPTED=1
  # A signal during the add only sets a flag, so WT_ADDED always follows git's exit status;
  # git itself still receives a terminal's Ctrl-C and cleans up its half-made worktree.
  SIG=
  trap 'SIG=1' INT TERM HUP
  add_rc=0
  git -C "$TOPLEVEL" worktree add --no-track -b "$BRANCH" "$LANES/$N" "$BOID" >/dev/null 2>&1 || add_rc=$?
  [ "$add_rc" -ne 0 ] || WT_ADDED=1
  trap on_signal INT TERM HUP
  [ -z "$SIG" ] || on_signal
  [ "$add_rc" -eq 0 ] || fail
  # git follows a symbolic link planted at the path and records the resolved one.
  [ ! -L "$LANES/$N" ] || fail
  git -C "$TOPLEVEL" worktree list --porcelain >"$TMP/wt.txt" 2>/dev/null || fail
  grep -Fx -- "worktree $LANES/$N" "$TMP/wt.txt" >/dev/null || fail
  head=$(git -C "$LANES/$N" rev-parse --verify -q HEAD 2>/dev/null) || fail
  [ "$head" = "$BOID" ] || fail
  # 8. the prompt file
  TMPNAME=$(mktemp "$LANES/.prompt.XXXXXX" 2>/dev/null) || fail
  emit_prompt >"$TMPNAME" || fail
  ln "$TMPNAME" "$LANES/$N-prompt.md" >/dev/null 2>&1 || fail
  PROMPT_MADE=1
  rm -f "$TMPNAME" || fail
  TMPNAME=
  hex=$(sha256sum "$LANES/$N-prompt.md" | awk '{print $1}') || fail
  [ "${#hex}" -eq 64 ] || fail
  trap 'exit 1' INT TERM HUP
  # 9. print
  printf '%s\n' "worktree=$LANES/$N" "branch=$BRANCH" "found=$FID $FUP" "milestone=$M" \
    "prompt=$LANES/$N-prompt.md" "prompt-sha256=$hex"
}

# ---- status ---------------------------------------------------------------------------------

# pr_checks P: one display-only word for an open PR's whole rollup, reduced inside gh's own --jq.
pr_checks() {
  pk_w=$(gh pr view "$1" --repo "$NAME" --json statusCheckRollup --jq '
    (.statusCheckRollup // []) as $r
    | if ($r | length) == 0 then "none" else
        [$r[] | if .__typename == "StatusContext" then (.state // "") else (.conclusion // "") end] as $v
        | [$r[] | select(.__typename != "StatusContext") | select((.status // "") != "COMPLETED")] as $open
        | if ([$v[] | select(. != "" and . != "SUCCESS" and . != "NEUTRAL" and . != "SKIPPED" and . != "PENDING" and . != "EXPECTED")] | length) > 0 then "fail"
          elif ($open | length) > 0 or ([$v[] | select(. == "PENDING" or . == "EXPECTED")] | length) > 0 then "pending"
          else "pass" end
      end' 2>/dev/null) || pk_w=unreadable
  case "$pk_w" in
    fail | pending | pass | none) printf '%s' "$pk_w" ;;
    *) printf unreadable ;;
  esac
}

lane_status() {
  if [ ! -e "$LANES" ] && [ ! -L "$LANES" ]; then
    echo none
    return 0
  fi
  lanes_check || stop unsafe-dir
  st_json=$(sh "$BIN/lane-state.sh" list "$LANES" "$DEFFILE" 2>/dev/null) || stop unreadable
  case "$st_json" in
    '[]') echo none; return 0 ;;
    '' | unreadable | *'
'*) stop unreadable ;;
  esac
  printf '%s\n' "$st_json" >"$TMP/lanes.json"
  yq -p=json -r '.[] | [(.issue | tostring), .branch,
      ((.pr | tag) as $t | if $t == "!!null" then "-" elif $t == "!!str" then .pr else "#" + (.pr.number | tostring) + " " + .pr.state end),
      ((.spec | tag) as $u | if $u == "!!map" then "found" else .spec end)] | @tsv' "$TMP/lanes.json" >"$TMP/lanes.tsv" 2>/dev/null || stop unreadable
  awk -F'\t' 'NF!=4 {bad=1} END {exit (bad || NR==0)}' "$TMP/lanes.tsv" || stop unreadable
  : >"$TMP/rows.tsv"
  while IFS='	' read -r sr_n sr_b sr_p sr_s; do
    num_ok "$sr_n" && branch_ok "$sr_b" || stop unreadable
    case "$sr_s" in '' | *[!a-z]*) stop unreadable ;; esac
    sr_c=-
    case "$sr_p" in
      - | ambiguous) ;;
      '#'*' OPEN' | '#'*' CLOSED' | '#'*' MERGED')
        sr_num=${sr_p#'#'}
        sr_num=${sr_num%% *}
        num_ok "$sr_num" || stop unreadable
        case "$sr_p" in
          *' OPEN') sr_c=$(pr_checks "$sr_num") ;;
        esac
        ;;
      *) stop unreadable ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$NAME" "$BACKLOG#$sr_n" "$sr_b" "$sr_p" "$sr_c" "$sr_s" >>"$TMP/rows.tsv"
  done <"$TMP/lanes.tsv"
  cat "$TMP/rows.tsv"
}

# ---- done -----------------------------------------------------------------------------------

# done_next: what the freed lane can take, from lane-groups.sh's groups minus the issues of live
# lanes and the issues whose `shared` field names one. A live lane is a lane worktree lane-state.sh
# lists (not a directory), and stays live until its own `done`, merged or not. Its issue number goes
# to lane-groups.sh, so it is checked for path overlap whatever its milestone, but only when
# lane-groups.sh could read its spec paths. A lane-state.sh list that fails or prints `unreadable`
# makes the result `next unreadable`. Display only: it never changes the exit status.
done_next() {
  dn_ms=$(gh api "repos/$BACKLOG/issues/$N" --jq '(.milestone.number // 0) | tostring' 2>/dev/null) || dn_ms=
  case "$dn_ms" in
    0) echo "next none"; return 0 ;;
  esac
  if ! num_ok "$dn_ms"; then
    echo "next unreadable"
    return 0
  fi
  dn_st=$(sh "$BIN/lane-state.sh" list "$LANES" "$DEFFILE" 2>/dev/null) || dn_st=unreadable
  case "$dn_st" in
    '[]') dn_nums= ;;
    '['*']')
      printf '%s\n' "$dn_st" >"$TMP/live.json"
      dn_nums=$(yq -p=json -r '.[] | (.issue | tostring)' "$TMP/live.json" 2>/dev/null) || dn_nums=bad
      ;;
    *) dn_nums=bad ;;
  esac
  dn_live=,
  for dn_i in $dn_nums; do
    if ! num_ok "$dn_i"; then
      echo "next unreadable"
      return 0
    fi
    dn_live="$dn_live$dn_i,"
  done
  dn_rc=0
  # shellcheck disable=SC2086
  (cd "$TOPLEVEL" && sh "$BIN/lane-groups.sh" "$dn_ms" "$DEFFILE" $dn_nums >"$TMP/groups.tsv" 2>/dev/null) || dn_rc=$?
  if [ "$dn_rc" -ne 0 ]; then
    echo "next unreadable"
    return 0
  fi
  dn_out=$(awk -F'\t' -v live="$dn_live" '
    function isl(n) { return index(live, "," n ",") > 0 }
    NF==5 && $1 ~ /^[1-9][0-9]*$/ {
      drop[$1] = isl($1)
      if ($4 ~ /^#[0-9]+(,#[0-9]+)*$/) {
        k = split($4, sh, ",")
        for (j = 1; j <= k; j++) { v = substr(sh[j], 2); if (isl(v)) drop[$1] = 1 }
      }
      next
    }
    $0 == "group none" { seen = 1; next }
    NF==3 && $1 == "group" && $2 ~ /^[1-9][0-9]*$/ && $3 ~ /^#[0-9]+( #[0-9]+)*$/ {
      seen = 1
      m = split($3, g, " "); line = ""
      for (j = 1; j <= m; j++) if (!(substr(g[j], 2) in drop) || !drop[substr(g[j], 2)]) line = line " " g[j]
      if (line != "") out[++c] = "next " $2 line
      next
    }
    { bad = 1 }
    END {
      if (bad || !seen) exit 3
      if (c == 0) print "next none"
      for (j = 1; j <= c; j++) print out[j]
    }' "$TMP/groups.tsv") || dn_out="next unreadable"
  printf '%s\n' "$dn_out"
}

lane_done() {
  if [ -e "$LANES" ] || [ -L "$LANES" ]; then
    lanes_check || stop unsafe-dir
  fi
  # 2. the lane
  st=$(wt_state) || stop unreadable
  case "$st" in
    "branch refs/heads/"*) X=${st#branch refs/heads/} ;;
    *) stop no-lane ;;
  esac
  branch_ok "$X" && [ "$X" != "$BASE" ] && [ "$X" != "$D" ] || stop no-lane
  [ -d "$LANES/$N" ] || stop missing
  # 3. the merged PR
  gh pr list --repo "$NAME" --base "$BASE" --head "$X" --state merged \
    --json number,headRefOid,isCrossRepository \
    --jq '.[] | select(.isCrossRepository == false) | [(.number|tostring), .headRefOid] | @tsv' \
    >"$TMP/pr.tsv" 2>/dev/null || stop unreadable
  awk -F'\t' 'NF!=2 {bad=1} END {exit bad}' "$TMP/pr.tsv" || stop unreadable
  rows=$(awk 'END {print NR}' "$TMP/pr.tsv")
  [ "$rows" -ne 0 ] || stop not-merged
  [ "$rows" -eq 1 ] || stop ambiguous
  OID=$(cut -f2 "$TMP/pr.tsv")
  hex40 "$OID" || stop unreadable
  # 4. the verdict
  TIP=$(git -C "$TOPLEVEL" rev-parse --verify -q "refs/heads/$X^{commit}" 2>/dev/null) || stop unreadable
  hex40 "$TIP" || stop unreadable
  verdict=$(cd "$TOPLEVEL" && sh "$BIN/prune-verdict.sh" "$X" "$OID" 2>/dev/null) || verdict=unreadable
  case "$verdict" in
    delete | skip-ahead | skip-unfetchable | unreadable) ;;
    *) verdict=unreadable ;;
  esac
  # 5.
  [ "$verdict" = delete ] || stop "kept $X $verdict"
  # 6. A branch checked out in a second worktree stops here, with nothing removed.
  git -C "$TOPLEVEL" worktree list --porcelain >"$TMP/wt.txt" 2>/dev/null || stop unreadable
  rows_rc=0
  rows=$(grep -Fx -c -- "branch refs/heads/$X" "$TMP/wt.txt") || rows_rc=$?
  case "$rows_rc" in 0 | 1) ;; *) stop unreadable ;; esac
  [ "$rows" -le 1 ] || stop "kept $X checked-out"
  git -C "$TOPLEVEL" worktree remove "$LANES/$N" >/dev/null 2>&1 || stop dirty
  # 7.
  git -C "$TOPLEVEL" worktree list --porcelain >"$TMP/wt.txt" 2>/dev/null || stop unreadable
  rows_rc=0
  grep -Fx -- "branch refs/heads/$X" "$TMP/wt.txt" >/dev/null 2>&1 || rows_rc=$?
  case "$rows_rc" in 0) stop "kept $X checked-out" ;; 1) ;; *) stop unreadable ;; esac
  git -C "$TOPLEVEL" update-ref -d "refs/heads/$X" "$TIP" >/dev/null 2>&1 || stop "kept $X moved"
  pb_rc=0
  probe_branch_config "$X" || pb_rc=$?
  case "$pb_rc" in
    0) git -C "$TOPLEVEL" config --remove-section "branch.$X" >/dev/null 2>&1 || stop failed ;;
    1) ;;
    *) stop failed ;;
  esac
  # 8.
  removed=
  if [ -e "$LANES/$N-prompt.md" ] || [ -L "$LANES/$N-prompt.md" ]; then
    rm -f "$LANES/$N-prompt.md" || stop failed
    removed=1
  fi
  # 9.
  printf '%s\n' "removed-worktree $LANES/$N" "deleted-branch $X"
  if [ -n "$removed" ]; then
    printf '%s\n' "removed-prompt $LANES/$N-prompt.md"
  else
    echo no-prompt
  fi
  done_next
}

# ---- groups ---------------------------------------------------------------------------------

# lane_groups: the groups lane-groups.sh finds for milestone M, with the live lanes' issues passed
# as `done` passes them. Nothing is printed until every check has passed.
lane_groups() {
  gp_nums=
  if [ -e "$LANES" ] || [ -L "$LANES" ]; then
    lanes_check || stop unsafe-dir
    gp_st=$(sh "$BIN/lane-state.sh" list "$LANES" "$DEFFILE" 2>/dev/null) || stop unreadable
    case "$gp_st" in
      '[]') ;;
      '['*']')
        case "$gp_st" in *'
'*) stop unreadable ;; esac
        printf '%s\n' "$gp_st" >"$TMP/live.json"
        gp_nums=$(yq -p=json -r 'unique_by(.issue) | sort_by(.issue) | .[] | (.issue | tostring)' "$TMP/live.json" 2>/dev/null) || stop unreadable
        ;;
      *) stop unreadable ;;
    esac
  fi
  gp_live=
  for gp_i in $gp_nums; do
    num_ok "$gp_i" || stop unreadable
    gp_live="$gp_live #$gp_i"
  done
  gp_rc=0
  # shellcheck disable=SC2086
  (cd "$TOPLEVEL" && sh "$BIN/lane-groups.sh" "$M" "$DEFFILE" $gp_nums >"$TMP/groups.tsv" 2>/dev/null) || gp_rc=$?
  [ "$gp_rc" -eq 0 ] || stop unreadable
  awk -F'\t' '
    NF==5 && $1 ~ /^[1-9][0-9]*$/ { next }
    $0 == "group none" { seen = 1; next }
    NF==3 && $1 == "group" && $2 ~ /^[1-9][0-9]*$/ && $3 ~ /^#[0-9]+( #[0-9]+)*$/ { seen = 1; next }
    { bad = 1 }
    END { exit (bad || !seen) }' "$TMP/groups.tsv" || stop unreadable
  cat "$TMP/groups.tsv"
  if [ -z "$gp_live" ]; then
    echo "live none"
  else
    printf 'live%s\n' "$gp_live"
  fi
}

FID= FUP=
case "$MODE" in
  prep) prep ;;
  status) lane_status ;;
  done) lane_done ;;
  groups) lane_groups ;;
esac
