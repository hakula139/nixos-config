---
name: pr-review-toolkit
description: >-
  Review pull requests, merge requests, branches, commit ranges, or uncommitted changes for bugs, regressions, security risks, missing tests, and maintainability issues. Use for code review requests or checking changes before merge.
---

# PR Review Toolkit

Find issues a maintainer would reasonably ask to fix before merge. Keep findings concrete and tied to the reviewed changes. For a review-only request, report findings without editing.

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
- **Security and operations:** secret exposure, authorization boundaries, command execution, destructive behavior, deployment, and rollback.
- **Platform and build behavior:** language or framework evaluation rules, host gating, dependency changes, and configuration activation.
- **Validation:** missing scenarios, required checks, and tests that would still pass with a plausible bug.
- **Maintainability and style:** naming, structure, formatting, wording, and consistency with established local patterns. Judge parameter and field ordering by semantic relationships and project conventions, with alphabetical order as a fallback. Style findings belong in the review when they have a concrete readability or maintenance cost.

Before reporting a finding, establish its trigger, affected behavior, and connection to the change. Check nearby guards and callers that might invalidate it. Separate pre-existing issues and unverified concerns from defects introduced by the diff.

## Report findings

Use the repository's review format and severity scheme when specified. Otherwise, report findings first, ordered by impact, using the shared reviewer categories:

- **Critical:** bugs threatening core behavior, security, or data integrity.
- **Warning:** edge-case failures, missing error handling or meaningful coverage, and maintainability problems with a concrete cost.
- **Suggestion:** style inconsistencies and minor readability improvements.

Each finding needs a file and line reference, the triggering condition, the resulting failure or maintenance cost, and a fix direction when clear. Keep it short enough to paste into a PR / MR review comment. Avoid inflating severity or using generic requests to add tests.

After the findings, state any consequential assumptions, checks run, and unverified scenarios. If no issues were found, say so and identify the review's limits.
