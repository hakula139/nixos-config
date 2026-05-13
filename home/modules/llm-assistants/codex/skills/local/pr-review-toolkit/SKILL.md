---
name: pr-review-toolkit
description: Perform a rigorous PR or pre-commit code review. Trigger for review requests, PR review, checking a branch before merge, finding bugs in a diff, or reviewing style consistency and maintainability.
---

# PR Review Toolkit

Review like a blocking code reviewer. Prioritize correctness, security, regressions, missing tests, operational risk, and style nits that affect maintainability or consistency.

## Purpose

Find issues a maintainer would reasonably ask to fix before merge. Be skeptical, concrete, and diff-focused.

## Review Target

Determine the target from the user's request:

- PR number or URL: inspect with `gh pr view` and `gh pr diff`.
- Current branch: compare with the default branch merge base.
- Commit range: review the specified range.
- Uncommitted work: review staged and unstaged diffs separately when that affects interpretation.

If the target is ambiguous and cannot be inferred from git state, ask one concise question.

## Context to Gather

Use the minimum context needed to make defensible findings.

- Changed files and stats:
  - `git status -sb`
  - `git diff --stat`
  - `git diff --cached --stat`
- Base comparison when reviewing a branch:
  - default branch from `git remote show origin`
  - merge base with `git merge-base`
  - `git diff --stat <base>...HEAD`
- File context:
  - changed functions and neighboring call sites
  - tests near the changed behavior
  - config, schema, deployment, and migration paths touched by the diff
- Existing conventions:
  - nearby code style
  - repository instructions
  - formatting/lint config
  - naming and module boundary patterns

## Workflow

1. Identify the review target.
   - For a PR number or URL, use `gh pr view` and `gh pr diff`.
   - For the current branch, compare against the default branch merge base.
   - For uncommitted work, review staged and unstaged diffs separately when that changes the conclusion.
2. Gather enough context.
   - Read the changed files and nearby call sites.
   - Check tests, schemas, config, deployment paths, and docs when the diff touches their contracts.
   - Run targeted commands only when they materially improve confidence.
3. Check correctness and regression risk.
   - Broken assumptions, null/empty cases, path handling, permissions, data shape changes, race conditions, and lifecycle ordering.
   - Nix-specific risks such as evaluation scope, store path visibility, activation behavior, platform gating, secret path ownership, and flake input drift.
4. Check security and operational risk.
   - Secret exposure, auth scope changes, network-facing behavior, command execution, filesystem writes, and destructive operations.
   - Deployment and rollback implications.
5. Check tests and validation.
   - Missing coverage for changed behavior.
   - Validation commands that should have been run.
   - Tests that would pass even if the implementation were wrong.
6. Check maintainability and style.
   - Style nits are in scope.
   - Flag naming, structure, formatting, wording, and local convention mismatches when they affect readability, consistency, or future maintenance.
   - Keep style feedback lower severity unless it creates real confusion or violates an explicit standard.
7. Produce findings first.
   - Order by severity.
   - Include file and line references.
   - Explain the concrete failure mode and why it is introduced by this change.
   - Keep each finding short enough to paste into a PR review comment.
8. Call out test gaps.
   - Name the missing scenario.
   - Avoid generic "add more tests" advice.
9. If no issues are found, say that clearly and state residual risk.

## Severity Guide

Match the repo's existing reviewer agent severity scheme so findings translate cleanly across tools.

- `Critical`: breaks core functionality, data integrity, security, deployment, or introduces a likely user-visible regression. Includes secret or auth risk and failing required workflows.
- `Warning`: maintainability problem, edge case, missing targeted test, confusing API, or important style consistency issue.
- `Suggestion`: minor nit worth fixing but not merge-blocking.

Do not inflate severity. A style nit is normally `Suggestion`.

## Output

Use the code review format:

```markdown
Findings:
<findings ordered by severity, or "No findings.">

Open questions or assumptions:
<only if needed>

Test gaps or residual risk:
<short list or "None identified">
```

Each finding should include:

- Severity.
- File and line reference.
- Concrete failure mode or maintenance cost.
- Suggested fix when the fix is clear.
