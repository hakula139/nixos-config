#!/usr/bin/env nu

# ==================================================================================================
# Model Call Stub
# ==================================================================================================
# Stands in for the model caller in the prose-polish tests. Each call applies the next rule from
# `STUB_RULES` to every passage and appends the passages it received to `STUB_LOG`, one JSON line
# per call.
# ==================================================================================================

def main [] {
  let request = (^cat | from json)
  let passages = ($request.user | lines | last | from json | get passages)

  let calls = if ($env.STUB_LOG | path exists) { open $env.STUB_LOG | lines | length } else { 0 }
  $passages | to json --raw | $"($in)\n" | save --append $env.STUB_LOG

  let rule = (open $env.STUB_RULES | get $calls)
  {
    passages: (
      $passages
      | each {|passage|
        {id: $passage.id, text: ($passage.text | str replace --all $rule.find $rule.replace)}
      }
    )
  }
  | to json
}
