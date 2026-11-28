## Host Environment

Read `${XDG_CONFIG_HOME:-$HOME/.config}/nixos-config/repository` to get the checkout path, then open `AGENTS.md` in that checkout to locate the configuration sources. If a tool or the environment misbehaves, hand the repair to `harness-repair` and continue the main task.

- **Secrets**: Managed secrets live at `/run/secrets/<service>/<secret>`. Write new values only into their SOPS secret or the untracked file that consumes them.
- **Browser tools**: Get Playwright / Chromium tools from `nix develop nixos-config#browser`.
