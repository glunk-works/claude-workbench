# `.ai/project.yml` — the parameterization contract

Every entry in this plugin except `reference/` and `.claude-plugin/` is portable.
**Shared plugin code may never name a repo-specific value.** Where behavior needs one, it
reads it from `.ai/project.yml` in the consuming repo. This file defines that contract.

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
name, a branch, or a gate. Guessing is worse than stopping: a `/way-of-working:pr-checks` that invents a
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
repo: glunk-works/bounty-infra   # owner/name. Also the namespace for labels a skill emits.
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
  repo: null                       # optional; defaults to `repo` above. See below —
                                   # only supported with kind: github_issues.
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
for the machine-emitted labels **they themselves** apply (`{repo-name}/*`) — correct because
a skill's emitter *is* the repo's own automation. The general rule is *namespace by the
emitting system*, which is not always the repo: a repo running a separately-named engine
namespaces under the engine. Deriving a skill's own namespace from `repo` is that rule
applied, not an exception to it. See `reference/conventions.md` § *Issue + label taxonomy*.

`pr_base` is the branch work is cut **from** and based **on**. Normally the repo's default
branch — the key exists because it does not have to be. A repo mid a large multi-sprint
migration may stage on a long-lived integration branch, point `pr_base` at it for the
duration, and revert once the migration lands as one deliberate merge commit. Never assume
`main`; `{pr_base}` is always the answer.

### `roadmap`, `sprints_dir`, `decisions`, `backlog`, `threat_model`

The repo's deep record, which the plugin points into and never duplicates.

`decisions.prefix` lets a skill say "record this as a `{decisions.prefix}` entry" without
knowing whether that reads `BI-D`, `WB-D`, or something else.

#### The `_archive` sibling — one derivation, every compactable record

A record the plugin compacts has an **archive sibling**, and that path is **derived, not
configured** — there is no schema key for it, and a repo never names one. In the **basename**
only, insert `_archive` before the final `.` (`docs/backlog.md` → `docs/backlog_archive.md`);
a basename with no `.` — or whose only `.` is a leading one, which names the file rather than
separating an extension — takes `_archive` appended (`docs/BACKLOG` → `docs/BACKLOG_archive`;
`docs/.backlog` → `docs/.backlog_archive`). **Never alter the directory part** — a dot in a
directory name is not an extension, and keeping the directory is what puts the archive beside
the record it came out of, as `reference/conventions.md` § *Prose economy* requires.

The rule applies to **`{roadmap}`** and to a **file-kind `{backlog.path}`** alike: one
derivation, so a reader who knows any live record's path knows its archive's path. It is a
derived path, **not a promise that the file exists** — anything reading a record to learn
what is already decided reads both, and treats a missing sibling as empty rather than as an
error. `/way-of-working:archive-sprint`'s compaction step is what fills them.

`backlog.kind` is the one genuinely bimodal key here, and it is load-bearing for `/way-of-working:retro`
and `/way-of-working:archive-sprint`, both of which route findings into a backlog and cite items by id:

- `github_issues` — findings become GitHub issues, cited as `#N`. There is no backlog file
  to read; the equivalent of "read what's already decided" is `gh issue list --state all`.
  **Two traps, both silent.** A bare `gh issue list` shows only *open* issues, so a
  citation of a closed one reads as dangling when it is perfectly live. And `--state all`
  does not widen the result window — it repopulates it: `--limit` defaults to 30, which
  closed issues now compete for, so an old issue can fall off the page and read as absent.
  To check **one cited id**, never scan — `gh issue view <N> --json state` answers directly,
  with no limit to truncate it.
- `file` — findings become items in `{backlog.path}`, cited as `{backlog.item_prefix}N`.
  Its **archive sibling** is derived by the single rule above. That is where items closed
  during a sprint go when the live record is compacted — **resolved and declined alike**
  (`reference/conventions.md` § *Prose economy*) — keeping their id anchors so existing
  citations still resolve. For a file-kind backlog the sibling is the equivalent of
  `gh issue list --state closed`: without reading it you cannot tell "never proposed" from
  "already done", and a missing sibling means empty, not error.

A skill must branch on `kind` and never assume a file exists. This key was **not** in the
original sprint plan; it was found while generalizing `/way-of-working:retro`, which the plan's inventory
recorded as having no coupling at all. It has three (`docs/backlog.md`, `BL-` ids, and a
named repo-local memory), and the first two are structural.

#### `backlog.repo` — when the backlog lives in a sibling repo

Optional. Absent or `null` means *this repo* — `{repo}` above — which is the common case and
needs no thought. Set it to an `owner/name` when the findings for this repo are tracked
somewhere else.

That shape is real and not exotic: a **hub** repo holding the roadmap and backlog for a small
family of satellite module repos, where a finding about a satellite is filed against the hub
because that is where the record of record lives. Without this key a satellite has three bad
options — a relative path escaping the repo (works on one machine, breaks in CI), a `kind`
that is factually wrong (findings route into a channel nobody reads), or `null` (honest, but
the skills then have nowhere to route a finding in a repo that demonstrably has somewhere).

**Only `kind: github_issues` supports it.** With issues, cross-repo is genuinely free — both
directions are one `gh` call with a `--repo` flag, no clone, no branch, no PR, no second
review surface:

```bash
gh issue list   --repo {backlog.repo} --state open      # read what's already decided
gh issue create --repo {backlog.repo} --title … --body … # route a finding
```

A satellite repo pointing at its hub:

```yaml
repo: <owner>/<satellite>        # this repo
backlog:
  kind: github_issues
  repo: <owner>/<hub>            # findings about this repo are filed there
  path: null
  item_prefix: null
```

With `kind: file`, a cross-repo pointer is **not supported** — a skill would have to read
through an API and *write* by opening a PR against a repo whose owner did not ask for it.
A repo in that position sets `backlog.repo` only if it can move to issues; otherwise it
leaves the backlog `null` and states the real location in a comment, which is lossy but
honest. Do not invent a path that escapes the repo.

> **Always establish reach before believing an answer.** Any `gh` call against a repo that
> is not `{repo}` can fail for two reasons that look identical and demand opposite
> responses: the thing is not there, or **this identity cannot see it** — GitHub answers an
> unreachable resource with `404`, not `403`. Before trusting a cross-repo read, confirm
> reach the same way `/way-of-working:resume` step 4 does:
> ```bash
> gh api repos/{backlog.repo} --jq .permissions
> ```
> No `pull` means **stop and report the identity** (`gh api user --jq .login`) — never
> report the backlog as empty or missing. An empty backlog and an unreachable one are
> different facts, and only one of them means "nothing has been decided yet."

### `load_bearing_docs`, `code_paths`

`load_bearing_docs` is the prose set whose claims must match reality — `docs-consistency`'s
audit target, and what makes a docs change worth a critic pass.

`code_paths` is the single definition of "this diff changes behavior." It drives
`/way-of-working:critic-gate`'s proposal (a diff touching none of these warrants no code critic), the
docs-only classification in `/way-of-working:pr-checks` and `/way-of-working:ship`, and — unless overridden — what trips
the review gate. One key, because two definitions of "is this docs-only" that can disagree
will eventually disagree.

### `gates.green`

An ordered list of `{cwd, run}`. `cwd` is relative to the repo root; `run` is a shell
command that must exit 0. Skills execute these in order and stop at the first failure.

This is a **local pre-check, not the gate of record** — CI on the PR is. It exists so a
coder finds the cheap failures before spending a CI run, and so `/way-of-working:critic-gate` never spends
critics on a diff that does not build.

### `ruleset`

`name` is the branch-protection ruleset's name, `rule_types` the rule types it must carry,
`required_checks` every check it requires. `/way-of-working:resume` verifies the live ruleset against all
three; `/way-of-working:pr-checks` reports every name in `required_checks` and only those.

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

`agents.enabled` is which of the plugin's agents this repo uses. `/way-of-working:critic-gate` proposes
from this list only — it never offers an agent the repo has not enabled, and never one that
is not in the plugin at all.

A repo may define **additional** agents locally in `.claude/agents/`. Those are repo-local
by definition and out of the plugin's scope; adding one to `agents.enabled` does not make it
shared. (Unlike skills, a local agent with a new name adds rather than shadows — the
whole-file shadowing hazard above applies to same-named components.)

`models` maps a role to the model it should run as. `/way-of-working:resume` compares the running model
against the role the cursor assigns; `/way-of-working:handoff` writes the next session's model from it.

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
existing key (a skill's own label namespace comes from `repo`; the review gate's trigger
paths default to `code_paths`), or the behavior may not be portable at all, in which case
it leaves the plugin instead of growing the schema.

When you do add one: define it here with its type and its default, state what happens when
it is absent, and update every skill that reads it in the same change. A key documented but
unread is worse than no key — it reads as configured behavior that silently does nothing.
