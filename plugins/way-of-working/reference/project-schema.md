# `.ai/project.yml` — the parameterization contract

Every skill and agent in this plugin is portable. **A shared skill may never name a
repo-specific value.** Where behavior needs one, it reads it from `.ai/project.yml` in the
consuming repo. This file defines that contract.

The rule that generated it, and the rule that keeps it honest:

> Every literal removed from a skill becomes a schema key. If a value cannot be expressed
> here, the behavior does not belong in the plugin.

## How skills reference keys

Skill and agent bodies write schema keys in braces — `{ruleset.required_checks}`,
`{pr_base}`, `{review.ci_gate.header}`. That notation always means *read this from
`.ai/project.yml`*, never a literal to type.

**Read `.ai/project.yml` once at the start of a skill**, then use it. It is small and
always-on by design; a skill that needs three keys reads the file, not three files.

**An agent reads it too, and must read it explicitly.** A subagent starts in a fresh context
with none of the spawning session's state, so every agent in this plugin opens by loading
`.ai/project.yml` and the local truth it points at (`CLAUDE.md`, `{roadmap}`,
`{threat_model}`) before looking at the diff. That first step is not boilerplate — it is what
stops an agent reviewing repo B against the invariants it remembers from repo A.

### When it is missing or unreadable

**Fail closed and say so.** A skill that cannot read `.ai/project.yml` reports
`no .ai/project.yml — this repo has not adopted the plugin contract` and then does only the
part of its job that needs no schema value. It **never** guesses a check name, a ruleset
name, a branch, or a gate. Guessing is worse than stopping: a `/pr-checks` that invents a
required-check list reports a confident verdict on the wrong set, which is precisely the
failure the skill exists to prevent.

Same rule for an individual key: a key that is absent is not a key that is `null`. `null` is
a decision ("this repo has no review CI gate"); absent is an unanswered question. Treat
absent as unreadable — report it, don't infer it.

## Overriding is a bug report, not a fix

**Plugin skills cannot be partially overridden.** A repo-local `.claude/skills/resume/`
shadows the plugin's copy *entirely* — there is no merge, no inheritance, no per-step
override. A repo that "just needs one tweak" therefore silently forks the whole skill and
stops receiving every upstream fix from that moment on, with nothing reporting the fork.

So when a shared skill assumes something untrue about your repo, there are exactly two
correct resolutions:

1. **A new schema key** — the assumption was repo-specific and the schema was missing a
   seam. Everyone benefits. This is the usual answer.
2. **The skill was never portable** — it encodes something structural about one repo, and it
   moves back to being repo-local *there*, out of the plugin.

"Override it locally" is not a third option.

And a corollary worth watching: **a schema that grows a key per adopting repo has failed.**
If repo N+1 needs N+1 new keys, the boundary is in the wrong place and the honest answer is
a smaller plugin, not a bigger schema.

---

## Full schema

```yaml
# ── identity ─────────────────────────────────────────────────────────────────
repo: glunk-works/bounty-infra   # owner/name. Also the machine-label namespace.
pr_base: main                    # branch every PR is cut from and based on.

# ── the deep record ──────────────────────────────────────────────────────────
roadmap: docs/hardening_roadmap.md   # reference of record: status + next action.
sprints_dir: sprints                 # sprint plans live at <sprints_dir>/*/sprint_plan.md
threat_model: docs/hardening_roadmap.md   # security-critic's ground truth.

decisions:
  log: docs/hardening_roadmap.md   # where locked decisions are recorded.
  prefix: BI-D                     # so a skill can cite "BI-D5" without knowing the repo.

backlog:
  kind: github_issues              # github_issues | file
  path: null                       # required when kind: file (e.g. docs/backlog.md)
  item_prefix: null                # required when kind: file (e.g. BL-)

load_bearing_docs:                 # docs-consistency's audit set. Globs allowed.
  - CLAUDE.md
  - docs/hardening_roadmap.md
  - .ai/next-steps.md
  - sprints/**/sprint_plan.md

# ── what counts as a behavior change ─────────────────────────────────────────
code_paths:                        # a diff touching these is not docs-only.
  - src/
  - infra/
  - .github/workflows/

# ── the local green gate ─────────────────────────────────────────────────────
gates:
  green:                           # run in order; all must exit 0.
    - { cwd: src,   run: hatch run lint:check }
    - { cwd: src,   run: hatch run test:run }
    - { cwd: infra, run: tofu fmt -check -recursive }
    - { cwd: infra, run: "tofu init -backend=false && tofu validate" }

# ── branch protection ────────────────────────────────────────────────────────
ruleset:
  name: protected-integration-branches
  rule_types: [deletion, non_fast_forward, pull_request, required_status_checks]
  required_checks: [lint, test, tofu-validate, tofu-plan,
                    dependency-audit, sbom, secrets-scan, zizmor]

# ── the fresh-session review gate ────────────────────────────────────────────
review:
  ci_gate: null                    # this repo has no review CI gate. See below.

# ── agents ───────────────────────────────────────────────────────────────────
agents:
  enabled: [architect, coder, security-critic, docs-consistency]
models:
  architect: opus
  coder: sonnet
```

---

## Key reference

### `repo`, `pr_base`

`repo` is `owner/name`. Skills use it for `gh api repos/{repo}/…` calls and as the namespace
for machine-emitted labels (`{repo-name}/*`).

`pr_base` is the branch work is cut **from** and based **on**. Normally the repo's default
branch — the key exists because it does not have to be. A repo mid a large multi-sprint
migration may stage on a long-lived integration branch, point `pr_base` at it for the
duration, and revert once the migration lands as one deliberate merge commit. Never assume
`main`; `{pr_base}` is always the answer.

### `roadmap`, `sprints_dir`, `decisions`, `backlog`, `threat_model`

The repo's deep record, which the plugin points into and never duplicates.

`decisions.prefix` lets a skill say "record this as a `{decisions.prefix}` entry" without
knowing whether that reads `BI-D`, `WB-D`, or something else.

`backlog.kind` is the one genuinely bimodal key here, and it is load-bearing for `/retro`
and `/archive-sprint`, both of which route findings into a backlog and cite items by id:

- `github_issues` — findings become GitHub issues, cited as `#N`. There is no backlog file
  to read; the equivalent of "read what's already decided" is `gh issue list`.
- `file` — findings become items in `{backlog.path}`, cited as `{backlog.item_prefix}N`.

A skill must branch on `kind` and never assume a file exists. This key was **not** in the
original sprint plan; it was found while generalizing `/retro`, which the plan's inventory
recorded as having no coupling at all. It has three (`docs/backlog.md`, `BL-` ids, and a
named repo-local memory), and the first two are structural.

### `load_bearing_docs`, `code_paths`

`load_bearing_docs` is the prose set whose claims must match reality — `docs-consistency`'s
audit target, and what makes a docs change worth a critic pass.

`code_paths` is the single definition of "this diff changes behavior." It drives
`/critic-gate`'s proposal (a diff touching none of these warrants no code critic), the
docs-only classification in `/pr-checks` and `/ship`, and — unless overridden — what trips
the review gate. One key, because two definitions of "is this docs-only" that can disagree
will eventually disagree.

### `gates.green`

An ordered list of `{cwd, run}`. `cwd` is relative to the repo root; `run` is a shell
command that must exit 0. Skills execute these in order and stop at the first failure.

This is a **local pre-check, not the gate of record** — CI on the PR is. It exists so a
coder finds the cheap failures before spending a CI run, and so `/critic-gate` never spends
critics on a diff that does not build.

### `ruleset`

`name` is the branch-protection ruleset's name, `rule_types` the rule types it must carry,
`required_checks` every check it requires. `/resume` verifies the live ruleset against all
three; `/pr-checks` reports every name in `required_checks` and only those.

Keep `required_checks` in sync with the **live** ruleset, not with a plan or a wish. The
list here is what skills report as authoritative, so a stale entry produces a confident
report of a check that no longer gates anything — and a missing entry means a real gate goes
unreported.

### `review.ci_gate`

The fresh-session review gate: a CI check that stays red on a behavior-changing PR until a
review carrying a specific header is posted against the PR's current head commit.

**`null` means this repo has no such gate**, and that is a fully supported configuration —
not a degraded one. Every skill takes the no-gate branch cleanly: no dangling instruction to
post a review nobody requires, no claim of exemption from a gate that does not exist, no
check name reported as missing when it was never required.

When a repo does have one:

```yaml
review:
  ci_gate:
    check: architect-review
    header: "**Opus/Architect HITL review (automated)**"
    attestation: "*Fresh-session review: this session did not author the diff.*"
    triggers_on: [src/]        # optional; defaults to code_paths
```

`check` must also appear in `ruleset.required_checks` — a review gate that does not gate is
prose.

> ### ⚠️ `header` and `attestation` are frozen wire strings — paste, never paraphrase.
>
> These two values live in the schema **as data** for exactly one reason: so a skill pastes
> them from a file instead of retyping them from memory. The CI check matches both by
> literal `contains()`. It is a substring test, not an intent test.
>
> A paraphrase that reads identically to a human still fails — "Fresh-session attestation:
> …" instead of "*Fresh-session review: …*" turns the check red about four seconds after the
> review posts, and the failure looks like a review problem rather than a string problem,
> which is why it recurs.
>
> Copy the value byte-for-byte out of `.ai/project.yml`. Do not re-type it, do not fix its
> capitalization, do not "correct" vocabulary that looks outdated. If a header says
> something the repo has since renamed, it says so **deliberately** — it is matched
> byte-for-byte by a workflow and often pinned by a test. Renaming one is an atomic change
> to the workflow, the test, and the schema value together, never a docs tidy-up.

### `agents`, `models`

`agents.enabled` is which of the plugin's agents this repo uses. `/critic-gate` proposes
from this list only — it never offers an agent the repo has not enabled, and never one that
is not in the plugin at all.

A repo may define **additional** agents locally in `.claude/agents/`. Those are repo-local
by definition and out of the plugin's scope; adding one to `agents.enabled` does not make it
shared. (Unlike skills, a local agent with a new name adds rather than shadows — the
whole-file shadowing hazard above applies to same-named components.)

`models` maps a role to the model it should run as. `/resume` compares the running model
against the role the cursor assigns; `/handoff` writes the next session's model from it.

**`models` governs *sessions*, not subagent spawns.** A plugin agent's runtime model comes
from the `model:` field in its own frontmatter, which is upstream data a consuming repo
cannot parameterize — agent frontmatter is read by the harness before any skill runs, so
there is nothing to substitute a schema value into. The two are kept deliberately in
agreement (`architect: opus`, `coder: sonnet`), and `models` exists so the *session*-routing
skills can state the rule without hardcoding it. A repo that sets `models.architect: sonnet`
is describing which model its own sessions should use for architecture work; it does **not**
change what the `architect` subagent runs as. If a repo genuinely needs a different agent
model, that is the not-portable case from *Overriding is a bug report* — a repo-local agent
under a different name, not a schema key.

---

## Worked example — a second repo, to show the seams move

The example above is bounty-infra: Python **and** OpenTofu, an 8-check ruleset, no review CI
gate. A repo with a review gate, a backlog file, and a single-language green gate fills the
same schema differently — and no skill body changes:

```yaml
repo: glunk-works/loop-orchestrator
pr_base: main

roadmap: docs/migration_roadmap.md
sprints_dir: sprints
threat_model: docs/threat_model.md

decisions:
  log: docs/migration_roadmap.md
  prefix: BL-D

backlog:
  kind: file
  path: docs/backlog.md
  item_prefix: BL-

load_bearing_docs:
  - CLAUDE.md
  - docs/migration_roadmap.md
  - docs/backlog.md
  - .ai/next-steps.md
  - sprints/**/sprint_plan.md

code_paths:
  - src/

gates:
  green:
    - { run: hatch run lint }
    - { run: hatch run format }
    - { run: hatch run test }

ruleset:
  name: protected-integration-branches
  rule_types: [deletion, non_fast_forward, pull_request, required_status_checks]
  required_checks: [lint, format-check, test, secrets-scan,
                    dependency-audit, sbom, pr-title, architect-review]

review:
  ci_gate:
    check: architect-review
    header: "**Opus/Architect HITL review (automated)**"
    attestation: "*Fresh-session review: this session did not author the diff.*"

agents:
  enabled: [architect, coder, security-critic, docs-consistency]
models:
  architect: opus
  coder: sonnet
```

The two configurations differ in every value and in one *shape* (`backlog.kind`,
`review.ci_gate` present vs `null`). That shape difference is the schema's real test: both
must be a clean path through every skill, or the seam is in the wrong place.

## Adding a key

A new key is justified when a skill would otherwise name a repo-specific value. Before
adding one, check the two cheaper answers first: the value may already be derivable from an
existing key (label namespaces come from `repo`; the review gate's trigger paths default to
`code_paths`), or the behavior may not be portable at all, in which case it leaves the
plugin instead of growing the schema.

When you do add one: define it here with its type and its default, state what happens when
it is absent, and update every skill that reads it in the same change. A key documented but
unread is worse than no key — it reads as configured behavior that silently does nothing.
