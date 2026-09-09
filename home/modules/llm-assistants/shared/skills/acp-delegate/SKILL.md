---
name: acp-delegate
description: Ask another coding agent a question or hand it a task through the Agent Client Protocol, including work in a different repository checkout. Use when a second agent's reading of a problem would help, when a task belongs in another repo you are not working in, or when a long job should run in its own session. Skip for work you can finish yourself.
---

# ACP Delegation

`acpx` is a headless Agent Client Protocol client. It starts a coding agent, sends it a prompt, and returns the result, so one agent can consult another without a terminal or an editor in between.

Because each target launches a Nix-installed executable, the delegate is this machine's configured install of that assistant, carrying its auth profile, proxy settings, MCP servers, permission rules, and instruction files. Once running, its own plugins and MCP servers can still reach the network.

Run `acpx config show` for the targets registered on this host. A target for an assistant that is not enabled here fails immediately with the option that would enable it.

| Target     | Runs             |
| ---------- | ---------------- |
| `claude`   | Claude Code      |
| `codex`    | OpenAI Codex CLI |
| `cursor`   | Cursor CLI       |
| `opencode` | OpenCode         |

## One-shot against a persistent session

`exec` sends one prompt in a throwaway session. Reach for it when the answer needs no follow-up.

```bash
acpx codex exec 'Which test covers the retry path in src/client.rs?'
```

A named session keeps context across several prompts. Create it once, then prompt it as often as needed. Sessions are scoped by target, working directory, and name, so the same name in two repositories stays two conversations.

```bash
acpx claude sessions new --name auth-review
acpx claude -s auth-review 'Read src/auth/ and summarise the token refresh flow.'
acpx claude -s auth-review 'Which of those steps can run concurrently?'
acpx claude sessions close auth-review
```

`acpx <target> sessions list` shows what is open, and `sessions history <name>` shows earlier turns.

These commands only create or resume sessions owned by `acpx`, so they never reach a session someone already has open in a terminal or an editor.

## Working in another repository

`--cwd` chooses the checkout the delegate works in. This is the whole point of cross-repository delegation: stay where you are and let the other agent read and change the other tree.

```bash
acpx --cwd ~/github/other-repo codex exec 'Does this repo still call the v1 endpoint anywhere?'
```

Pass an absolute path. The delegate resolves its own project instructions and configuration from that directory, so it picks up that repository's `AGENTS.md` rather than yours.

## Permissions

`acpx` answers the permission requests an agent sends to its client before acting. By default, it approves reads and searches and prompts for the rest. When invoked from an agent with no terminal to prompt at, it denies anything else, using exit code `5` to signal that at least one request came in and every one was refused.

Read-only consultation works out of the box, and `--approve-all` accepts every request the delegate raises when you want it to edit. Because some agents allow their own file and shell tools without asking a client at all, what a delegate does depends as much on its own configuration as on this flag, so say in the prompt when you only want an answer.

```bash
acpx --approve-all --cwd ~/github/other-repo codex exec 'Add the missing regression test and run the suite.'
```

Use it only for work you are already authorized to do yourself. Because a delegate acts under your authority, passing `--approve-all` means you are approving the changes, not bypassing a restriction you were given.

While `--deny-all` refuses every permission request and `--no-terminal` warns the delegate up front that client terminal calls are unavailable, neither option creates a sandbox. They govern only the requests routed through `acpx`, leaving the delegate's native tooling subject to its own configuration and whatever sandboxing that assistant enforces.

## Reading the result

Default output is human-readable text. `--format json` gives a machine-readable stream, and `--json-strict` keeps anything non-JSON off stdout.

```bash
acpx --format json codex exec 'List the public functions in src/lib.rs.'
```

Useful exit codes: `2` usage error, `3` timeout from `--timeout`, `4` no such session, `5` everything denied, `130` interrupted. Anything else non-zero is an agent or runtime error with detail on stderr.

## Choosing well

Give the delegate the context it cannot see. It does not share your conversation, so name the files, the branch, and the question. State the deliverable you expect back.

Pick a target for what it is good at rather than at random, and say in your own report which agent you asked and what it answered. Treat the answer as a second opinion to check, since a delegate can be confidently wrong about a repository it has just met.

Set `--timeout` on anything open-ended so a stalled delegate surfaces as exit `3` instead of hanging.

Do not delegate a task whose result you cannot verify, and do not chain delegations for their own sake. Every hop loses context.
