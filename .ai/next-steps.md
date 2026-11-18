# Cursor — claude-workbench

**Now:** **Sprint 23** (cursor id `sprint-23`), status **implementing**, milestone 38 (*Rule-based critic selection by default*) has no open issue: closing the sprint.

**Just done (2026-11-18, driver session, opus):**
- #1614: its lane survived the crash with PR #1627 already open, reviewed (architect-review pass at `2b86752`) and critic-gated by the lane (architect, security-critic, docs-consistency; 1 round, converged). Driver merge assessment against spec comment 6984335809: no blocking issue. The maintainer merged it as `2ba7a0e`, which closes #1614 and records `WB-D54`.
- Lane 1614 cleaned up (`lane.sh done 1614`: worktree, branch and prompt removed).

**Next:** Close sprint 23: open the way-of-working v0.39.0 release PR for the Unreleased changelog lines (#1614, PR #1627), then, after it merges and is tagged, the PR that bumps the pin to v0.39.0 and records sprint 23 in `docs/decisions.md`; run `/way-of-working:archive-sprint` only once that entry is on main. Model: opus (architect).

**HITL Gate: OPEN** — the maintainer decides whether to release way-of-working v0.39.0 to close sprint 23 (milestone 38 has no open issue).

**Also waiting on the driver or the maintainer:**
- Milestones 32 and 35 have no open issue and say "none left", but are still open on GitHub.
- #1623, #1624 and #1625 need the maintainer's reaction on the issue before their specs.
- 603-Identity/devcontainers: two driver prompts handed over on 2026-11-18. One updates `docs/host-steps.md` Procedure B and the threat model for #1608's token path. The other sets `agents.diff_rule: []`. devcontainers#556's spec still needs the maintainer's reaction.
- #1595 needs the maintainer's reaction on the issue before its spec.
- A possible backlog item from the #1627 assessment: the schema interview's free-text `agents.diff_rule` option does not name the literal-prefix rule (a glob entry reads as unreadable and falls back to the pick-list); one of the spec's unapplied tightenings.
- #1591: the admin-App route ran end to end for #1566 (PR #1615). Each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`. bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** none this session: the driver wrote no diff (the lane's own pass is recorded on PR #1627).

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: [milestone 38](https://github.com/glunk-works/claude-workbench/milestone/38) · [.ai/parked/](parked/)
