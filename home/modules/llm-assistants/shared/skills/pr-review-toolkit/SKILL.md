---
name: pr-review-toolkit
description: >-
  Review pull requests, merge requests, branches, commit ranges, or uncommitted changes for bugs, regressions, security risks, error-handling gaps, missing tests, and maintainability issues. Use for code review requests or checking changes before merge.
---

# PR Review Toolkit

Find issues a maintainer would reasonably ask to fix before merge. Keep findings concrete and tied to the reviewed changes. Reviewing is read-only by default: report findings and fix directions without editing, unless the request explicitly includes fixing.

## Select the target

- **PR / MR number or URL:** use `gh pr view` / `gh pr diff` for GitHub or `glab mr view` / `glab mr diff` for GitLab. Read the request's source and target repository, branch, and head commit.
- **Current branch:** use its PR / MR target when available, otherwise the intended remote's default branch. Establish that remote from branch tracking and repository configuration. Do not assume it is `origin`.
- **Commit range:** review the specified range.
- **Uncommitted work:** inspect staged and unstaged diffs, keeping them separate when staging changes the interpretation.

For a local branch comparison, refresh the relevant remote refs and use `git merge-base` and `git diff <base>...HEAD`. Confirm that the checkout matches the requested head before relying on local files or test results. If fetching fails, state which revision was reviewed and the limit on freshness.

Ask when the target cannot be inferred from the request, hosting metadata, or Git state.

## Review the changes

Read repository instructions, the diff, and enough surrounding code to trace each changed contract through its callers. Compare with nearby conventions and check affected tests, configuration, schemas, deployment paths, and docs. Run targeted commands when they materially improve confidence.

Check these concerns where the diff makes them relevant:

- **Correctness and regressions:** broken assumptions, null / empty cases, paths, permissions, data shapes, concurrency, and resource lifecycles.
- **Error handling:** catch blocks that are empty or overly broad, errors swallowed or merely logged instead of propagated to a level that can act on them, fallbacks or default values that mask failures from callers, and missing or unhelpful user-facing error feedback.
- **Types and invariants:** concrete invalid states the changed API lets a caller create, and public construction or mutation paths that fail to preserve invariants the type requires.
- **Security and operations:** secret exposure, authorization boundaries, command execution, destructive behavior, deployment, and rollback.
- **Platform and build behavior:** language or framework evaluation rules, host gating, dependency changes, and configuration activation.
- **Validation:** missing behavioral coverage of new branches, edge cases, and error paths, tests pinned to implementation details rather than observable behavior, and required checks the change omits. Judge coverage against the changed behavior, not line counts, and do not demand exhaustive suites.
- **Comments and documentation:** comments and docs, added or untouched, that the changed behavior makes inaccurate, that reference removed behavior, or that restate the obvious in a way that will rot.
- **Maintainability and style:** naming, structure, formatting, wording, unnecessary complexity or redundant abstraction in the changed code, and consistency with established local patterns. Judge parameter and field ordering by semantic relationships and project conventions, with alphabetical order as a fallback. Style findings belong in the review when they have a concrete readability or maintenance cost.

Before reporting a finding, establish its trigger, affected behavior, and connection to the change. Check nearby guards and callers that might invalidate it. Separate pre-existing issues and unverified concerns from defects introduced by the diff.

## Split large reviews

Apply each concern in a single pass by default. Split only when the diff is too large for one careful pass or the request names distinct aspects, and delegate only genuinely independent aspects as parallel passes over the same target. The reviewer who delegates aggregates the results, holds delegated findings to the same evidence bar, and drops duplicates.

## Report findings

Use the repository's review format and severity scheme when specified. Otherwise, report findings first, ordered by impact, using the shared reviewer categories:

- **Critical:** bugs threatening core behavior, security, or data integrity.
- **Warning:** edge-case failures, missing error handling or meaningful coverage, and maintainability problems with a concrete cost.
- **Suggestion:** style inconsistencies and minor readability improvements.

Each finding needs a file and line reference, the triggering condition, the resulting failure or maintenance cost, and a fix direction when clear. Keep it short enough to paste into a PR / MR review comment. Avoid inflating severity or using generic requests to add tests.

After the findings, state any consequential assumptions, checks run, and unverified scenarios. If no issues were found, say so and identify the review's limits.
