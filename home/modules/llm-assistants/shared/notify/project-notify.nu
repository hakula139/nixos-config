#!/usr/bin/env nu

# ==================================================================================================
# Project-Scoped Notification
# ==================================================================================================

# Notify with the title and message, prefixed by the project's directory name.
def main [
  title: string # Notification title
  message: string = "" # Notification body
  payload: string = "" # Event JSON whose cwd names the project in place of the working directory
  --notify: path # Wrapper-supplied command that shows the notification
] {
  mut project = ($env.PWD | path basename)

  if ($payload | is-not-empty) {
    # `from json` returns non-JSON text unchanged rather than raising, so the shape has to be
    # checked before reading a field.
    let parsed = try {
      $payload | from json
    } catch {
      null
    }
    if (($parsed | describe) | str starts-with "record") {
      let payload_cwd = ($parsed | get -o cwd)
      if ($payload_cwd | is-not-empty) {
        $project = ($payload_cwd | path basename)
      }
    }
  }

  ^$notify $title $"[($project)] ($message)"
}
