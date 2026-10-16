#!/usr/bin/env nu

# ==================================================================================================
# Nushell Test Runner
# ==================================================================================================
# A test is a command named `test <behavior>` in a `.test.nu` file. Each runs in its own `nu`
# process, so a test that changes its environment or exits cannot affect the others.
# ==================================================================================================

def nu-run [file: string, body: string]: nothing -> record {
  ^$nu.current-exe --no-config-file --commands $"source ($file | to nuon)\n($body)" | complete
}

# The outcome of every test in `file`, or a single failure when the file does not load.
def run-file [file: string]: nothing -> list<record> {
  let path = ($file | path expand)
  let found = (nu-run $path "scope commands | where name starts-with 'test ' | get name | to json")
  if $found.exit_code != 0 {
    return [{file: $file, name: "(load)", run: $found}]
  }
  $found.stdout | from json | each {|name| {file: $file, name: $name, run: (nu-run $path $name)} }
}

# Run every test in the given files, exiting nonzero if any fails or none exist.
def main [
  ...files: string # `.test.nu` files to run
] {
  let results = (
    $files
    | each {|file|
      let scratch = (mktemp --directory)
      let results = with-env {TMPDIR: $scratch} { run-file $file }
      rm --recursive --force $scratch
      $results
    }
    | flatten
  )

  for result in $results {
    if $result.run.exit_code == 0 {
      print $"PASS ($result.file): ($result.name)"
    } else {
      print -e $"FAIL ($result.file): ($result.name)\n($result.run.stdout)($result.run.stderr)"
    }
  }

  let failed = ($results | where run.exit_code != 0 | length)
  let passed = ($results | length) - $failed
  print $"($passed) passed, ($failed) failed"
  if $failed > 0 or $passed == 0 {
    exit 1
  }
}
