#!/usr/bin/env nu

# ==============================================================================
# Nushell Diagnostic Check
# ==============================================================================
# Wraps `nu --ide-check`, which reports diagnostics as JSON on stdout but always
# exits 0. Indentation is the `editorconfig-checker` hook's job.
# ==============================================================================

const MAX_ERRORS = 100

def diagnostics [target: string]: nothing -> list<string> {
  ^$nu.current-exe --ide-check $MAX_ERRORS $target
  | complete
  | get stdout
  | from json --objects
  | where ($it.severity? | default "") == "Error"
  | each {|d| $"  ($d.message) \(offset ($d.span.start)\)" }
}

def main [...files: string] {
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

    let errors = (diagnostics $file)
    if ($errors | is-not-empty) {
      print -e $"($file):"
      $errors | each {|e| print -e $e }
      $failed = true
    }
  }
  if $failed {
    exit 1
  }
}
