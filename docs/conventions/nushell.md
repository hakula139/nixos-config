# Nushell

General Nushell conventions and traps live in the `nushell` skill from [hakula139/plugins](https://github.com/hakula139/plugins). This page covers the choices, packaging, and test runner specific to nixos-config.

## Scripts

- **Script-relative resources**: bind `const SCRIPT_DIR = path self "."` after the header and imports. It resolves at parse time from the defining file, so Nix must package those resources beside the script.
- **Help**: point to the help output with `Run with --help for usage.` only when the header says something else. Start a parameter help comment with a capital and end it without a period, and end a `def` docstring with one.
- **Quote style**: use double quotes, switching to single quotes when the text holds a literal backslash or double quote.
- **`path join`**: merge adjacent literal segments into one string and keep the call on one line, so the path reads as one value.

## In Nix

- **Inputs**: keep checked-in Nushell valid on its own. Build a command that needs a wrapper with `repoLib.mkNuCommand`, since `writeNuBin`'s `makeWrapperArgs` renames the script that `--help` names. Put executables in its `runtimeInputs`, pass structured values as `config`, which the script reads through a typed `--config` flag, and pass a few scalars as typed `flags`, which leaves positional parameters to the user. A wrapped command rejects a `--` operand that is not a plain flag name, a bare redirection such as `o>`, and a `...$` spread, so its operands must not start with `--`.
- **Fixed values**: a script reachable through a generated allow rule takes wrapper-fixed values from the environment through `--set`, because a caller can override a `--config` flag.
- **Shebang**: the writers prepend a store-path shebang without `--stdin`, which demotes the script's `#!/usr/bin/env nu` to a comment. Keep that line for standalone runs and LSP checks, and commit the executable bit on helpers run from the checkout. Spawn Nushell from a generated script with `$nu.current-exe`.
- **Modules**: a parse-time `use` target must resolve in both the source tree and the store. Without such a path, expose the helper as an executable.

## Testing

Each script's tests live in a `<script>.test.nu` beside it. The `nushell` skill's [nu-test runner section](https://github.com/hakula139/plugins/blob/main/plugins/hakula-languages/skills/nushell/SKILL.md#the-nu-test-runner) covers how the runner executes them. A test needing tools beyond Nushell, bash, and coreutils adds them to the check's inputs.

- **Fixtures**: golden fixtures live under `fixtures/<group>/<case>/`. Store fixtures are read-only and `cp` keeps the mode, so `chmod u+w` a copy the script writes.
- **Stubs**: a stub that records calls appends JSON lines to `$env.STUB_LOG`, read back with `open $log | from json --objects`.
- **Refactors and ports**: run the old script (`git show HEAD:<path>`) under the wrapper's runtime `PATH`, so a pre-existing bug does not read as a regression, and do this before porting a hook, since a hook error leaves the tool call running and silently disables the hook.

## Linting

`nix develop -c run-hooks` runs `nu-check` over every script, and `editorconfig-checker` owns indentation. Don't use `nufmt`, which reindents to four spaces.
