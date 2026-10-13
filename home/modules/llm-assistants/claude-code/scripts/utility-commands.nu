#!/usr/bin/env nu

# ==================================================================================================
# Claude Code Utility Subcommands
# ==================================================================================================

# List the subcommands that break under root options, one per line. `plugin test` rejects them and
# `stop <id>` reads them as a prompt, while `agents` passes them to the sessions it dispatches.
def main [
  claude: path # Unwrapped Claude Code executable
] {
  let commands = (
    ^$claude --help
    | lines
    | skip until { $in == "Commands:" }
    # Command entry: two-space indent, then the name and any `|`-separated aliases
    | parse -r '^  (?<names>[a-z][a-z|-]*)'
    | get names
    | split row "|"
    | where $it != "agents"
  )
  if "mcp" not-in $commands {
    error make {msg: "No subcommands parsed from claude --help"}
  }

  print ($commands | str join "\n")
}
