# Cursor — claude-workbench

**Now:** **Sprint 3** — [milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4),
*harden architect-review's trust chain*, ships as **v0.11.0**. Status: **implementing** —
the build order is the milestone description; step 1 needs no plan, step 2 waits on a pick.

**Just done (2026-09-24, Fable):**
- #113's isolation-mechanism design spec is on the issue
  ([comment](https://github.com/glunk-works/claude-workbench/issues/113#issuecomment-5815745651)):
  options A (throwaway clone + credential-stripped env), B (container, needs a schema key),
  C (no local execution for untrusted authors, CI as witness), D (re-verify, rejected),
  E (container for everyone). Recommendation: A + C now, B filed as a follow-up. The
  mechanism A rests on was probed live on this machine before it was written up.
- Both staged milestone writes landed (milestone 5 lists #152, milestone 4 lists #153);
  that gate is cleared. Cursor sync from the triage merged as
  [PR #154](https://github.com/glunk-works/claude-workbench/pull/154).
- First anchor for milestone 4, description sha
  `fbd0041b9b6171fb9e0d22ceefb1cb927535ed98d1de83833b03f21739f95e07`.

**Next:** task #126 — on **sonnet** (`coder`): extract `architect-review`'s preflight chain
to `bin/review-base-anchor.sh` with `tests/review-base-anchor.test.sh` covering every case
the issue lists; `SKILL.md` calls it by bare name. Design settled in the issue body. Then
the green gate, `/way-of-working:critic-gate` (architect + security-critic), `/way-of-working:ship`.

**HITL Gate: OPEN** — (1) first anchor for milestone 4 (above): a human "go" at the next
resume confirms the milestone description is the plan. (2) Pick #113's isolation mechanism
from the spec comment; needed before build-order step 2, not before #126.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 4](https://github.com/glunk-works/claude-workbench/milestone/4) ·
[all milestones](https://github.com/glunk-works/claude-workbench/milestones)
