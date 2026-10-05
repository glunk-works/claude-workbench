Paste the block below as the first message of a NEW Claude Code session opened in this repo,
started on Opus. Opus is outside the author's family (Fable 5.1, which also produced v4 and v5)
but is the same family as the v6 reviser. The prompt asks the reviewer to treat § 6.5 as
one voice to be checked, not a second opinion to agree with.

§ 8.1–8.4 were decided by the maintainer on 2026-10-04. § 8.5 and § 8.6 are open decisions
the v6 review raised. The reviewer reviews a plan with decisions in it; it may say a decision
is inconsistent with the rest of the plan, but it does not re-litigate the maintainer's call.

---

You are reviewing the sixth draft of a proposal for context and bias, not implementing it. Read-only: do not edit, commit, or run write-side git commands, and do not change any GitHub setting.

The author and the first two revisers (v4, v5) were Fable 5.1. The third reviser (v6) was Opus 5.5, the first from outside the author's family. v6 changed no maintainer decision, but it added review notes under § 8.1–8.4, raised two open decisions (§ 8.5, § 8.6), rewrote § 7.3's session-configuration and host controls, and overruled v5 on the cause of § 8.3's throughput ceiling. You are the same model family as v6. Your job is partly to review the plan and partly to check v6 hard, because nobody outside its family has.

Read, in this order, and nothing else first:
1. `docs/proposals/sprint-orchestrator-plan-v6.md`, the proposal. § 0 lists declared biases (including v6's own) and eight suggested checks. § 6.3, § 6.4 and § 6.5 list what each reviser changed. § 8 carries the maintainer's decisions, v6's notes under them, and the two open items.
2. Only after you have written down your own first-pass verdict on v6: `docs/proposals/analysis/orchestrator-plan-v5.md`. Use it to judge whether each § 6.5 change was warranted, whether § 6.5's verdicts on § 6.3 items 11–17 were right, and whether v6 kept the maintainer's decisions intact. Open `orchestrator-plan-v4.md` and `-v3.md` only if § 6.5's account of what v4 or v5 said leaves you unsure.

Do NOT open `docs/proposals/analysis/session-export/` unless a specific claim is unverifiable from the repo and the cited URLs and you need the primary source. If you open any file in it, name the file and section in your report and say why. No reviser's transcript is exported.

Verify against primary sources, not the plan's text:
- The repo files it cites: `docs/decisions.md`, `plugins/way-of-working/**`, `.ai/project.yml`.
- The consuming repos via read-only `gh api`: 603-Identity/devcontainers, 603-Identity/infrastructure-core, glunk-works/bounty-infra. Include their live rulesets and their `.ai/project.yml` `gates.green`.
- The code.claude.com, github.com, docs.github.com and learn.microsoft.com URLs via WebFetch. Fetch hooks.md, settings.md, permissions.md and plugins/mods/admin.md raw (`curl -sL … | grep`), because summaries of those pages have invented sentences before.
- GitHub's documentation for ruleset merge restrictions and `require_extra_approval_for_unattributed_changes`, which no reviewer has read.
- Docker Desktop's documentation for file sharing on the WSL2 backend and for `--internal` networks.
- Re-run `docs/proposals/analysis/pr_analysis.py` for **infrastructure-core or claude-workbench**, not devcontainers. Input: `gh pr list -R <repo> --state all --limit 200 --json number,title,createdAt,mergedAt,state,additions,deletions,changedFiles,files`.

Pay particular attention to:
- § 6.5 item 1, § 2.2's new ruleset row, § 5 principle 2 and § 8.5. v6 says the loop's PAT can merge a green PR today because every ruleset requires 0 approvals. Is that right on GitHub's actual semantics, including `require_extra_approval_for_unattributed_changes`? Are § 8.5's options complete and correctly described? In particular, does option (a), restricting updates to bypass actors, break the human's normal merge, required checks, or resume's cursor-sync merge?
- § 6.5 item 2, § 2.3 and § 8.6. v6 says devcontainers' gate cannot run in the hardened container without the Docker socket, and that the socket reaches every Windows credential through Docker Desktop's drive sharing. Verify both. Is § 8.6's recommended option (a), CI as the gate of record for the Docker steps, an honest reading of the maintainer's "same quality bar", or a quiet lowering of it?
- § 7.3's rewritten settings control (v6 replaced v5's read-only files with `allowManagedHooksOnly` + `allowManagedPermissionRulesOnly` + managed deny rules + Claude Code's sandbox). Does the documentation support each piece? What does `allowManagedPermissionRulesOnly` do to `--allowedTools` and `--settings`, which v6 did not find out? Does Claude Code's sandbox run inside an unprivileged read-only container? Is anything still loaded from the session's writable `CLAUDE_CONFIG_DIR` that can widen the session: plugins, agents, skills, output styles, MCP config, `.claude.json`?
- § 7.3's host bullet and § 6.2's container row as rewritten. Attack the `--internal` network plus dual-homed proxy design, the per-repo egress allowlist, token exfiltration over allowed hosts (§ 7.2's mitigations), and what a process running as the maintainer on Windows can reach. The maintainer has since confirmed the host is an always-on desktop, not a laptop.
- § 7.3's driver-side git rule. v6 says the driver must run no git in a clone the session touched, because `.git/config` entries (`core.fsmonitor`, `credential.helper`, `core.sshCommand`, `url.<x>.insteadOf`) execute or redirect where `core.hooksPath` does not reach. Is that right, and is the GitHub-compare replacement sufficient for the human-only-path and fixture checks?
- § 6.5's § 8.3 verdict and § 7.4's merge-triggered dispatch option. v6 says the ceiling comes from the away-only dispatch window, not principle 1. Is that right? Does merge-triggered dispatch during a sitting weaken any trust rule in § 2.2, or the human's read of `next_action`?
- § 8.4a's v6 note recommending a deterministic critic floor. The maintainer explicitly wanted LLM judgment while they are away. Is the floor a fair reconciliation with principle 3, or did v6 re-decide the maintainer's call under the label of a note? Do critic-gate's table rows (`skills/critic-gate/SKILL.md`) actually support computing the floor without a model?
- Whether v6's notes under § 8.1–8.4 are consistent with the decisions as recorded, and whether any v6 edit outside § 8 changed a decision's effect without saying so.

Report back:
- Your first-pass verdict on v6, written before step 2 above, unchanged.
- Claims in v6 you checked and found wrong, overstated, or unsupported, with evidence. Include any § 6.5 "correction" that was itself wrong, and anything v6 introduced that no source supports.
- For each of § 6.3 items 11–17, and for § 6.5 items 1–8: did v6 have it right, or not?
- Places the author's or any reviser's biases visibly shaped the result. Include any shared-family bias you can see between v6 and yourself, and any bias none of them declared.
- For § 8.5 and § 8.6: which option you would recommend per repo and why, without deciding for the maintainer.
- What you would change in v6, ranked, and what you would leave alone.

Be concrete, cite file:line or URL for every finding, and keep it under 1500 words. A clean "v6 holds" on any point is a valid answer; do not invent findings, and do not agree with v6 because it is your family. Where you disagree with any reviser, say so plainly and give the evidence, not a compromise.
