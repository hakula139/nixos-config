#!/usr/bin/env nu

# ==================================================================================================
# Cursor CLI Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  {args: $args}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  match $args {
    ["--list-extensions"] => {
      let exit_code = ($env.STUB_LISTING_EXIT? | default "0" | into int)
      if $exit_code != 0 {
        print -e "Unable to connect to VS Code server: Error in request.\nError: connect failed"
        exit $exit_code
      }
      print --no-newline $env.STUB_LISTING
    }
    [_ $id] if $id == $env.STUB_FAILING_ID? => {
      print $"Extension diagnostic: ($id)"
      print -e $"Failed Installing Extensions: ($id)"
      exit 1
    }
    [_ $id] => {
      print $"Extension info: ($id)"
      print -e $"Extension progress: ($id)"
    }
  }
}
