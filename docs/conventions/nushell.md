# Nushell

General Nushell conventions and traps live in the `nushell` skill. This page covers the choices, packaging, and test runner specific to nixos-config.

## Scripts

- **Script-relative resources**: bind `const SCRIPT_DIR = path self "."` after the header and imports. It resolves at parse time from the defining file, so Nix must package those resources beside the script.
- **Help**: point to the help output with `Run with --help for usage.` only when the header says something else. Start a parameter help comment with a capital and end it without a period, and end a `def` docstring with one.
- **Quote style**: use double quotes, switching to single quotes when the text holds a literal backslash or double quote.
- **`path join`**: merge adjacent literal segments into one string and keep the call on one line, so the path reads as one value.

## In Nix

- **Inputs**: keep checked-in Nushell valid on its own. Build a command that needs a wrapper with `repoLib.mkNuCommand`, since `makeWrapperArgs` renames the script that `--help` names. Put executables in its `runtimeInputs`, pass structured values as `config`, which the script reads through a typed `--config` flag, and pass a few scalars as typed `flags`, which leaves positional parameters to the user.
- **Shebang**: the writers prepend a store-path shebang without `--stdin`, which demotes the script's `#!/usr/bin/env nu` to a comment. Keep that line for standalone runs and LSP checks, and commit the executable bit on helpers run from the checkout. Spawn Nushell from a generated script with `$nu.current-exe`.
- **Modules**: a parse-time `use` target must resolve in both the source tree and the store. Without such a path, expose the helper as an executable.

## Testing

Each script's tests live in a `<script>.test.nu` beside it, as commands named `test <behavior>`. `nu-test <file>...` starts every test concurrently in its own process and `TMPDIR` and confines `mktemp` to a scratch directory. A test needing tools beyond Nushell, bash, and coreutils adds them to the check's inputs.

- **Fixtures**: golden fixtures live under `fixtures/<group>/<case>/`. Store fixtures are read-only and `cp` keeps the mode, so `chmod u+w` a copy the script writes.
- **Stubs**: a stand-in for an executable is `<executable>.stub.nu` beside the test, which the runner installs in `$env.NU_TEST_STUBS`. A stub that records calls appends JSON lines to `$env.STUB_LOG`, read back with `open $log | from json --objects`.
- **Refactors and ports**: run the old script (`git show HEAD:<path>`) under the wrapper's runtime `PATH` too, so a pre-existing bug does not read as a regression, and do this before porting a hook, since a hook error leaves the tool call running and silently disables the hook.

## Linting

`nix flake check` runs `nu-check` over every script, and `editorconfig-checker` owns indentation. Don't use `nufmt`, which reindents to four spaces.
