#!/usr/bin/env nu

# ==================================================================================================
# tmux Task Name
# ==================================================================================================
# Names the calling pane's tmux session or window after an agent's task. A default numeric session
# with one window renames the session, while a named or multi-window session renames the current
# window when automatic-rename is still active. Multi-pane and Workmux windows stay unchanged.
# ==================================================================================================

# Session and window names sit on their own lines because either may contain the field separator.
# An unknown pane prints empty fields, since display-message tolerates a missing target.
const FORMAT = (
  [
    (
      [
        "#{pane_id}"
        "#{session_id}"
        "#{session_windows}"
        "#{window_id}"
        "#{window_panes}"
        "#{automatic-rename}"
        "#{@workmux_token}"
      ]
      | str join "|"
    )
    "#{session_name}"
    "#{window_name}"
  ]
  | str join "\n"
)

const FIELDS = (
  [
    '^(?<pane>%\d+)'
    '(?<session_id>\$\d+)'
    '(?<windows>\d+)'
    '(?<window_id>@\d+)'
    '(?<panes>\d+)'
    '(?<auto_rename>[01])'
    '(?<token>[^|]*)$'
  ]
  | str join '\|'
)

def skip [reason: string] {
  print $"Skipped: ($reason)."
}

def rename-target [kind: string, target: string, pane: string, name: string] {
  ^tmux $"rename-($kind)" -t $target $name
  let renamed = (
    ^tmux display-message
      -p
      -t $pane
      $"#{($kind)_name}"
    | str trim
  )
  if $renamed != $name {
    error make {msg: $"($kind) ($target) is named '($renamed)' after renaming to '($name)'"}
  }
  print $"Renamed ($kind) ($target) to '($name)'."
}

# Rename the calling pane's tmux session or window to a task name, or print why it stays unchanged.
def main [
  name: string # Short, hyphenated task name
] {
  let pane = $env.TMUX_PANE? | default ""
  if ($env.TMUX? | is-empty) or ($pane | is-empty) {
    skip "not running inside a tmux pane"
    return
  }

  let rows = try {
    (
      ^tmux display-message
        -p
        -t $pane
        $FORMAT
    )
    | lines
  } catch {
    []
  }

  let info = if ($rows | length) >= 3 {
    $rows.0
    | parse --regex $FIELDS
    | where pane == $pane
    | get 0?
  }
  if $info == null {
    skip $"cannot inspect pane ($pane)"
  } else if ($info.panes | into int) > 1 {
    skip $"its window has ($info.panes) panes"
  } else if ($info.token | is-not-empty) {
    skip "Workmux manages its window"
  } else if ($rows.1 =~ '^\d+$') and (($info.windows | into int) == 1) {
    rename-target "session" $info.session_id $pane $name
  } else if $info.auto_rename != "1" {
    skip $"the window already has the name '($rows.2)'"
  } else {
    rename-target "window" $info.window_id $pane $name
  }
}
