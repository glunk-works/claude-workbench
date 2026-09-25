#!/bin/sh
# Fixture tests for plugins/way-of-working/bin/milestone-close-line.sh.
#
# Issue #153 (second occurrence after #128): archive-sprint's milestone-close
# outcome reached neither the ledger nor the gate. This predicate is the
# deterministic check /way-of-working:resume runs against a `planning`-status
# cursor's ledger so that gap is surfaced instead of silently read as clean.
#
# Permitted toolset: POSIX sh. No jq, no yq, no python.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/plugins/way-of-working/bin/milestone-close-line.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

assert_eq() {
  desc="$1"
  expected="$2"
  actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc: expected [$expected], got [$actual]" >&2
    fail=1
  fi
}

with_line="$tmp/with-line.md"
cat >"$with_line" <<'EOF'
**Now:** Sprint 3

**Just done:** archived sprint 2.

**Milestone close:** closed (milestone 2, "sprint 2")

**Next:** plan sprint 3
EOF

no_line="$tmp/no-line.md"
cat >"$no_line" <<'EOF'
**Now:** Sprint 3

**Just done:** archived sprint 2. Milestone close: closed (mentioned in prose, not its own line).

**Next:** plan sprint 3
EOF

indented_line="$tmp/indented-line.md"
cat >"$indented_line" <<'EOF'
**Now:** Sprint 3

  **Milestone close:** closed (milestone 2, "sprint 2") -- indented, not column 0

**Next:** plan sprint 3
EOF

bulleted_line="$tmp/bulleted-line.md"
cat >"$bulleted_line" <<'EOF'
**Now:** Sprint 3

- **Milestone close:** closed (milestone 2, "sprint 2")

**Next:** plan sprint 3
EOF

empty_value="$tmp/empty-value.md"
cat >"$empty_value" <<'EOF'
**Now:** Sprint 3

**Milestone close:**

**Next:** plan sprint 3
EOF

trailing_space_only="$tmp/trailing-space-only.md"
printf '**Now:** Sprint 3\n\n**Milestone close:**   \n\n**Next:** plan sprint 3\n' >"$trailing_space_only"

two_lines="$tmp/two-lines.md"
cat >"$two_lines" <<'EOF'
**Now:** Sprint 4

**Milestone close:** closed (milestone 2, "sprint 2") -- STALE, describes an unrelated close

**Just done:** parked sprint 3, unparked, archived.

**Milestone close:** pending (milestone 3, "sprint 3"; refused write)

**Next:** plan sprint 4
EOF

missing_file="$tmp/does-not-exist.md"

# --- not-applicable: planning.kind is not github_milestones -----------------
assert_eq "not-applicable: files-kind planning, status planning, line present" \
  "not-applicable" "$("$script" files planning "$with_line")"

# --- not-applicable: sprint_status is not planning ---------------------------
assert_eq "not-applicable: github_milestones, status implementing, line absent" \
  "not-applicable" "$("$script" github_milestones implementing "$no_line")"

# --- present: the fixed line is there, at column 0 ---------------------------
assert_eq "present: applicable and the line is there" \
  "present" "$("$script" github_milestones planning "$with_line")"

# --- missing: applicable, but the outcome is only prose, no fixed line ------
assert_eq "missing: applicable, outcome only in Just done prose" \
  "missing" "$("$script" github_milestones planning "$no_line")"

# --- missing: applicable, but the line is indented, not at column 0 ---------
assert_eq "missing: the line exists but is not at column 0" \
  "missing" "$("$script" github_milestones planning "$indented_line")"

# --- present: an optional leading "- " bullet marker is tolerated -----------
assert_eq "present: a bulleted Milestone close line still matches" \
  "present" "$("$script" github_milestones planning "$bulleted_line")"

# --- missing: an unfilled template line names no outcome --------------------
assert_eq "missing: the label is there but nothing follows it" \
  "missing" "$("$script" github_milestones planning "$empty_value")"

assert_eq "missing: the label is there but only trailing whitespace follows it" \
  "missing" "$("$script" github_milestones planning "$trailing_space_only")"

# --- present: known behavior on two lines (defense-in-depth, not the primary
# fix) -- the skill-level rule is that at most one such line ever survives a
# ledger write (archive-sprint's unpark branch REPLACES, park-sprint's override
# REPLACES, handoff's carry-forward only preserves the same sprint's own line);
# this fixture pins what the script itself does if that invariant is ever
# violated, so a regression there is caught by a changed grep result, not by
# rediscovering it live. The script reports the FIRST match; it does not detect
# or flag a second one -- duplicate-prevention is a skill-prose contract, not
# this predicate's job.
assert_eq "present: two lines -- the script matches the first, does not detect the second" \
  "present" "$("$script" github_milestones planning "$two_lines")"

# --- unreadable: applicable, but the file does not exist --------------------
assert_eq "unreadable: applicable file does not exist" \
  "unreadable" "$("$script" github_milestones planning "$missing_file")"

# --- not-applicable wins even when the file is unreadable -------------------
# (wrong kind/status is decided before the file is ever touched)
assert_eq "not-applicable: wrong kind, even against a missing file" \
  "not-applicable" "$("$script" files planning "$missing_file")"

# --- usage: wrong arity is an error, never folded into a verdict ------------
out=$("$script" github_milestones planning "$with_line" extra 2>/dev/null) && rc=0 || rc=$?
assert_eq "usage: wrong arity exits 2 with no verdict on stdout" "2/" "$rc/$out"

exit "$fail"
