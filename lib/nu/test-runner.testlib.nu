# ==================================================================================================
# Test Runner Helpers
# ==================================================================================================

# Run a checked-in Nushell script in an isolated child process and return its `complete` record.
export def --wrapped run-script [script: path, ...args: string]: any -> record {
  let lib_dirs = $env.NU_LIB_DIRS? | default []
  let include = if ($lib_dirs | describe) == "string" {
    $lib_dirs
  } else {
    $lib_dirs | str join (char esep)
  }
  let include_args = if ($include | is-empty) {
    []
  } else {
    [--include-path $include]
  }

  $in
  | (
    ^$nu.current-exe
      --no-config-file
      ...$include_args
      $script
      ...$args
  )
  | complete
}
