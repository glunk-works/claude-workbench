#!/bin/sh
# Fixture tests for scripts/coupling-check.sh.
#
# The gate's whole job is to fail closed, and every bug it has had was a way to
# report a pass over something it never read: #49 (hooks/ outside a hardcoded
# allowlist), and then six more found across two rounds of #53's own critic pass
# -- files at a plugin root unscanned, a whole plugin skipped by a repo-wide
# counter, a trailing newline defeating the exclusion `case`, grep's exit 2 read
# as "no match", an exclusion matching a plugin-root file by name when it is
# justified by type, and dotglob (which alone makes a root .mcp.json visible)
# pinned by nothing. A gate that silently stops gating looks exactly like a gate
# that passed, so the behaviour is pinned here rather than left to convention.
# Every assertion below is mutation-checked: reverting its fix must fail it.
# See issue #53.
#
# Each fixture is a throwaway plugins/ tree in a tempdir; the script is run with
# that tree as cwd, which is how CI runs it.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/coupling-check.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

# A literal from TIER1 -- the pattern set is the script's business, not this
# suite's; these tests are about which paths get looked at at all.
LITERAL='hatch run'

assert_status() {
  desc="$1"
  expected="$2"
  dir="$3"
  actual=0
  ( cd "$dir" && bash "$script" >/dev/null 2>&1 ) || actual=$?
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected exit [$expected], got [$actual]" >&2
    fail=1
  fi
}

tree() {
  d="$tmp/$1"
  mkdir -p "$d/plugins"
  echo "$d"
}

# --- a clean tree passes ----------------------------------------------------
d="$(tree clean)"
mkdir -p "$d/plugins/wow/skills"
echo "portable content" >"$d/plugins/wow/skills/a.md"
assert_status "clean: a portable plugin passes" 0 "$d"

# --- the #49 bug: a component directory nobody added to a list --------------
d="$(tree newdir)"
mkdir -p "$d/plugins/wow/commands" "$d/plugins/wow/skills"
echo "$LITERAL" >"$d/plugins/wow/commands/c.md"
# The sibling matters: without a second scannable directory this fixture would
# also fail via the per-plugin guard, and would then still pass if commands/
# were wrongly excluded. The clean sibling keeps the guard quiet so the only
# thing that can fail this case is commands/ actually being read.
echo "portable content" >"$d/plugins/wow/skills/a.md"
assert_status "denylist: a brand-new component directory is scanned" 1 "$d"

# --- files at a plugin's root are plugin content too ------------------------
d="$(tree rootfile)"
mkdir -p "$d/plugins/wow/skills"
echo "portable content" >"$d/plugins/wow/skills/a.md"
# A non-dot name deliberately: this case must prove the `*/` -> `*` glob change
# on its own, independently of dotglob, which the .mcp.json case below covers.
echo "$LITERAL" >"$d/plugins/wow/plugin-notes.md"
assert_status "root file: a literal in a plain plugin-root file is caught" 1 "$d"

# --- the exclusions are real, and only they are ------------------------------
d="$(tree excluded)"
mkdir -p "$d/plugins/wow/reference" "$d/plugins/wow/.claude-plugin" "$d/plugins/wow/skills"
echo "$LITERAL" >"$d/plugins/wow/reference/schema.md"
echo "$LITERAL" >"$d/plugins/wow/.claude-plugin/plugin.json"
echo "portable content" >"$d/plugins/wow/skills/a.md"
assert_status "exclusions: reference/ and .claude-plugin/ may carry literals" 0 "$d"

# The exclusions are justified by what the entry IS, so they must match on type
# as well as name: a plugin-root FILE named `reference` is not documentation.
# Matching on name alone was a green pass over unread content.
d="$(tree named_like_exclusion)"
mkdir -p "$d/plugins/wow/skills"
echo "portable content" >"$d/plugins/wow/skills/a.md"
echo "$LITERAL" >"$d/plugins/wow/reference"
assert_status "exclusions: a plugin-root FILE named reference is still scanned" 1 "$d"

# dotglob is what makes the exclusion `case` a real decision rather than an
# accident -- without it the glob never yields dot-entries at all, so
# .claude-plugin/ would be skipped for the wrong reason and a dot-named root
# file (.mcp.json carries MCP server commands) would never be scanned.
d="$(tree dotfile)"
mkdir -p "$d/plugins/wow/skills"
echo "portable content" >"$d/plugins/wow/skills/a.md"
echo "$LITERAL" >"$d/plugins/wow/.mcp.json"
assert_status "dotglob: a literal in a plugin-root .mcp.json is caught" 1 "$d"

# A reference/ nested BELOW a component dir is not the documentation exclusion
# -- the exclusion is by name at depth 1 only.
d="$(tree nested_reference)"
mkdir -p "$d/plugins/wow/skills/reference"
echo "$LITERAL" >"$d/plugins/wow/skills/reference/a.md"
assert_status "exclusions: a nested reference/ is still scanned" 1 "$d"

# --- a plugin the gate never looked at is not a pass ------------------------
# One repo-wide counter used to let any single scannable directory anywhere
# satisfy the guard, so this second plugin passed green.
d="$(tree unscanned_plugin)"
mkdir -p "$d/plugins/good/skills" "$d/plugins/second/reference"
echo "portable content" >"$d/plugins/good/skills/a.md"
echo "docs" >"$d/plugins/second/reference/r.md"
assert_status "per-plugin: a plugin with nothing scannable fails the gate" 1 "$d"

# --- nothing to scan at all is a failure, not a pass ------------------------
d="$(tree empty)"
assert_status "empty: a plugins/ tree with no plugins fails" 1 "$d"

d="$tmp/noplugins"
mkdir -p "$d"
assert_status "missing: no plugins/ tree at all fails" 1 "$d"

# --- the exclusion compares the name actually used --------------------------
# $(basename ...) strips trailing newlines, so `reference<LF>` compared equal to
# `reference` and was skipped. A newline is a legal path character in git, so
# that was a committable bypass. Skipped where the filesystem will not hold such
# a name (Windows transliterates it), because there the bypass is unreachable.
d="$(tree newline_name)"
mkdir -p "$d/plugins/wow/skills"
echo "portable content" >"$d/plugins/wow/skills/a.md"
NL='
'
nl_dir="$d/plugins/wow/reference$NL"
mkdir "$nl_dir" 2>/dev/null || true
# Only assert if the filesystem really produced that name. Windows transliterates
# the newline to a lookalike codepoint, which makes the bypass unreachable there
# and the fixture meaningless -- so verify the name before trusting it.
nl_real=0
for entry in "$d/plugins/wow/"*; do
  [ "${entry##*/}" = "reference$NL" ] && nl_real=1
done
if [ "$nl_real" -eq 1 ]; then
  echo "$LITERAL" >"$nl_dir/e.md"
  assert_status "newline: 'reference<LF>' does not hit the exclusion" 1 "$d"
else
  rm -rf "$nl_dir"
  echo "ok - newline: skipped, filesystem will not hold the name"
fi

# --- a grep that errors must not read as "clean" ----------------------------
# The old `if hits=$(grep ...)` form took grep's exit 2 (a real error: unreadable
# file, I/O error) down the same branch as exit 1 (clean), so the gate reported a
# pass over a tree it could not read. Forcing a genuine grep error from a
# committable fixture is platform-dependent, so the error is injected instead:
# a stub grep earlier on PATH that always exits 2. The script must fail.
stub="$tmp/stub"
mkdir -p "$stub"
printf '#!/bin/sh\nexit 2\n' >"$stub/grep"
chmod +x "$stub/grep"

d="$(tree greperr)"
mkdir -p "$d/plugins/wow/skills"
echo "portable content" >"$d/plugins/wow/skills/a.md"
actual=0
( cd "$d" && PATH="$stub:$PATH" bash "$script" >/dev/null 2>&1 ) || actual=$?
if [ "$actual" -eq 1 ]; then
  echo "ok - grep: an erroring grep fails the gate instead of reading as clean"
else
  echo "FAIL - grep: expected exit [1] when grep errors, got [$actual]" >&2
  fail=1
fi

# The same tree with the real grep must pass -- otherwise the case above proves
# nothing about grep's exit status.
assert_status "grep: the same tree passes with a working grep" 0 "$d"

exit "$fail"
