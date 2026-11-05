#!/usr/bin/env nu

# ==================================================================================================
# Cursor Extension Sync
# ==================================================================================================
# Installs the provisioned Cursor extensions and, when pruning, uninstalls the rest. A missing
# Cursor CLI, a failed listing, or a failed install or uninstall is reported without failing.
# ==================================================================================================

# Matches an extension ID, which excludes the header a remote host prints before the list.
const EXTENSION_ID = '^[[:alnum:]_-]+\.[[:alnum:]_-]+$'

# Returns the most recently modified of the given paths, or null when there are none.
def newest []: list<string> -> oneof<string, nothing> {
  let paths = $in
  if ($paths | is-empty) { return null }
  ls -D ...$paths | sort-by modified | last | get name
}

# Returns the first `cursor` in the CLI directories or the newest Cursor server, or null.
def find-cursor [cli_dirs: list<string>, server_dir: string]: nothing -> oneof<string, nothing> {
  $cli_dirs
  | append (glob ($server_dir | path join "*/bin/remote-cli") --no-file | newest)
  | each {|dir| $dir | path join "cursor" }
  | where ($it | path exists)
  | get -o 0
}

# Sets VSCODE_IPC_HOOK_CLI, which activation outside a Cursor terminal lacks, to the user's newest
# IPC socket.
def --env use-ipc-socket [username: string]: nothing -> nothing {
  if ($env.VSCODE_IPC_HOOK_CLI? | is-not-empty) { return }
  let uid = (^id -u $username | str trim)
  let socket = (glob $"/run/user/($uid)/vscode-ipc-*.sock" | newest)
  if $socket != null {
    $env.VSCODE_IPC_HOOK_CLI = $socket
  }
}

# Runs one install or uninstall, warning when the CLI rejects it.
def change-extension [cursor: string, action: string, id: string]: nothing -> nothing {
  try {
    ^$cursor $"--($action)-extension" $id
  } catch {
    print -e $"Cursor extension ($action) failed for ($id), continuing sync"
  }
}

# Syncs the installed Cursor extensions with the provisioned list.
#
# The config holds `baseExtensions`, plus `remoteExtensions` for a CLI outside a Cursor server,
# `cliDirs` and `serverDir` to search for the CLI, `username` for the IPC socket, and `prune`.
def main [
  --config: path # Wrapper-supplied JSON with the extension lists, CLI directories, and prune flag
]: nothing -> nothing {
  let cfg = (open $config)

  let cursor = (find-cursor $cfg.cliDirs $cfg.serverDir)
  if $cursor == null {
    print -e "Cursor CLI not found, skipping sync"
    return
  }
  use-ipc-socket $cfg.username

  let expected = if ($cursor | str starts-with $cfg.serverDir) {
    $cfg.baseExtensions
  } else {
    $cfg.baseExtensions | append $cfg.remoteExtensions
  }

  let listing = (^$cursor --list-extensions | complete)
  if $listing.exit_code != 0 {
    print -e $"Cursor extension listing failed, skipping sync: ($listing.stderr | lines | get -o 0)"
    return
  }
  let installed = ($listing.stdout | lines | where $it =~ $EXTENSION_ID)

  let installed_keys = ($installed | str lowercase)
  for id in ($expected | where ($it | str lowercase) not-in $installed_keys) {
    change-extension $cursor install $id
  }

  if $cfg.prune {
    let expected_keys = ($expected | str lowercase)
    for id in ($installed | where ($it | str lowercase) not-in $expected_keys) {
      change-extension $cursor uninstall $id
    }
  }
}
