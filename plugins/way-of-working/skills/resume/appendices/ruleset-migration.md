# Resume appendix — the default-branch half of the ruleset check

Loaded on demand from `SKILL.md`'s *Check the branch-protection ruleset for drift* step,
only when its `migration_base` read left `$MB_ERR` set, `$MB_ABSENT` set, or `$MB` non-empty.
Run the rules call below in the **same Bash call** as that read block — each call is a fresh
shell, and an empty `$MB`/`$MB_ERR` would read as "no migration". The read block itself stays in `SKILL.md`; this is its rationale, the default branch's rules
call and the report lines.

   **When a migration is live, also check the default branch.** `/way-of-working:architect-review`
   accepts a non-default PR base only because the **default branch's own** `.ai/project.yml`
   names it as `migration_base` (`reference/project-schema.md` § `repo`, `pr_base`,
   `migration_base`) — the base branch's own copy is the author's claim and can't vouch for
   itself. That trust holds only if the default branch itself cannot be written to directly,
   and nothing in the ruleset check itself (in `SKILL.md`) checks that.

   **The trigger is `migration_base` itself, read from the default branch, never `{pr_base}`
   differing from it.** A first draft of this check gated on `{pr_base} != <default>`, which
   misses the session that resumes **on the default branch** while a migration is still open:
   the schema keeps that branch's own `pr_base` equal to itself throughout ("hotfixes and the
   migration's landing merge stay ordinary PRs to it"), so `{pr_base}` never differs there even
   though `migration_base` is live and exactly as unprotected. Gating on `migration_base`
   catches both shapes with one read.

   **Read `migration_base` (and, below, the ci_gate check name) only from the default
   branch's own committed copy — never from this checkout's local `.ai/project.yml`.** A
   session resuming on the integration branch is, by the same logic as `migration_base`
   itself, reading a **potentially adversary-controlled** copy of that file: if this step
   asked *that* copy whether `{review.ci_gate}` is set, an attacker who can push the
   integration branch could blank it there and silently drop the `required_status_checks`
   half of the check below, on the one branch where it matters most. `bin/review-base-anchor.sh`
   already solves exactly this for `migration_base` (`git fetch` the default branch, `git show`
   its tree's `.ai/project.yml`, never the working tree's); reuse the same technique here
   rather than inventing a second one, and read the ci_gate check name from that same fetched
   copy for the same reason. Reset every value this block can set first — the same lesson
   `bin/review-base-anchor.sh`'s own header names for a stale value inherited from the calling
   shell's environment — and resolve the repo root explicitly rather than `cd`-ing there,
   since `git show <rev>:./path` resolves `.` against the **current directory**, not the repo
   root (the exact bug `review-base-anchor.sh`'s own header lists as found and fixed there;
   `-C "$TOPLEVEL"` gets the same correctness without changing this step's own cwd for
   whatever runs after it).

   **Resolve the repo from `origin`, not from `{repo}`, for this block specifically.** Naming
   `D` via `gh api repos/{repo} --jq .default_branch` would still let the same untrusted local
   copy decide *which branch* gets treated as "the default branch" — a `{repo}:` pointed at an
   attacker-controlled repo whose own default branch happens to share the integration branch's
   name would make this block dutifully fetch `refs/heads/<that name>` from the *real* `origin`
   (the fetch target is a name, not an identity) and read the integration branch's own copy
   right back, defeating the redesign above through a different door. `bin/review-base-anchor.sh`
   already avoids this by deriving the repo from the checkout's own `origin` remote
   (`git remote get-url origin` → `gh repo view`) rather than from any schema value — reuse
   that, and treat a mismatch against `{repo}` as a failure, not a tie-break in either value's
   favor (the read block does this):

(The read block those paragraphs describe is in `SKILL.md`, in the ruleset step.)

   `has("migration_base")` is what makes `MB_ABSENT` possible at all — WB-D17 (#142): a bare
   `.migration_base // ""` traversal cannot tell "declared `null`" from "the key isn't there"
   apart, since both print the literal string `null` (confirmed live, the same fact
   `bin/review-base-anchor.sh`'s own header now records for its identical read). `MB` still
   stays empty either way, so every step below that branches on `[ -n "$MB" ]` is **unchanged**
   — absent fails in the same safe direction null already did (the `gh api` rules call below
   still correctly does not fire); only the **report** gains the ability to say which one
   actually happened, instead of folding both into "no migration is live."
   This is a **different** reach than the `gh api` calls in `SKILL.md`'s ruleset check — local `git` access to
   `origin`, plus `gh repo view` against whatever `origin` names, not a GitHub-token
   permissions check on `{repo}` — so it is not "the same reach check reused"; say so if it
   fails rather than folding it into the `gh api` reach story in `SKILL.md`. A redirected `origin` in
   `.git/config` is a pre-existing, accepted residual (`docs/decisions.md` `WB-D13`) that needs
   local write access to set up in the first place — out of scope here, same as there.
   `$MB_ERR` is set explicitly at each stage that can fail — never inferred from the bare
   success/failure of whichever command happened to run last — which is what separates "the
   chain broke" from "yq legitimately answered empty", the same distinction the primary
   check's own `$RID` empty-after-success case draws. **A `{repo}` mismatch gets its own value,
   `MB_ERR=repo-mismatch`, rather than the bare `1` a network/git/yq failure sets** — the one
   failure here that may mean the local copy was tampered with, not merely unreachable, and
   worth naming as such in the report rather than folding into the same generic
   "inconclusive" every other failure gets. **`$R`, once the chain past its own check has
   succeeded, replaces `{repo}` for the rest of this block** — they're now known equal, but
   using the derived value throughout, rather than reverting to the literal token, keeps that
   guarantee legible instead of silently assumed again a few lines later.

   Only when `$MB` is non-empty **and the read block did not fail**, ask for the default branch's
   own rules — one read-only call, same GitHub-token reach as `rules/branches/{pr_base}`
   in `SKILL.md` — and thread the same failure tracking through it, since a `gh api` or `yq` failure
   here must read the same as one in the read block, never as "no migration":
   ```bash
   if [ -n "$MB_ERR" ]; then
     :   # the read block failed -- inconclusive below, never "no migration"
   elif [ -n "$MB" ]; then
     DB=$(gh api --paginate "repos/$R/rules/branches/$D") &&
     HAS_PR=$(printf '%s' "$DB" | jq 'any(.[]; .type=="pull_request")') &&
     APPROVALS=$(printf '%s' "$DB" | jq '[.[] | select(.type=="pull_request") | .parameters.required_approving_review_count] | max // 0') &&
     CHECK=$(printf '%s' "$DEF_YML" | yq -r '.review.ci_gate.check // ""') || MB_ERR=1
     if [ -z "$MB_ERR" ] && [ -n "$CHECK" ]; then
       HAS_CHECK=$(printf '%s' "$DB" | jq --arg c "$CHECK" \
         'any(.[]; .type=="required_status_checks"
               and any(.parameters.required_status_checks[]?; .context==$c))') || MB_ERR=1
     fi
   fi
   ```
   `max`, not `first`: when more than one ruleset applies, GitHub enforces the strictest
   `pull_request` rule, and `first` would report whichever the API happened to list first —
   under-reporting the true requirement is the safe direction (a false alarm, never false
   comfort), but `max` reports the actual answer instead of a coin flip that merely fails
   safe.
   `$CHECK` is bound with `jq --arg`, the same as `{ruleset.name}` in `SKILL.md`'s ruleset check — never interpolated
   into the filter string, and never the literal `{review.ci_gate.check}` token spliced in
   directly, since (per the read-block paragraphs earlier in this file) its value came from a variable, not a
   compile-time schema constant. **The report below must key off `$CHECK`/`$HAS_CHECK` for the
   same reason it must not be interpolated: branching the *report* on the local `{review.ci_gate}`
   token, even only to pick a message, reopens the exact trust inversion this redesign exists
   to close — an attacker who blanks `review.ci_gate` on the branch being resumed from would
   make the report silently take the "no ci_gate configured" case even when the trusted
   default-branch copy requires one and this check found it missing.**

   This runs **independently** of the ruleset lookup in `SKILL.md` — it does not depend on `$RID` or `$B`, and,
   **once the reach check has passed**, fires whenever `$MB` is non-empty regardless of
   whether that lookup came back healthy, weakened, or inconclusive. (If the reach check
   itself failed, this whole *Check the branch-protection ruleset for drift* step already
   stopped per the reach paragraph in `SKILL.md` — this check never runs either, and both fold into that
   same "could not run" line; "independent of the ruleset lookup"
   means independent of its *ruleset-lookup* outcome, never a license to run past a failed
   reach check.) It has to run independent of that outcome: it does not need the default
   branch's rule to come from `{ruleset.name}` specifically, only that *some* ruleset there
   requires it, so a repo whose `{ruleset.rule_types}` doesn't happen to list `pull_request`
   would otherwise read "healthy" in `SKILL.md` while `migration_base` stayed exposed. For the same
   reason it asks for generic GitHub rule types only — `pull_request`,
   `required_status_checks` — never a repo-specific ruleset name, so `coupling-check.sh` stays
   clean either way.

   **State plainly what this does and does not establish** — "requires `pull_request`" is
   narrower than "cannot be written to directly", and overclaiming the second from the first
   is its own defect: a rule with `required_approving_review_count: 0` still lets anyone with
   push access open and self-merge a PR that rewrites `migration_base`, gaining an audit trail
   but no actual review, and this check cannot see a ruleset's bypass actors (an "always"
   admin/role/app bypass on an otherwise-correct rule) at all. Report `$APPROVALS` alongside
   `pull_request` rather than treating the bare presence of the rule type as the whole answer.
   Like the ruleset lookup in `SKILL.md`, this one also sees **rulesets only** — classic (non-ruleset) branch
   protection on the default branch would read as "does NOT require pull_request," which is
   the safe direction (a false alarm, not false comfort) but still worth naming so a reader
   knows which kind of gap they're looking at.

   Fold the result into the ruleset check's **same single line** in `SKILL.md`, never a second one — and
   whenever `$MB` is non-empty, that line must say something about the default branch, so a
   bare `Ruleset check: healthy ({N} rule types, {M} required checks).` with nothing else can
   only mean "no migration is live," never "migration live, default-branch half silently
   skipped":
   Every branch below keys on `$MB`/`$MB_ERR`/`$HAS_PR`/`$CHECK`/`$HAS_CHECK` — the values
   this block itself just derived from the *default branch's* trusted copy — **never** on the
   local `{review.ci_gate}` token, and the printed check name is `$CHECK` (the real value),
   never the literal text `{review.ci_gate.check}`:
   - `$MB_ERR` set → **inconclusive**, same as the ruleset lookup's own inconclusive case, folded
     onto the same line rather than a second one — never silently treated as "no migration."
   - `$MB_ABSENT` set, no error — `migration_base` is entirely missing from the default
     branch's own `.ai/project.yml` (`WB-D17`, `#142`: absent is an unanswered question,
     never silently read as "no migration is under way") → impossible to miss, distinct from
     the next bullet: `...; migration_base is absent from the default branch's own
     .ai/project.yml (not declared null) — /way-of-working:resume there, or a completion PR
     to that branch, is what resolves it.`
   - `$MB` empty, `$MB_ABSENT` unset, no error (`migration_base` present and declared `null` —
     the common, non-migration case) → say nothing extra; nothing to check.
   - `$MB` non-empty, no error, `$HAS_PR` false → impossible to miss, whatever `$CHECK` is:
     `...; migration_base (default branch) can be written with NO pull_request required.`
   - `$MB` non-empty, no error, `$HAS_PR` true, `$CHECK` empty (no ci_gate configured on the
     *default branch's* copy — not the local one) → `...; migration_base (default branch)
     requires pull_request ($APPROVALS approvals) — no ci_gate configured there to also
     require.`
   - `$MB` non-empty, no error, `$HAS_PR` true, `$CHECK` non-empty, `$HAS_CHECK` true → `...;
     migration_base (default branch) requires pull_request ($APPROVALS approvals) + $CHECK.`
   - `$MB` non-empty, no error, `$HAS_PR` true, `$CHECK` non-empty, `$HAS_CHECK` false → `...;
     migration_base (default branch) requires pull_request ($APPROVALS approvals) but not
     $CHECK — a change there ships without that review.`

   This is a report, not a gate — never block or fail the session on its result.
