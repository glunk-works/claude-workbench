#!/usr/bin/env bash
# The DRY gate: shared plugin code may never name a repo-specific value.
#
# Every literal shared plugin code needs is either a key in .ai/project.yml (see
# plugins/*/reference/project-schema.md) or it does not belong in the plugin at all.
# This check is the mechanical half of that rule -- it cannot prove a body is portable,
# but it catches the way portability actually rots: someone pastes a working command,
# a check name, or a repo name in from the repo they happen to be sitting in.
#
# Scope is every directory under plugins/*/ EXCEPT reference/, .claude-plugin/, and .git/
# -- a denylist, not an allowlist, so this loop fails closed for its one job: a new
# component *directory* (commands/, templates/, whatever comes next) is scanned
# automatically the moment it exists, with no separate edit to this script required first.
# #49 was the allowlist version of this exact bug: hooks/ shipped and ran in every
# consuming repo for a full sprint before this check ever looked at it, because the loop
# only knew the names in the sprint's original acceptance pattern (skills, agents, bin).
# `dotglob` is on below so the glob itself yields dot-directories -- without it,
# .claude-plugin/ would be skipped by the glob, not by the `case` arm that documents the
# skip, and the same silent gap would apply to any future dot-directory. reference/ is
# documentation about the contract and necessarily quotes concrete values --
# project-schema.md's worked examples are the whole point of it. Widening this to
# reference/ would make the schema doc unwritable. .claude-plugin/ is excluded for a
# different reason: it is plugin *metadata*, not executed code, and plugin.json's author
# field legitimately carries the org name that TIER2 matches -- scanning it would
# false-positive on correct content. .git/ is excluded so a plugin ever vendored as a
# nested clone or submodule doesn't fail on its own remote URL, which is exactly this kind
# of match on a directory that isn't plugin content at all.
#
# What this does NOT cover: a repo-specific literal sitting in a file at the *root* of a
# plugin directory, outside any subdirectory (there are none today) -- a narrower gap than
# the one #49/#53 closed, not silently reopened by this loop, and tracked separately rather
# than folded in here. The empty-or-missing plugins/ tree is NOT such a gap: the
# zero-scanned guard below fails the gate rather than reporting a pass having looked at
# nothing, which is the same failure shape this script exists to close.
set -euo pipefail

# Tier 1 -- the sprint's acceptance pattern (SW Task 3). These are the specific literals
# the 7 skills and 4 agents actually carried before they were generalized.
TIER1='hatch run|migration_roadmap|architect-review|loop-orchestrator|Seuss27'

# Tier 2 -- every repo in the org, plus any emitter name the reference docs use as a worked
# example. A skill that names one of these is the same defect as tier 1, caught before it
# ships rather than after. `loop-orchestrator` is also matched by TIER1 (it predates this
# tier), but is listed here too so this tier's own membership rule is literally true on its
# own and doesn't silently depend on TIER1 never being pruned. Hand-maintained today (see
# #48 for the derive-vs-hand-maintain call); keep this list in sync with
# `gh repo list glunk-works`.
TIER2='bounty-infra|global-bootstrap|scope-core|glunk-works|claude-workbench|bedrock-serverless-rag|pm-agent-loop|appsec-triage-agent|loop-engine|loop-orchestrator'

# Tier 3 -- structural literal SHAPES, not exact strings. SW Task 5 found that tiers 1-2
# match repo/org names and a curated string list but were blind to a hardcoded *path* that
# is not a repo name: the v0.1.0 skeleton carried `docs/migration_roadmap.md` and three
# `.ai/context/*.md` files, and "zero hits" proved only that no repo NAME leaked, not that
# the skills were portable. These patterns catch the shape of the two path literals that
# always have a schema-key home: a roadmap path is `{roadmap}`; a specific
# `.ai/context/<file>` either moved into this plugin's own reference/ or is the consuming
# repo's local truth, which a skill references as the bare directory, never a named file.
# A bare `.ai/context/` with no filename is a legitimate generic reference and is
# deliberately NOT matched.
#
# Check *names* are intentionally absent here. They appear legitimately in illustrative
# example output (see pr-checks' "Report shape" block, whose own prose says the real names
# come from {ruleset.required_checks}), so grepping them would false-positive on the
# examples. Check-name coupling is caught by a different mechanism instead: /way-of-working:resume and
# /way-of-working:pr-checks read {ruleset.required_checks} and report *inconclusive* on a mismatch rather
# than trusting a hardcoded list.
TIER3='docs/[A-Za-z_]+roadmap\.md|\.ai/context/[A-Za-z_]+\.(md|json)'

PATTERN="${TIER1}|${TIER2}|${TIER3}"

fail=0
scanned=0
shopt -s nullglob dotglob
for plugin_dir in plugins/*/; do
  for target in "${plugin_dir}"*/; do
    target="${target%/}"
    component="$(basename "$target")"
    case "$component" in
      reference|.claude-plugin|.git) continue ;;
    esac
    scanned=$((scanned + 1))
    if hits=$(grep -rnE "$PATTERN" "$target"); then
      echo "COUPLING FAIL: repo-specific literal in $target" >&2
      echo "$hits" >&2
      fail=1
    fi
  done
done

if [ "$scanned" -eq 0 ]; then
  echo "COUPLING FAIL: scanned zero directories under plugins/*/ -- the tree is missing, empty, or this script is running from the wrong cwd. A gate that scans nothing and reports pass is the exact failure mode #49/#53 exist to close." >&2
  exit 1
fi

if [ "$fail" -ne 0 ]; then
  cat >&2 <<'EOF'

Shared plugin code names a repo-specific value. Two correct fixes, per
project-schema.md:
  1. Add a schema key and read it from .ai/project.yml (usually this one).
  2. The behavior was never portable -- move it back to being repo-local, out
     of the plugin.
"Override it locally in the consuming repo" is not a third option.

A third case is narrower than either: the sentence didn't need the value at
all. If it's descriptive prose rather than a behavior that varies per repo,
say the concept (e.g. "the plugin's source repo"), not the name.
EOF
  exit 1
fi

echo "Coupling check passed: scanned $scanned directories under plugins/*/ (except reference/, .claude-plugin/, .git/), no repo-specific literals found."
