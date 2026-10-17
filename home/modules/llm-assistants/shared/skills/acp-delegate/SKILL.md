---
name: acp-delegate
description: Delegate a bounded task or consult Claude Code or Codex through ACP, including work in another repository.
---

# ACP Delegation

Use `acpx` to start or resume a configured assistant. Run `acpx config show` to see this host's targets, `claude` and `codex`. If a target is disabled, the output tells you which option enables it. Other names fall through to acpx's upstream registry and may launch an unmanaged agent.

Delegates do not share your conversation, so provide the repository, relevant files, task scope, and expected result. For code changes, assign file ownership and follow the shared worktree rules.

## Single task

`exec` runs in a disposable session. Use `--cwd` to select another checkout and `--timeout` to set the wait limit in seconds.

```bash
acpx --cwd /absolute/path/to/repo --timeout 120 codex exec 'Read src/auth/ and identify the token refresh race. Do not edit files.'
```

The delegate loads the selected checkout's project instructions and runs through this host's assistant wrappers, using their authentication and proxy setup. Its tools and plugins retain their own configuration.

## Follow-up work

Named sessions retain context and are scoped to a target and working directory. When running commands outside the current checkout, pass the same `--cwd` each time.

```bash
acpx claude sessions new --name auth-review
acpx --timeout 120 claude -s auth-review 'Inspect src/auth/ for token refresh races.'
acpx --timeout 120 claude -s auth-review 'Which test would expose the race?'
acpx claude sessions close auth-review
```

`sessions list --local --filter-cwd .` lists local session records for the target and directory without starting an adapter. Omit `--filter-cwd .` to include other directories. Plain `sessions list` queries the agent's own session list when supported. acpx cannot attach to a session already open in a terminal or editor.

## Permissions and results

By default, acpx approves read requests and prompts for all others. If no interactive terminal is available, pass `--non-interactive-permissions deny` to reject prompts. Use `--approve-all` only for delegated work that is already authorized. These flags apply only to permission requests sent through ACP, so they do not sandbox tools an assistant runs without asking. State the read-only scope explicitly in the prompt.

For structured output, pass `--format json --json-strict`. Exit codes include `2` for invalid usage, `3` for timeout, `4` for a missing session, `5` for permission denial, and `130` for interruption. Verify the delegate's work before reporting completion.
