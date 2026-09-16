# Proxy

When `hakula.llm-assistants.enable` is set, `hakula.llm-assistants.proxy.*` supplies defaults to `claude-code`, `codex`, `omp`, and `opencode`. An assistant enabled independently of the bundle uses its own `hakula.<assistant>.proxy` options. The URL defaults to `http://127.0.0.1:7897` (local mihomo), overridable via `url` or `secretUrlFile`.

The workstation role profile enables it by default in `hosts/_profiles/role/workstation/default.nix`, so `macbook` and `wsl` both inherit it. `wsl-non-nixos` sets it explicitly, since a system-manager host imports no role profile, and `devvm` sets it with `secretUrlFile`. Wrapped commands export HTTP proxy variables, with local and configured `noProxy` destinations excluded.

`lib/proxy.nix` holds the helpers: `mkProxyOptions`, `mkProxyScript`, `wrapWithProxy`, and `no_proxy` rendering. A script produced by `mkProxyScript` is sourced through `makeWrapper --run`, which is why it [stays bash](../conventions/nushell.md#what-stays-bash).
