#!/usr/bin/env nu

# ==================================================================================================
# PicList Upload Key Map Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self .
const SCRIPT = ($SCRIPT_DIR | path join piclist-upload-key.nu)

def run-script [token_file: string, output_dir: string] {
  let output_file = ($output_dir | path join key.map)

  let run = (^$nu.current-exe --no-config-file $SCRIPT $token_file $output_file | complete)
  let map = (
    if ($output_file | path exists) { open --raw $output_file | into string } else { "<missing>" }
  )
  let mode = (
    if ($output_file | path exists) { ls -l $output_file | get 0.mode } else { "<missing>" }
  )
  {run: $run, map: $map, mode: $mode}
}

def token-file [dir: string, raw: string] {
  let path = ($dir | path join token)
  $raw | save --force --raw $path
  $path
}

def entries [dir: string] {
  ls $dir | get name | path basename | sort
}

def "test the generator renders a literal, fail-closed map" [] {
  let cases = [
    {
      name: "valid"
      raw: "Correct-Token_abc.123"
      accepted: true
      map: '"~^\QCorrect-Token_abc.123\E$" 1;'
    }
    {
      name: "valid trailing newline"
      raw: "Correct-Token-abc123\n"
      accepted: true
      map: '"~^\QCorrect-Token-abc123\E$" 1;'
    }
    {name: "map keyword default", raw: "default", accepted: true, map: '"~^\Qdefault\E$" 1;'}
    {name: "empty", raw: "", accepted: false}
    {name: "tilde", raw: "a~b", accepted: false}
    {name: "percent", raw: "a%b", accepted: false}
    {name: "embedded newline", raw: "a\nb", accepted: false}
  ]

  for case in $cases {
    let dir = (mktemp --directory)
    let result = (run-script (token-file $dir $case.raw) $dir)
    assert equal $result.run.exit_code 0 $"($case.name): ($result.run.stderr)"

    if $case.accepted {
      assert equal $result.map ($case.map + "\n") $case.name
      assert not ($result.run.stdout | str contains $case.raw) $case.name
    } else {
      assert equal $result.map "" $case.name
      assert str contains $result.run.stderr "outside A-Z" $case.name
      if not ($case.raw | is-empty) {
        assert not ($result.run.stderr | str contains $case.raw) $case.name
      }
    }
  }
}

def "test a missing token file writes a fail-closed map" [] {
  let dir = (mktemp --directory)
  let token_file = ($dir | path join missing)

  let result = (run-script $token_file $dir)
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal $result.map ""
  assert str contains $result.run.stderr "cannot be read"
}

def "test a rerun replaces the map and leaves no temporary file" [] {
  let dir = (mktemp --directory)
  let token_file = (token-file $dir "Correct-Token-abc123")

  let first = (run-script $token_file $dir)
  assert equal $first.run.exit_code 0 $first.run.stderr
  assert equal $first.map ('"~^\QCorrect-Token-abc123\E$" 1;' + "\n")
  assert equal $first.mode "r--------"
  assert equal (entries $dir) [key.map, token]

  token-file $dir "Rotation-Token_xyz.789" | ignore
  let rotated = (run-script $token_file $dir)
  assert equal $rotated.run.exit_code 0 $rotated.run.stderr
  assert equal $rotated.map ('"~^\QRotation-Token_xyz.789\E$" 1;' + "\n")
  assert equal (entries $dir) [key.map, token]

  token-file $dir "bad token/%" | ignore
  let revoked = (run-script $token_file $dir)
  assert equal $revoked.run.exit_code 0 $revoked.run.stderr
  assert equal $revoked.map ""
  assert equal (entries $dir) [key.map, token]
}

def "test a missing output directory fails" [] {
  let dir = (mktemp --directory)
  let token_file = (token-file $dir "Correct-Token-abc123")

  let result = (run-script $token_file ($dir | path join missing))
  assert not equal $result.run.exit_code 0
}
