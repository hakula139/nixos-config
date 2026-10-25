#!/usr/bin/env nu

# ==================================================================================================
# Proxy Helper Tests
# ==================================================================================================

use std/assert
use std-rfc/str

def expected-env [url: string]: nothing -> string {
  let no_proxy = "localhost,127.0.0.1,10.*,example.test"
  [
    $"HTTP_PROXY=($url)"
    $"HTTPS_PROXY=($url)"
    $"NO_PROXY=($no_proxy)"
    $"http_proxy=($url)"
    $"https_proxy=($url)"
    $"no_proxy=($no_proxy)"
    ""
  ] | str join (char nl)
}

def run-proxy [
  dir: string
  script: string
  --no-errexit
  --changing-secret
]: nothing -> record {
  let paths = if $changing_secret { [$env.NU_TEST_STUBS ...$env.PATH] } else { $env.PATH }
  let flags = if $no_errexit { [-u -o pipefail] } else { [-e -u -o pipefail] }
  let consumer = (
    '
    cd "$1"
    source "$2"
    printf "%s\n" \
      "HTTP_PROXY=$HTTP_PROXY" \
      "HTTPS_PROXY=$HTTPS_PROXY" \
      "NO_PROXY=$NO_PROXY" \
      "http_proxy=$http_proxy" \
      "https_proxy=$https_proxy" \
      "no_proxy=$no_proxy" >consumer
    '
    | str dedent
  )

  (
    ^env -i $"PATH=($paths | str join ':')"
    HTTP_PROXY=stale HTTPS_PROXY=stale NO_PROXY=stale
    http_proxy=stale https_proxy=stale no_proxy=stale
    bash ...$flags -c $consumer -- $dir $script
    | complete
  )
}

def "test literal and secret values reach every proxy variable unchanged" [] {
  let fixtures = (open $env.PROXY_TEST_FIXTURES)
  let cases = [
    {name: normal, scripts: $fixtures.normal, url: $fixtures.normalUrl, secret: false}
    {name: literal, scripts: $fixtures.literal, url: $fixtures.literalUrl, secret: false}
    {name: empty, scripts: $fixtures.empty, url: "", secret: false}
    {name: secret, scripts: $fixtures.secret, url: $fixtures.literalUrl, secret: true}
  ]

  for case in $cases {
    for kind in [script envFile] {
      let dir = (mktemp --directory)
      if $case.secret { ($case.url + (char nl)) | save ($dir | path join "proxy secret") }

      let run = (run-proxy $dir ($case.scripts | get $kind))
      assert equal $run.exit_code 0 $"($case.name) ($kind): ($run.stderr)"

      let output = if $kind == script { "consumer" } else { "proxy environment" }
      assert equal (open --raw ($dir | path join $output)) (expected-env $case.url)
      assert equal $run.stdout ""
      for marker in [backtick substitution] {
        assert not ($dir | path join $marker | path exists) $"executed ($marker)"
      }
    }
  }
}

def "test required secret failures stop consumers and preserve environment files" [] {
  let fixtures = (open $env.PROXY_TEST_FIXTURES)
  let original = "KEEP=original\n"
  let cases = [
    {kind: script, strict: true, existing: false}
    {kind: script, strict: false, existing: false}
    {kind: envFile, strict: true, existing: false}
    {kind: envFile, strict: true, existing: true}
  ]

  for failure in [missing unreadable empty] {
    for case in $cases {
      let dir = (mktemp --directory)
      let secret = ($dir | path join "proxy secret")
      let dest = ($dir | path join "proxy environment")
      if $failure == empty { "" | save $secret }
      if $failure == unreadable {
        $fixtures.normalUrl | save $secret
        ^chmod 000 $secret
      }
      if $case.existing { $original | save $dest }

      let run = (run-proxy $dir ($fixtures.secret | get $case.kind) --no-errexit=(not $case.strict))
      if $failure == unreadable { ^chmod 600 $secret }

      let context = $"($failure), ($case | to nuon): ($run.stderr)"
      assert not equal $run.exit_code 0 $context
      assert str contains $run.stderr "proxy secret" $context
      assert equal $run.stdout "" $context
      assert not ($dir | path join consumer | path exists) $context
      if $case.existing {
        assert equal (open --raw $dest) $original $context
      } else {
        assert not ($dest | path exists) $context
      }
    }
  }
}

def "test one secret read supplies a consistent value to every variable" [] {
  let fixtures = (open $env.PROXY_TEST_FIXTURES)

  for kind in [script envFile] {
    let dir = (mktemp --directory)
    $fixtures.normalUrl | save ($dir | path join "proxy secret")

    let run = (run-proxy $dir ($fixtures.secret | get $kind) --changing-secret)
    assert equal $run.exit_code 0 $"($kind): ($run.stderr)"

    let output = if $kind == script { "consumer" } else { "proxy environment" }
    assert equal (open --raw ($dir | path join $output)) (expected-env $fixtures.normalUrl) $kind
    assert equal (open --raw ($dir | path join "proxy secret")) (
      "http://changed.proxy.example.test:8081"
    )
  }
}
