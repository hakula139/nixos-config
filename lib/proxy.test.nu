#!/usr/bin/env nu

# ==================================================================================================
# Proxy Helper Tests
# ==================================================================================================

use std/assert
use std-rfc/str

def expected-env [url: string]: nothing -> string {
  let no_proxy = 'localhost,127.0.0.1,10.*,example.test,host$var`x`\y"z'
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

def expected-env-file [quoted_url: string]: nothing -> string {
  let no_proxy = '"localhost,127.0.0.1,10.*,example.test,host\$var\`x\`\\y\"z"'
  [
    $"HTTP_PROXY=($quoted_url)"
    $"HTTPS_PROXY=($quoted_url)"
    $"NO_PROXY=($no_proxy)"
    $"http_proxy=($quoted_url)"
    $"https_proxy=($quoted_url)"
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

def assert-output [dir: string, kind: string, url: string, quoted_url: string] {
  if $kind == envFile {
    let file = ($dir | path join "proxy environment")
    assert equal (open --raw $file) (expected-env-file $quoted_url)

    let run = (run-proxy $dir $file)
    assert equal $run.exit_code 0 $run.stderr
  }

  assert equal (open --raw ($dir | path join consumer)) (expected-env $url)
  for marker in [backtick substitution] {
    assert not ($dir | path join $marker | path exists) $"executed ($marker)"
  }
}

def "test literal and secret values reach every proxy variable unchanged" [] {
  let fixtures = (open $env.PROXY_TEST_FIXTURES)
  let cases = [
    {
      name: normal, scripts: $fixtures.normal, url: $fixtures.normalUrl
      quoted: ('"' + $fixtures.normalUrl + '"'), secret: false
    }
    {
      name: literal, scripts: $fixtures.literal, url: $fixtures.literalUrl
      quoted: $fixtures.quotedLiteralUrl, secret: false
    }
    {name: empty, scripts: $fixtures.empty, url: "", quoted: '""', secret: false}
    {
      name: secret, scripts: $fixtures.secret, url: $fixtures.literalUrl
      quoted: $fixtures.quotedLiteralUrl, secret: true
    }
  ]

  for case in $cases {
    for kind in [script envFile] {
      let dir = (mktemp --directory)
      if $case.secret { ($case.url + (char nl)) | save ($dir | path join "proxy secret") }

      let run = (run-proxy $dir ($case.scripts | get $kind))
      assert equal $run.exit_code 0 $"($case.name) ($kind): ($run.stderr)"

      assert-output $dir $kind $case.url $case.quoted
      assert equal $run.stdout ""
    }
  }
}

def "test dash prefixed secret filenames are read as paths" [] {
  let fixtures = (open $env.PROXY_TEST_FIXTURES)

  for kind in [script envFile] {
    let dir = (mktemp --directory)
    $fixtures.normalUrl | save ($dir | path join "-n")

    let run = (run-proxy $dir ($fixtures.dashSecret | get $kind))
    assert equal $run.exit_code 0 $"($kind): ($run.stderr)"

    assert-output $dir $kind $fixtures.normalUrl ('"' + $fixtures.normalUrl + '"')
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

    assert-output $dir $kind $fixtures.normalUrl ('"' + $fixtures.normalUrl + '"')
    assert equal (open --raw ($dir | path join "proxy secret")) (
      "http://changed.proxy.example.test:8081"
    )
  }
}
