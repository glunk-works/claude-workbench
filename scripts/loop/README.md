# scripts/loop

Host tooling for the orchestrator loop (`WB-D23`). Never on an adopter's `PATH`, outside the
coupling gate. See `docs/proposals/orchestrator-m2-decisions.md` for what each piece is for.

## baseline.sh: the PR-flow baseline

Read-only. Derives work PRs, cursor PRs per work PR, median open-to-merge, the likely-dependent
share, wave overlap and an open-to-merge time per work PR for one repo from its merged-PR
history on GitHub. The method is in the script's header. `open_to_merge_min_per_work_pr` is
wait-to-merge time, not keyboard time (GitHub does not record attention), and it is **not** the
M2b exit metric: that needs a different source. The dependent and overlap shares print `n/a`
under 21 work PRs.

```
bash scripts/loop/baseline.sh <owner/repo> [--days 60] [--until YYYY-MM-DD]
```

Pass `--until` to reproduce an earlier run; the window is the merged PRs in the `--days` days
ending on the `--until` day, that day included. Tests: `sh tests/loop-baseline.test.sh`.

### Adoption step: run it before enabling the loop on a repo

1. Run `baseline.sh` against the repo and read the numbers. Do this **before** the first
   dispatch: afterwards the loop's own PRs are in the history and the "before" is gone.
2. If cursor_prs_per_work_pr is high (the brief saw 1.3 in devcontainers, where cursor PRs were 57% of merges), check that the repo
   has adopted the plugin version that addresses it (v0.17.0's no-op handoff); otherwise the baseline is not a valid
   "before".
3. Add one line to the table below: the repo, the date the loop was enabled and the window the
   baseline used (`--days`, `--until`). **Never record the numbers.** They are re-derivable
   from that window, as long as it still falls inside the newest 1000 merged PRs (the script warns when it hits that limit).

| Repo | Loop enabled | Baseline window |
|---|---|---|
