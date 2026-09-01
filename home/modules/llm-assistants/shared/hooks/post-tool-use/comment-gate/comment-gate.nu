#!/usr/bin/env nu

# ==============================================================================
# Comment Gate (PostToolUse)
# ==============================================================================

const MIN_CHARS = 12
const MAX_TOKENS = 2048

# Line comment openers by file extension. A payload carrying none of its
# language's openers cannot carry a comment, which is the whole prefilter.
const OPENERS = {
  c: ["//" "/*"], cc: ["//" "/*"], cpp: ["//" "/*"], cs: ["//" "/*"]
  css: ["/*"], dart: ["//" "/*"], el: [";"], elm: ["--"]
  go: ["//" "/*"], h: ["//" "/*"], hpp: ["//" "/*"], hs: ["--"]
  ini: [";" "#"], java: ["//" "/*"], js: ["//" "/*"], jsx: ["//" "/*"]
  kt: ["//" "/*"], less: ["//" "/*"], lua: ["--"], mjs: ["//" "/*"]
  nix: ["#" "/*"], nu: ["#"], php: ["//" "/*" "#"], proto: ["//"]
  py: ["#" '"""' "'''"], rb: ["#"], rs: ["//" "/*"], scala: ["//" "/*"]
  scss: ["//" "/*"], sh: ["#"], sql: ["--"], swift: ["//" "/*"]
  toml: ["#"], ts: ["//" "/*"], tsx: ["//" "/*"], vue: ["//" "/*" "<!--"]
  yaml: ["#"], yml: ["#"], zsh: ["#"]
}

# A rule of repeated punctuation is a banner frame rather than a comment, so it
# never justifies a judge call on its own.
const BANNER_RULE = '(?m)^\s*(?://|#|--|;)\s*[=*_-]{4,}\s*$'

def payload [input: record]: nothing -> record {
  let tool = ($input | get -o tool_name | default "")
  let args = ($input | get -o tool_input | default {})
  if ($args | describe | str starts-with "record") == false {
    return {path: "", text: ""}
  }
  let key = match $tool {
    "Write" => "content"
    "Edit" => "new_string"
    _ => "",
  }
  if ($key | is-empty) {
    return {path: "", text: ""}
  }
  let text = ($args | get -o $key | default "")
  {
    path: ($args | get -o file_path | default "")
    text: (if ($text | describe) == "string" { $text } else { "" })
  }
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

# The verdict sits at the end of the reply, after a scan that quotes the text
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
  if ($input | describe | str starts-with "record") == false {
    return null
  }
  let found = (payload $input)
  # Markdown belongs to the prose rewriter.
  if ($found.path | str ends-with ".md") {
    return null
  }
  # `str length` defaults to UTF-8 bytes.
  if ($found.text | str trim | str length --grapheme-clusters) < $MIN_CHARS {
    return null
  }
  if (commentish $found.path $found.text) == false {
    return null
  }

  let raw = (judge $found.text $config)
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
        "Drop or tighten them in place, then continue."
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
