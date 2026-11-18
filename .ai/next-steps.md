# Cursor — claude-workbench

**Now:** **Sprint 23** (cursor id `sprint-23`), status **planning**, no milestone picked yet.

**Just done (2026-11-18, driver session, opus):**
- Sprint 22 archived: milestone 36 (*Review findings flow*) done. #1564 (PR #1609) and #1566 (PR #1615) built. Off the milestone: #1608 (PR #1611, `WB-D53`) and the `#1591` amendment that keeps containers running in the admin-token window (PR #1616). Released as `v0.38.0` (PR #1618, tag at `f37258d`). The pin bump and Sprint 22's status entry merged in PR #1621 (`c082f44`). Final cursor snapshot: `.ai/archive/sprint-22-next-steps.md`.

**Milestone close:** closed — milestone 36, *Review findings flow* (verify --plan `match`, read back `closed` with 0 open issues).

**Next:** plan sprint-23. First, after the restart for the `v0.38.0` pin, check the plugin install: the user entry and the `/workspace` entry in `installed_plugins.json` must both be at `f37258d`. Then `/way-of-working:plan-sprint` can help triage the backlog: #1614, and the findings issues #1579, #1610, #1612, #1613 and #1617 through `/way-of-working:plan-sprint findings`, whose first run is #1620's live check. The maintainer picks the milestone, and `/way-of-working:handoff` anchors it. Model: opus (architect).

**HITL Gate: NONE OPEN** — next gate: plan the next unit

**Also waiting on the driver or the maintainer:**
- 603-Identity/devcontainers: two driver prompts handed over on 2026-11-18. One updates `docs/host-steps.md` Procedure B and the threat model for #1608's token path. The other sets `agents.diff_rule: []`. devcontainers#556's spec still needs the maintainer's reaction.
- #1595 needs the maintainer's reaction on the issue before its spec.
- #1591: the admin-App route ran end to end for #1566 (PR #1615). Each other glunk-works repo switches at its milestone 34 item.
- Maintainer, on the host: `docker rmi wow-review:60985f814e95`. bounty-infra, bedrock-serverless-rag, global-bootstrap and scope-core have a review poller but no `broker.json` entry (milestone 34). #1603's live checks when convenient.
- Carried from sprint 21 (details in `.ai/archive/sprint-21-next-steps.md`): bounty-infra PRs #193 and #202; #412's cutover; devcontainers follow-ups; #419's private record and the other out-of-repo follow-ups.

**Critic pass:** the driver-shipped PRs ran by rule, 1 round each, converged with no defects:
- the `v0.38.0` release (#1618): architect, security-critic and docs-consistency;
- #1616 and the Sprint 22 entry (#1621): docs-consistency.

Lane PRs #1609, #1611 and #1615 ran their own critic gates.

**Pointers:** [docs/decisions.md](../docs/decisions.md) · sprint plan: to be picked · [.ai/parked/](parked/)
