---
name: retro
description: >-
  A session-end (or on-demand) retrospective on HOW WE WORKED — mine the live session for
  friction that RECURRED or cost real rework, then route each finding to its existing home
  (a backlog item, a memory, or a small skill/doc edit). High signal bar; no speculative
  suggestions, no new parallel doc, no gratuitous new personas. Run at the end of a working
  session or when asked to look for workflow improvements. NOT for code diffs (that is
  /way-of-working:critic-gate) or prose-vs-code drift (that is the docs-consistency subagent).
---

# /way-of-working:retro — retrospective on the workflow (route findings, don't duplicate)

Goal: turn a working session's friction into durable improvement **consistently** — not only
when the human happens to ask. This audits the layer nothing else does: **how we worked** —
session mechanics, recurring toil, claims that overreached, manual steps a skill already
covers. (`/way-of-working:critic-gate` and the `architect` agent audit code; `docs-consistency` audits
prose-vs-code; the backlog holds product/infra defects. None look at the working
relationship.) It exists to **reduce** friction — so it must not become a friction generator.

**Read `.ai/project.yml` first** for `{backlog}`, `{roadmap}`, and `{decisions}`.

## Where the backlog lives

Routing a finding means writing it somewhere real, and that somewhere differs per repo.
Branch on `{backlog.kind}` and never assume a backlog file exists:

- **`github_issues`** — findings become GitHub issues, cited as `#N`. Read what's already
  decided with `gh issue list --state open` (plus `--state closed` when checking whether
  something was already considered and rejected).
- **`file`** — findings become items in `{backlog.path}`, cited as `{backlog.item_prefix}N`.
  Read that file's index directly, **and its `_archive` sibling** —
  `reference/project-schema.md` derives the path and says how to treat one that does not
  exist. Compaction puts resolved *and declined* items there, so for a file-kind backlog
  the sibling is what `--state closed` is above: without it you will re-propose something
  already done.

**The backlog may not live in this repo.** `{backlog.repo}` — absent or `null` means
`{repo}`, the common case — names the repo that actually holds the findings, for the
hub-and-spoke shape where one repo carries the record for a family of sibling repos. When it
is set, pass `--repo {backlog.repo}` to **every** `gh issue` call, read and write alike:

```bash
gh issue list   --repo {backlog.repo} --state open
gh issue create --repo {backlog.repo} --title "…" --body "…"
```

> **Establish reach first, or step 1 lies to you.** A `gh` call against a repo this identity
> cannot see returns **`404`, not `403`** — so an unreachable backlog reads as an *empty*
> one, and step 1's whole purpose is reading what's already decided. A retro that believes
> an empty list re-proposes everything the hub already rejected. Confirm reach before
> trusting the result:
> ```bash
> gh api repos/{backlog.repo} --jq .permissions
> ```
> No `pull` → **stop and report the identity** (`gh api user --jq .login`); do not run the
> retro against a backlog you could not read. Same failure class as `/way-of-working:resume`
> step 4's ruleset preflight, on a different surface.

`{backlog.repo}` is supported only with `kind: github_issues`. If it is set alongside
`kind: file`, that is a misconfiguration, not a cross-repo file — report it and take the
no-backlog branch rather than guessing a path. See `reference/project-schema.md`.

## When to run
- At the end of a working session, before `/way-of-working:handoff` or `/way-of-working:archive-sprint` (optional, never a gate).
- On demand — "look for improvements" / "review how that went."
- **NOT automatically every session.** Most sessions yield nothing worth recording, and
  auto-firing is itself friction.

## The signal bar (apply ruthlessly — this IS the value)
Surface a finding **only** if it **recurred** or **cost real time/rework** this session. A
one-off, or a "could be marginally nicer," is noise — drop it. The model for a good finding
is a backlog item written from something that actually went wrong live: concrete, caused by
a specific moment, worth the cost of recording.

Explicitly reject:
- **Speculative / hypothetical** improvements ("we could add X someday").
- **New personas/subagents** — the default answer is **no**. The catalog is already rich and
  every added agent adds friction; propose one only for a real, *repeated* task with no owner.
- Anything **already decided** — see step 1.

## Steps

1. **Read what's already decided FIRST — so you never re-propose it.** Skim the backlog
   index (per `{backlog.kind}` above), `{roadmap}`'s next-action line, the locked entries in
   `{decisions.log}`, and any standing memories. A "finding" that is already an open backlog
   item, an owner-deferred decision, a locked `{decisions.prefix}` entry, or a standing
   memory is **not** a finding — at most add a one-line "confirmed again (date/PR)" to the
   existing item if that adds signal. This is the anti-noise step; skipping it turns a retro
   into a re-litigation.

2. **Mine THIS session for friction.** Walk the actual exchange and list every point where a
   step cost more than it should have: a manual workaround, a re-diagnosis, a correction the
   human had to make, a thing done by hand that a skill already covers, a claim that
   overreached. Tie each to the **concrete moment**, not a general worry. Rank most-costly first.

3. **Filter through the signal bar.** Drop the one-offs and speculation. What survives is real.

4. **Route each survivor to its existing home — never a new standing doc:**
   - **Recurring workflow defect / infra idea** → a **backlog item** per `{backlog}` (or a
     "confirmed again" note on an existing one), in whatever shape that backlog already uses
     (found-live-during-X · why · shape · related).
   - **A how-I-should-work correction or a confirmed-good approach** → a **memory**
     (`feedback`/`user` type; include the why + how-to-apply). Update an existing memory
     rather than duplicate it, and add its index entry.
   - **A friction point in a plugin skill or agent** → this is an **upstream** fix, not a
     local one. Plugin skills cannot be partially overridden — a repo-local copy shadows the
     whole skill and silently stops receiving upstream fixes — so the resolution is a PR
     against the plugin's source repo: either a new schema key, or the skill leaving the
     plugin as not-portable. See `reference/project-schema.md` § *Overriding is a bug report*.
   - **A small mechanical fix** in *this* repo (a doc line, a local config) → **do it** on a
     branch → PR, if cheap and unambiguous; otherwise file it.
   - **A genuine judgment call for the owner** → **surface it, don't resolve it.**

5. **Implement the cheap; propose the rest.** Land the unambiguous mechanical fixes; present
   the judgment calls with a recommendation and let the owner pick. Report **where each
   finding was routed** (backlog item / memory / PR / deferred) — the git + PR + backlog
   history *is* the record; there is deliberately no retro log to maintain.

## Guardrails
- **Route, don't duplicate.** Every finding lands in the backlog, a memory, or a skill/doc
  edit — never a new standing document. If it fits no existing register, that is a signal it
  is noise.
- **Default answer to "new persona?" is no** (a real, repeated, ownerless task is the only yes).
- **Never resolve an owner-deferred decision** as a retro finding — re-surface at most.
- **Meta, not code/product.** Code diff → `/way-of-working:critic-gate`; prose-vs-code drift →
  `docs-consistency` subagent; product/infra defect → a backlog item. `/way-of-working:retro` is the working
  relationship and the session mechanics.
- **Less friction is the objective.** If a proposed "improvement" adds a step, a doc, or an
  agent without removing more than it adds, it fails its own test — drop it.
