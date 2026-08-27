#!/usr/bin/env nu

# ==============================================================================
# Nushell Diagnostic Check
# ==============================================================================
# Wraps `nu --ide-check`, which reports diagnostics as JSON on stdout but always
# exits 0. Indentation is the `editorconfig-checker` hook's job.
# ==============================================================================

const MAX_ERRORS = 100

# A `@name@` placeholder only parses once Nix has substituted it. `[]` stands in
# because it satisfies a `list` parameter and degrades to a string in quotes,
# where a bare word would trip the type checker.
def substitute [text: string, stub: string]: nothing -> string {
  $text
  | str replace --regex --multiline '^(use\s+)@[a-zA-Z][a-zA-Z0-9]*@' $"${1}($stub)"
  | str replace --all --regex '@[a-zA-Z][a-zA-Z0-9]*@' "[]"
}

def diagnostics [target: string]: nothing -> list<string> {
  ^$nu.current-exe --ide-check $MAX_ERRORS $target
  | complete
  | get stdout
  | lines
  | each {|line| try { $line | from json } catch { {} } }
  | where ($it.severity? | default "") == "Error"
  | each {|d| $"  ($d.message) \(offset ($d.span.start)\)" }
}

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

    # `open --raw` yields a byte stream, and the `-> string` signature below
    # rejects invalid UTF-8 with a trace naming this script instead of the file.
    let text = (try { open --raw $file | into string } catch { null })
    if $text == null {
      print -e $"($file): not valid UTF-8"
      $failed = true
      continue
    }

    let target = (mktemp --tmpdir --suffix .nu)
    substitute $text $stub | save --force $target

    let errors = (diagnostics $target)
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
