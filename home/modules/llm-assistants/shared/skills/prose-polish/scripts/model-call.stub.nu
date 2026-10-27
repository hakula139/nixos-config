#!/usr/bin/env nu

# ==================================================================================================
# Model Call Stub
# ==================================================================================================
# Stands in for the model caller in the prose-polish tests. Each call applies the next rule from
# `STUB_RULES`, the last rule repeating for any later call, and appends the model, user message, and
# passages it received to `STUB_LOG`, one JSON line per call. A rule is `{find, replace}`,
# `{fail: <reason>}` to exit nonzero with that stderr, or `{reply: <value>}`, where a string returns
# verbatim and any other value returns as JSON.
# ==================================================================================================

def main [] {
  let request = (^cat | from json)
  let passages = ($request.user | lines | last | from json | get passages)

  let calls = if ($env.STUB_LOG | path exists) { open $env.STUB_LOG | lines | length } else { 0 }
  {model: $request.model, user: $request.user, passages: $passages}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  let rules = (open $env.STUB_RULES)
  let rule = (if $calls < ($rules | length) { $rules | get $calls } else { $rules | last })
  if ($rule | get -o fail) != null {
    print --stderr $rule.fail
    exit 1
  }
  if ($rule | get -o reply) != null {
    if ($rule.reply | describe) == "string" {
      print --no-newline $rule.reply
    } else {
      print --no-newline ($rule.reply | to json --raw)
    }
    return
  }
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
