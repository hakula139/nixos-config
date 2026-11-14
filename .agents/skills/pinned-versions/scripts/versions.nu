# ==================================================================================================
# Pinned Version Comparison
# ==================================================================================================
# Version ordering and tag selection shared by the drift checker and its tests.
# ==================================================================================================

# Whether the left version is at or above the right one. The release core compares first, and a
# final release ranks above the same core's pre-release.
def version-at-least [left: string, right: string]: nothing -> bool {
  let left_core = ($left | split row "-" | first | str replace -r "^v" "")
  let right_core = ($right | split row "-" | first | str replace -r "^v" "")
  let left_suffix = ($left | split row "-" | skip 1 | str join "-")
  let right_suffix = ($right | split row "-" | skip 1 | str join "-")

  if $left_core != $right_core {
    ([$left_core $right_core] | sort --natural | last) == $left_core
  } else if ($left_suffix | is-empty) != ($right_suffix | is-empty) {
    $left_suffix | is-empty
  } else {
    ([$left_suffix $right_suffix] | sort --natural | last) == $left_suffix
  }
}

# Whether the left version is below the right one.
def version-older [left: string, right: string]: nothing -> bool {
  not (version-at-least $left $right)
}

# The release a commit-pinned version derives from. Nixpkgs writes such a version as
# `<release>-unstable-<date>`, which no upstream tag matches.
def version-base [version: string]: nothing -> string {
  $version | str replace -r -- '-unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}$' ''
}

# The highest version-shaped tag, optionally including pre-releases.
def newest-version [tags: list<string>, --allow-pre-release]: nothing -> string {
  let pattern = if $allow_pre_release {
    '^v?[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?$'
  } else {
    '^v?[0-9]+(\.[0-9]+)*$'
  }

  $tags
  | where {|tag| $tag =~ $pattern }
  | reduce --fold "" {|tag, newest|
    if ($newest | is-empty) or (version-at-least $tag $newest) { $tag } else { $newest }
  }
}
