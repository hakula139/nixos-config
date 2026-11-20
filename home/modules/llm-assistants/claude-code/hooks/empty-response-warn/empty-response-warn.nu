#!/usr/bin/env nu

# ==================================================================================================
# Empty Response Warning Hook
# ==================================================================================================
# Warns the user through `systemMessage` when Claude Code ends a turn with no assistant text,
# which it otherwise ends silently.
# ==================================================================================================

const WARNING = "Assistant returned an empty response, likely an upstream or gateway failure."

def warn-if-empty []: nothing -> any {
  let input = (^cat | from json)
  if not ($input | describe | str starts-with "record") { return null }

  let message = ($input | get -o last_assistant_message)
  let has_text = (
    ($message | describe) == "string"
    and ($message | str trim | is-not-empty)
  )
  if $has_text { return null }

  {
    systemMessage: $WARNING
  }
  | to json --raw
}

# Emit a `systemMessage` warning when the Stop hook input has no assistant text.
def main [] {
  let out = try {
    warn-if-empty
  } catch {
    null
  }
  if $out != null {
    print $out
  }
}
