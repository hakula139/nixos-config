---
name: git-workflow
description: >-
  Prepare commits, draft or create and update pull requests or merge requests, push branches, merge
  approved requests, and update existing issues. Use when completing a logical implementation chunk
  or performing Git ref creation and publication tasks, including PR titles and descriptions and
  edits to existing issues. Skip read-only Git inspection and code review.
---

# Git Workflow

Read the repository's contribution instructions before changing Git state or preparing publication. Use its existing tooling for worktrees, rebases, and merges when relevant.

## Authorization

- **Publish completed changes by default.** For requested repository changes and incidental environment repairs, create an appropriate task branch when needed, commit verified changes, push, and create or update a PR / MR. Complete publication before reporting the work done. Reuse the task's existing branch and request when appropriate.
- **Honor narrower authorization.** Review-only and draft-text-only requests do not authorize publication. Respect explicit instructions to keep work local, avoid pushing, or omit a PR / MR. Tags and backup refs require an explicit request.
- **Wait for explicit approval before merging each PR / MR.** Earlier blanket approvals do not cover requests opened later in the session. After publishing, share the URL and wait for `lgtm` or `merge` referring to that specific PR / MR. A request to review and merge approves each PR / MR covered by the review, including any opened for its fixes, once the review reports no remaining findings.

## Commits

- **Commit at the seam.** Commit each logical chunk once its relevant checks pass, before moving on.
- Verify the current branch and inspect the diff before staging. Stage only the intended files or hunks.
- Make each commit one logical change. Use `type(scope): description` in the imperative mood. Types are `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, and `perf`. Infer the scope from the affected component, file, or host and comparable commit history. Follow established naming and granularity.
- For substantial changes, include a body explaining the problem, rationale, and relevant tradeoffs or validation. Keep it proportional to the change and avoid repeating the subject. A subject alone is sufficient for small, self-explanatory changes.
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
- Never include internal information in PR / MR descriptions, including URLs and plain-text references.

### Publication

- Before creating or updating a request, compare the complete draft title and body with the recorded conventions and selected examples. Correct differences in heading hierarchy, section order, and validation format before publishing. Reading examples alone does not complete this check.
- Verify the base branch, diff, and commit count before pushing. When asked only to draft a title and body, return the text without publishing. A request to create a draft PR / MR authorizes publishing it in draft state.
- When creating a PR / MR, set assignees and existing labels according to repository conventions. Use the hosting service's CLI when available.
- Pass multiline bodies through a file or structured argument. Prefer `gh pr create --body-file <file>` and `gh pr edit --body-file <file>` to shell interpolation. Use `#N` for same-repository issues and GitHub PRs, and `!N` for GitLab MRs.
- Read back the created or updated request to verify its title, body, base, diff, assignees, and labels. Check that the published body preserves the reviewed structure and content. Correct omissions before reporting completion.
- For an approved merge, confirm that CI passes on the current head and the host reports the branch as mergeable. Use the repository's merge method, then verify the resulting remote state. Rebase only if the branch has conflicts or the host requires it to be up to date. CI on the target branch checks the combined result, so confirm it passes after the merge. For GitHub squash merges, use GitHub's default commit message without supplying a custom subject or body. Report queued auto-merge as pending until it has landed.

## Issues

Keep an existing GitHub or GitLab issue's description as its one current, organized spec. A reader should get the issue's state from the body alone, while comment trails accumulate superseded decisions.

- Record decisions, scope changes, research findings, progress updates, and close reasons by editing the description. Do not add comments to existing issues.
- Revise acceptance criteria in place without keeping superseded wording beside the correction. Record decisions under the issue's Notes section or the repository's equivalent.
- When existing comments carry this kind of content, fold them into a reorganized body, then delete the folded comments.
- Close an issue as not planned with the reason stated in the body and no closing comment.
- Pass the edited body through a file or structured argument, then read the issue back to verify it.
