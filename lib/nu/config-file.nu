# ==================================================================================================
# Config File Helpers
# ==================================================================================================
# Read and replace the config files that activation scripts merge managed settings into.
# ==================================================================================================

# Read a structured file as a record, or an empty one when it is missing, empty, or not a record.
export def open-record [path: path]: nothing -> record {
  if not ($path | path exists) {
    return {}
  }

  let content = (open $path)
  if ($content | describe | str starts-with "record") { $content } else { {} }
}

# Replace a file with the content through a temporary file in its directory, so a reader never sees
# a partial write. The temporary file is removed when the write fails.
export def save-atomic [content: string, target: path] {
  let temporary = (
    mktemp --tmpdir-path ($target | path dirname) $".($target | path basename).XXXXXXXXXX"
  )

  try {
    $content | save --raw --force $temporary
    ^mv --force $temporary $target
  } catch {|error|
    rm --force $temporary
    error make $error
  }
}
