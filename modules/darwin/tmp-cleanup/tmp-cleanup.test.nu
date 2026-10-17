#!/usr/bin/env nu

# ==================================================================================================
# /tmp Cleanup Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join tmp-cleanup.nu)
const LSOF_STUB = ($SCRIPT_DIR | path join lsof.stub.nu)

# Creates an empty cleanup root. Entries are created relative to it.
def make-root []: nothing -> string {
  mktemp --directory | path expand
}

# Runs the cleanup over `root` with a stubbed lsof that reports `open` as held open. `left` lists
# the entries remaining afterwards.
def clean [root: string, args: list<string>, open: list<string> = [], status: int = 0]: nothing -> record {
  let bin = (mktemp --directory)
  let lsof = ($bin | path join lsof)
  $"#!($nu.current-exe) --no-config-file\n" + (open --raw $LSOF_STUB) | save $lsof
  ^chmod +x $lsof

  let run = (
    with-env {
      PATH: ([$bin] | append $env.PATH)
      STUB_OPEN: ($open | each {|p| $root | path join $p } | str join "\n")
      STUB_STATUS: ($status | into string)
    } {
      ^$nu.current-exe --no-config-file $SCRIPT --root $root ...$args | complete
    }
  )
  $run | insert left (ls --all $root | get name | path basename | sort)
}

def "test only trees without recent changes are removed" [] {
  let root = (make-root)
  mkdir ($root | path join stale/ro) ($root | path join mixed)
  touch ($root | path join stale/ro/file) ($root | path join mixed/old) ($root | path join old-file)
  ^chmod -R a-w ($root | path join stale)
  sleep 2sec
  mkdir ($root | path join mixed/sub)
  touch ($root | path join mixed/sub/new) ($root | path join fresh)
  ^touch -m -t 202001010000 ($root | path join copied)

  let run = (clean $root [--max-age 1sec])

  assert equal $run.exit_code 0 $run.stderr
  assert equal $run.left [copied fresh mixed]
}

def "test entries held open are kept" [] {
  let root = (make-root)
  mkdir ($root | path join held/deep) ($root | path join idle)

  let run = (clean $root [--max-age 0sec] [held/deep/file])

  assert equal $run.exit_code 0 $run.stderr
  assert equal $run.left [held]
}

def "test runtime dirs and pipes are kept" [] {
  let root = (make-root)
  mkdir ($root | path join claude-501) ($root | path join tmux-501) ($root | path join review)
  ^mkfifo ($root | path join steam.pipe)

  let run = (clean $root [--max-age 0sec])

  assert equal $run.exit_code 0 $run.stderr
  assert equal $run.left [claude-501 steam.pipe tmux-501]
}

def "test a dry run removes nothing" [] {
  let root = (make-root)
  mkdir ($root | path join review)

  let run = (clean $root [--max-age 0sec --dry-run])

  assert equal $run.exit_code 0 $run.stderr
  assert str contains $run.stdout review
  assert equal $run.left [review]
}

def "test an lsof failure removes nothing" [] {
  let root = (make-root)
  mkdir ($root | path join review)

  let run = (clean $root [--max-age 0sec] [] 1)

  assert not equal $run.exit_code 0
  assert equal $run.left [review]
}
