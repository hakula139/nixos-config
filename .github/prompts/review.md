Review this PR. This is a flake-based NixOS / nix-darwin configuration repo.

## Focus areas

### Nix modules and configuration

1. Module correctness: option declarations, `mkIf` guards, import structure
2. Secrets handling: agenix patterns (`mkSecret` / `mkHomeSecret`), no hardcoded secrets
3. Cross-platform: `isNixOS` / `isDesktop` flags used correctly where needed
4. DRY: no duplicated configuration across hosts or modules
5. Security: exposure of secrets in logs or Nix store paths

### Shell scripts and CI

1. Command injection: unquoted variables, unsafe interpolation of untrusted input
2. Correctness: wrong flags, missing error handling (`set -e` / `|| exit`), broken pipelines
3. GitHub Actions: incorrect event triggers, overly broad permissions, misconfigured conditions

## Review principles

### Scope

- Only review **changed lines** in the diff. Do not flag pre-existing code unless a change makes it newly broken.
- Check existing patterns in the codebase before suggesting alternatives — if the code follows an established convention, it is not a finding.

### Hard exclusions — never flag these

- **Formatting / whitespace**: nixfmt handles all formatting.
- **Hypothetical future issues**: problems that require imagined future changes to trigger.
- **Style alternatives**: "I would have done it differently" is not a finding.

### Signal quality — every finding must pass ALL of these

1. **Concrete failure**: You can describe a specific, reproducible scenario where the code breaks, produces wrong output, or creates a vulnerability. "This could fail" is not sufficient — explain exactly *when* and *how*.
2. **Not already addressed**: You have checked inline comments, commit messages, and surrounding context. The author has not already documented the rationale for the pattern you are questioning.
3. **Verified behavior**: If your finding depends on how a platform feature works (GitHub Actions expressions, Nix evaluator, systemd, etc.), you have confirmed the actual behavior — not assumed it from another language or platform.
4. **Actionable fix**: You can propose a specific code change. "Verify that X works" or "consider whether Y" are not actionable — either show the fix or do not report it.

### Severity rules

Use these definitions consistently in both inline comments and the summary:

- **Critical**: Bugs that will cause build / evaluation / runtime failure, security vulnerabilities with a concrete exploit path, data loss.
- **Warning**: Logic errors with a specific trigger condition, missing guards where you can name the failing input.
- **Suggestion**: A clearly better alternative exists and you can show both the current behavior and the improved one side-by-side.
- When in doubt about severity, **downgrade** rather than upgrade. Do not inflate suggestions into warnings.

## Posting the review

You MUST post your review to the PR using GitHub tools — do not just output text.

### Inline review comments

For line-specific issues, use `mcp__github_inline_comment__create_inline_comment`. Each inline comment MUST include a severity prefix (**Critical** / **Warning** / **Suggestion**) matching the definitions above.

### Top-level summary comment

The summary comment MUST start with the HTML marker `<!-- claude-review -->` on its own line, followed by this structure.

If there are findings, use (omit empty severity sections):

```markdown
<!-- claude-review -->

## Summary

<1-3 sentences: what the PR changes, scope, affected modules / hosts>

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

<1-3 sentences: what the PR changes, scope, affected modules / hosts>

## Assessment

No issues found.
```

### How to post the summary comment

The `--body` flag does not work because the Bash permission glob cannot match multi-line arguments. Always use `--body-file` or `--input` instead.

1. Write the review body to `review-comment.md` using the **Write** tool.

2. Search for an existing comment containing `<!-- claude-review -->`:

   ```bash
   gh pr view $PR_NUMBER --repo $REPO --json comments --jq \
     '.comments[] | select(.body | contains("claude-review")) | .url'
   ```

3. Post or update:

   - If found: update that comment:

     ```bash
     gh api <url> -X PATCH -F body=@review-comment.md
     ```

   - If not found: create a new comment:

     ```bash
     gh pr comment $PR_NUMBER --repo $REPO --body-file review-comment.md
     ```
