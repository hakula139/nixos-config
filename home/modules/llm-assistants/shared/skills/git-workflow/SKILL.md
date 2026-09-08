---
name: git-workflow
description: Prepare commits, draft or create and update pull requests or merge requests, push branches, and merge approved requests. Use for these Git publication tasks, including PR titles and descriptions. Skip read-only Git inspection and code review.
---

# Git Workflow

Follow the global Git safety rules and read the repository's contribution instructions before writing commits or publishing changes. Use its existing tooling for worktrees, rebases, and merges when relevant.

## Commits

- Verify the current branch and inspect the diff before staging. Stage only the intended files or hunks.
- Make each commit one logical change. Use `type(scope): description` in the imperative mood. Types are `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, and `perf`. Use the most specific meaningful scope.
- Focus the message on why the change is needed. Add a body only for necessary rationale, tradeoffs, or issue links.
- Branch names use `<type>/<short-name>`, with the same type set. Keep an appropriate existing branch.

## Pull / Merge Requests

### Repository conventions

- Read the PR / MR template, then inspect recent comparable human-authored requests for title, body structure, assignees, and labels. Follow explicit repository rules where examples differ. Broaden the sample when recent examples do not cover the change.
- Keep one purpose per request. Unrelated changes, including dependency or lockfile churn, belong in separate requests.

### Description

- Lead with the concrete problem or goal and the resulting behavior. A short paragraph or a few bullets can cover a small change without headings.
- Scale detail to what a reviewer needs to assess the change. Add sections for non-obvious rationale, tradeoffs, measurements, or migration steps when relevant, using headings that fit the content. Avoid repeating the same points under Summary, Changes, and Design decisions.
- Report relevant checks and their results, distinguishing verified behavior from untested limits. Use prose, bullets, tables, or checklists as the evidence warrants. Neither `Test plan` nor `Verification` is a required heading.
- Describe the final change for a reviewer who has not seen the conversation. Fold review fixes into that description, and omit implementation history, commit inventories, and abandoned approaches unless they explain a current tradeoff.
- Skip boilerplate sections. Omit generated-by attributions and emojis unless requested. Keep local-only paths out of commits and published descriptions.

### Publication

- Verify the base branch, diff, and commit count before pushing. For a draft-only request, return the title and body without publishing.
- When creating a PR / MR, set assignees and existing labels according to repository conventions. Use the hosting service's CLI when available.
- Pass multiline bodies through a file or structured argument. Prefer `gh pr create --body-file <file>` and `gh pr edit --body-file <file>` to shell interpolation. Do not reference prior PRs as `#N` in the body, because GitHub expands them into title cards.
- Read back the created or updated request to verify its base, diff, assignees, and labels. Correct omissions before reporting completion.
- For an approved merge, check the current head and CI status, use the repository's merge method, and confirm the resulting remote state. Report queued auto-merge as pending until it has landed.
