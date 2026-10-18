---
name: git-workflow
description: >-
  Prepare commits, draft or create and update pull requests or merge requests, push branches, merge
  approved requests, resolve merge or rebase conflicts, update existing issues, and clean up
  finished work. Use when completing a logical implementation chunk, resolving conflicts, updating
  an existing issue, cleaning up after merged or abandoned work, or performing Git ref creation and
  publication tasks, including PR titles and descriptions. Skip read-only Git inspection and code
  review.
---

# Git Workflow

Read the repository's contribution instructions before starting, and use its own tools for worktrees, rebases, and merges.

## Authorization

- **Publish completed changes by default.** For requested work and incidental environment repairs, create a task branch if needed, commit the verified changes, push them, and create or update a PR / MR before reporting completion. Reuse the task's existing branch and request when appropriate.
- **Clean up finished work by default.** You may remove a merged branch, or an abandoned branch whose commits all exist on a remote, together with its worktree once that worktree is verified clean. You may also delete plans and notes when a closed issue or merged PR / MR confirms the work is complete. Ask before deleting abandoned work with commits missing from every remote, or notes whose completion you cannot confirm.
- **Honor narrower authorization.** Review-only and draft-text-only requests do not authorize publication. Follow instructions to keep work local, avoid pushing, or omit a PR / MR. Create tags and backup refs only when explicitly requested.
- **Get explicit approval before merging each PR / MR.** Blanket approval given earlier does not cover requests opened later in the session. Share the URL and wait for `lgtm` or `merge` referring to that specific PR / MR. A request to review and merge authorizes merging each PR / MR covered by the review, including requests opened for its fixes, once the review reports no remaining findings.

## Commits

- Commit each logical chunk after its checks pass and before moving on.
- Verify the current branch and inspect the diff, then stage only the intended files or hunks.
- Use `type(scope): description` in the imperative mood, with one logical change per commit. Types are `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, and `perf`. Infer the scope and granularity from the affected component, file, or host, and from comparable commits.
- For substantial changes, include a body explaining the problem, rationale, and relevant tradeoffs or validation without repeating the subject. Keep the body proportional to the change. Small, self-explanatory changes need only a subject.
- Name branches `<type>/<short-name>` using the same types, and keep an appropriate existing branch.

## Pull / Merge Requests

### Repository conventions

- Read the PR / MR template and recent comparable, human-authored requests to learn the conventions for titles, body structure, assignees, and labels. Follow explicit repository rules where examples differ. Broaden the sample if recent examples do not cover the change.
- Before drafting, record in working notes which examples you chose and the conventions they show, including heading names, hierarchy and order, prose or list structure, and validation format. Include these notes in any handoff. Prefer examples closest in scope and size. An abbreviated body for a small fix does not establish the format for a substantial feature.
- Infer assignees from comparable requests and the relationship between the author and maintainers. When the convention involves self-assignment, check the authenticated identity. The repository owner is not always the assignee.
- After reading the available labels and their descriptions, match labels to established usage. Commit types can inform the choice but do not imply a fixed mapping.
- If metadata remains ambiguous, ask a focused question. Never invent a rule or silently omit metadata. Repository-specific instructions should cover only exceptions that cannot be inferred from history and metadata.
- Keep each request focused on one purpose. Put unrelated changes, including dependency or lockfile churn, in separate requests.

### Description

Follow the repository's conventions for structure. The guidance below applies within that structure and fills gaps only when the evidence does not determine the choice.

- Open with the concrete problem or goal and the resulting behavior, using the established opening section if there is one.
- Give reviewers the details they need to assess the change, including rationale, tradeoffs, measurements, or migration steps where relevant. Preserve the established headings and validation format while removing repetition.
- Report the checks you ran and their results in the repository's validation format. Distinguish verified behavior from untested limits.
- Write for reviewers who have not seen the conversation. Fold review fixes into the description, and omit implementation history, commit inventories, and abandoned approaches unless they explain a current tradeoff.
- Omit boilerplate sections, generated-by attributions, and emojis unless requested.
- Keep local-only paths out of commits and descriptions. Never include internal information in a description, including internal URLs or plain-text references.

### Publication

- Before creating or updating a request, compare its complete title and body with the recorded conventions and examples. Fix any differences in heading hierarchy, section order, or validation format. Reading the examples alone does not complete this check.
- Before pushing, verify the base branch, diff, and commit count. If asked only to draft a title and body, return the text without publishing. A request for a draft PR / MR authorizes publishing it as a draft.
- When creating a request, set assignees and existing labels, using the hosting service's CLI when available.
- Pass multiline bodies through a file or structured argument, such as `gh pr create --body-file <file>` or `gh pr edit --body-file <file>`. Use `#N` for issues and GitHub PRs in the same repository, and `!N` for GitLab MRs.
- Read back each created or updated request to verify its title, body, base, diff, assignees, and labels. Correct anything lost from the published body before reporting completion.
- For an approved merge, confirm the host reports the branch as mergeable, then use the repository's merge method. If branch protection requires CI checks, queue an auto-merge, such as `gh pr merge --auto --squash`, and move on without polling. Otherwise, wait for CI to pass on the current head. Rebase only if the branch conflicts or the host requires it to be up to date. If a queued auto-merge falls behind, run `gh pr update-branch` because auto-merge does not update the branch.
- After the merge, verify the remote state and confirm CI passes on the target branch, since CI checks the combined result. For GitHub squash merges, keep GitHub's default commit message. Report queued auto-merges as pending until they land.
- Stack a request that depends on or overlaps another open request on that request's branch, and name the base request in the description. After the base squash-merges, run `git rebase --onto <default-branch> <old-base-head> <branch>` to drop its pre-squash commits, then retarget the request to the default branch if the host has not.

## Conflict Resolution

A mechanical conflict resolution can compile while silently reverting an upstream rename, reorder, or simplification.

- Read the upstream PR / MR or commit message and surrounding code to understand the intent on each side.
- Integrate both sides so each purpose is preserved. Keeping one side loses the other's change, while concatenating them can duplicate or contradict content.
- Check that the result's ordering and grouping follow local conventions, such as sorted lists, import order, section order, and documentation tables. Then rerun the checks covering the conflicting files.

## Issues

An issue is a public record of one unit of work, with a designated place for each kind of information:

- **Description:** the current specification, including the goal, acceptance criteria, decisions and scope, dependencies, and findings that shape the work. Edit it in place, mark criteria as they are met, and replace superseded wording so the body shows the current state on its own.
- **Comments:** events that watchers should be notified about. These include why an issue is being closed without a linked PR / MR closing it (not planned, duplicate, or completed by other means), why it is being reopened, questions or discussion that need a reply, and brief notices of material scope changes that point to the edited description. Skip progress updates and information already shown in a linked PR / MR.
- **Local working notes:** execution details such as agent assignments, worktrees, in-flight branches, ordering, raw research, and private context. Keep these in the session or a gitignored plans directory, never in the issue.
- **Existing comments:** when a comment carries a decision or finding that belongs in the spec, fold it into the description. Delete the comment only after the description covers everything it says.

Pass an edited body through a file or structured argument, then read the issue back.

## Cleanup

When work finishes, clean up within the authorization above. Stale worktrees, branches, and plans can mislead later sessions, while scratch builds fill the disk.

- Before removing a worktree, check it for uncommitted, untracked, and ignored files, preserve anything still needed, and confirm that no other agent or terminal is using it. `git -C <worktree> status --short --ignored` lists the ignored files. Diff unique ignored content, such as agent memory directories, local settings, and notes, against its counterpart in the main checkout, and merge anything missing there.
- Remove the worktree and its local branch, then prune its remote-tracking ref. Use the repository's tooling or the `clean-gone` skill for merged branches. Delete a remote branch only when explicitly requested.
- Delete completed plans and working notes from the plans directory, such as a gitignored `.agents/plans/`. Rewrite stale notes to show only the current state and remaining work.
- When its task ends, each agent removes any scratch copies and build directories it created, such as `git archive` exports and their `CARGO_TARGET_DIR`s under `/tmp`. In its report, name anything it leaves for someone else.
