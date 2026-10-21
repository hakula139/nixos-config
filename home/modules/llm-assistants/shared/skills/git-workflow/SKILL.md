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

- **Publish completed changes by default.** For requested work and incidental environment repairs, commit the verified changes on a task branch, push them, and create or update a PR / MR before reporting completion, reusing the task's existing branch and request when appropriate.
- **Clean up finished work by default.** You may remove a merged branch, or an abandoned branch whose commits all exist on a remote, together with its worktree once that worktree is verified clean. You may also delete plans and notes when a closed issue or merged PR / MR confirms the work is complete. Ask before deleting abandoned work with commits missing from every remote, or notes whose completion you cannot confirm.
- **Honor narrower authorization.** Review-only and draft-text-only requests do not authorize publication. Follow instructions to keep work local, avoid pushing, or omit a PR / MR. Create tags and backup refs only when explicitly requested.
- **Get explicit approval before merging each PR / MR.** Blanket approval given earlier does not cover requests opened later in the session. Share the URL and wait for `lgtm` or `merge` referring to that specific PR / MR. A request to review and merge authorizes merging each PR / MR covered by the review, including requests opened for its fixes, once the review reports no remaining findings.

## Worktrees

- Keep the main checkout on the default branch, because several agents may work in the repository at once and editing it or switching its branch can collide with their work.
- Create every task branch, including the coordinator's own, in a worktree under `.claude/worktrees/<name>`. Claude Code and Workmux (under `workmux/`) create their worktrees there too, so they all share one gitignored directory.

## Commits

- Commit each logical chunk after its checks pass and before moving on.
- Verify the current branch and inspect the diff, then stage only the intended files or hunks.
- Before discarding a lockfile that a tool regenerated, check whether it corrects a stale lock, as `uv lock --check` reports. Keep a correction, publishing it separately when it falls outside the task.
- Use `type(scope): description` in the imperative mood, with one logical change per commit. Types are `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `style`, and `perf`. Infer the scope and granularity from comparable commits.
- For substantial changes, include a body explaining the problem, rationale, and relevant tradeoffs or validation without repeating the subject. Keep the body proportional to the change.
- Name branches `<type>/<short-name>` using the same types, and keep an appropriate existing branch.

## Pull / Merge Requests

### Repository conventions

- Before drafting, learn the conventions for titles, body structure, assignees, and labels from the PR / MR template and recent comparable, human-authored requests. Prefer those closest in scope and size, broaden the sample when they do not cover the change, and follow explicit repository rules where examples differ.
- Record the chosen examples and the conventions they show, including heading names, hierarchy and order, prose or list structure, and validation format, and include these notes in any handoff.
- Infer assignees from comparable requests, checking the authenticated identity when the convention is self-assignment.
- Match labels to established usage and the available labels' descriptions. Commit types can inform the choice but do not imply a fixed label mapping.
- If metadata remains ambiguous, ask a focused question. Never invent a rule or silently omit metadata.
- Keep each request focused on one purpose. Put unrelated changes, including dependency or lockfile churn, in separate requests, and fix every occurrence of the same problem within a repository in one request.

### Description

Write within the recorded structure, for reviewers who have not seen the conversation, and preserve the established headings and validation format while removing repetition.

- Open with the concrete problem or goal and the resulting behavior.
- Give reviewers what they need to assess the change, such as rationale, tradeoffs, measurements, or migration steps, and report the checks you ran with their results, distinguishing verified behavior from untested limits.
- Fold review fixes into the description, and update it without asking whenever later pushes make any part of it inaccurate. Omit implementation history, commit inventories, and abandoned approaches unless they explain a current tradeoff, and omit boilerplate sections, generated-by attributions, and emojis unless requested.
- Keep local-only paths and internal information, including internal URLs and plain-text references, out of commits and descriptions.

### Publication

- Never force-push a branch that someone else may push to. Land fixes there as new commits, using `git revert` for a pushed commit, and rewrite history only on branches you alone own. After pushing `HEAD:refs/heads/<branch>` from a detached worktree, fast-forward the local branch so later commits are not stranded on a stale ref.
- Before pushing, verify the base branch, diff, and commit count. Before creating or updating a request, compare its complete title and body with the recorded conventions, fixing any difference in heading hierarchy, section order, or validation format.
- If asked only to draft a title and body, return the text without publishing. A request for a draft PR / MR authorizes publishing it as a draft.
- Set assignees and labels when creating a request. If no existing label fits, create one that follows the repository's label scheme. Pass multiline bodies through a file or structured argument, such as `gh pr create --body-file <file>`. Use `#N` for issues and GitHub PRs in the same repository, and `!N` for GitLab MRs.
- Read back each created or updated request, verifying its title, body, base, diff, assignees, and labels, and fix anything lost before reporting completion.
- For an approved merge, confirm the host reports the branch as mergeable, then use the repository's merge method. If branch protection requires CI checks, queue an auto-merge, such as `gh pr merge --auto --squash`, and move on without polling. Otherwise, wait for CI to pass on the current head. Rebase only if the branch conflicts or the host requires it to be up to date. If a queued auto-merge falls behind, run `gh pr update-branch` because auto-merge does not update the branch.
- After the merge, verify the remote state and confirm CI passes on the target branch. For GitHub squash merges, keep GitHub's default commit message. Report queued auto-merges as pending until they land.
- Stack a request that depends on or overlaps another open request on that request's branch, and name the base request in the description. After the base squash-merges, run `git rebase --onto <default-branch> <old-base-head> <branch>` to drop its pre-squash commits, then retarget the request to the default branch if the host has not.

## Conflict Resolution

Read the upstream PR / MR or commit message and the surrounding code to learn each side's intent, integrate both so each purpose survives without duplication or contradiction, keep local ordering conventions such as sorted lists and section order, then rerun the checks covering the conflicting files.

## Issues

- **Description:** the current specification, covering the goal, acceptance criteria, decisions and scope, dependencies, and findings that shape the work. Edit it in place, marking criteria as they are met, so it shows the current state on its own.
- **Comments:** only events watchers need, such as why an issue closes without a linked PR / MR or reopens, questions or discussion that need a reply, and brief pointers to material scope changes in the description. Skip progress updates and anything a linked PR / MR already shows.
- **Working notes:** execution details, such as agent assignments, worktrees, in-flight branches, and private context, stay in the session or a gitignored plans directory.
- **Existing comments:** fold a decision or finding that belongs in the spec into the description, and delete the comment only once the description covers everything it says.

Pass an edited body through a file or structured argument, then read the issue back.

## Cleanup

When work finishes, clean up within the authorization above.

- Before removing a worktree, check it for uncommitted, untracked, and ignored files, preserve anything still needed, and confirm that no other agent or terminal is using it. A detached HEAD may be the only reference to its commits, so confirm they reached a remote branch, matching by subject as well as patch ID because conflict resolution changes patch IDs. Treat a denied or interrupted removal as an unknown outcome and reread `git worktree list` before retrying. Diff unique ignored content, such as agent memory directories, local settings, and notes, against its counterpart in the main checkout, and merge anything missing there.
- Remove the worktree and its local branch, then prune its remote-tracking ref. Use the repository's tooling or the `clean-gone` skill for merged branches. Delete a remote branch only when explicitly requested.
- Delete completed plans and working notes from the plans directory, such as a gitignored `.agents/plans/`. Rewrite stale notes to show only the current state and remaining work.
- Each agent removes the scratch copies and build directories it created, such as `git archive` exports and their `CARGO_TARGET_DIR`s under `/tmp`, and names in its report anything it leaves for someone else.
