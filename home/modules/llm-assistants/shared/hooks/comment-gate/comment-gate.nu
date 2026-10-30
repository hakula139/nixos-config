#!/usr/bin/env nu

# ==================================================================================================
# Comment Gate
# ==================================================================================================

use std-rfc/str

const MIN_CHARS = 12
const MAX_TOKENS = 8192

# Line comment openers by file extension. A payload carrying none of its language's openers cannot
# carry a comment, which is the whole prefilter.
const OPENERS = {
  c: ["//" "/*"]
  cc: ["//" "/*"]
  cpp: ["//" "/*"]
  cs: ["//" "/*"]
  css: ["/*"]
  dart: ["//" "/*"]
  el: [";"]
  elm: ["--"]
  go: ["//" "/*"]
  h: ["//" "/*"]
  hpp: ["//" "/*"]
  hs: ["--"]
  ini: [";" "#"]
  java: ["//" "/*"]
  js: ["//" "/*"]
  jsx: ["//" "/*"]
  kt: ["//" "/*"]
  less: ["//" "/*"]
  lua: ["--"]
  mjs: ["//" "/*"]
  nix: ["#" "/*"]
  nu: ["#"]
  php: ["//" "/*" "#"]
  proto: ["//"]
  py: ["#" '"""' "'''"]
  rb: ["#"]
  rs: ["//" "/*"]
  scala: ["//" "/*"]
  scss: ["//" "/*"]
  sh: ["#"]
  sql: ["--"]
  swift: ["//" "/*"]
  toml: ["#"]
  ts: ["//" "/*"]
  tsx: ["//" "/*"]
  vue: ["//" "/*" "<!--"]
  yaml: ["#"]
  yml: ["#"]
  zsh: ["#"]
}

# A whole line of nothing but a comment opener and four or more rule characters. That frames a
# banner, so it never justifies a judge call on its own.
const BANNER_RULE = '(?m)^\s*(?://|#|--|;)\s*[=*_-]{4,}\s*$'

def payload [input: record, config: record]: nothing -> list<record> {
  let args = $input.tool_input
  match $input.tool_name {
    "Write" => [{path: $args.file_path, text: $args.content}]
    "Edit" => [{path: $args.file_path, before: $args.old_string, text: $args.new_string}]
    "apply_patch" => {
      let parser = $config.patchInput
      $args.command | ^$parser | from json | where action != "Delete" | each {|file|
        {path: $file.path, text: ($file.added | str join "\n")}
      }
    }
    _ => []
  }
}

def commentish [path: string, text: string]: nothing -> bool {
  let extension = ($path | path parse | get extension | str lowercase)
  let openers = ($OPENERS | get -o $extension | default [])
  if ($openers | is-empty) {
    return false
  }
  let stripped = ($text | str replace --regex --all $BANNER_RULE "")
  $openers | any {|opener| $stripped | str contains $opener }
}

# The model's reply, or the caller's reason for having none.
def judge [text: string, config: record]: nothing -> record {
  let caller = $config.modelCall
  let request = {
    model: $config.model
    maxTokens: $MAX_TOKENS
    system: $config.prompt
    user: $text
  }
  let run = ($request | to json | ^$caller | complete)
  if $run.exit_code != 0 {
    {error: ($run.stderr | str trim)}
  } else {
    {reply: $run.stdout}
  }
}

def context [message: string]: nothing -> string {
  {
    hookSpecificOutput: {
      hookEventName: "PostToolUse"
      additionalContext: $message
    }
  }
  | to json --raw
}

# A check that could not run still tells the agent, since silence would read as a pass.
def unchecked [problem: string]: nothing -> string {
  print --stderr $"comment-gate: ($problem)"
  context ({problem: $problem} | format pattern (
    "
    The comment gate could not check the text you just wrote, so its comments went unreviewed.
    Reason: {problem}
    "
    | str dedent
  ))
}

# The verdict sits at the end of the reply, after findings that quote the text under judgment.
# Reading from the last line backwards is what keeps a brace or an `ok:` inside a quoted span from
# being mistaken for the verdict.
def verdict [raw: string]: nothing -> record {
  let lines = ($raw | lines | reverse)
  for line in $lines {
    # A trailing `ok` verdict, with or without JSON or Markdown decoration
    let hit = ($line | parse --regex '(?i)"?\bok"?\s*[:=]\s*\**\s*(?<value>true|false)')
    if ($hit | is-not-empty) {
      return {ok: (($hit | get -o 0.value | default "true" | str lowercase) == "true")}
    }
  }
  {}
}

def reason [raw: string]: nothing -> string {
  let body = (
    $raw
    | lines
    | where ($it | str trim | is-not-empty)
    | last 24
    | str join "\n"
  )
  if ($body | is-empty) { "comment doctrine violation" } else { $body }
}

def gate [config: record]: nothing -> any {
  let input = (^cat | from json)
  let found = (payload $input $config | where {|file|
    ((not ($file.path | str ends-with ".md"))
      and ($file.text | str trim | str length --grapheme-clusters) >= $MIN_CHARS
      and (commentish $file.path $file.text))
  })
  if ($found | is-empty) { return null }

  let judged = (judge ($found | to json) $config)
  if ($judged | get -o error) != null {
    return (unchecked $judged.error)
  }
  let ok = (verdict $judged.reply | get -o ok)
  if $ok == null {
    return (unchecked "the model's reply carries no verdict")
  }
  if $ok {
    return null
  }
  context ({reason: (reason $judged.reply)} | format pattern (
    "
    The comment gate flagged comments in the text you just wrote.
    Check each finding against surrounding code and comparable files before changing it.
    Change only the flagged spans.

    {reason}
    "
    | str dedent
  ))
}

def main [config_file: string] {
  let out = try { gate (open $config_file) } catch {|err| unchecked $err.msg }
  if $out != null {
    print $out
  }
}
