#!/usr/bin/env nu

# ==================================================================================================
# PicList Upload Key Map
# ==================================================================================================

# Read the token file, dropping one trailing newline. Returns the token, or why it cannot be used.
def read-token [token_file: string] {
  try {
    {token: (open --raw $token_file | into string | str replace --regex '\n$' ''), reason: ""}
  } catch {|err|
    {token: "", reason: $"file ($token_file) cannot be read: ($err.msg)"}
  }
}

# Return the token when every character survives every query encoder, or the reason it does not.
def validate-key [token: string] {
  if ($token =~ '^[A-Za-z0-9._-]+$') {
    {token: $token, reason: ""}
  } else {
    {token: "", reason: 'contains characters outside A-Z, a-z, 0-9, dot, underscore and hyphen'}
  }
}

# nginx must never read a partial map.
def write-map [output_file: string, content: string] {
  let dir = ($output_file | path dirname)
  let tmp = (mktemp --tmpdir-path $dir piclist-upload-key.XXXXXX)
  $content | save --force --raw $tmp
  ^chmod 400 $tmp
  ^mv -f $tmp $output_file
}

# Render an nginx map include that admits only the exact key query parameter value.
def main [
  token_file: string  # Path to the file holding the upload key
  output_file: string  # Path of the map include to write
] {
  let read = (read-token $token_file)
  let check = (if ($read.reason | is-empty) { validate-key $read.token } else { $read })
  if not ($check.reason | is-empty) {
    print --stderr $"PicList upload key ($check.reason). The upload map authorizes nothing."
    write-map $output_file ""
    return
  }

  # A case-sensitive anchored PCRE regex. The leading ~ marks the entry as a regex, so `default` and
  # `include` stay literal keys. \Q..\E quotes regex metacharacters such as `.`.
  let entry = ('"~^\Q' + $check.token + '\E$" 1;' + "\n")
  write-map $output_file $entry
  print "Rendered the PicList upload key map"
}
