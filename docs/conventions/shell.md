# Shell

New helper scripts default to [nushell](nushell.md), which also records why each remaining bash script stays bash.

- Multi-line layout for non-trivial flow (`if/else`, multi-arg `printf`, process substitutions). One-line invocations stay on one line.
- Quote variables, including inside `[[ ]]`. Use `set -euo pipefail` at the top of every script that runs more than one command.
- Use `lib.escapeShellArg` / `lib.escapeShellArgs` when interpolating Nix values into shell.
