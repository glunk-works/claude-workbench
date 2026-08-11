# Cursor — claude-workbench

**Now:** No sprint in flight (this repo runs issue-driven, single-task PRs, not sprints).
**#23** implemented — status: awaiting_review (PR open, not yet merged).

**Just done (2026-08-11):**
- Implemented #23's preferred fix — **(3) + (1)**: documented the `gh`-vs-`git`
  push-identity failure signature in `reference/conventions.md` § *Push identity*, and
  added a `gh`-side push-reach preflight to `/way-of-working:ship` step 1
  (`gh api repos/{repo} --jq .permissions.push`, explicit about only covering `gh`'s
  identity). `/way-of-working:handoff` got a pointer to the same section.
- Two rounds of `/way-of-working:critic-gate` (architect + docs-consistency, each run
  twice) — first pass found a real credential-disclosure risk (`git credential fill`
  printing a live token) and a functional bug (an untestable "no `push` in the result"
  string check); second pass found a residual `{repo}`-substitution trap and a structural
  regression from the first round's fix. Both rounds fixed; green gate clean throughout.
- Shipped as PR **#31** (`232c002`, branch `fix/gh-git-push-identity-preflight`), labeled
  `feature` + `area/way-of-working`. **Confirmed the documented failure live**: the actual
  `git push` for this PR hit the exact `403 denied to <account>` split described in the
  doc, and the documented workaround fixed it on the first try.

**Next:** Confirm PR #31 merged (closes #23), then start **#21**: extract the
deterministic predicates from skill prose into testable scripts (explicitly "not urgent" —
picked up here only because #23 is now done).

No HITL gate open. Next gate is the human's merge of PR #31 — no `review.ci_gate` in this
repo, so that critic-gate pass was the only review this diff had.

**Also open:** #28's taxonomy half (decisions 1–7) remains decided-not-started.

**Pointers:** [`docs/decisions.md`](docs/decisions.md) (roadmap/decisions of record) ·
[#31](https://github.com/glunk-works/claude-workbench/pull/31) (this session's PR) ·
[#23](https://github.com/glunk-works/claude-workbench/issues/23) ·
[#21](https://github.com/glunk-works/claude-workbench/issues/21) ·
[#28](https://github.com/glunk-works/claude-workbench/issues/28)
