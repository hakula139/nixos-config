#!/usr/bin/env nu

# ==================================================================================================
# tmux Task Name
# ==================================================================================================
# Names the calling pane's tmux session after an agent's task. Only a default numeric session with
# one window and one pane qualifies, and never a Workmux window, so user-chosen names and shared
# layouts stay intact.
# ==================================================================================================

# The session name comes last because it may contain the separator. An unknown pane prints empty
# fields, since display-message tolerates a missing target.
const FORMAT = ([
  '#{pane_id}' '#{session_id}' '#{session_windows}' '#{window_panes}' '#{@workmux_token}'
  '#{session_name}'
] | str join '|')

# A line of FORMAT output
const FIELDS = (
  '^(?<pane>%\d+)\|(?<id>\$\d+)\|(?<windows>\d+)\|(?<panes>\d+)\|(?<token>[^|]*)\|(?<name>.*)$'
)

def skip [reason: string] {
  print $"Skipped: ($reason)."
}

# Rename the calling pane's tmux session to a task name, or print why it stays unchanged.
def main [
  name: string # Short, hyphenated task name
] {
  let pane = $env.TMUX_PANE? | default ""
  if ($env.TMUX? | is-empty) or ($pane | is-empty) {
    skip "not running inside a tmux pane"
    return
  }

  let output = try { ^tmux display-message -p -t $pane $FORMAT } catch { "" }
  let session = $output | lines | parse --regex $FIELDS | where pane == $pane | get 0?
  if $session == null {
    skip $"cannot inspect pane ($pane)"
  } else if $session.name !~ '^\d+$' {
    skip $"the session already has the name '($session.name)'"
  } else if ($session.windows | into int) > 1 {
    skip $"the session has ($session.windows) windows"
  } else if ($session.panes | into int) > 1 {
    skip $"its window has ($session.panes) panes"
  } else if ($session.token | is-not-empty) {
    skip "Workmux manages its window"
  } else {
    ^tmux rename-session -t $session.id $name
    let renamed = ^tmux display-message -p -t $pane '#{session_name}' | str trim
    if $renamed != $name {
      error make {msg: $"session ($session.id) is named '($renamed)' after renaming to '($name)'"}
    }
    print $"Renamed session ($session.id) to '($name)'."
  }
}
