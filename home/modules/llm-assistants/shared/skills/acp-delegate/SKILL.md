---
name: acp-delegate
description: Delegate a bounded task or consult Claude Code or Codex through ACP, including work in another repository.
---

# ACP Delegation

Use `acpx` to start or resume a configured assistant. `acpx config show` lists this host's targets: `claude` and `codex`. Disabled targets report the option needed to enable them. Other names fall through to acpx's upstream registry and may launch an unmanaged agent.

Provide the repository, relevant files, task scope, and expected result. Delegates do not share your conversation. For code changes, assign file ownership and follow the shared worktree rules.

## Single task

`exec` uses a disposable session. Pass `--cwd` to select another checkout and `--timeout` to bound the wait in seconds.

```bash
acpx --cwd /absolute/path/to/repo --timeout 120 codex exec 'Read src/auth/ and identify the token refresh race. Do not edit files.'
```

The delegate loads that checkout's project instructions. Configured targets use this host's assistant wrappers, including their authentication and proxy setup. The delegate's tools and plugins retain their own configuration.

## Follow-up work

Named sessions retain context and are scoped by target and working directory. Use the same `--cwd` on each command when working outside the current checkout.

```bash
acpx claude sessions new --name auth-review
acpx --timeout 120 claude -s auth-review 'Inspect src/auth/ for token refresh races.'
acpx --timeout 120 claude -s auth-review 'Which test would expose the race?'
acpx claude sessions close auth-review
```

`sessions list` lists sessions for the target and directory. acpx cannot attach to an assistant session already open in a terminal or editor.

## Permissions and results

By default, acpx approves read requests and prompts for other operations. Without an interactive terminal, use `--non-interactive-permissions deny` to reject those requests. Use `--approve-all` only when the delegated work is already authorized.

These flags govern permission requests sent through ACP. They do not sandbox tools an assistant runs without asking its client, so state read-only scope explicitly in the prompt.

For structured output, pass `--format json --json-strict`. Exit codes include `2` for invalid usage, `3` for timeout, `4` for a missing session, `5` for permission denial, and `130` for interruption. Inspect the result and verify the delegate's work before reporting completion.
