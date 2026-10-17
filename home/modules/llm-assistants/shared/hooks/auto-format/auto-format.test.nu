#!/usr/bin/env nu

# ==================================================================================================
# Auto-Format Tests
# ==================================================================================================

use std/assert
use std-rfc/str

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join auto-format.nu)
const DPRINT_STUB = ($SCRIPT_DIR | path join dprint.stub.nu)
const SAMPLE = "```md\n<!-- note -->\ntext\n```\n"

# Runs the hook on a Markdown write with `dprint` as the formatter and returns the file afterwards.
# The linters are a no-op executable.
def format-notes [content: string, dprint: string]: nothing -> string {
  let dir = (mktemp --directory | path expand)
  let file = ($dir | path join notes.md)
  let noop = ($dir | path join noop)
  let config_file = ($dir | path join config.json)

  $content | save $file
  "#!/bin/sh\n" | save $noop
  ^chmod +x $noop
  {
    cspell: $noop
    direnv: ""
    dprint: $dprint
    dprintConfig: ""
    markdownlint: $noop
  }
  | to json
  | save $config_file

  let run = (
    {tool_name: Write, tool_input: {file_path: $file}, cwd: $dir}
    | to json
    | ^$nu.current-exe --no-config-file $SCRIPT $config_file
    | complete
  )
  assert equal $run.exit_code 0 $run.stderr

  open --raw $file
}

def executable [name: string, body: string]: nothing -> string {
  let path = (mktemp --directory | path join $name)
  $body | save $path
  ^chmod +x $path
  $path
}

def "test a fenced Markdown example keeps its layout" [] {
  let stub = $"#!($nu.current-exe) --no-config-file\n" + (open --raw $DPRINT_STUB)
  let dprint = (executable dprint $stub)
  let example = (
    "
    ```markdown
    <!-- note -->
    `value`
    ```

    ~~~MD title
    <!-- note -->
    text
    ~~~

    - Item

      ```md
      <!-- note -->
      text
      ```
    " | str dedent
  ) + "\n"

  assert equal (format-notes $example $dprint) $example
}

def "test empty dprint output leaves the file alone" [] {
  let dprint = (executable dprint "#!/bin/sh\ncat >/dev/null\n")

  assert equal (format-notes $SAMPLE $dprint) $SAMPLE
}

def "test a failing dprint leaves the file alone" [] {
  let dprint = (executable dprint "#!/bin/sh\ncat\necho broken\nexit 1\n")

  assert equal (format-notes $SAMPLE $dprint) $SAMPLE
}
