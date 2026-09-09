# Agent Client Protocol

The `home/modules/llm-assistants/acp` module enables cross-assistant delegation over the [Agent Client Protocol](https://agentclientprotocol.com) by installing the [`acpx`](https://acpx.sh) headless client and generating `~/.acpx/config.json` with a target for each assistant managed by this repository. Its activation (`hakula.llm-assistants.acp.enable`) tracks `hakula.llm-assistants.enable`.

Cross-assistant usage guidance is defined in the `acp-delegate` skill, which `home/modules/llm-assistants/shared/skills` installs for all four assistants: Claude Code and OpenCode share a copy under `.claude/skills`, Codex takes the same sources through its own skill bundle, and Cursor gets its own copy under `.cursor/skills` because it scans that directory first and treats the others as third-party entries a user can turn off.

| Target     | Launches                               |
| ---------- | -------------------------------------- |
| `claude`   | `claude-agent-acp` against Claude Code |
| `codex`    | `codex-acp` against the Codex CLI      |
| `cursor`   | `cursor-agent acp`                     |
| `opencode` | `opencode acp`                         |

Claude Code and Codex connect to ACP using standalone adapters packaged by [`llm-agents.nix`](https://github.com/numtide/llm-agents.nix) alongside the agents themselves, whereas OpenCode and the Cursor CLI serve ACP directly from their own binaries.

## Why the config looks the way it does

**`argv` must use a profile path rather than a store path.** Because acpx keys saved sessions on the exact agent command string and working directory, store paths would orphan persistent sessions whenever an adapter or underlying agent changes across rebuilds. The profile path remains constant across rebuilds, though its basename must still match the upstream program name for acpx to recognize the adapter and apply the correct handling.

**The adapters are wrapped to force the configured agent.** Each adapter reads its agent binary from an environment variable, `CLAUDE_CODE_EXECUTABLE` or `CODEX_PATH`, and falls back to a bundled, unwrapped build. Only the wrapped binaries installed by this repo carry the auth profile, the proxy environment, and `--mcp-config`. The wrapper uses `--set` rather than `--set-default` because an adapter exports its resolved value into the agent it starts, so an agent delegating onwards would otherwise pass the inherited unwrapped path back to acpx.

**`ACPX_CLAUDE_INCLUDE_USER_SETTINGS=1` is required, not cosmetic.** By default, acpx restricts a Claude ACP session's setting sources to project and local, keeping globally enabled plugins out of spawned sessions. While the wrapper's auth, proxy, and MCP flags reach the session either way, everything Claude Code loads from user settings does not, including the hooks, the permission rules, the status line, and `~/.claude/CLAUDE.md`.

**Codex reaches its profile through config overrides, not `--profile`.** Because the adapter spawns `codex app-server`, which rejects `--profile`, the loader in `home/modules/llm-assistants/codex` translates the active profile into one `-c <key>=<value>` per top-level key. Omitting the profile would leave an ACP session on the base config, losing the gateway provider and its credentials on a work host. In the pinned Codex, a top-level table override deep-merges sibling keys from the base config, making per-key translation equivalent to `--profile`'s layering. `scripts/profile-overrides.py` renders the values with a TOML serializer because string splicing breaks on keys containing quoted project paths and values containing nested tables or arrays of tables.

**Disabled assistants retain their entries.** Each disabled target points `argv` to a script explaining how to enable it. Removing an entry would instead expose acpx's built-in launch command for that name, which starts an agent lacking this repository's auth profiles, MCP servers, and hooks, and downloads a package first whenever the built-in uses `npx`. Similarly, `defaultAgent` is pinned to an enabled target because upstream directs unassigned prompts to `codex`.

Any target name outside the four configured targets falls through to acpx's built-in registry and launches on its own terms.

## What it does and does not give you

acpx owns and persists sessions under `~/.acpx/`, scoping them by target and working directory to support cross-repository delegation via `--cwd`. Because these commands only create or resume sessions started by acpx, they cannot reach sessions already open in an interactive terminal or editor.

acpx answers permission requests routed through the protocol by an agent, defaulting to reads and searches only and denying the rest when no terminal is available for prompts. That boundary applies strictly to requests reaching acpx, not as a sandbox around the delegate, whose own tooling stays under its own configuration.

## Cursor

Because the Cursor module configures only the editor rather than a CLI, the ACP target provisions `cursor-agent` directly. This sizeable addition to the closure authenticates through Cursor's own login or `CURSOR_API_KEY` / `CURSOR_AUTH_TOKEN` rather than a managed secret, and `hakula.llm-assistants.acp.cursor.enable` tracks `hakula.cursor.enable`.

Because `cursor-agent` has no other wrappers, the ACP module applies the assistant proxy to it directly.
