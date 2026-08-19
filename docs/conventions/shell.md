# Shell

Read this before writing or editing a `.sh` file or an inline `writeShellScript` block. New helper scripts default to [nushell](nushell.md), which also records why each remaining bash script stays bash.

- Multi-line layout for non-trivial flow (`if/else`, multi-arg `printf`, process substitutions). One-line invocations stay on one line.
- Quote variables. Use `set -euo pipefail` at the top of every script that runs more than one command.
- Use `lib.escapeShellArg` / `lib.escapeShellArgs` when interpolating Nix values into shell.
- Keep substantial scripts in adjacent `.sh` files and load them with `builtins.readFile`. Inline only short wrappers or generated snippets.

## Formatting

`shfmt` runs as a pre-commit hook and reads its layout from `.editorconfig`, including the two keys that are `shfmt` extensions rather than EditorConfig proper, `binary_next_line` and `switch_case_indent`.

Every `settings` value in `flake.nix` is null or false on purpose. Each flag in the `git-hooks-nix` hook `entry` is conditional, so those values yield a bare `shfmt -w -l`, and that is the only invocation where `shfmt` consults `.editorconfig` at all. Passing a single flag reverts it to its own defaults, which are tabs, and drops both extension keys. `simplify` would additionally strip the quotes inside `[[ ]]` that the rule above requires.

A glob in `.editorconfig` has to cover every extension the hook's `types` matches. `types = [ "shell" ]` matches `.zsh`, and a file no glob covers falls back to tabs rather than to no rule.
