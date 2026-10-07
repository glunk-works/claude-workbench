# Cursor — claude-workbench

**Now:** **Sprint 12** (cursor id `sprint-12`) on milestone 13, *Orchestrator M2a: loop container
proven*. Status: **implementing**.

**Just done (2026-10-07):**
- Task #315 shipped as PR #337 (`9dc6066`), **awaiting the human's merge**: plan v9 § 7.1 synced to
  the M2a/M2b/M2c cut, the driver moved to `scripts/loop/` (new WB-D23), step 4's stale
  prerequisite sentence dropped.
- Scope the maintainer added to #315: the loop image is built from
  `ghcr.io/603-identity/devcontainer-base` (tag and digest, provenance-verified) plus a loop layer
  that installs `claude`; one loop image per toolchain (bounty-infra later from `devcontainer-tofu`);
  no new devcontainers variant for now. #315's and #317's issue bodies were edited to match.
- `scripts/loop/` is a name PR #337 picked; the maintainer chose only "under `scripts/`".
- Critic pass: none needed, the diff is docs only and touches no `code_paths`.

**Next:** task #316 — verify the headless subscription terms and Fable availability before the
first dispatch, per the issue body; record the findings and ship them as one docs PR. On
**sonnet** (coder). Independent of #337's merge (`depends_on: none`).

**HITL Gate: OPEN** — no verified baseline for milestone 13's anchor: the resume that started #315
waited on the first-anchor gate and never ran `verify`, so handoff's rule treats it as no baseline
(handoff's own `verify --plan` read `match`; description sha
`ada92ac23e7fbff5b1543d5ad2272f37e257e8a416cb658fc0bb486f0cf2a159`). The human confirms and starts
#316 with a go. No review CI gate in this repo.

**Pointers:** [docs/decisions.md](../docs/decisions.md) ·
[milestone 13](https://github.com/glunk-works/claude-workbench/milestone/13) ·
[docs/proposals/orchestrator-m2-decisions.md](../docs/proposals/orchestrator-m2-decisions.md) ·
[.ai/parked/](parked/)
