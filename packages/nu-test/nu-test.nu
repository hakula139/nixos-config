#!/usr/bin/env nu

# ==================================================================================================
# Nushell Test Runner
# ==================================================================================================
# A test is a command named `test <behavior>` in a `.test.nu` file. Each runs in its own `nu`
# process, so a test that changes its environment or exits cannot affect the others. Each
# `<name>.stub.nu` beside a test file is installed as an executable `<name>` in `NU_TEST_STUBS`.
# ==================================================================================================

def nu-run [file: string, body: string]: nothing -> record {
  ^$nu.current-exe --no-config-file --commands $"source ($file | to nuon)\n($body)" | complete
}

# Installs each `<name>.stub.nu` beside `file` in `dir` as an executable `<name>`. The shebang
# names this interpreter by its store path, since the build sandbox has no `/usr/bin/env`.
def install-stubs [file: string, dir: string]: nothing -> nothing {
  mkdir $dir
  let source = ($file | path expand | path dirname)
  for stub in (ls $source | where name ends-with ".stub.nu" | get name) {
    let target = ($dir | path join ($stub | path basename | str replace ".stub.nu" ""))
    open --raw $stub
    | str replace --regex '^#!.*' $"#!($nu.current-exe) --no-config-file"
    | save $target

    ^chmod +x $target
  }
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
      let stubs = ($scratch | path join stubs)
      install-stubs $file $stubs
      let results = with-env {TMPDIR: $scratch, NU_TEST_STUBS: $stubs} { run-file $file }
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
