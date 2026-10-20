#!/usr/bin/env nu

# ==================================================================================================
# Codex Stale Daemon Stop
# ==================================================================================================

# Stop a managed app-server daemon still running an older Codex package.
#
# The next Codex client starts it again from this generation's package, in that client's
# environment. Restarting it here would pin the activation environment for its lifetime.
def main [package: string] {
  let version = (^codex app-server daemon version | complete)
  if $version.exit_code != 0 { return }

  let daemon = ($version.stdout | from json)
  if $daemon.backend? == null { return }

  let selected = ($daemon.managedCodexPath | path expand)
  if $selected == ($package | path join 'libexec/codex/bin/codex' | path expand) { return }

  ^codex app-server daemon stop
}
