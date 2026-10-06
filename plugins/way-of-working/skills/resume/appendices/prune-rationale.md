# Resume appendix — why the branch prune asks GitHub for the merged commit

Loaded on demand; the runnable block and its guards stay in `SKILL.md`'s *Prune squash-merged
local branches* step. This is the argument behind them.

   `-D` is safe only **per commit**, not per branch. Merged-ness is confirmed out-of-band,
   but a merged branch whose local tip has moved since the push still deletes without
   complaint — and a squash-merged branch's commits are unreachable, so that work is gone
   with no warning. So the candidate test asks GitHub *which commit it merged*
   (`headRefOid`, free in the call already being made), and the deletion happens only when
   the local tip **is** that commit or an **ancestor** of it. A tip *behind* the merged
   head — the PR picked up more commits after this checkout stopped — carries nothing the
   merge lacks, so `-D` loses nothing; `bin/prune-verdict.sh` fetches the oid by SHA when it is not already local (GitHub
   serves a merged PR's head by SHA after the branch is gone) and answers `delete`,
   `skip-ahead` (the tip has a commit the merged head lacks — the real stranded-work
   case), `skip-unfetchable` or `unreadable` (`#271`).

   **Do not substitute the obvious "is my tip pushed?" test** — `git rev-list --count
   origin/$b..$b`. It reads the remote-tracking ref, which stops resolving as soon as the
   head branch is deleted on the remote (the repo's `deleteBranchOnMerge` setting, the PR
   page's *Delete branch* button, or by hand) and the local ref is pruned. From then on the
   count command fails for that branch, and any fallback that fails safe skips it
   **permanently** — reporting stranded work that does not exist and implying a push that
   is no longer possible. How much of the prune that quietly disables is decided by a repo
   setting the test never consults: eventually everything, where branches are deleted on
   merge; one candidate per hand-deleted branch, where they are not. `headRefOid` does not
   depend on it — the PR record keeps the merged commit after the branch is gone.
