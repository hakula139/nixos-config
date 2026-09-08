#!/usr/bin/env nu

# ==============================================================================
# Comment Gate
# ==============================================================================

const MIN_CHARS = 12
const MAX_TOKENS = 2048

# Line comment openers by file extension. A payload carrying none of its
# language's openers cannot carry a comment, which is the whole prefilter.
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

# A whole line of nothing but a comment opener and four or more rule characters.
# That frames a banner, so it never justifies a judge call on its own.
const BANNER_RULE = '(?m)^\s*(?://|#|--|;)\s*[=*_-]{4,}\s*$'

def payload [input: record, config: record]: nothing -> list<record> {
  let tool = $input.tool_name
  let args = $input.tool_input
  if $tool == "apply_patch" {
    let parser = $config.patchInput
    return ($args.command | ^$parser | from json | where action != "Delete" | each {|file|
      {path: $file.path, text: ($file.added | str join "\n")}
    })
  }
  let key = match $tool {
    "Write" => "content"
    "Edit" => "new_string"
    _ => "",
  }
  if ($key | is-empty) {
    return []
  }
  let file = {path: $args.file_path, text: ($args | get $key)}
  [($file | merge (if $tool == "Edit" { {before: $args.old_string} } else { {} }))]
}

def commentish [path: string, text: string]: nothing -> bool {
  let extension = ($path | path parse | get extension | str downcase)
  let openers = ($OPENERS | get -o $extension | default [])
  if ($openers | is-empty) {
    return false
  }
  let stripped = ($text | str replace --regex --all $BANNER_RULE "")
  $openers | any {|opener| $stripped | str contains $opener }
}

def judge [text: string, config: record]: nothing -> string {
  let caller = $config.modelCall
  let request = {
    system: $config.prompt
    user: $text
    maxTokens: $MAX_TOKENS
  }
  let run = ($request | to json | ^$caller | complete)
  if $run.exit_code != 0 { "" } else { $run.stdout }
}

# The verdict sits at the end of the reply, after findings that quote the text
# under judgement. Reading from the last line backwards is what keeps a brace
# or an `ok:` inside a quoted span from being mistaken for the verdict.
def verdict [raw: string]: nothing -> record {
  let lines = ($raw | lines | reverse)
  for line in $lines {
    # A trailing `ok` verdict, with or without JSON or Markdown decoration
    let hit = ($line | parse --regex '(?i)"?\bok"?\s*[:=]\s*\**\s*(?<value>true|false)')
    if ($hit | is-not-empty) {
      return {ok: (($hit | get -o 0.value | default "true" | str downcase) == "true")}
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
    (($file.path | str ends-with ".md") == false
      and ($file.text | str trim | str length --grapheme-clusters) >= $MIN_CHARS
      and (commentish $file.path $file.text))
  })
  if ($found | is-empty) { return null }

  let raw = (judge ($found | to json) $config)
  if ($raw | str trim | is-empty) {
    return null
  }
  if ((verdict $raw) | get -o ok | default true) != false {
    return null
  }
  {
    hookSpecificOutput: {
      hookEventName: "PostToolUse"
      additionalContext: ([
        "The comment gate flagged comments in the text you just wrote."
        "Check each finding against surrounding code and comparable files before changing it."
        ""
        (reason $raw)
      ] | str join "\n")
    }
  }
  | to json --raw
}

def main [config_file: string] {
  let out = (try { gate (open $config_file) } catch { null })
  if $out != null {
    print $out
  }
}
