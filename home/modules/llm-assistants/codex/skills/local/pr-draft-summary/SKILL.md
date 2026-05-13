---
name: pr-draft-summary
description: Create a PR-ready summary block, branch suggestion, title, and draft description after substantive code changes are finished. Trigger when wrapping up moderate-or-larger work touching runtime code, tests, build/test config, deployment config, or docs with behavior impact. Trigger on phrases like "wrap up the PR", "draft a PR", "summarize my changes for a PR", "what should the PR title be", "prep a PR description", or any handoff request immediately after substantive code changes.
---

# PR Draft Summary

Prepare a handoff that can be used directly for a pull request.

## Purpose

Produce a PR-ready block after substantive work is complete. The result should make it easy to create or edit a GitHub PR without re-reading the full diff.

## When to Trigger

- The task is finished or ready for review.
- The change touched runtime code, tests, examples, build/test configuration, deployment configuration, secrets wiring, or docs with behavior impact.
- Skip for trivial conversation-only work, repo-meta/doc-only work without behavior impact, or when the user explicitly says not to include a PR draft.

## Inputs to Collect Automatically

Do not ask the user for information that can be derived from git or the repository. Prefer the consolidated commands below over per-mode variants; the short status format already includes untracked files, and a single range diff covers both staged and unstaged changes when comparing against the base.

- Current branch: `git rev-parse --abbrev-ref HEAD`.
- Working tree and untracked files: `git status -sb`.
- Default branch: `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null || echo origin/main`. Avoids the slow network round-trip from `git remote show origin`.
- Base commit: `git merge-base <base-ref> HEAD`. Use `--fork-point` only when the local reflog is needed to disambiguate.
- Range against base: `git diff --stat <base>...HEAD` plus `git log --oneline --no-merges <base>..HEAD`. Together these subsume the four separate `git diff --name-only / --stat (--cached)` variants.
- Recent local context: `git log --oneline --decorate -n 8`. Reach for this only when the range above is empty (clean tree, draft-from-history mode).
- PR template:
  - `.github/pull_request_template.md`
  - `.github/PULL_REQUEST_TEMPLATE/*`

## Workflow

1. Run the collection commands above before drafting.
2. If there are no staged, unstaged, untracked, or ahead-of-base changes, say no code changes were detected and skip the PR block.
3. Classify the primary change type from the diff:
   - `feat`: new user-visible behavior, service, module, package, or workflow.
   - `fix`: bug fix, regression fix, broken config, or failed workflow repair.
   - `refactor`: structure change without intended behavior change.
   - `docs`: docs with behavior impact.
   - `chore`: dependency, lockfile, tooling, or maintenance work.
4. Identify the main touched area from changed paths.
   - Use a specific scope when obvious, such as `codex`, `claude-code`, `mcp`, `flake`, `home`, `nixos`, `darwin`, or a service name.
   - Omit the scope only when no meaningful single area exists.
5. Summarize the change in one to three short paragraphs.
   - Use the top changed paths and diff stats.
   - Include untracked files explicitly because diff stats do not include them.
   - If the working tree is clean but commits are ahead of base, summarize from commit messages and the range diff.
6. Suggest a branch name.
   - Keep the current branch if it is already descriptive and not `main`.
   - Otherwise propose `<type>/<short-kebab-topic>`.
7. Draft a Conventional Commit style title.
   - Use imperative mood.
   - Prefer the most specific scope changed.
8. Draft the PR body.
   - Match the repository's PR template when one exists.
   - Include summary, validation, and risks or notes.
   - Include issue closure only when an issue is clearly referenced by the user, branch name, commit history, or existing PR metadata.
9. Keep the draft honest.
   - Include only validation commands that actually ran.
   - State when validation was not run.
   - Do not mention local-only planning files.
   - Do not include generated-by attributions.

## Output

Use this structure unless a PR template requires a different body:

```markdown
# Pull Request Draft

## Branch name suggestion

git checkout -b <type>/<short-kebab-topic>

## Title

<type(scope): summary>

## Description

<PR body ready for gh pr create/edit>
```

Keep surrounding prose short. The PR block is the deliverable.
