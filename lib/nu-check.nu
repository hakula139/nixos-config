#!/usr/bin/env nu

# ==============================================================================
# Nushell Diagnostic Check
# ==============================================================================
# Wraps `nu --ide-check`, which reports diagnostics as JSON on stdout but always
# exits 0, and enforces the indentation `nufmt` cannot be trusted to apply.
# ==============================================================================

const NU = "@nu@"
const MAX_ERRORS = 100
const INDENT = @indent@

# ------------------------------------------------------------------------------
# Diagnostics
# ------------------------------------------------------------------------------

# A `@name@` placeholder only parses once Nix has substituted it. `[]` stands in
# because it satisfies a `list` parameter and degrades to a string inside quotes,
# where a bare word would trip the type checker.
def substitute [text: string, stub: string]: nothing -> string {
  $text
  | str replace --regex --multiline '^(use\s+)@[a-zA-Z][a-zA-Z0-9]*@' $"${1}($stub)"
  | str replace --all --regex '@[a-zA-Z][a-zA-Z0-9]*@' "[]"
}

def diagnostics [target: string]: nothing -> list<string> {
  ^$NU --ide-check $MAX_ERRORS $target
  | complete
  | get stdout
  | lines
  | each {|line| try { $line | from json } catch { {} } }
  | where ($it.severity? | default "") == "Error"
  | each {|d| $"  ($d.message) \(offset ($d.span.start)\)" }
}

# ------------------------------------------------------------------------------
# Layout
# ------------------------------------------------------------------------------

def layout-errors [text: string]: nothing -> list<string> {
  $text
  | lines
  | enumerate
  | each {|row|
    let indent = ($row.item | parse --regex '^(?<ws>[ \t]*)' | get -o 0.ws | default "")
    let n = ($row.index + 1)

    if ($indent | str contains (char tab)) {
      $"  line ($n): tab indent, expected spaces"
    } else if ($row.item | str trim | is-not-empty) and (($indent | str length) mod $INDENT != 0) {
      $"  line ($n): indent of ($indent | str length) is not a multiple of ($INDENT)"
    }
  }
  | compact --empty
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

def main [...files: string] {
  let stub = (mktemp --tmpdir --suffix .nu)
  "" | save --force $stub
  mut failed = false

  for file in $files {
    if not ($file | path exists) {
      print -e $"($file): no such file"
      $failed = true
      continue
    }

    # `open --raw` yields a byte stream, and the `-> string` signatures below
    # reject invalid UTF-8 with a trace naming this script instead of the file.
    let text = (try { open --raw $file | into string } catch { null })
    if $text == null {
      print -e $"($file): not valid UTF-8"
      $failed = true
      continue
    }

    let target = (mktemp --tmpdir --suffix .nu)
    substitute $text $stub | save --force $target

    let errors = [...(diagnostics $target) ...(layout-errors $text)]
    rm --force $target
    if ($errors | is-not-empty) {
      print -e $"($file):"
      $errors | each {|e| print -e $e }
      $failed = true
    }
  }

  rm --force $stub
  if $failed {
    exit 1
  }
}
