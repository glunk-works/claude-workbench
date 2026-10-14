# Cursor — claude-workbench

**Now:** **Sprint 15** (cursor id `sprint-15`) on [milestone 18, *Identity M3: host broker and dev container*](https://github.com/glunk-works/claude-workbench/milestone/18). Status: **implementing**.

**Just done (2026-10-14):**
- [#598](https://github.com/glunk-works/claude-workbench/pull/598) merged (`891ffc7`): one repo-wide `* text=auto eol=lf` rule in `.gitattributes`; the renormalize was a no-op. #579 is closed. The dev-container check was a pending item in the PR body for the maintainer.
- No critic pass: the diff touched only `.gitattributes`, outside `code_paths` and `load_bearing_docs`; `review.ci_gate` is `null`, so the human merge was the only gate.
- The anchor was re-taken on #588 with no spec comment (milestone 18's description verified as `match` against the prior anchor).

**Next:** task #588 — post its spec as a comment on #588 (evaluate signing container commits through the dev App's API commits), then anchor it at handoff and have a maintainer react; build only after that. On **opus** (architect), in a fresh session. After it: `/way-of-working:archive-sprint` for milestone 18.

**HITL Gate: OPEN** — #588 has no spec comment; the architect posts one and a maintainer reacts to it before any build

**Pointers:** [docs/decisions.md](../docs/decisions.md) · [milestone 18](https://github.com/glunk-works/claude-workbench/milestone/18) · [.ai/parked/](parked/)
