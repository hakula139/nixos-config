#!/usr/bin/env nu

# ==================================================================================================
# tmux Restore Clients
# ==================================================================================================
# Continuum's restore switches the current or best client to the session active in the snapshot.
# While it runs, this records the first session id seen for every attached client, then returns each
# surviving client to it.
# ==================================================================================================

const FORMAT = '#{client_name}|#{session_id}'

# Move every client still attached after a restore back to its recorded session.
def main [
  restore_script: path # Continuum's restore script to run
] {
  mut recorded = []
  let restore = (job spawn { ^$restore_script | ignore })
  loop {
    for row in (^tmux list-clients -F $FORMAT | lines | parse '{client}|{session}') {
      if not ($recorded | any {|entry| $entry.client == $row.client }) {
        $recorded = ($recorded | append {client: $row.client, session: $row.session})
      }
    }
    if not ($restore in (job list | get id)) {
      break
    }
    sleep 50ms
  }

  let surviving = (^tmux list-clients -F '#{client_name}' | lines)
  for entry in $recorded {
    if $entry.client in $surviving {
      try { ^tmux switch-client -c $entry.client -t $entry.session }
    }
  }
}
