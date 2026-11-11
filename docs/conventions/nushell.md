# Nushell

General Nushell conventions and traps live in the `nushell` skill from [hakula139/plugins](https://github.com/hakula139/plugins). This page covers the choices, packaging, and test setup specific to nixos-config.

## Scripts

- **Script-relative resources**: Nix must package the resources the shared `SCRIPT_DIR` pattern resolves beside the script, so those resources resolve in the store.
- **Help**: point to the help output with `Run with --help for usage.` only when the header says something else. Start a parameter help comment with a capital and end it without a period, and end a `def` docstring with one.
- **`path join`**: keep the call on one line.

## In Nix

- **Inputs**: keep checked-in Nushell valid on its own. Build a command that reads generated `config` or `flags` with `repoLib.mkNuCommand`, which packages it with devkit's [`writeNuApplication`](https://github.com/hakula139/devkit/blob/v3/docs/nushell.md#package-a-single-file). Put executables in its `runtimeInputs`, pass structured values as `config`, which the script reads through a typed `--config` flag, and pass a few scalars as typed `flags`, which leaves positional parameters to the user.
- **Shebang**: the writers prepend a store-path shebang without `--stdin`, which demotes the script's `#!/usr/bin/env nu` to a comment. Keep that line for standalone runs and LSP checks, and commit the executable bit on helpers run from the checkout. Spawn Nushell from a generated script with `$nu.current-exe`.
- **Modules**: a parse-time `use` target must resolve in both the source tree and the store. Without such a path, expose the helper as an executable.

## Testing

The linked `nushell` skill covers test placement and nu-test execution. A test needing tools beyond Nushell, bash, and coreutils adds them to the check's inputs.

- **Fixtures**: golden fixtures live under `fixtures/<group>/<case>/`. Store fixtures are read-only and `cp` keeps the mode, so `chmod u+w` a copy the script writes.
- **Stubs**: a stub that records calls appends JSON lines to `$env.STUB_LOG`, read back with `open $log | from json --objects`.
- **Refactors and ports**: run the old script (`git show HEAD:<path>`) under the wrapper's runtime `PATH`, so a pre-existing bug does not read as a regression, and do this before porting a hook, since a hook error leaves the tool call running and silently disables the hook.

## Linting

`nix develop -c run-hooks` runs `nu-check` over every script, and `editorconfig-checker` owns indentation.
