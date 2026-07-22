#!/usr/bin/env bash
# The DRY gate: a shared skill or agent may never name a repo-specific value.
#
# Every literal a skill or agent needs is either a key in .ai/project.yml (see
# plugins/*/reference/project-schema.md) or it does not belong in the plugin at all.
# This check is the mechanical half of that rule -- it cannot prove a body is portable,
# but it catches the way portability actually rots: someone pastes a working command,
# a check name, or a repo name in from the repo they happen to be sitting in.
#
# Scope is skills/ and agents/ ONLY. reference/ is documentation about the contract and
# necessarily quotes concrete values -- project-schema.md's worked examples are the
# whole point of it. Widening this to reference/ would make the schema doc unwritable.
set -euo pipefail

# Tier 1 -- the sprint's acceptance pattern (SW Task 3). These are the specific literals
# the 7 skills and 4 agents actually carried before they were generalized.
TIER1='hatch run|migration_roadmap|architect-review|loop-orchestrator|Seuss27'

# Tier 2 -- the repos this plugin is being adopted into next. A skill that names one of
# these is the same defect as tier 1, caught before it ships rather than after.
TIER2='bounty-infra|global-bootstrap|scope-core|glunk-works'

PATTERN="${TIER1}|${TIER2}"

fail=0
shopt -s nullglob
for plugin_dir in plugins/*/; do
  for component in skills agents; do
    target="${plugin_dir}${component}"
    [ -d "$target" ] || continue
    if hits=$(grep -rnE "$PATTERN" "$target"); then
      echo "COUPLING FAIL: repo-specific literal in $target" >&2
      echo "$hits" >&2
      fail=1
    fi
  done
done

if [ "$fail" -ne 0 ]; then
  cat >&2 <<'EOF'

A skill or agent names a repo-specific value. Two correct fixes, per
project-schema.md:
  1. Add a schema key and read it from .ai/project.yml (usually this one).
  2. The behavior was never portable -- move it back to being repo-local, out
     of the plugin.
"Override it locally in the consuming repo" is not a third option.
EOF
  exit 1
fi

echo "Coupling check passed: no repo-specific literals in any skills/ or agents/ tree."
