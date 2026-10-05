Paste the block below as the first message of a NEW Claude Code session opened in this repo.
Start that session on a model from a different family than both the author and the v3
reviewer (both were Fable 5.1; Opus is the natural choice) so the review is not same-family
for a third time.

---

You are reviewing the fourth draft of a proposal for context and bias, not implementing it. Read-only: do not edit, commit, or run write-side git commands.

This draft is unusual: v3 was reviewed by a second Claude session that then also edited it into v4. The reviser is the same model family as the author. Your job is partly to review the plan and partly to review the reviser.

Read, in this order, and nothing else first:
1. `docs/proposals/sprint-orchestrator-plan-v4.md` — the proposal. §0 lists the author's declared biases and six suggested checks; §6.3 lists what the v3 reviewer changed and why.
2. Only after you have written down your own first-pass verdict on v4: `docs/proposals/analysis/orchestrator-plan-v3.md`, the draft the reviser edited, to judge whether each §6.3 change was warranted. Then `orchestrator-plan-v1.md` and `-v2.md` only if §6.1 or §8.3 leaves you unsure about the sprint-branch question.

Do NOT open `docs/proposals/analysis/session-export/` unless a specific claim is unverifiable from the repo and the cited URLs and you need the primary source. It is the authoring session's transcript and its critics' reports; reading it first anchors you on their conclusions. If you open any file in it, name the file and section in your report and say why. The v3 review session's transcript is not exported; its reasoning exists only as §6.3.

Verify against primary sources, not the plan's text: the repo files it cites (`docs/decisions.md`, `plugins/way-of-working/**`, `.ai/project.yml`), the consuming repos via read-only `gh api` (603-Identity/devcontainers, 603-Identity/infrastructure-core, glunk-works/bounty-infra), and the code.claude.com, github.com and docs.github.com URLs in §4 via WebFetch. Re-run at least `docs/proposals/analysis/pr_analysis.py` for one repo (input: `gh pr list -R <repo> --state all --limit 200 --json number,title,createdAt,mergedAt,state,additions,deletions,changedFiles,files`).

Pay particular attention to:
- §4.2's reversal on `PermissionRequest` hooks under `--permission-prompts none`, and whether §7.3's response to it is sufficient or overbuilt. Read headless.md and hooks.md yourself.
- §7.3's restore list and the `core.hooksPath` line: is the git-hook execution vector real on the loop host, and does the mitigation cover `.git/hooks` writes by the task session as well as `.husky/`?
- §6.1's v4 note and §8.3: the reviser argues the sprint branch was over-rejected and that "one wave per sitting" is today's cadence, not a new ceiling. Is the reviser right, or did it swing too far the other way? v1's own "Known risks" section is relevant evidence.
- §7.1 step 1's trust surface, now "small" with the WB-D extended to cover it. Is that the right call, or does it put ceremony around a change that genuinely has no trust surface?
- The new WSL2 row in §6.2 and option in §8.2: the reviser added it without a security reviewer. What does it miss?
- §6.3 items 11–17 are judgement calls the reviser made and flagged. Say which you would reverse.

Report back:
- Your first-pass verdict on v4, written before step 2 above, unchanged.
- Claims in v4 you checked and found wrong, overstated, or unsupported, with evidence. Include any §6.3 "correction" that was itself wrong.
- Which §6.3 changes were warranted, which were over-correction, and which you would reverse.
- Places the author's or the reviser's biases visibly shaped the result, and any bias neither declared.
- Which of the four decisions in §8 are genuinely the maintainer's and which are a preference in disguise.
- What you would change in v4, ranked, and what you would leave alone.

Be concrete, cite file:line or URL for every finding, and keep it under 1500 words. A clean "v4 holds" on any point is a valid answer; do not invent findings. Where you and the v3 reviewer disagree, say so plainly and give the evidence, not a compromise.
