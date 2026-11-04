# Shell

Write new helper scripts in [nushell](nushell.md) by default, and check that page for what stays in bash.

- Split non-trivial control flow and long calls across lines so each step is easy to read and diff on its own.
- Quote variables, even inside `[[ ]]`, and start every multi-command script with `set -euo pipefail`.
- Interpolate Nix values into shell strings with `lib.escapeShellArg` or `lib.escapeShellArgs`.
