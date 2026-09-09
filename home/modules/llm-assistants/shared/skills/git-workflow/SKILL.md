---
name: git-workflow
description: Prepare commits, draft or create and update pull requests or merge requests, push branches, and merge approved requests. Use when completing a logical implementation chunk or performing Git ref creation and publication tasks, including PR titles and descriptions. Skip read-only Git inspection and code review.
---

# Git Workflow

Read the repository's contribution instructions before changing Git state or preparing publication. Use its existing tooling for worktrees, rebases, and merges when relevant.

## Authorization

- **Do not create refs unless asked.** Branches, tags, and backup refs outlive the task. Keep the assigned branch unless creating another ref is authorized. Tool permissions alone do not provide that authorization.
- **Wait for explicit per-PR approval before merging.** Earlier blanket approvals do not extend to PRs opened later in the session. After publishing, report the URL and wait for `lgtm` or `merge` referencing that specific PR.

## Commits

- **Commit at the seam.** Commit each logical chunk once its relevant checks pass, before moving on.
- Verify the current branch and inspect the diff before staging. Stage only the intended files or hunks.
- Make each commit one logical change. Use `type(scope): description` in the imperative mood. Types are `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, and `perf`. Infer the scope from the affected component, file, or host and comparable commit history. Follow established naming and granularity.
- For substantial changes, include a body explaining the problem, rationale, and relevant tradeoffs or validation. Keep it proportional to the change and avoid repeating the subject. A subject alone is sufficient for small, self-explanatory changes.
- Branch names use `<type>/<short-name>`, with the same type set. Keep an appropriate existing branch.

## Pull / Merge Requests

### Repository conventions

- Read the PR / MR template, then inspect recent comparable human-authored requests for title, body structure, assignees, and labels. Follow explicit repository rules where examples differ. Broaden the sample when recent examples do not cover the change.
- Infer assignees from comparable human-authored requests and the current author or maintainer relationship. Check the authenticated identity when the convention is self-assignment. Do not assume the repository owner is always the assignee.
- Inspect available labels and their descriptions, then match the change to established usage. Commit types can guide selection, but do not imply a fixed label mapping.
- If metadata remains ambiguous after checking conventions, ask a focused question instead of inventing a rule or silently omitting it. Keep repository-specific instructions only for exceptions that history and metadata cannot reliably reveal.
- Keep one purpose per request. Unrelated changes, including dependency or lockfile churn, belong in separate requests.

### Description

- Lead with the concrete problem or goal and the resulting behavior. A short paragraph or a few bullets can cover a small change without headings.
- Scale detail to what a reviewer needs to assess the change. Add sections for non-obvious rationale, tradeoffs, measurements, or migration steps when relevant, using headings that fit the content. Avoid repeating the same points under Summary, Changes, and Design decisions.
- Report relevant checks and their results, distinguishing verified behavior from untested limits. Use prose, bullets, tables, or checklists as the evidence warrants. Neither `Test plan` nor `Verification` is a required heading.
- Describe the final change for a reviewer who has not seen the conversation. Fold review fixes into that description, and omit implementation history, commit inventories, and abandoned approaches unless they explain a current tradeoff.
- Skip boilerplate sections. Omit generated-by attributions and emojis unless requested. Keep local-only paths out of commits and published descriptions.

### Publication

- Verify the base branch, diff, and commit count before pushing. When asked only to draft a title and body, return the text without publishing. A request to create a draft PR / MR authorizes publishing it in draft state.
- When creating a PR / MR, set assignees and existing labels according to repository conventions. Use the hosting service's CLI when available.
- Pass multiline bodies through a file or structured argument. Prefer `gh pr create --body-file <file>` and `gh pr edit --body-file <file>` to shell interpolation. Use native references such as `#N` for related issues and PRs in the same repository.
- Read back the created or updated request to verify its base, diff, assignees, and labels. Correct omissions before reporting completion.
- For an approved merge, check the current head and CI status, use the repository's merge method, and confirm the resulting remote state. For GitHub squash merges, use GitHub's default commit message without supplying a custom subject or body. Report queued auto-merge as pending until it has landed.
