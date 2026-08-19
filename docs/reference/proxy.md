# Proxy

`hakula.llm-assistants.proxy.*` fans out to each assistant (`claude-code`, `codex`, `opencode`). The URL defaults to `http://127.0.0.1:7897` (local mihomo), overridable via `url` or `secretUrlFile`.

The workstation role profile enables it by default in `hosts/_profiles/role/workstation/default.nix`, so `macbook` and `wsl` both inherit it. `wsl-non-nixos` sets it explicitly, since a system-manager host imports no role profile, and `devvm` sets it with `secretUrlFile`. When network operations matter on those hosts, requests route through the proxy.

`lib/proxy.nix` holds the helpers: `mkProxyOptions`, `mkProxyScript`, `wrapWithProxy`, and `no_proxy` rendering. A script produced by `mkProxyScript` is injected through `makeWrapper --run`, which is why it [stays bash](../conventions/nushell.md#what-stays-bash).
