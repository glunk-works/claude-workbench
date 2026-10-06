# Cursor — claude-workbench

**Now:** **Sprint 10** (cursor id `sprint-10`), milestone 12 *Session-start hardening:
banner and branch prune* (due 2026-10-13). Status: **implementing**.

**Just done (2026-10-06):**
- Filed #270 and #271; `/way-of-working:plan-sprint` created milestone 12 for them (#270,
  then #271) and left #223 and #227 unmilestoned.
- Archived sprint-09: marked done in `docs/decisions.md` by PR #272 (`f878603`); milestone 11
  closed. The live smoke of its `--admin` offer path is tracked as #273.
- First anchor for milestone 12, description sha `018e1324…89ff4`.
- No code diff this session, so no critic pass applied.

**Next:** task #270 — in `plugins/way-of-working/hooks/ai-cursor-banner.sh`, make the jq
`cap` replace control characters (at least newline, carriage return and tab) with a space
before slicing to 200; update the header comment; add a `tests/ai-cursor-banner.test.sh`
fixture whose field embeds a newline and a forged `Next action:` line, asserting a fixed
output line count; run the green gate, then `/way-of-working:critic-gate` (security-critic +
architect). On **sonnet** (`coder`).

**HITL Gate: OPEN** — first anchor for milestone 12; the human confirms its plan (#270, then
#271) before task #270 starts.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 12](https://github.com/glunk-works/claude-workbench/milestone/12) ·
[.ai/parked/](parked/)
