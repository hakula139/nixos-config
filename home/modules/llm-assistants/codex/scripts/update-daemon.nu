#!/usr/bin/env nu

# ==================================================================================================
# Codex Daemon Update
# ==================================================================================================

# Repin a running app-server daemon to this generation's Codex package.
#
# A stopped daemon selects the current package when it next starts. A running one keeps its old
# package until updated, which drains its active work before restarting.
def main [package: string] {
  let version = (^codex app-server daemon version | complete)
  if $version.exit_code != 0 { return }

  let daemon = ($version.stdout | from json)
  let selected = ($daemon.managedCodexPath | path expand)
  if $selected == ($package | path join 'libexec/codex/bin/codex' | path expand) { return }

  ^codex app-server daemon update --from-cli --yes
}
