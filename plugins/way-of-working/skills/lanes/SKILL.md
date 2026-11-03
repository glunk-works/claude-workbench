---
name: lanes
description: >-
  Start, report on and clean up coder lanes from the repo's own container, through the plugin's
  bin/lane.sh: start preps a worktree and a prompt file for one task and prints the host command,
  status prints one table of the live lanes, clean up removes a merged lane and says what the freed
  lane can take. Run from the main worktree by the driver session. Never drafts specs, plans or
  approves, never starts a session, never merges.
---

# /way-of-working:lanes — start, report on and clean up coder lanes

A lane is a second Claude session building one task in a worktree under `{lanes.dir}`. This
skill is the driver's front for `lane.sh`, the plugin's script: each mode below is **one call** to
it, run from the main worktree, and its output is printed as the script gives it. The skill reads no
project file itself; a repo with no `lanes` declared stops on the script's `no-lanes`.

`lane.sh` runs only from the installed plugin (it finds its sibling scripts beside itself), so call
it by name on `PATH`, never as a copy by path. If `lane.sh` is not found, the installed plugin
predates it: say so and stop.

## start `N M BRANCH CRITICS [ALSO]`

`N` is the task issue, `M` the milestone the driver expects it on, `BRANCH` is `TYPE/SLUG` and
`CRITICS` a comma list of `architect`, `security-critic` and `docs-consistency`. `ALSO`, when
given, is the comma list of issues folded into `N`, each checked open and on `M`, which the prompt
tells the lane its PR closes too.

1. Run `lane.sh prep N M BRANCH CRITICS [ALSO]`. A stop word it prints (`not-main`, `no-lanes`,
   `unsafe-dir`, `unreadable`, `repo-mismatch`, `unreached`, `not-map`, `finder: WORD`,
   `bad-issue`, `exists`, `failed`) is the answer: print it and stop.
2. On success it prints `worktree=`, `branch=`, `found=`, `milestone=`, `prompt=` and
   `prompt-sha256=`. Print them, then the host command with `N` and the hash filled in, and the two
   clone paths left for the maintainer:
   ```powershell
   pwsh -File $env:WOW_HOME\bin\wow-lane.ps1 -Clone <clone> -Reference <other clone> -Issue N -Hash <prompt-sha256>
   ```
3. Say that the spec pin, the mode and the critics (and, when `ALSO` is given, the closes line) are in
   the prompt file.

## status

Run `lane.sh status` and show its rows as one table: repo, task, branch, PR, checks, spec. It
prints `none` for no lanes. Checks is a display-only summary of the PR's whole rollup; for a merge
verdict point at `/way-of-working:pr-checks`.

## clean up `N`

Only after the maintainer says the lane session has exited. Run `lane.sh done N` and print its
lines. The `next` lines are what the freed lane can take; `next none` and `next unreadable` are
printed as they are.

## What this skill never does

It never drafts a spec, plans or approves (`/way-of-working:spec-task`,
`/way-of-working:plan-sprint` and the maintainer on GitHub do), never starts a session, never
merges, approves or force-pushes, and never writes under `.ai/`. It names no repo-specific value.
