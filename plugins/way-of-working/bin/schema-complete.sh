#!/bin/sh
# The deterministic predicate behind WB-D17 (#142) -- every dotted key path the
# schema documents must be PRESENT in a consuming repo's `.ai/project.yml`.
# `null` is the explicit "no value" wherever a key's own reference gives `null`
# a meaning; a key that is entirely absent is an unanswered question, never a
# silent default. Mirrors cursor-drift.sh's and plan-anchor.sh's shape: a
# predicate with a correctness argument, not a judgment call, so
# /way-of-working:resume's *Ensure the schema is complete* step and
# scripts/invariants-check.sh call this script rather than recomputing the
# check in prose.
#
# Usage:
#   schema-complete.sh check <file>
#     Prints, on stdout:
#       complete             -- every required key present and well-formed
#       incomplete           -- first line `incomplete`, then one line per
#                                finding:
#                                  missing <dotted.path> <kind>
#                                  invalid <dotted.path> <json-value>
#                                <kind> is one of: enum:<a>|<b>  nullable
#                                value  list. <json-value> is the OFFENDING
#                                value, compact JSON (`yq -o=json -I=0`),
#                                truncated. This is STRUCTURAL containment,
#                                not semantic neutralization: it keeps a
#                                malicious multi-line or fake-finding-shaped
#                                value from splitting across lines or forging
#                                a `missing `/`invalid ` line of its own (a
#                                JSON string literal can't open one), which
#                                matters because this file may be
#                                adversary-controlled on a branch other than
#                                the default (see resume/SKILL.md's *Check the
#                                branch-protection ruleset for drift* step,
#                                which reads a DIFFERENT copy of this same
#                                file for exactly that reason). It does NOT
#                                stop a quoted 200-character string from
#                                reading as an instruction to whatever later
#                                relays it in prose (a pick-up summary) --
#                                that reader must still treat the finding's
#                                value as data, never as something to act on,
#                                the same rule this schema's own § `planning`
#                                already states for a milestone description or
#                                issue body.
#       unreadable            -- the file doesn't exist or can't be read, its
#                                YAML doesn't parse, or `yq` is not on PATH
#     Always exits 0 -- the verdict is stdout, the caller decides policy.
#
#   schema-complete.sh keys
#     Prints the required dotted key paths, one per line, in schema order.
#     The four `review.ci_gate.*` sub-keys are suffixed ` if-map` -- they are
#     required only when `review.ci_gate` itself resolves to a map, never
#     when it is `null`. Always exits 0.
#
# The key set is NOT derived from `.ai/project.yml` or from walking any YAML
# at all -- it is the union of the dotted paths BOTH documented examples in
# `reference/project-schema.md` show (Full schema + Worked example), STOPPING
# AT SEQUENCES (`gates.green`, `load_bearing_docs`, `code_paths`,
# `ruleset.*` lists are leaves; their elements are values, never keys of
# their own). Enum value sets (`planning.kind`, `backlog.kind`, `models.*`)
# are hardcoded below, not derived from the doc -- `scripts/invariants-check.sh`
# is what holds this list and the doc in sync, by set equality on `keys`'
# own output (conditional suffix stripped) against a real path-walk of both
# example blocks. A key present in `.ai/project.yml` but not in this list is
# ignored, never flagged -- two plugin versions may write the same file, and
# an unknown extra key is not this script's business.
#
# --- Presence vs. null, the whole point of this script -------------------
#
# A plain `yq eval '.a.b' file` traversal returns the literal string `null`
# BOTH when `.a.b` is present with an explicit null value AND when it is
# entirely absent -- yq does not distinguish the two on a bare path read
# (confirmed live: `.a.d` on a document with no `d` key under `a` prints
# `null`, tag `!!null`, exit 0, identical to `.a.b: null`). `has("key")`
# is what distinguishes them, and confirmed live to degrade gracefully
# rather than error when the node it's called on is itself null, a scalar,
# a sequence, or simply absent (`.x | has("y")` on a document with no `x`
# key at all still answers `false`, not an error) -- so a single-shot
# `<parent> | has("<lastseg>")` query is enough per key, with no need to
# walk each intermediate segment by hand.
#
# --- `invalid` is also a shape check for the routing keys ------------------
#
# `repo`/`backlog.repo` must match `owner/name` (checked in pure POSIX
# parameter expansion -- exactly one `/`, non-empty on both sides).
# `pr_base`/`migration_base` must round-trip through `git check-ref-format
# --branch` -- comparing the OUTPUT back to the input, not just the exit
# status, because `--branch` expands shorthand like `@{-1}` (the same
# reasoning `bin/review-base-anchor.sh`'s header records for the identical
# check there; a value spelled `-Cmain` reaching a later `git switch`
# un-checked is the exact bug that check guards against).
#
# All four also pass through `is_safe_chars`: every byte must be in
# `[A-Za-z0-9._/-]`. These are the keys OTHER skills interpolate, unsanitized,
# into shell command templates the model builds at runtime (a branch-cut, a
# `gh pr create --base {pr_base}`, a `[ "$R" != "{repo}" ]` comparison) --
# neither the owner/name split nor `check-ref-format` alone rejects shell
# metacharacters (a security-critic pass confirmed `repo: "a/b $(id)"` and
# ``pr_base: "m$(id>&2)"`` both read `complete` before this guard existed).
# `complete` on these four keys means safe to interpolate, not merely
# shape-plausible.
#
# --- What this script deliberately does NOT check --------------------------
#
# Cross-key consistency (`planning.kind: github_milestones` with
# `backlog.kind: file`; `backlog.kind: file` with `backlog.path: null`) is
# out of scope -- those are already documented config errors with their own
# reporting in the skills that hit them, and folding them in here would make
# this a validator, not a completeness check. `models.*` values are checked
# against the harness's known model names as a courtesy, not because this
# script is the enforcement point for that set changing.
#
# Permitted toolset: POSIX sh, `yq` (mikefarah v4 -- the python `yq` has a
# different syntax; `yq --version` in a fixture-less environment is the
# caller's job to confirm, not this script's), and `git` (check-ref-format
# only, the same narrow use `review-base-anchor.sh` makes of it). `yq`
# missing from PATH is `unreadable`, never treated as "no findings, therefore
# complete" -- `complete` needs positive evidence, exactly like
# `plan-anchor.sh`'s header states for its own `unreadable` cases.
set -eu

# --- the required key table -------------------------------------------------
# <dotted.path> <kind> <shape>
#   kind:  value | nullable | enum:<a>|<b>|... | cigate (review.ci_gate only)
#   shape: - | ownername | branch   (only consulted for value/nullable kinds)
MAIN_KEYS='
repo value ownername
pr_base value branch
migration_base nullable branch
roadmap value -
sprints_dir value -
threat_model value -
planning.kind enum:files|github_milestones -
decisions.log value -
decisions.prefix value -
backlog.kind enum:github_issues|file -
backlog.repo nullable ownername
backlog.path nullable -
backlog.item_prefix nullable -
load_bearing_docs list -
code_paths list -
gates.green list -
ruleset.name value -
ruleset.rule_types list -
ruleset.required_checks list -
review.ci_gate cigate -
agents.enabled list -
models.architect enum:sonnet|opus|haiku|fable -
models.coder enum:sonnet|opus|haiku|fable -
models.second_opinion nullable enum:sonnet|opus|haiku|fable
'

# The four sub-keys, required only when review.ci_gate resolves to a map.
CIGATE_KEYS='
review.ci_gate.check value -
review.ci_gate.header value -
review.ci_gate.attestation value -
review.ci_gate.triggers_on nullable list
'

mode="${1:-}"
case "$mode" in
  keys)
    printf '%s\n' "$MAIN_KEYS" | while IFS=' ' read -r path kind shape; do
      [ -n "$path" ] || continue
      [ "$path" = "review.ci_gate" ] && continue   # printed via CIGATE_KEYS below
      printf '%s\n' "$path"
    done
    printf '%s\n' "review.ci_gate"
    printf '%s\n' "$CIGATE_KEYS" | while IFS=' ' read -r path kind shape; do
      [ -n "$path" ] || continue
      printf '%s if-map\n' "$path"
    done
    exit 0
    ;;
  check) ;;
  *)
    echo "usage: schema-complete.sh check <file>" >&2
    echo "       schema-complete.sh keys" >&2
    echo unreadable
    exit 0
    ;;
esac

if [ "$#" -ne 2 ]; then
  echo "usage: schema-complete.sh check <file>" >&2
  echo unreadable
  exit 0
fi
FILE="$2"

if ! command -v yq >/dev/null 2>&1; then
  echo unreadable
  exit 0
fi
if [ ! -f "$FILE" ] || [ ! -r "$FILE" ]; then
  echo unreadable
  exit 0
fi
if ! yq eval '.' "$FILE" >/dev/null 2>&1; then
  echo unreadable
  exit 0
fi

findings=''
add_finding() { # add_finding <line, no trailing newline>
  if [ -z "$findings" ]; then
    findings="$1"
  else
    findings="$findings
$1"
  fi
}

truncate_json() { # truncate_json <compact-json> -- one line, capped length
  v="$1"
  max=200
  if [ "${#v}" -gt "$max" ]; then
    printf '%s...' "$(printf '%s' "$v" | cut -c1-"$max")"
  else
    printf '%s' "$v"
  fi
}

is_safe_chars() { # is_safe_chars <value> -- every byte in [A-Za-z0-9._/-], non-empty
  # These four routing keys (repo, pr_base, backlog.repo, migration_base) are read
  # by OTHER skills and interpolated -- unsanitized -- into shell command
  # templates the model builds at runtime (a branch-cut, a `gh pr create --base`,
  # a comparison against `{repo}`). "Shape-valid" alone is not "safe to
  # interpolate": `git check-ref-format --branch` and a bare owner/name split
  # both happily accept `$(id)`, backticks, `;`, `|`, `&`, spaces and quotes --
  # confirmed live, a security-critic pass found `complete` on
  # `repo: "a/b $(id)"` and `pr_base: "m$(id>&2)"`` before this charset guard
  # existed. Real GitHub owner/repo names and this plugin's own branch names
  # never need anything outside this set, so restricting to it costs nothing
  # legitimate and closes the injection path at the source, rather than
  # depending on every future reader to re-quote correctly.
  case "$1" in
    '') return 1 ;;
    *[!A-Za-z0-9._/-]*) return 1 ;;
    *) return 0 ;;
  esac
}

is_owner_name() { # is_owner_name <value> -- exactly one '/', non-empty, non-dot-only both sides
  v="$1"
  is_safe_chars "$v" || return 1
  case "$v" in
    */*) : ;;
    *) return 1 ;;
  esac
  before="${v%%/*}"
  after="${v#*/}"
  case "$after" in
    */*) return 1 ;;
  esac
  [ -n "$before" ] && [ -n "$after" ] || return 1
  # A segment of exactly "." or ".." is syntactically owner/name-shaped (one
  # slash, non-empty both sides) but is a path-traversal token, not a real
  # GitHub owner or repo name. A security-critic pass confirmed LIVE that
  # `backlog.repo: "../user"` read `complete` here and that `gh api
  # repos/../user` actually resolves -- the API does not reject a `..`
  # segment, it walks it, the same way a shell `cd` would.
  case "$before" in '.' | '..') return 1 ;; esac
  case "$after" in '.' | '..') return 1 ;; esac
  return 0
}

is_branch_name() { # is_branch_name <value> -- safe charset, round-trips check-ref-format
  v="$1"
  is_safe_chars "$v" || return 1
  out=$(git check-ref-format --branch "$v" 2>/dev/null) || return 1
  [ "$out" = "$v" ]
}

path_present() { # path_present <dotted-path> -- exit 0 present, 1 absent
  p="$1"
  case "$p" in
    *.*)
      parent="${p%.*}"
      last="${p##*.}"
      q=".${parent} | has(\"$last\")"
      ;;
    *)
      last="$p"
      q="has(\"$last\")"
      ;;
  esac
  ok=$(yq eval "$q" "$FILE" 2>/dev/null) || return 1
  [ "$ok" = "true" ]
}

read_tag() { yq eval ".${1} | tag" "$FILE" 2>/dev/null; }
read_scalar() { yq eval ".${1}" "$FILE" 2>/dev/null; }
read_json() { yq eval -o=json -I=0 ".${1}" "$FILE" 2>/dev/null; }

enum_match() { # enum_match <value> <pipe-separated-set>
  v="$1"; set_str="$2"
  old_ifs="$IFS"
  IFS='|'
  match=1
  for opt in $set_str; do
    [ "$v" = "$opt" ] && match=0
  done
  IFS="$old_ifs"
  return "$match"
}

invalid_finding() { # invalid_finding <path> -- reads+truncates the offending value
                     # ONLY when a finding is actually about to be recorded, not on
                     # every key -- an extra `yq` spawn per VALID key is pure waste,
                     # and on some machines that overhead is not free (confirmed live:
                     # a full run took ~6s per invocation immediately after a burst of
                     # unrelated git subprocess activity, vs. sub-second in isolation).
  add_finding "invalid $1 $(truncate_json "$(read_json "$1")")"
}

has_only_safe_chars_at() { # has_only_safe_chars_at <path> -- the charset check done
                            # INSIDE yq, against the file directly, never against a
                            # shell-captured `$(...)` value. `$(...)` strips EVERY
                            # trailing newline before a shell variable ever sees it, so
                            # `pr_base: "main\n"` (or the block form `pr_base: |` \n
                            # `  main`) reads back as the harmless string "main" --
                            # `is_safe_chars` on that captured value can never see the
                            # newline it validated. A security-critic pass confirmed
                            # this live in round 2, after round 1's charset guard closed
                            # the shell-metacharacter path. Not a real injection (a
                            # shell reader elsewhere strips the same trailing newline the
                            # same way), but "complete means safe to interpolate" must be
                            # true of the actual bytes, not of a lossy shell capture of
                            # them -- checking inside yq, before any capture happens,
                            # closes that gap at the source instead of special-casing it.
  yq eval ".${1} | test(\"^[A-Za-z0-9._/-]+\$\")" "$FILE" 2>/dev/null | grep -qx true
}

check_value_shape() { # check_value_shape <path> <tag> <shape> -- exit 0 if OK, prints
                       # nothing; caller records the finding. Requires tag = !!str for
                       # every scalar shape (ownername/branch/enum:*) -- a critic pass
                       # on this script's first version found `pr_base: true` (tag
                       # !!bool) and `repo: [a/b]` (tag !!seq) both read as VALID,
                       # because `git check-ref-format`/the owner-name split ran on
                       # yq's plain scalar rendering of the value without ever
                       # checking what kind of node produced that rendering.
                       # "Shape-valid" now requires "is actually a string" first.
  path="$1"; tag="$2"; shape="$3"
  case "$shape" in
    ownername)
      [ "$tag" = '!!str' ] && has_only_safe_chars_at "$path" && is_owner_name "$(read_scalar "$path")"
      ;;
    branch)
      [ "$tag" = '!!str' ] && has_only_safe_chars_at "$path" && is_branch_name "$(read_scalar "$path")"
      ;;
    enum:*)
      set_str="${shape#enum:}"
      [ "$tag" = '!!str' ] && enum_match "$(read_scalar "$path")" "$set_str"
      ;;
    list)
      # A nullable key whose non-null form is a LIST, never a scalar --
      # `review.ci_gate.triggers_on` is the one such key (a path-glob list, per
      # `code_paths`'s own shape). A round-2 architect pass caught the
      # shapeless catch-all below rejecting exactly this: `triggers_on: [src/]`,
      # the form `project-schema.md` itself documents, read as `invalid` once
      # the shapeless branch started rejecting `!!seq` generally.
      [ "$tag" = '!!seq' ]
      ;;
    *)
      # No shape: any scalar is fine (str/int/bool/float); map/seq is not --
      # a critic pass found `roadmap: {a: 1}` read as VALID under the old code,
      # which never checked a shapeless `value` key's tag at all.
      case "$tag" in
        '!!map' | '!!seq') return 1 ;;
        *) return 0 ;;
      esac
      ;;
  esac
}

check_one() { # check_one <path> <kind> <shape>
  path="$1"; kind="$2"; shape="$3"

  if ! path_present "$path"; then
    add_finding "missing $path $kind"
    return
  fi

  tag="$(read_tag "$path")"

  case "$kind" in
    value)
      if [ "$tag" = '!!null' ]; then
        invalid_finding "$path"; return
      fi
      check_value_shape "$path" "$tag" "$shape" || { invalid_finding "$path"; return; }
      ;;
    nullable)
      if [ "$tag" = '!!null' ]; then
        :   # valid -- the explicit no-value answer
      else
        check_value_shape "$path" "$tag" "$shape" || { invalid_finding "$path"; return; }
      fi
      ;;
    enum:*)
      set_str="${kind#enum:}"
      if [ "$tag" != '!!str' ]; then invalid_finding "$path"; return; fi
      enum_match "$(read_scalar "$path")" "$set_str" || { invalid_finding "$path"; return; }
      ;;
    list)
      [ "$tag" = '!!seq' ] || { invalid_finding "$path"; return; }
      ;;
  esac
}

cigate_is_map=0
# A HEREDOC, never a pipe (`cmd | while read`) -- a pipe forks the loop body
# into a subshell under some shells even without an explicit `()`, and
# `findings`/`cigate_is_map` set inside it would not survive to the parent.
# `<<EOF` keeps the loop body in THIS shell's process, so the accumulation
# below is visible after the loop exits.
while IFS=' ' read -r path kind shape; do
  [ -n "$path" ] || continue
  if [ "$path" = "review.ci_gate" ]; then
    if ! path_present "$path"; then
      add_finding "missing $path nullable"
      continue
    fi
    tag="$(read_tag "$path")"
    case "$tag" in
      '!!null') : ;;
      '!!map') cigate_is_map=1 ;;
      *) invalid_finding "$path" ;;
    esac
    continue
  fi
  check_one "$path" "$kind" "$shape"
done <<EOF_KEYS
$MAIN_KEYS
EOF_KEYS

if [ "$cigate_is_map" = 1 ]; then
  while IFS=' ' read -r path kind shape; do
    [ -n "$path" ] || continue
    check_one "$path" "$kind" "$shape"
  done <<EOF_CIGATE
$CIGATE_KEYS
EOF_CIGATE
fi

if [ -z "$findings" ]; then
  echo complete
else
  echo incomplete
  printf '%s\n' "$findings"
fi
exit 0
