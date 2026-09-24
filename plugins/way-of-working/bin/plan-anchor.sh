#!/bin/sh
# The deterministic predicate behind the `planning: kind: github_milestones` key
# (reference/project-schema.md § `planning`) -- whether a cursor's `plan_anchor`
# still describes the LIVE milestone description, task issue, and spec comment.
# Mirrors cursor-drift.sh's shape and reasoning: a predicate with a correctness
# argument, not a judgment call, so /way-of-working:resume's auto-start test and
# /way-of-working:handoff's re-anchor check both call this script rather than
# recomputing the comparison in skill prose.
#
# Usage:
#   plan-anchor.sh write  <repo> <milestone> <N|-> [<comment-id|->]
#     Prints the anchor JSON (one line, compact, fixed key order) on stdout,
#     or `unreadable`.
#   plan-anchor.sh verify [--plan] <repo> <pointer-url> <anchor-json>
#     Prints exactly one of `match | drift | unreadable`.
#
# Both modes always exit 0 -- the verdict is stdout, exactly like
# cursor-drift.sh; the caller decides policy.
#
# `verify` (full) checks: the milestone is open, its number equals the anchor's
# and the pointer's; `#N` is open, a true issue (no `pull_request` key), its
# `repository_url` names `<repo>` and its `number` is `N`, its `milestone.number`
# matches, and its `updated_at` equals the anchor's; the spec comment (when
# anchored) has `updated_at` equal to the anchor's and belongs to issue `#N`;
# the description hash matches.
#
# `verify --plan` checks only: milestone open, number equality, description
# hash. It ignores `task_issue` and `spec_comment` entirely -- the mode
# handoff's baseline re-anchor check uses, and that a milestone-closing check
# would use too, since `#N` is legitimately null or closed by the time a
# milestone closes.
#
# The anchor JSON's shape is fixed and produced only by this script's own
# `write` mode -- never hand-written -- so `verify` parses that one shape with
# a handful of anchored sed patterns rather than a general JSON parser. That is
# a deliberate, narrow choice (the same one entry-anchor.sh makes for ledger
# lines): a general parser needs a real interpreter, which the rest of this
# plugin's bin/ scripts are written to avoid requiring.
#
# Hashing: description bytes are read into a FILE by direct redirection
# (`gh api ... > file`), never captured through `$(...)`, which strips
# trailing newlines and would make `write`'s hash and `verify`'s recomputed
# hash diverge on content that legitimately ends in one. An empty or missing
# description hashes like any other content gh and jq agree on -- `unreadable`
# is tied to a FAILED call, never to empty content, so a failed read on both
# sides can never accidentally compare equal.
#
# Permitted toolset: POSIX sh, `gh` (using only its own embedded --jq), and
# `sha256sum` or `shasum -a 256`. No system `jq`, no `yq`, no python -- the
# same bar as cursor-drift.sh and entry-anchor.sh: this must run on any
# maintainer machine with nothing extra installed beyond `gh` itself, which
# the rest of this predicate's job already requires. The anchor parser below
# also avoids `sed`'s `\|` alternation deliberately -- it is a GNU extension,
# not POSIX BRE, and BSD/macOS sed (the default `sed` on a stock Mac) gives no
# output at all for it, which would silently break this script on exactly the
# "any maintainer machine" this header promises. Two independent `sed -n`
# passes (try the non-null shape, then try the literal `null`) do the same job
# with only single-alternative BRE patterns.
set -eu

tmp="$(mktemp -d)" || { echo unreadable; exit 0; }
trap 'rm -rf "$tmp"' EXIT

hash_file() { # hash_file <path> -- prints the hex sha256 of its bytes
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

is_digits() { # is_digits <s> -- true iff <s> is one or more ASCII digits
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

tsv_field() { # tsv_field <n> <tsv-line> -- the nth tab-separated field
  printf '%s\n' "$2" | awk -F'\t' -v n="$1" '{print $n}'
}

# --- anchor JSON: a fixed shape parsed narrowly (see header) ----------------
#
#   {"milestone":<N>,"description_sha256":"<64 hex>","task_issue":<N|null>,
#    "task_issue_updated_at":<"<ts>"|null>,"spec_comment":<{"id":<N>,
#    "updated_at":"<ts>"}|null>}
#
# Every value here is either digits, "null", or a quote-free string (a hex
# hash or an ISO-8601 timestamp), so one pair of anchored sed patterns per key
# is enough -- there is never an escaped quote or a brace to worry about,
# because this script is the only writer of this shape. `[[:space:]]*` after
# the colon tolerates any run of spaces or tabs there (`"key":  value`),
# because `sed` matches per LINE, not across them. That covers a key and its
# value staying on one line, whatever else on the same line is reformatted --
# it does NOT cover a genuinely multi-line, pretty-printed anchor (`jq .`'s
# default output splits `"spec_comment"` from its object across several
# lines), which this parser cannot read at all and answers `unreadable` for,
# same as any other malformed shape. The caller is responsible for handing
# this script the anchor as a SINGLE LINE -- `jq -c` ("compact"), never plain
# `jq .` -- when extracting it from wherever it is stored; the calling skills
# say so at each call site.
#
# Every extractor returns empty ("") when the key is present but its value
# doesn't match the expected shape -- callers MUST check `anchor_has_key`
# first and treat "key present, value didn't parse" as unreadable. Treating
# that emptiness the same as "key legitimately absent" is exactly the bug a
# critic round caught here: a truncated or malformed `spec_comment` object
# read as `null` and `verify` answered `match` on an anchor it could not
# actually parse -- the one path to a false `match` in a script whose whole
# job is to fail closed.
anchor_has_key() { # anchor_has_key <key> <json> -- true (0) iff `"key":` occurs literally
  case "$2" in
    *'"'"$1"'":'*) return 0 ;;
    *) return 1 ;;
  esac
}
anchor_num() { # anchor_num <key> <json> -- digits, "null", or "" (malformed)
  v="$(printf '%s' "$2" | sed -n 's/.*"'"$1"'":[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
  if [ -n "$v" ]; then printf '%s' "$v"; return; fi
  printf '%s' "$2" | sed -n 's/.*"'"$1"'":[[:space:]]*null.*/null/p'
}
anchor_str() { # anchor_str <key> <json> -- the string (unquoted), "null", or ""
  v="$(printf '%s' "$2" | sed -n 's/.*"'"$1"'":[[:space:]]*"\([^"]*\)".*/\1/p')"
  if [ -n "$v" ]; then printf '%s' "$v"; return; fi
  printf '%s' "$2" | sed -n 's/.*"'"$1"'":[[:space:]]*null.*/null/p'
}
anchor_obj() { # anchor_obj <key> <json> -- the raw {...} (one level deep), "null", or ""
  v="$(printf '%s' "$2" | sed -n 's/.*"'"$1"'":[[:space:]]*\({[^{}]*}\).*/\1/p')"
  if [ -n "$v" ]; then printf '%s' "$v"; return; fi
  printf '%s' "$2" | sed -n 's/.*"'"$1"'":[[:space:]]*null.*/null/p'
}

mode="${1:-}"
case "$mode" in
  write | verify) shift ;;
  *)
    echo "plan-anchor.sh: usage: plan-anchor.sh write <repo> <milestone> <N|-> [<comment-id|->]" >&2
    echo "                       plan-anchor.sh verify [--plan] <repo> <pointer-url> <anchor-json>" >&2
    echo unreadable
    exit 0
    ;;
esac

# =============================================================================
if [ "$mode" = write ]; then
  if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "plan-anchor.sh: write needs <repo> <milestone> <N|-> [<comment-id|->]" >&2
    echo unreadable
    exit 0
  fi
  repo="$1"; milestone="$2"; task="$3"; comment="${4:--}"

  if ! is_digits "$milestone"; then echo unreadable; exit 0; fi
  if [ "$task" != "-" ] && ! is_digits "$task"; then echo unreadable; exit 0; fi
  if [ "$comment" != "-" ] && ! is_digits "$comment"; then echo unreadable; exit 0; fi

  if ! gh api "repos/$repo/milestones/$milestone" --jq '.description // empty' \
       >"$tmp/desc" 2>/dev/null; then
    echo unreadable; exit 0
  fi
  desc_hash="$(hash_file "$tmp/desc")" || { echo unreadable; exit 0; }

  task_field=null
  task_updated_field=null
  if [ "$task" != "-" ]; then
    task_updated="$(gh api "repos/$repo/issues/$task" --jq '.updated_at // empty' 2>/dev/null)" \
      && [ -n "$task_updated" ] || { echo unreadable; exit 0; }
    task_field="$task"
    task_updated_field="\"$task_updated\""
  fi

  comment_field=null
  if [ "$comment" != "-" ]; then
    comment_updated="$(gh api "repos/$repo/issues/comments/$comment" --jq '.updated_at // empty' 2>/dev/null)" \
      && [ -n "$comment_updated" ] || { echo unreadable; exit 0; }
    comment_field="{\"id\":$comment,\"updated_at\":\"$comment_updated\"}"
  fi

  printf '{"milestone":%s,"description_sha256":"%s","task_issue":%s,"task_issue_updated_at":%s,"spec_comment":%s}\n' \
    "$milestone" "$desc_hash" "$task_field" "$task_updated_field" "$comment_field"
  exit 0
fi

# =============================================================================
# mode = verify
plan_only=0
if [ "${1:-}" = "--plan" ]; then plan_only=1; shift; fi

if [ "$#" -ne 3 ]; then
  echo "plan-anchor.sh: verify needs [--plan] <repo> <pointer-url> <anchor-json>" >&2
  echo unreadable
  exit 0
fi
repo="$1"; pointer="$2"; anchor="$3"

# The pointer must be exactly https://github.com/<repo>/milestone/<digits> --
# an anchored match on <repo>, digits-only number (project-schema.md § `planning`).
prefix="https://github.com/$repo/milestone/"
case "$pointer" in
  "$prefix"*) num_pointer="${pointer#"$prefix"}" ;;
  *) echo unreadable; exit 0 ;;
esac
if ! is_digits "$num_pointer"; then echo unreadable; exit 0; fi

if ! anchor_has_key milestone "$anchor" || ! anchor_has_key description_sha256 "$anchor"; then
  echo unreadable; exit 0
fi
a_milestone="$(anchor_num milestone "$anchor")"
a_hash="$(anchor_str description_sha256 "$anchor")"
if [ -z "$a_milestone" ] || [ "$a_milestone" = null ] || [ -z "$a_hash" ] || [ "$a_hash" = null ]; then
  echo unreadable; exit 0
fi

if [ "$a_milestone" != "$num_pointer" ]; then echo drift; exit 0; fi

ms_state="$(gh api "repos/$repo/milestones/$a_milestone" --jq '.state // empty' 2>/dev/null)" \
  && [ -n "$ms_state" ] || { echo unreadable; exit 0; }
if [ "$ms_state" != open ]; then echo drift; exit 0; fi

if ! gh api "repos/$repo/milestones/$a_milestone" --jq '.description // empty' \
     >"$tmp/desc" 2>/dev/null; then
  echo unreadable; exit 0
fi
live_hash="$(hash_file "$tmp/desc")" || { echo unreadable; exit 0; }
if [ "$live_hash" != "$a_hash" ]; then echo drift; exit 0; fi

if [ "$plan_only" -eq 1 ]; then
  echo match
  exit 0
fi

if ! anchor_has_key task_issue "$anchor"; then echo unreadable; exit 0; fi
a_task="$(anchor_num task_issue "$anchor")"
a_task_updated="$(anchor_str task_issue_updated_at "$anchor")"
if [ -z "$a_task" ]; then
  # The key is present but its value didn't parse as digits or `null` --
  # malformed, not the legitimate "no task anchored" shape below.
  echo unreadable; exit 0
fi
if [ "$a_task" = null ]; then
  # A planning cursor, or a milestone-close use, legitimately anchors no
  # task -- full verify has nothing to confirm live and therefore never
  # matches. Those callers use --plan instead; reaching here under full
  # verify with no task means the auto-start caller cannot proceed -- drift,
  # not unreadable.
  echo drift; exit 0
fi

issue_tsv="$(gh api "repos/$repo/issues/$a_task" --jq \
  '[.state, .updated_at, .repository_url, (.number|tostring),
    ((.milestone.number // "") | tostring),
    (if has("pull_request") then "1" else "0" end)] | @tsv' 2>/dev/null)" \
  && [ -n "$issue_tsv" ] || { echo unreadable; exit 0; }

i_state="$(tsv_field 1 "$issue_tsv")"
i_updated="$(tsv_field 2 "$issue_tsv")"
i_repo_url="$(tsv_field 3 "$issue_tsv")"
i_number="$(tsv_field 4 "$issue_tsv")"
i_milestone="$(tsv_field 5 "$issue_tsv")"
i_is_pr="$(tsv_field 6 "$issue_tsv")"

if [ "$i_state" != open ] || [ "$i_is_pr" = 1 ] || [ "$i_number" != "$a_task" ] \
   || [ "$i_repo_url" != "https://api.github.com/repos/$repo" ] \
   || [ "$i_milestone" != "$a_milestone" ] || [ "$i_updated" != "$a_task_updated" ]; then
  echo drift; exit 0
fi

if ! anchor_has_key spec_comment "$anchor"; then echo unreadable; exit 0; fi
a_comment="$(anchor_obj spec_comment "$anchor")"
if [ -z "$a_comment" ]; then
  # The key is present but its value is neither `null` nor a parseable
  # `{...}` -- malformed, never treated as "no comment anchored".
  echo unreadable; exit 0
fi
if [ "$a_comment" != null ]; then
  if ! anchor_has_key id "$a_comment" || ! anchor_has_key updated_at "$a_comment"; then
    echo unreadable; exit 0
  fi
  c_id="$(anchor_num id "$a_comment")"
  c_updated="$(anchor_str updated_at "$a_comment")"
  if [ -z "$c_id" ] || [ "$c_id" = null ] || [ -z "$c_updated" ] || [ "$c_updated" = null ]; then
    echo unreadable; exit 0
  fi
  comment_tsv="$(gh api "repos/$repo/issues/comments/$c_id" --jq \
    '[.updated_at, .issue_url] | @tsv' 2>/dev/null)" \
    && [ -n "$comment_tsv" ] || { echo unreadable; exit 0; }
  cm_updated="$(tsv_field 1 "$comment_tsv")"
  cm_issue_url="$(tsv_field 2 "$comment_tsv")"
  if [ "$cm_updated" != "$c_updated" ] \
     || [ "$cm_issue_url" != "https://api.github.com/repos/$repo/issues/$a_task" ]; then
    echo drift; exit 0
  fi
fi

echo match
exit 0
