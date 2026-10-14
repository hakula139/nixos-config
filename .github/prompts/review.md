Review this PR by applying the review skill in `home/modules/llm-assistants/shared/skills/review/SKILL.md` in its default review mode, together with the repository instructions it loads.

## CI scope

- Review in a single pass without delegating. The only commands available are the `gh` calls below, so skip coverage runs and builds, and list them as unverified.
- Post inline comments only on lines the diff changes. Report pre-existing issues under Observations.

## Posting the review

Post the review to the PR with the GitHub tools below. Text left in the final response never reaches the PR.

### Inline review comments

For line-specific issues, use `mcp__github_inline_comment__create_inline_comment`. Start each inline comment with a severity prefix (**Critical** / **Warning** / **Suggestion**) matching the skill's severity definitions.

### Top-level summary comment

Start the summary comment with the HTML marker `<!-- claude-review -->` on its own line, which lets a later run find and update it, followed by this structure.

If there are findings, use (omit empty severity sections):

```markdown
<!-- claude-review -->

## Summary

<1–3 sentences: what the PR changes, scope, affected modules / hosts>

## Assessment

### Critical

- <item>

### Warnings

- <item>

### Suggestions

- <item>

## Observations

- <noteworthy items that are not issues>
```

If there are no findings:

```markdown
<!-- claude-review -->

## Summary

<1–3 sentences: what the PR changes, scope, affected modules / hosts>

## Assessment

No issues found.
```

### How to post the summary comment

The `--body` flag does not work because the Bash permission glob cannot match multi-line arguments. Always use `--body-file` instead. All Bash commands **must be single-line** (no `\` line continuations).

1. Write the review body to `review-comment.md` using the **Write** tool.

2. Search for an existing comment containing `<!-- claude-review -->` using the REST API (returns API URLs, unlike `gh pr view` which returns HTML URLs):

   ```bash
   gh api repos/$REPO/issues/$PR_NUMBER/comments --jq '.[] | select(.body | contains("claude-review")) | .url'
   ```

3. Post or update:

   - If found: update that comment using the API URL from step 2:

     ```bash
     gh api <api-url> -X PATCH -F body=@review-comment.md
     ```

   - If not found: create a new comment:

     ```bash
     gh pr comment $PR_NUMBER --repo $REPO --body-file review-comment.md
     ```
