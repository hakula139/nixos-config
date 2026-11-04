#!/usr/bin/env nu

# ==================================================================================================
# Nushell Test Runner
# ==================================================================================================
# A test is a command named `test <behavior>` in a `.test.nu` file. Each runs in its own `nu`
# process with its own `TMPDIR`, so a test that changes its environment or exits cannot affect the
# others. Each `<name>.stub.nu` beside a test file is installed as `<name>` in `NU_TEST_STUBS`.
# ==================================================================================================

def nu-run [file: string, body: string, tmp: string, stubs: string]: nothing -> record {
  with-env {TMPDIR: $tmp, NU_TEST_STUBS: $stubs} {
    ^$nu.current-exe --no-config-file --commands $"source ($file | to nuon)\n($body)" | complete
  }
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

# Creates the scratch directory and stubs for `file`, then returns them with one job per test, or
# one job carrying the discovery failure when the file does not load.
def plan-file [file: string]: nothing -> record {
  let path = ($file | path expand)
  let scratch = (mktemp --directory)
  let stubs = ($scratch | path join stubs)
  install-stubs $file $stubs
  let query = "scope commands | where name starts-with 'test ' | get name | to json"
  let found = (nu-run $path $query $scratch $stubs)
  let jobs = if $found.exit_code != 0 {
    [{file: $file, name: "(load)", run: $found}]
  } else {
    try {
      $found.stdout
      | from json
      | each {|name| {file: $file, name: $name, path: $path, scratch: $scratch, stubs: $stubs} }
    } catch {|err|
      let run = ($found | update exit_code 1 | update stderr $err.rendered)
      [{file: $file, name: "(load)", run: $run}]
    }
  }

  {scratch: $scratch, jobs: $jobs}
}

# Runs `job` in a fresh `TMPDIR` under its file's scratch, or returns any discovery failure.
def run-job [job: record]: nothing -> record {
  if ($job.run? != null) { return $job }
  let tmp = (mktemp --directory --tmpdir-path $job.scratch)
  {file: $job.file, name: $job.name, run: (nu-run $job.path $job.name $tmp $job.stubs)}
}

# Run every test in the given files, exiting nonzero if any fails or none exist.
def main [
  ...files: string # `.test.nu` files to run
] {
  # Nested `par-each` builds a private thread pool per inner call, so plan every test first and
  # run the flat job list on one default-size pool.
  let plans = ($files | par-each --keep-order {|file| plan-file $file })
  let results = ($plans | get jobs | flatten | par-each --keep-order {|job| run-job $job })
  for plan in $plans { rm --recursive --force $plan.scratch }

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
