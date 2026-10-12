---
name: review
description: >-
  Review a repository, pull or merge requests, branches, commit ranges, or local changes from first
  principles for correctness, conventions, design, tests, documentation, and security. Use for code
  review and audit requests, including requests to fix the findings or merge the reviewed PRs / MRs.
---

# Review

Find every issue a careful maintainer would want fixed, and support each finding with evidence. Reviews are read-only unless the request also asks you to fix findings or merge, as described under [Choose the mode](#choose-the-mode).

## Select the target

Infer the target from the request and conversation context. Ask only if they leave it genuinely ambiguous:

- **Nothing named:** Review the work at the center of the conversation, such as a PR / MR or changes it just produced. Without that context, review the current branch's open PR / MR, or, if there is none, the whole repository at the checked-out revision, including uncommitted and untracked files.
- **PR / MR number or URL:** Read its metadata and diff with `gh pr view` / `gh pr diff` or `glab mr view` / `glab mr diff`. Include the source and target repositories, branches, and head commit.
- **Branch:** Review its open PR / MR, if one exists. Otherwise, compare it with the intended remote's default branch, identified from branch tracking and repository configuration without assuming `origin`.
- **All open PRs / MRs:** List them and review each separately.
- **Commit range or uncommitted work:** Review the range, or the staged, unstaged, and untracked changes. Keep staged and unstaged changes separate when staging affects how they should be interpreted.

For a branch comparison, refresh the relevant remote refs, then use `git merge-base` and `git diff <base>...HEAD`. If tools must run against a PR / MR head that differs from the current checkout, use a separate worktree and leave the current one untouched. If fetching fails, state which revision you reviewed.

## Load the instructions

Apply the global instructions, the repository's `AGENTS.md` / `CLAUDE.md` files, including nested files for touched paths, and every convention document they reference for the affected areas. Treat project review sections, such as a `## Code Review` checklist, as additional criteria. Repository rules for review format and severity take precedence over this skill's defaults.

## Review each dimension

For a whole-repository review, existing code and design choices are in scope, so challenge any that a better design could replace. For a diff review, read each full touched file, since defects in unchanged lines of a touched function are in scope. Trace every changed contract through its callers, tests, configuration, and documentation. When checking DRY, consistency, and integration, include sibling repositories the project integrates with, such as downstream consumers checked out nearby.

- **Correctness and edge cases:** broken assumptions, empty or boundary inputs, paths, permissions, data shapes, concurrency, and resource lifecycles.
- **Error handling:** swallowed or merely logged errors, overly broad catches, fallbacks that hide failures, and unhelpful error messages.
- **Types, invariants, and API surface:** invalid states the API permits, construction paths that bypass invariants, and visibility broader than callers need.
- **Conventions:** every rule in the loaded instructions, checked against the complete changed construct.
- **Simplicity:** unnecessary abstractions, speculative configurability, dead code, workarounds that leave the root cause in place, and logic better expressed in a shorter idiomatic form.
- **DRY:** duplicated logic across modules or related repositories, and extractions that remove it.
- **Cross-file consistency:** parallel types, files, and modules that differ in structure, naming, ordering, or derived traits.
- **Ordering and grouping:** the order of fields, parameters, match arms, imports, tests, sections, and documentation bullets, plus blank-line grouping. Judge each by semantic relationships and project conventions, using alphabetical order when no stronger basis applies. Reviews often miss this dimension, so check every changed group explicitly.
- **Comments and prose:** comments, docstrings, and documentation that restate code, narrate history, exceed the constraint they explain, have gone stale, or break the writing rules.
- **Idioms and existing primitives:** non-idiomatic language or standard library use, and handwritten logic already provided by a dependency, framework primitive, or established library.
- **Tests and coverage:** missing behavioral coverage for new branches and error paths, assertions that would pass despite a plausible bug, and real personal data in fixtures. Run the project's coverage tool on the changed lines, such as `cargo llvm-cov`, read the PR's Codecov comment if one exists, and list each uncovered changed line with its reason.
- **Documentation:** README feature lists, roadmaps, layout trees, and usage instructions made inaccurate by the target, and user-facing docs that include implementation detail or outgrow their sibling entries.
- **Security and secrets:** secret exposure, authorization boundaries, injection from untrusted input, and destructive behavior.
- **Dependencies, CI, release, and deployment:** dependency downgrades, dropped build outputs, and versions or pins that drift between packages and downstream consumers. Exercise the build, packaging, and publish paths the target affects without relying on stubbed tests. For a deployed site, check the preview deployment before merge and production after it.

Read the target from these angles to surface defects a linear read may miss:

- **Removed behavior:** For every deleted or moved line, name the invariant it upheld and identify what upholds it now.
- **Consumers across boundaries:** For each new or changed type, variant, message, flag, or default, find every consumer, including dispatch points outside the diff that might silently drop it.
- **History:** Check `git log` and `git blame` on touched lines, and earlier review comments on the same files, for constraints the change might break.
- **Altitude:** Check whether a fix addresses the root cause at the right depth or only patches a symptom.

## Fan out and verify

Review a small target in one pass. For a whole repository, large diff, or several PRs, fan out parallel agents by dimension group. Split large diffs further by file locality, keeping tests with their implementation. Use the `reviewer` role for these audits, which loads this skill itself, and add `usability-reviewer` for user-facing surfaces such as CLI help, error messages, and documentation. When aggregating, map the usability reviewer's categories to severity levels. Each brief should name the target and revision, its dimensions, and any command results the reviewer needs. Reviewer roles may lack a shell, so run coverage, builds, and other commands yourself.

A delegated reviewer covers only the scope in its brief. It does not fan out, edit files, or run mutating commands, and returns findings as text in the [report](#report) format.

Verify every candidate finding before reporting it. Reproduce its trigger or trace it to quoted lines, check guards and callers that could invalidate it, and confirm platform behavior from documentation or source. Mark a finding **confirmed** when you demonstrate the trigger, or **plausible** when it depends on a realistic state you cannot fully construct. Drop it if the code provably prevents the trigger. Any impact claim about other code must name the affected code, and any convention finding must quote the rule and the violating line. After verification, make one fresh pass for defects missing from the list, such as moved code that lost a guard, a flipped default, or setup without matching teardown.

These are not findings:

- Issues reported by the project's formatter, linter, or type checker.
- The contents of generated, vendored, lock, and minified files beyond what their changes imply, such as a dependency downgrade.
- Patterns whose documented rationale in code, commits, or the PR discussion still holds.
- Security issues with no reachable untrusted input.
- Personal preferences without a documented convention or established pattern behind them.

If the repository ignores the plans directory `.agents/plans/`, save the review briefs and verified findings there so they survive context compaction.

## Classify findings

Each finding needs a `file:line` reference, the triggering condition, the resulting failure or maintenance cost, a fix direction, and its verification mark. Follow the repository's severity scheme, if it defines one. Otherwise:

- **Critical:** Bugs that break core behavior, builds, or deployment, as well as security vulnerabilities and data loss.
- **Warning:** Edge-case failures with a named trigger, missing error handling or behavioral coverage, and maintainability problems with a concrete cost.
- **Suggestion:** Convention, consistency, ordering, and readability issues.

When in doubt, choose the lower severity. Avoid generic requests to add tests.

## Choose the mode

- **Review (default):** Report findings without editing files, committing, or posting comments. Post PR / MR comments only when asked.
- **Fix:** If asked to fix findings, resolve every verified finding in the same round, including Suggestions and pre-existing issues. Do not defer any to follow-up PRs or TODOs. Fix a PR's own findings on its branch, and put pre-existing issues and repository-review fixes in scoped PRs / MRs. Resolve design questions from first principles, and record each decision and its rationale in the PR / MR description. Rerun the checks and review the fixed areas until no findings remain. Commit and publish through `git-workflow`.
- **Merge:** If asked to merge, merge each reviewed PR / MR once no findings remain, through `git-workflow`. Then update pins or submodules that track the merged commit, and remove merged branches and worktrees with `clean-gone`.

## Report

When the host provides a findings-report tool for the top-level review, such as Claude Code's `ReportFindings`, use it as instructed. Otherwise, start with the reviewed revision and scope, a verdict on whether the target is ready to merge, and finding counts by severity. Then list findings by severity, ordered by impact within each group, with pre-existing issues in their own group.

Write each finding as one short paragraph. State the triggering scenario first, quote at most three lines of code, and make the note matter-of-fact and easy for the author to grasp at a glance. Anchor a posted inline comment to the shortest line range in the diff that shows the problem.

After the findings, state which checks you ran and their results, including changed-line coverage, consequential assumptions, and anything that remains unverified. If you found no issues, say so and state the review's limits. In fix and merge modes, report the fixes, final checks, PR / MR states, and any actions only the user can take.
