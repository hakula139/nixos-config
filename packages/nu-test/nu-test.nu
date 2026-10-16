#!/usr/bin/env nu

# ==================================================================================================
# Nushell Test Runner
# ==================================================================================================
# A test is a command named `test <description>` in a `.test.nu` file. Each runs in its own `nu`
# process, so a test that changes its environment or exits cannot affect the others.
# ==================================================================================================

def nu-run [file: string, body: string]: nothing -> record {
  ^$nu.current-exe --no-config-file --commands $"source ($file | to nuon)\n($body)" | complete
}

def tests [file: string]: nothing -> list<string> {
  let run = (nu-run $file "scope commands | where name starts-with 'test ' | get name | to json")
  if $run.exit_code != 0 {
    error make {msg: $"($file): failed to load\n($run.stderr)"}
  }
  $run.stdout | from json
}

# Run every test in the given files, exiting nonzero if any fails.
def main [...files: string] {
  mut failed = 0
  mut passed = 0

  for file in $files {
    let file = ($file | path expand)
    # Tests write fixtures with `mktemp`, and this keeps them out of the shared temp directory.
    let scratch = (mktemp --directory)
    for name in (with-env {TMPDIR: $scratch} { tests $file }) {
      let run = with-env {TMPDIR: $scratch} { nu-run $file $name }
      if $run.exit_code == 0 {
        $passed += 1
        print $"PASS ($file | path basename): ($name)"
      } else {
        $failed += 1
        print -e $"FAIL ($file | path basename): ($name)\n($run.stdout)($run.stderr)"
      }
    }
    rm --recursive --force $scratch
  }

  print $"($passed) passed, ($failed) failed"
  if $failed > 0 or $passed == 0 {
    exit 1
  }
}
