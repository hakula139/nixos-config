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
- Focus the message on why the change is needed. Add a body only for necessary rationale, tradeoffs, or issue links.
- Branch names use `<type>/<short-name>`, with the same type set. Keep an appropriate existing branch.

## Pull / Merge Requests

### Repository conventions

- Read the PR / MR template, then inspect recent comparable human-authored requests for title, body structure, assignees, and labels. Follow explicit repository rules where examples differ. Broaden the sample when recent examples do not cover the change.
- Before drafting, record the chosen examples and the resulting conventions in working notes: heading names, hierarchy and order, prose or list structure, and validation format. Carry these notes into any handoff. When examples vary, use the ones closest in scope and size to the current change. A small fix's abbreviated body does not establish the format for a substantial feature.
- Infer assignees from comparable human-authored requests and the current author or maintainer relationship. Check the authenticated identity when the convention is self-assignment. Do not assume the repository owner is always the assignee.
- Inspect available labels and their descriptions, then match the change to established usage. Commit types can guide selection, but do not imply a fixed label mapping.
- If metadata remains ambiguous after checking conventions, ask a focused question instead of inventing a rule or silently omitting it. Keep repository-specific instructions only for exceptions that history and metadata cannot reliably reveal.
- Keep one purpose per request. Unrelated changes, including dependency or lockfile churn, belong in separate requests.

### Description

The discovered repository conventions govern the description's structure. Apply the writing guidance below within that structure. Use it to choose a structure only where repository evidence leaves a gap.

- Lead with the concrete problem or goal and the resulting behavior under the established opening section, if any.
- Scale the detail within sections to what a reviewer needs to assess the change. Preserve the established headings and validation format while removing repetition. Include rationale, tradeoffs, measurements, or migration steps where relevant.
- Report relevant checks and their results, distinguishing verified behavior from untested limits. Match the repository's validation heading and use of prose, bullets, tables, or checklists.
- Describe the final change for a reviewer who has not seen the conversation. Fold review fixes into that description, and omit implementation history, commit inventories, and abandoned approaches unless they explain a current tradeoff.
- Skip boilerplate sections. Omit generated-by attributions and emojis unless requested. Keep local-only paths out of commits and published descriptions.

### Publication

- Before creating or updating a request, compare the complete draft title and body with the recorded conventions and selected examples. Correct differences in heading hierarchy, section order, and validation format before publishing. Reading examples alone does not complete this check.
- Verify the base branch, diff, and commit count before pushing. When asked only to draft a title and body, return the text without publishing. A request to create a draft PR / MR authorizes publishing it in draft state.
- When creating a PR / MR, set assignees and existing labels according to repository conventions. Use the hosting service's CLI when available.
- Pass multiline bodies through a file or structured argument. Prefer `gh pr create --body-file <file>` and `gh pr edit --body-file <file>` to shell interpolation. Use native references such as `#N` for related issues and PRs in the same repository.
- Read back the created or updated request to verify its title, body, base, diff, assignees, and labels. Check that the published body preserves the reviewed structure and content. Correct omissions before reporting completion.
- For an approved merge, check the current head and CI status, use the repository's merge method, and confirm the resulting remote state. For GitHub squash merges, use GitHub's default commit message without supplying a custom subject or body. Report queued auto-merge as pending until it has landed.
