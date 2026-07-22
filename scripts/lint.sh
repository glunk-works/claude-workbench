#!/usr/bin/env bash
# Validates every marketplace.json / plugin.json against the schema confirmed in
# bounty-infra SW Task 1 (see plugins/way-of-working/reference/ for the source docs
# cited there), and every SKILL.md for the required frontmatter fields.
set -euo pipefail

fail=0

fail_with() {
  echo "LINT FAIL: $1" >&2
  fail=1
}

# --- marketplace.json ---
MARKETPLACE=".claude-plugin/marketplace.json"
if [ ! -f "$MARKETPLACE" ]; then
  fail_with "$MARKETPLACE missing"
else
  jq -e '.name and .owner and .owner.name and .plugins and (.plugins | type == "array") and (.plugins | length > 0)' \
    "$MARKETPLACE" >/dev/null || fail_with "$MARKETPLACE missing a required field (name, owner.name, plugins[])"
  jq -e '[.plugins[] | (.name and .source)] | all' "$MARKETPLACE" >/dev/null \
    || fail_with "$MARKETPLACE has a plugin entry missing name or source"
fi

# --- plugin.json (one per plugins/*/.claude-plugin/plugin.json) ---
shopt -s nullglob
for pj in plugins/*/.claude-plugin/plugin.json; do
  jq -e '.name' "$pj" >/dev/null || fail_with "$pj missing required field: name"
done

# --- SKILL.md frontmatter ---
for skill in plugins/*/skills/*/SKILL.md; do
  head1=$(sed -n '1p' "$skill")
  if [ "$head1" != "---" ]; then
    fail_with "$skill: does not open with a --- frontmatter block"
    continue
  fi
  fm=$(awk 'NR==1{next} /^---$/{exit} {print}' "$skill")
  echo "$fm" | grep -qE '^name:' || fail_with "$skill: frontmatter missing 'name'"
  echo "$fm" | grep -qE '^description:' || fail_with "$skill: frontmatter missing 'description'"
done

if [ "$fail" -ne 0 ]; then
  echo "One or more lint checks failed." >&2
  exit 1
fi

echo "All marketplace.json / plugin.json / SKILL.md checks passed."
