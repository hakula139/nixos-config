#!/usr/bin/env nu

# ==============================================================================
# Project-Scoped Notification
# ==============================================================================
# projectNotify <title> <message> [payload]
# ==============================================================================

def main [notify: string, title: string, message: string = "", payload: string = ""] {
  mut project = ($env.PWD | path basename)

  if ($payload | is-not-empty) {
    # `from json` returns non-JSON text unchanged rather than raising, so the
    # shape has to be checked before reading a field.
    let parsed = (try { $payload | from json } catch { null })
    if (($parsed | describe) | str starts-with "record") {
      let payload_cwd = ($parsed | get -o cwd)
      if ($payload_cwd | is-not-empty) {
        $project = ($payload_cwd | path basename)
      }
    }
  }

  ^$notify $title $"[($project)] ($message)"
}
