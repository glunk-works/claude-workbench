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
#                                branch-protection ruleset for drift* step
#                                and skills/resume/appendices/ruleset-migration.md,
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
#
# --- One yq call per key table, not per key (#189) -------------------------
#
# Every fact the checks need (present, tag, charset, compact JSON) is read in ONE
# `yq` expression per table, because process spawns dominate on Git Bash: the
# per-key form took ~100 spawns and ~3.6s per run (the fixture suite, ~2m15s).
# The `has()` query above is therefore `select(tag == "!!map") | has(...)`, which
# also reads as absent under a scalar parent instead of failing the whole call.
# Consequences kept on purpose, each with a fixture:
#   - rows must match the key table exactly, in order, else `unreadable` (a
#     multi-document file, or any row a value could forge, is never `complete`);
#   - the tag field is a closed set inside yq (a verbatim `!<..%0A..>` tag is
#     percent-decoded by yq into a real newline);
#   - an enum value must also pass the charset test, so `models.coder: "opus\n"`
#     is now `invalid` (it used to pass, via the lossy `$(...)` capture);
#   - a root that is a sequence is `unreadable` (yq refuses to index it -- a side
#     effect, not a deliberate check); a scalar, null or empty root still reads
#     `incomplete` with every key `missing`, as before;
#   - a trailing empty document (`---` after the content) is `unreadable` too;
#     it used to read every key `missing`, because yq answered once per document
#     (`true` then `false`), which never equalled `true`;
#   - a present child under a custom-tagged parent map (`planning: !custom`) reads
#     `missing`, because the guard requires the literal `!!map` tag. Fails closed,
#     and an exotic form; `yq`'s `kind` operator would restore the old answer.
# Needs a yq with `to_json(0)`, `to_string`, `//` and `select`; verified on
# v4.53.6. An older yq that cannot parse the expression prints `unreadable`.
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


# ONE `yq` call reads every fact the checks below need, instead of 3-5 spawns per
# key (#189: ~100 spawns per run made the fixture suite take ~2m15s on Git Bash,
# where process-spawn latency dominates). Each key becomes one tab-separated row,
# in table order:
#   <path> <kind> <shape> <present> <tag> <safe> <json>
# `kind`/`shape` are the table's own literals, echoed back so the loop below needs
# no lookup. `present` is `has()` on the parent, guarded by `select(tag == "!!map")`
# so a scalar parent (`planning: 5`) reads as absent, never as a failed call that
# would take every other key down with it. `safe` is the [A-Za-z0-9._/-] charset
# test done INSIDE yq, against the parsed string, never against a shell-captured
# `$(...)` value: `$(...)` strips every trailing newline, so `pr_base: "main\n"`
# would read back as the harmless "main" and pass a check that never saw the
# newline (a round-2 security-critic finding). `json` is `to_json(0)` -- compact,
# one line, newlines escaped -- so a row can never be split by a value, and a
# string that passed `safe` has no escapes to undo (see `unquote`). `@tsv` is not
# used: it csv-quotes fields containing `"`, which every JSON string does.
TAB=$(printf '\t')

build_rows() { # build_rows <table> -- the yq expression, one row per key
  expr=''
  while IFS=' ' read -r path kind shape; do
    [ -n "$path" ] || continue
    case "$path" in
      *.*) parent=".${path%.*}"; last="${path##*.}" ;;
      *)   parent="."; last="$path" ;;
    esac
    v="($parent | select(tag == \"!!map\") | .${last})"
    row="\"$path\t$kind\t$shape\t\""
    row="$row + (((($parent | select(tag == \"!!map\") | has(\"$last\")) // false)) | to_string)"
    row="$row + \"\t\" + (($v | tag | select(. == \"!!str\" or . == \"!!null\" or . == \"!!map\" or . == \"!!seq\" or . == \"!!bool\" or . == \"!!int\" or . == \"!!float\")) // \"other\")"
    row="$row + \"\t\" + ((($v | select(tag == \"!!str\") | test(\"^[A-Za-z0-9._/-]+\$\")) // false) | to_string)"
    row="$row + \"\t\" + (($v | to_json(0)) // \"null\")"
    if [ -z "$expr" ]; then expr="$row"; else expr="$expr, $row"; fi
  done <<EOF_ROWS
$1
EOF_ROWS
  printf '%s' "$expr"
}

unquote() { # unquote <json-string> -- "abc" -> abc. Only ever called on a string
            # that already passed `safe` (charset excludes " and \), so there are
            # no JSON escapes to undo.
  v="${1#\"}"
  printf '%s' "${v%\"}"
}

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

invalid_finding() { # invalid_finding <path> <json>
  add_finding "invalid $1 $(truncate_json "$2")"
}

check_value_shape() { # check_value_shape <shape> <tag> <safe> <json> -- exit 0 if OK,
                       # prints nothing; caller records the finding. Requires tag =
                       # !!str for every scalar shape (ownername/branch/enum:*) -- a
                       # critic pass on this script's first version found `pr_base:
                       # true` (tag !!bool) and `repo: [a/b]` (tag !!seq) both read
                       # as VALID, because `git check-ref-format`/the owner-name
                       # split ran on yq's plain scalar rendering of the value without
                       # ever checking what kind of node produced that rendering.
                       # "Shape-valid" now requires "is actually a string" first.
  shape="$1"; tag="$2"; safe="$3"; json="$4"
  case "$shape" in
    ownername)
      [ "$tag" = '!!str' ] && [ "$safe" = true ] && is_owner_name "$(unquote "$json")"
      ;;
    branch)
      [ "$tag" = '!!str' ] && [ "$safe" = true ] && is_branch_name "$(unquote "$json")"
      ;;
    enum:*)
      set_str="${shape#enum:}"
      [ "$tag" = '!!str' ] && [ "$safe" = true ] && enum_match "$(unquote "$json")" "$set_str"
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

check_row() { # check_row <path> <kind> <shape> <present> <tag> <safe> <json>
  path="$1"; kind="$2"; shape="$3"; present="$4"; tag="$5"; safe="$6"; json="$7"

  if [ "$present" != true ]; then
    [ "$kind" = cigate ] && kind=nullable   # printed as the interview asks it
    add_finding "missing $path $kind"
    return
  fi

  case "$kind" in
    value)
      if [ "$tag" = '!!null' ]; then
        invalid_finding "$path" "$json"; return
      fi
      check_value_shape "$shape" "$tag" "$safe" "$json" || { invalid_finding "$path" "$json"; return; }
      ;;
    nullable)
      if [ "$tag" = '!!null' ]; then
        :   # valid -- the explicit no-value answer
      else
        check_value_shape "$shape" "$tag" "$safe" "$json" || { invalid_finding "$path" "$json"; return; }
      fi
      ;;
    enum:*)
      set_str="${kind#enum:}"
      if [ "$tag" != '!!str' ] || [ "$safe" != true ]; then invalid_finding "$path" "$json"; return; fi
      enum_match "$(unquote "$json")" "$set_str" || { invalid_finding "$path" "$json"; return; }
      ;;
    list)
      [ "$tag" = '!!seq' ] || { invalid_finding "$path" "$json"; return; }
      ;;
    cigate)
      case "$tag" in
        '!!null') : ;;
        '!!map') cigate_is_map=1 ;;
        *) invalid_finding "$path" "$json" ;;
      esac
      ;;
  esac
}

run_table() { # run_table <table> -- one yq call, then check each row
  # An outright yq failure here (the file already parsed above) is unreadable, not
  # a pile of per-key findings: fail closed rather than guess.
  rows=$(yq eval "$(build_rows "$1")" "$FILE" 2>/dev/null) || { echo unreadable; exit 0; }
  # The output must be exactly one row per table key, in table order -- checked, not
  # assumed. yq evaluates the expression once PER DOCUMENT, so a multi-document file
  # (`---`) yields a second set of rows that each look fine alone while a consumer's
  # `yq '.pr_base'` prints both documents' values; and any field that let a value
  # forge a row would land here as a count or path mismatch. Either is `unreadable`.
  # (The tag field is a closed set inside yq for the same reason: a verbatim tag
  # `!<...%0A...>` is decoded by yq into real separators.)
  want=''
  while IFS=' ' read -r path _kind _shape; do
    [ -n "$path" ] || continue
    want="$want$path
"
  done <<EOF_WANT
$1
EOF_WANT
  # A HEREDOC, never a pipe (`cmd | while read`) -- a pipe forks the loop body
  # into a subshell under some shells even without an explicit `()`, and
  # `findings`/`cigate_is_map` set inside it would not survive to the parent.
  while IFS="$TAB" read -r path kind shape present tag safe json; do
    next="${want%%
*}"
    [ -n "$next" ] && [ "$path" = "$next" ] || { echo unreadable; exit 0; }
    want="${want#*
}"
    check_row "$path" "$kind" "$shape" "$present" "$tag" "$safe" "$json"
  done <<EOF_ROWS
$rows
EOF_ROWS
  [ -z "$want" ] || { echo unreadable; exit 0; }
}

cigate_is_map=0
run_table "$MAIN_KEYS"
[ "$cigate_is_map" = 1 ] && run_table "$CIGATE_KEYS"

if [ -z "$findings" ]; then
  echo complete
else
  echo incomplete
  printf '%s\n' "$findings"
fi
exit 0
