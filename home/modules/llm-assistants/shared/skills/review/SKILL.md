---
name: review
description: >-
  Review a repository, pull or merge requests, branches, commit ranges, or local changes from first
  principles for correctness, conventions, design, tests, documentation, and security. Use for code
  review and audit requests, including requests to fix the findings or merge the reviewed PRs / MRs.
---

# Review

Find every issue a careful maintainer would want fixed, and support each finding with evidence. Reviews are read-only unless the request also asks for fixes or a merge, as [Choose the mode](#choose-the-mode) explains.

## Select the target

Infer the target from the request and conversation. Ask only if it remains ambiguous:

- **Nothing named:** Review the work at the center of the conversation, such as a PR / MR or changes it just produced. Otherwise, review the current branch's open PR / MR or, if there is none, the entire repository at the checked-out revision, including uncommitted and untracked files.
- **PR / MR number or URL:** Review its metadata and diff using `gh pr view` / `gh pr diff` or `glab mr view` / `glab mr diff`, including the source and target repositories, branches, and head commit.
- **Branch:** Review its open PR / MR, if one exists. Otherwise, compare it with the intended remote's default branch, identified from branch tracking and repository configuration without assuming `origin`.
- **All open PRs / MRs:** Review each one separately.
- **Commit range or uncommitted work:** Review the specified range or the staged, unstaged, and untracked changes. Keep those change groups separate when staging affects their meaning.

For a branch comparison, refresh the relevant remote refs, then use `git merge-base` and `git diff <base>...HEAD`. When other agents share the ref store, skip the refresh, since a fetch moves `origin/*` under every agent, and instead pin the PR / MR head SHA and read files through `git show <sha>:<path>`. If tools must run against a PR / MR head that differs from the checkout, use a separate worktree and leave the current one untouched. If fetching fails, state which revision you reviewed.

## Load the instructions

Apply the global instructions, the repository's `AGENTS.md` / `CLAUDE.md` files, including nested files for touched paths, and every convention document they reference for the affected areas. Treat project review sections, such as a `## Code Review` checklist, as additional criteria. Repository rules for review format and severity take precedence over this skill's defaults.

## Review each dimension

A whole-repository review covers existing code and design, so challenge choices that a better design could replace. A diff review also covers the code around the change: read each touched file in full, review its callers, siblings, and touched modules for defects, and propose more concise or elegant designs there even when one takes a large refactor. Trace every changed contract through its callers, tests, configuration, and documentation. For DRY, consistency, and integration checks, include sibling repositories the project integrates with, such as downstream consumers checked out nearby.

- **Correctness and edge cases:** broken assumptions, empty or boundary inputs, paths, permissions, data shapes, concurrency, and resource lifecycles.
- **Error handling:** swallowed or merely logged errors, overly broad catches, fallbacks that hide failures, and unhelpful messages.
- **Types, invariants, and API surface:** invalid states the API permits, construction paths that bypass invariants, and visibility broader than callers need.
- **Conventions:** every rule in the loaded instructions, checked against the complete changed construct.
- **Simplicity:** unnecessary abstractions, speculative configurability, dead code, and logic with a shorter idiomatic form.
- **DRY:** logic duplicated across modules or related repositories that an extraction would remove.
- **Cross-file consistency:** parallel types, files, and modules that differ in structure, naming, ordering, or derived traits.
- **Ordering and grouping:** the order of fields, parameters, match arms, imports, tests, sections, and documentation bullets, and their blank-line grouping, judged by semantic relationships and project conventions with alphabetical order as the fallback. Reviews often miss this, so check every changed group explicitly.
- **Comments and prose:** comments, docstrings, and documentation that restate code, narrate history, exceed the constraint they explain, have gone stale, or break the writing rules.
- **Idioms and existing primitives:** non-idiomatic language or standard library use, and handwritten logic that a dependency, framework primitive, or established library already provides.
- **Tests and coverage:** missing behavioral coverage of new branches and error paths, assertions that would pass despite a plausible bug, and real personal data in fixtures. Run the project's coverage tool on the changed lines, such as `cargo llvm-cov`, read the PR's Codecov comment if any, and list each uncovered changed line with its reason.
- **Documentation:** README feature lists, roadmaps, layout trees, and usage instructions the target makes inaccurate, and user-facing docs that include implementation detail or outgrow their sibling entries.
- **Security and secrets:** secret exposure, authorization boundaries, injection from untrusted input, and destructive behavior.
- **Dependencies, CI, release, and deployment:** dependency downgrades, dropped build outputs, and versions or pins that drift between packages and downstream consumers. Exercise the affected build, packaging, and publish paths without relying on stubbed tests. For a deployed site, check the preview deployment before merge and production after it.

Then reread the target from these perspectives:

- **Removed behavior:** For each deleted or moved line, name the invariant it upheld and identify what upholds it now.
- **Consumers across boundaries:** For each new or changed type, variant, message, flag, or default, find every consumer, including dispatch points outside the diff that might silently drop it.
- **History:** Check `git log` and `git blame` for touched lines, along with earlier review comments on the same files, to identify constraints the change might break.
- **Altitude:** Check whether a fix addresses the root cause at the right depth or only patches a symptom. Flag workarounds that get checks passing: skipped, ignored, or platform-gated tests that could be made hermetic, retries or sleeps, suppressions that hide real problems (`|| true`, `continue-on-error`, ignore and allowlist entries), and special cases for specific commits or data. Name the root cause and the fix at the layer that owns it.

## Fan out and verify

Review a small target in one pass. For a whole repository, a large diff, or several PRs, delegate dimension groups to parallel `reviewer` agents, which load this skill themselves, and split large diffs further by file locality while keeping tests with their implementation. Add a `usability-reviewer` for user-facing surfaces such as CLI help, error messages, and documentation, then map its categories to severity levels when aggregating findings. Each brief should name the target and revision, the dimensions to review, and any command results the reviewer needs. Reviewer roles may lack a shell, so run coverage, builds, and other commands yourself.

A delegated reviewer covers only the scope in its brief, does not delegate further, edit files other than a report file named in its brief, or run mutating commands, and returns findings as text in the [report](#report) format.

Verify each candidate finding before reporting it. Reproduce its trigger or trace it to quoted lines, check guards and callers that could invalidate it, and confirm platform behavior from documentation or source. Mark it **confirmed** if you demonstrate the trigger, or **plausible** if it depends on a realistic state you cannot fully construct. Drop it if the code provably prevents the trigger. An impact claim about other code must name that code, and a convention finding must quote both the rule and the violating line. Once findings are verified, make a fresh pass for defects the list missed, such as moved code that lost a guard, a flipped default, or setup without matching teardown.

These are not findings:

- Issues reported by the project's formatter, linter, or type checker.
- The contents of generated, vendored, lock, and minified files beyond what their changes imply, such as a dependency downgrade.
- Patterns whose documented rationale in code, commits, or the PR discussion still applies, such as generated-file ignores or deliberate license exceptions. A stated reason does not exempt a workaround whose root cause can be fixed.
- Security issues with no reachable untrusted input.
- Personal preferences without a documented convention or established pattern behind them.

If the repository ignores the plans directory `.agents/plans/`, save the review briefs and verified findings there so they survive context compaction.

## Classify findings

Each finding needs a `file:line` reference, the triggering condition, the resulting failure or maintenance cost, a suggested fix, and its verification mark. Use the repository's severity scheme if it has one. Otherwise, use:

- **Critical:** Bugs that break core behavior, builds, or deployment, as well as security vulnerabilities and data loss.
- **Warning:** Edge-case failures with a named trigger, missing error handling or behavioral coverage, and maintainability problems with a concrete cost.
- **Suggestion:** Issues with conventions, consistency, ordering, or readability.

When in doubt, choose the lower severity. Avoid generic requests to add tests.

## Choose the mode

- **Review (default):** Report findings without editing files, committing, or posting comments. Post PR / MR comments only when asked.
- **Fix:** Resolve every verified finding in the same round, including Suggestions and pre-existing issues, such as those in the code around a diff. Do not defer any to follow-up PRs or TODOs. Fix findings specific to a PR on its branch, and put pre-existing issues and repository-review fixes in scoped PRs / MRs. Resolve design questions from first principles and record each decision with its rationale in the PR / MR description. Rerun checks and review the fixed areas until no findings remain, then commit and publish through `git-workflow`.
- **Merge:** Once no findings remain, merge each reviewed PR / MR through `git-workflow`, which hands the merge to the `operator` agent when one is available, quoting the user's review-and-merge request verbatim as the approval. Then update pins or submodules that track the merged commit, and clean up as the `git-workflow` skill's Cleanup section describes.

## Report

For the top-level review, use the host's findings-report tool when available, such as Claude Code's `ReportFindings`. Otherwise, start with the reviewed revision and scope, a merge-readiness verdict, and finding counts by severity. Then list findings by severity and impact, grouping pre-existing issues separately. When Critical and Warning findings already make the report long, summarize Suggestions as a count with one-line bullets.

Write each finding as one short, matter-of-fact paragraph. State the triggering scenario first so the author can grasp the issue at a glance, and quote no more than three lines of code. Anchor any posted inline comment to the shortest diff range that shows the problem.

Close with the checks you ran and their results, including changed-line coverage, consequential assumptions, anything left unverified, and any area the review did not cover. If there are no findings, say so. In fix and merge modes, also report the fixes, final checks, PR / MR states, and any actions only the user can take.
