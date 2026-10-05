Paste the block below as the first message of a NEW Claude Code session opened in this repo.
Start that session on a different model from the author (the plan was written on Fable 5.1;
Opus is the natural choice) so the review is not same-family.

---

You are reviewing a proposal for context and bias, not implementing it. Read-only: do not edit, commit, or run write-side git commands.

Read, in this order, and nothing else first:
1. `docs/proposals/sprint-orchestrator-plan-v3.md` — the proposal. Its §0 lists the author's self-declared biases and five suggested checks.
2. Only after you have written down your own first-pass verdict on the plan: `docs/proposals/analysis/orchestrator-plan-v1.md` and `-v2.md`, the drafts the author rejected, to judge whether the rejection was fair.

Do NOT open `docs/proposals/analysis/session-export/` unless a specific claim in the plan is unverifiable from the repo and the cited URLs and you need the primary source. That folder is the authoring session's own transcript and its critics' reports; reading it first will anchor you on their conclusions, which defeats the purpose of this review. If you do open any file in it, name the file and section in your report and say why.

Verify against primary sources, not the plan's text: the repo files it cites (`docs/decisions.md`, `plugins/way-of-working/**`, `.ai/project.yml`), the consuming repos via read-only `gh api` (603-Identity/devcontainers, 603-Identity/infrastructure-core, glunk-works/bounty-infra), and the code.claude.com and docs.github.com URLs in §4 via WebFetch. The analysis scripts in `docs/proposals/analysis/*.py` can regenerate the numbers in §3; re-run at least `pr_analysis.py` for one repo.

Report back:
- Your first-pass verdict, written before step 2 above, unchanged.
- Claims in the plan you checked and found wrong, overstated, or unsupported, with evidence.
- Places the author's declared biases visibly shaped the result, and any bias the author did not declare.
- Whether the v1 sprint-branch design was rejected on evidence or on the first critic's say-so.
- Whether the "one wave of independent tasks per merge sitting" trade-off is stated fairly.
- Which of the five decisions in §8 are genuinely the maintainer's and which are the author's preference in disguise.
- What you would change in the plan, ranked, and what you would leave alone.

Be concrete, cite file:line or URL for every finding, and keep it under 1500 words. A clean "the plan holds" on any point is a valid answer; do not invent findings.
