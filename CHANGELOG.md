# Changelog

Consuming repos **pin a tag**, so nothing here reaches a repo until it bumps its pin in
`.claude/settings.json`. This file exists so that decision can be made with the contents in
view — `/way-of-working:archive-sprint`'s *Consider bumping the plugin pin* step prompts for
one at every sprint close, and a prompt that cannot say *"this one needs a migration"* is a
trap.

**Read the `⚠️ Migration` line, if a release has one, before bumping.**

**Bumping the pin is three steps, and skipping either of the last two fails silently.**
Editing `.claude/settings.json` changes what is *pinned*; it does not change what is *loaded*.

```bash
# 1. edit the ref in .claude/settings.json, then:
claude plugin update <plugin>@<marketplace>   # 2. fetch the newly pinned tag
# 3. restart the session — `update` reports "restart required to apply", and a
#    running session keeps executing the copy it started with
claude plugin list                            # verify: does it report the new version?
```

**Verify with `claude plugin list`, never by looking for a new cache directory.** The cache
keeps one directory per version and does **not** remove the old one, so "a new directory
appeared" is true even while the session still runs the old code. Observed three times now —
twice in `WB-D6`, and again during the `v0.5.0` release, where a session was served skills
from a `0.1.0` cache directory while `claude plugin list` correctly reported `0.5.0`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases before
`v0.5.0` are summarized from their tags; the full record is `docs/decisions.md` (`WB-D*`) and
the GitHub release notes.

## [Unreleased]

**No migration required.** No `.ai/project.yml` key was added, removed, or renamed — the
archive destinations added this release are *derived* from paths a repo already sets, not
configured. Three behavioral edges, all the same shape: an absent key is not a `null` key,
so a skill that newly reads one reports it as unreadable where it previously said nothing.
`/way-of-working:critic-gate` now reads `{ruleset.required_checks}`;
`/way-of-working:archive-sprint` now reads `{agents.enabled}` and `{load_bearing_docs}`;
and `/way-of-working:ship` now reads `{backlog}` and `{roadmap}` for its ledger-conflict
rule.

### Added

- **Prose economy: the deep record gets a lifecycle.** Repeated critic-gate rounds (the
  evidence is gathered in `#57`) found the dominant defect class to be prose restating
  current state — each fix round minting the next round's defects — while `{roadmap}` and a
  file-kind `{backlog}` grew without bound as a standing per-session token cost. The class
  fix is less load-bearing prose, not more review:
  - `reference/conventions.md` — new **Prose economy** section: derive-don't-restate, one
    authoritative site per fact, corrections replace text (the story lives in git),
    evidence-then-prose (a correction is re-verified as hard as the claim it replaces),
    the deep record is compacted rather than append-only, and — once the mistake a
    paragraph warns against has actually occurred — the paragraph shrinks to a pointer at
    a check that fails the same way, verified by a deliberate regression.
  - `/way-of-working:handoff` — the regenerated cursor states no regenerable aggregates
    (no counts, no check inventories); it names the deriving command or authority
    instead. The cursor's own fields (status, hashes, model) and the critic pass's
    round count + stopping condition stay.
  - `/way-of-working:critic-gate` — findings checkable by execution are checked before
    being acted on (trust but verify); prose fixes prefer deletion/derivation over
    hand-correction, and a recurring prose defect class is promoted to a gate check.
  - `reference/workflow.md` — the `/way-of-working:critic-gate` line no longer says
    "iterates to clean", the formulation that skill explicitly rejects as unbounded.
  - **A file-kind `{backlog}` gets a defined archive sibling, and the surfaces that read
    the backlog read it too.** `reference/project-schema.md` derives the path rather than
    configuring it; `/way-of-working:retro`, the `docs-consistency` agent, and
    `/way-of-working:archive-sprint`'s evidence preconditions now consult it alongside the
    live file. Without it a resolved item reads as missing — a re-proposed finding in
    `retro`, a false "dangling citation" in `docs-consistency`, and a blocked sprint close
    in `archive-sprint`. A sibling that does not exist yet is empty, not an error — the
    derivation names a path, it does not promise a file.
  - **Two silent `gh issue list` traps are now named where the contract is defined**
    (`reference/project-schema.md`), and the readers follow it. A bare call shows only
    *open* issues, so citing a closed one reads as dangling; and `--state all` does not
    widen the result window but repopulates it against a `--limit` that defaults to 30, so
    an old issue can fall off the page and read as absent — for one cited id, worse than
    the bare call. To check a cited id, `gh issue view <N> --json state` answers directly.

  **For anyone who injects `reference/conventions.md` into a managed repo:** it now
  carries schema keys in braces (`{roadmap}`, `{gates.green}`, `{ruleset.required_checks}`)
  where before it had none, and a new preamble says so. Injected verbatim, those read as
  placeholders — the file is meant to be read in place beside the `project-schema.md` that
  defines them.

  The rules and the readers landed first, then **the writer** — the entries below.

- **One archive rule, now applied to `{roadmap}` as well.** Part A derived an `_archive`
  sibling for a file-kind `{backlog}` and left `{roadmap}`'s destination "a per-repo choice
  until one is defined." The writer defines it — as the *same* derivation, not a second
  convention and not a new schema key. That keeps the archive **beside the live record**, as
  the Prose economy rules require (an archive parked in a sprint directory is not), needs
  nothing added to `.ai/project.yml`, and lets a repo with **no sprint cadence** compact its
  roadmap — which the sprint-directory destination structurally could not, leaving the repos
  most prone to roadmap bloat unable to do anything about it.

- **The writer: `/way-of-working:archive-sprint` now performs the compaction, on its own
  PR.** A new **step 2**, before the cursor advances (advance/seed renumbered 3–4;
  prune/report/pin 5–7): the closed sprint's execution narrative moves out of `{roadmap}`
  to its `_archive` sibling, file-kind `{backlog}` items closed during the sprint —
  **resolved *and* declined**, matching what every reader of the sibling already expects to
  find there — move to theirs keeping their id anchors, and correction annotations whose
  gated action is confirmably closed are deleted. **Move, don't rewrite**, and the guardrail
  is checkable rather than a claim about intent: a line may leave a source only when the
  identical bytes are in an archive file staged in the same change — verified before the
  commit, since a move that cannot show its destination is a deletion whatever it was meant
  to be. It surveys first, confirms the sprint actually merged, cuts its branch from
  `{pr_base}` before editing a file (editing first can abort the checkout, and git's own
  advice then strands the work on a branch step 5 deletes), stages by explicit path, and
  stops at an open PR the human merges. A repo with nothing to move takes a one-line exit.

  Four details that are the difference between a working procedure and a plausible one, the
  first three verified against git rather than reasoned about:
  - the branch cut ends in **`git merge --ff-only origin/{pr_base}`, not `git pull`** —
    where `pull.rebase=false` is configured, a plain pull *succeeds* on a diverged local
    `{pr_base}`, merging silently, so every link in the chain returns zero and the compaction
    branch is cut from a base carrying an unrelated commit. (With no pull config at all git
    refuses instead, so the hazard is config-dependent — which is exactly why the procedure
    should not depend on the operator's config. The ref is named for the same reason: a bare
    merge follows `@{upstream}`, wherever that points.);
  - **`git check-ignore` runs before `git add`, not after** — it is index-aware, so once a
    path is staged it reports nothing even when `.gitignore` matches, making the check pass
    by construction and prove nothing;
  - **a non-zero `git add` is a stop** — given an ignored destination it stages the sources
    anyway and exits 1, leaving exactly the deletion-without-destination in the index;
  - the addition-side check is **scoped to the archive paths** — unscoped, the pointer lines
    left at vacated anchors supply insertions and the check passes with no archive staged.

  The correction-annotation exception has no destination to verify, so every removal claiming
  it must be **enumerated with its evidence in the commit and PR body**. In a repo with a
  `github_issues` backlog that exception can be all a compaction does, which would otherwise
  leave the bright line resting entirely on the agent's own say-so. Relatedly, `state` alone
  cannot tell a completed item from a declined one — both read `CLOSED` — so the check now
  asks for `state,stateReason`.

  The guardrail this replaces — *"archival only moves the `.ai/` cursor snapshot"* — was
  true until this step existed and is now removed rather than annotated.

- **The reader half: `/way-of-working:ship` gains a ledger-conflict exception.** Without it
  the "keep both sides" default silently resurrects whatever a compaction archived, the
  first time a stale branch is refreshed against `{pr_base}`. The exception is **proved,
  never inferred from the hunk shape** — a compaction's removal and your branch's new
  neighbouring item look identical in a conflict. It compares two revisions instead:
  `git show :1:<ledger>`, the base the merge itself used, against
  `git show MERGE_HEAD:<ledger>`, the incoming side. **Removed nothing → keep both sides and
  move on**, which is the ordinary two-additions conflict and the common case. **Removed
  entries → name them to the human and let them resolve those**, while everything untouched
  still keeps both. Where a `git show` fails — a renamed ledger, or an add/add conflict with
  no stage 1 — the default stands unchanged.

  **It deliberately stops at the human rather than deciding each entry.** The mechanical
  version — look a removed id up in the incoming `_archive` sibling and drop it if found —
  needs to match an id at its own **entry anchor**, and a line-shaped `grep` cannot do that
  safely. Three critic rounds each broke it in a new way: it misses real entries
  (`- **BL-3** — …`, `1. BL-3 …`, `| BL-3 | …`), and it *matches* a wrapped citation whose
  continuation line begins with the id — which in the archive means silently dropping a live
  item. `/way-of-working:retro` mandates the citation shape that produces those, so they are
  ordinary content rather than an edge case. Per `WB-D10` that predicate belongs in a
  fixture-backed `bin/` script, not in prose — filed as `#66`, with the failing shapes as a
  ready-made fixture table. Until it exists this step reports and the human decides, which
  loses automation, not safety.

  **It asks a revision, never a merge base.** The obvious form — diff `git merge-base HEAD
  MERGE_HEAD` against `MERGE_HEAD` and call the result "the incoming side's changes, with
  your side absent" — is **false under squash-merge, this project's own default**, and was
  written that way first. A squash commit is not a descendant of the branch's commits, so
  the merge base does not advance past it (`WB-D7`'s premise in a different command): once a
  PR squash-merges and work continues on the branch, that diff replays the branch's *own*
  additions and deletions as the incoming side's. Stage 1 is the base **git itself resolved
  for this merge**, virtual bases included, so it is right where a recomputed base is not.
  Reproduced before the fix — a decline and
  an addition made on the work branch were both attributed to `{pr_base}`, which inverts the
  rule's conclusion. `git show MERGE_HEAD:<path>` has no fork point to be wrong about.

- **`/way-of-working:retro`'s "confirmed again" path is now defined for an archived item.**
  Step 1 reads the `_archive` sibling, so it will match resolved and declined items;
  neither annotating one in place nor reopening it is right. Archive files are never
  edited — historical record, and a compaction moves text without rewriting it — and a
  resolved item recurring is new information that earns a new item citing the old ID, not a
  reopen that buries it. A declined one goes back to the owner rather than being reversed.

### Fixed

- **The branch prune in `/way-of-working:resume` and `/way-of-working:archive-sprint` could
  delete unpushed work without warning.** Both fused the merged test onto the deletion
  (`grep -qxF "$b" && git branch -D "$b"`), which makes `-D` safe per *branch* while the
  risk is per *commit*: a branch whose PR GitHub reports `merged` can since have taken a
  local commit, and because a squash-merged branch's commits are unreachable from
  `{pr_base}`, `-D` takes that commit with no complaint and nothing to recover it from.
  The deletion is now gated on the commit GitHub actually merged — `headRefOid`, which the
  same `gh pr list` call already returns — and fires only when the local tip **is** that
  commit; anything else is reported as a skip rather than deleted.

  The first attempt at this fix tested `git rev-list --count origin/$b..$b` ("is my tip
  pushed?"). That failed *safe* — it deleted nothing — so it was never as dangerous as the
  bug, but it was not a fix either: it reads the remote-tracking ref, which stops resolving
  once the head branch is deleted on the remote (`deleteBranchOnMerge`, the PR page's
  *Delete branch* button, or by hand) and the local ref is pruned. The count then fails for
  that branch and the safe fallback skips it permanently, reporting stranded work that does
  not exist. What makes it a trap rather than a plain bug is that **the blast radius is set
  by a repo setting the test never consults**: where branches are deleted on merge it
  eventually disables the prune entirely, and where they are not — as here, where
  `deleteBranchOnMerge` was `false` and 37 of 41 merged head branches still existed on
  2026-08-31 — it looks
  flawless. `headRefOid` does not depend on that setting. Found while working #57 and
  carved out of it.

- **`/way-of-working:handoff` step 5 could cut the cursor branch off the wrong base.** The
  switch to `{pr_base}` was chained but the `checkout -b` after it was not, so an aborted
  switch was followed by a branch cut from wherever the session was standing — quietly
  producing the exact outcome the step exists to prevent. There are two abort paths, not
  one, and the step now names both — and names the right determinant, which is whether
  `.ai/next-steps.md`'s *committed* content differs between the branch being left and
  `{pr_base}`, not whether the local base is stale. Where it differs, `git checkout`
  refuses; where it does not — the ordinary case — the checkout succeeds and carries the
  modification across, and `git pull` aborts instead once the fetch brings a change to that
  file. Unchained, the first lands the cursor branch on the **code branch** and the second
  on a **stale `{pr_base}`**. The cut is now one `&&` chain; a failed link stops,
  names the blocking file, and hands it to the human rather than committing or stashing on
  their behalf — including the case where the chain stops with the session parked on
  `{pr_base}`. Found while working #57 and carved out of it.

- **`coupling-check.sh`'s component loop was an allowlist, which is what let the
  `plugins/*/hooks/` gap below (#49) happen in the first place: a new component directory
  had to be added to a hardcoded list by hand before the gate would ever look at it.**
  Inverted to a denylist -- the loop now scans every entry under `plugins/*/` except
  `reference/` (documentation, legitimately quotes concrete example values),
  `.claude-plugin/` (plugin metadata, `plugin.json`'s `author` field legitimately carries
  the org name), and `.git/` (defensive only, for a plugin vendored as a nested clone;
  git refuses to commit a `.git` path, so in CI the arm is unreachable). `shopt -s
  dotglob` was required for the `.claude-plugin/` exclusion to be a real decision rather
  than an accident: bash globs skip dot-directories by default, so without it the
  exclusion `case` arm was unreachable and `.claude-plugin/` was already being skipped for
  the wrong reason.

  Two rounds of critique on this change found five further ways the gate could report a
  pass over something it had not read, all now closed and each covered by a regression in
  `tests/coupling-check.test.sh`:
  - **Files at a plugin's root were never scanned** -- the inner glob was `*/`, so only
    directories were examined. `.mcp.json` lives there and carries MCP server commands.
    The glob is now `*`; `grep -r` takes a file as happily as a directory.
  - **The exclusions matched on name alone**, so a plugin-root *file* called `reference`,
    `.claude-plugin` or `.git` was skipped as though it were the directory of that name --
    a green pass over unread content, and new surface created by scanning root files at
    all. Each exclusion is justified by what the entry *is*, so it now matches on type too.
  - **A whole plugin could be skipped silently.** The zero-scanned guard was one repo-wide
    counter, so any one scannable directory anywhere satisfied it -- a second plugin whose
    every entry was excluded passed green. The guard is now per-plugin.
  - **`$(basename ...)` stripped trailing newlines**, so a directory named `reference` plus
    a newline compared equal to `reference` and was skipped. A newline is a legal path
    character in git, making that a committable bypass. Now `${target##*/}`, which
    compares the value actually used.
  - **`grep` exiting 2 (a real error) was read as "no match"** by the `if hits=$(grep ...)`
    form, discarding any hits already found -- a gate that dies quietly reporting the same
    "nothing to see" as a gate that passed, the failure `invariants-check.sh` already
    names. Exit status is now captured, and anything `>= 2` fails the gate.

  An empty or missing `plugins/` tree and a wrong cwd all fail the gate too, rather than
  reporting a pass having read nothing. (`.` and `..`, which `dotglob` yields on bash
  before 5.2, are *skipped* rather than failed -- left in they would send `grep` up into
  the whole repo and make the documented local run permanently red on macOS's system
  bash.) The cases the gate still does *not* cover -- a file directly in `plugins/`
  outside any plugin directory, a symlink below a component directory, a plugin-root
  symlink named like an exclusion, and an empty directory satisfying the per-plugin
  counter -- are enumerated in the script's header rather than left to be discovered. `CLAUDE.md`,
  `README.md`, `reference/project-schema.md`, and the two CI workflow step names were all
  widened to match, per the precedent #49 set below. See #53.

- **The coupling gate never scanned `plugins/*/hooks/`, and a stale literal was sitting in
  the blind spot.** The scanned set was `skills/`, `agents/`, and `bin/`. `hooks/` carries
  shipped, executed plugin code by exactly the argument that added `bin/` in #21:
  `hooks/ai-cursor-banner.sh` is a `SessionStart` hook registered in `hooks.json` and runs in
  every consuming repo. Adding `hooks` to the scanned set immediately caught the one live hit
  it had been blind to — the hook's header comment pointed at `.ai/context/workflow.md` and a
  CLAUDE.md section heading, **neither of which exists here**: that workflow content moved
  into the plugin's own `reference/workflow.md`. Reworded to name the concept rather than the
  path. The two CI workflow step names that enumerated the old three-tree set
  (`ci.yml`, `release.yml`) were corrected with it — the `coupling` **job id**, which is what
  `ruleset.required_checks` matches, is deliberately untouched. The gate's rule sentence and
  failure banner now say "shared plugin code" rather than "a skill or agent", which had
  under-described the scanned set since `bin/` joined it — as did the same sentence in
  `CLAUDE.md`, `README.md`, and `reference/project-schema.md`, all widened to match. The
  last of those matters most: it is where the failure banner sends a reader for the fix.
  Found by the architect critic during #43's `/way-of-working:critic-gate` pass and filed
  separately. See #49.

- **`coupling-check.sh` guarded only 4 of the org's 8 repos.** `TIER2` itself listed 3
  (`bounty-infra`, `global-bootstrap`, `scope-core`); the 4th (`loop-orchestrator`) was
  covered only via `TIER1`, and the check's other four org repos had no coverage anywhere.
  Added the missing four (`claude-workbench`, `bedrock-serverless-rag`, `pm-agent-loop`,
  `appsec-triage-agent`), plus the `loop-engine` worked-example emitter name and
  `loop-orchestrator` itself, to `TIER2`, and restated its comment as a membership rule
  instead of an ad-hoc list. `claude-workbench` is the repo a contributor is most likely to
  be sitting in while editing the plugin, and was the highest-risk gap. Two pre-existing,
  legitimate self-references to `claude-workbench` in `archive-sprint`/`retro`'s own prose
  (describing the plugin's distribution source, not a leaked local-repo literal) were
  reworded to name the concept instead of the repo. See #43.

- **The pin-bump procedure was wrong for a second time, and this release changes where it
  lives rather than only what it says.** `claude plugin update` resolves against the ref
  registered in `~/.claude/plugins/known_marketplaces.json`, not the ref just edited into
  `.claude/settings.json`, so it reported *"already at the latest version"* and loaded the
  old tag — a silent no-op reporting success. Corrected in
  `reference/conventions.md` § *Bumping a pinned plugin*, which also covers the two
  adjacent traps: `update` defaulting to `--scope user` on a project-scoped install, and a
  first registration made **without** a `ref` shadowing a project pin permanently. See #37.
- **The corrected steps now ship in the generated release notes** (`release.yml`), because
  `CHANGELOG.md` is the wrong channel for this by construction: a consuming repo reads the
  pin-bump instructions from the version it *already has*, so a fix here is only readable
  after the bump it describes. Release notes are read at bump time and stay editable after
  the tag is cut. `WB-D6`'s lesson, applied to the delivery mechanism instead of the prose.
- **Verification is now by commit, not by version string.** `claude plugin list` reports the
  `version` field from the installed `plugin.json`, which is self-consistent at the wrong
  commit and therefore proves nothing; the check compares `gitCommitSha` in
  `installed_plugins.json` against the tag. Found live: a consuming repo reporting `0.5.1`
  while running a `main` commit two merges past that tag.
- **The machine-namespace rule shipped with an example that contradicted it — and a second
  doc that contradicted the rule outright.** Global Conventions § *Issue + label taxonomy*
  stated the namespace as *the emitting system*, then illustrated it with the **repo** name,
  which is only coincidentally the same thing: in the repo the example was drawn from the
  emitter is `loop-engine`, so the label reads `loop-engine/needs-human`, and the one
  instance a reader had to generalize from taught the wrong rule. `project-schema.md` then
  stated that wrong rule flatly, in three places, as a plain property of the `repo` key.
  Fixed together — the conventions bullet now names the emitter and gives both cases (the
  one where the namespace matches the repo and the one where it does not), while
  `project-schema.md` and `/way-of-working:ship` step 6 still derive a skill's namespace
  from `{repo}` but now say **why** that is correct: a skill's emitter *is* the repo's own
  automation, so it is the general rule applied, not an exception to it. **No emitted label
  changes and no key moved** — every namespace any skill produced was already right; what
  was wrong was the reason given for it, which is what a reader generalizes from. Closes
  #28's decision 1.

## [0.6.0] — 2026-08-13

**No migration required.** No `.ai/project.yml` key changed and no skill contract moved.
Two things behave differently after the bump, though, and neither is visible in a diff of
your own repo: `/way-of-working:ship` step 1 now runs a preflight that can **stop** a ship
before anything is committed, and the plugin ships its first executable — `bin/` is on the
Bash tool's `PATH` while the plugin is enabled, so a name collision with a script of your
own on `PATH` is possible in principle. Only `cursor-drift.sh` is claimed today.

### Added

- **`/way-of-working:ship` step 1 gains a push-reach preflight** (`gh api repos/{repo}
  --jq .permissions.push`), so a wrong-identity push is caught before anything is
  committed rather than at `git push`. It only verifies `gh`'s identity, not `git`'s — see
  the new Global Conventions section below for the case it can't catch.
- **Global Conventions documents the `git`-vs-`gh` push-identity split**
  (`reference/conventions.md` § *Push identity*): `git push` and `gh` can resolve
  different GitHub accounts on the same machine, so a healthy `gh` preflight does not
  guarantee the next `git push` succeeds. Includes the diagnosis, a per-push workaround,
  and the durable fix.
- **`/way-of-working:handoff`'s own push (step 5) gets a pointer to the same section** —
  it has the identical exposure but, per #23's own preferred shape, no preflight of its
  own; only `ship` does. Closes #23.
- **`plugins/way-of-working/bin/cursor-drift.sh`**, a tested extraction of
  `/way-of-working:resume` step 2's cursor-freshness classifier (`clean | cursor-sync |
  drift | unreadable`), proven by `tests/cursor-drift.test.sh` against real throwaway git repos —
  including the squash-merge case `WB-D7` names. `bin/` is on the Bash tool's `PATH` while
  the plugin is enabled, so the skill calls it by bare name; `${CLAUDE_PLUGIN_ROOT}` was
  confirmed **not** set in that context first (issue #21 step 1), which is what made `bin/`
  the right delivery mechanism rather than the interpolated path the issue proposed. A new
  `tests` CI job runs the fixtures on every PR (not yet a required check). See `WB-D10`.
- **`coupling-check.sh` and `invariants-check.sh` now also cover `plugins/*/bin/`** — the
  no-repo-specific-literal rule and the drift-classifier regression guard both apply to the
  script the same way they already applied to skill/agent prose.

## [0.5.1] — 2026-08-10

**No migration required.** Docs-only. Worth taking before a fan-out, though: it corrects the
pin-bump instructions themselves, which a repo reads from the version it already has.

### Fixed

- **The pin-bump instructions named no command.** Every mention of the plugin cache said
  "clear it" and "confirm the version rotated" without saying how, and the directory-rotation
  test was wrong — the cache keeps the old version's directory alongside the new one. Now
  states the three steps (edit the ref, `claude plugin update`, **restart**) and verification
  via `claude plugin list`. `WB-D6` updated: the mechanism it left open is now understood.

### Changed

- `WB-D8` records that the reporting repos confirmed their hubs can expose findings as
  issues, so the breaking file-based cross-repo backlog is **not scheduled** rather than
  deferred. See #5.

## [0.5.0] — 2026-08-10

**No migration required.** Every existing `.ai/project.yml` stays valid untouched;
`backlog.repo` is optional and defaults to the current behavior. Bump the pin, clear the
plugin cache, confirm the version rotated.

Closes five issues raised upstream by `/way-of-working:retro` in consuming repos: #5
(partially), #6, #7, #12, #13.

### Added

- **`backlog.repo`** — a `kind: github_issues` backlog may name the repo that holds it, for
  the hub-and-spoke shape where one repo carries the record for a family of sibling repos.
  Reads *and* writes work cross-repo (`gh issue list/create --repo …`). Not supported with
  `kind: file`; see `WB-D8` for why that asymmetry is the design. (#5, partial)
- **Blocking preconditions get a convention and two checks.** `reference/conventions.md`
  defines the `BLOCKING:` marker and extends the Definition of Done to enumerate
  preconditions, not only deliverables; `/way-of-working:ship` records a precondition's
  satisfaction in the PR that relies on it; `/way-of-working:archive-sprint` gains
  precondition 5, which checks it at close. (`WB-D9`, #7)
- **`invariants` CI job** (`scripts/invariants-check.sh`) — asserts that three
  already-shipped defects have not returned: cursor freshness compared by commit range,
  `gh auth status` being parsed, and the reach check ordered after the ruleset call.
- **This changelog.**

### Changed

- **`/way-of-working:resume` compares cursor freshness by content, not ancestry.** The
  `v0.4.0` carve-out used a commit *range* (`<last_commit>..HEAD`), which is meaningless
  unless `last_commit` is an ancestor of `HEAD` — and under squash-merge it frequently never
  becomes one, so auto-start could not fire whenever a handoff ran with a code PR still open.
  Now a two-argument `git diff <last_commit> HEAD`. (`WB-D7`, #6)
- **`/way-of-working:critic-gate` has a bounded stopping rule.** *"Iterate until the critics
  are clean"* is replaced by a severity-based convergence test, an unconditional re-run on
  the fixed tree, cross-round finding tracking, and a hard cap of 2 fix-and-re-run rounds
  before the decision returns to the human. (#12)
- **`/way-of-working:resume` establishes repo reach before the ruleset preflight.** An
  identity that cannot see a ruleset gets `404`, not `403`, so the old behavior reported a
  reachability failure as *"the ruleset does not exist"*. (#13)

### Fixed

- `/way-of-working:handoff`'s cursor-PR note described the superseded range-based rule.
- `/way-of-working:critic-gate`'s closing rationale claimed the spawn decision stays with the
  human, which stopped being true of re-spawns when the round cap replaced per-round
  confirmation.
- The README described `project-schema.md` as `v0.2.0`; the schema carries no version of its
  own and had changed since.

## [0.4.0]

`WB-D6` dispositions from the pilot's real-work exercise: tier-3 coupling patterns for
path-shaped literals, a `/way-of-working:critic-gate` proposal row for newly-added docs, and
a `/way-of-working:handoff` step-5 clarification for stacked handoffs. The first (later
superseded) fix for the cursor-drift check. A release workflow that derives its tag from
`plugin.json`, and the published `/way-of-working:<skill>` command names.

## [0.3.0]

Interim tag; see the release notes.

## [0.2.0]

`.ai/project.yml` and `reference/project-schema.md` — the parameterization contract
(`WB-D2`). Full generalization of the 7 skills and the 4 agents against it (`WB-D5`), and the
grep-based `coupling` CI job that enforces it mechanically.

## [0.1.0]

The plugin skeleton: marketplace and plugin manifests, 7 skills, 4 agents, the `SessionStart`
cursor-banner hook, and the Global Conventions (`WB-D1`, `WB-D3`, `WB-D4`). Skills were
copied across still coupled to their source repo **on purpose** — generalizing them was
`v0.2.0`'s job.
