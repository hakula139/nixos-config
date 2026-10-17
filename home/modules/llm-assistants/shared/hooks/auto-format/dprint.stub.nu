#!/usr/bin/env nu

# ==================================================================================================
# dprint Stub
# ==================================================================================================
# Stands in for dprint in the auto-format tests. Like dprint-plugin-markdown, it formats a fence
# tagged `markdown` or `md` as a nested document, here by adding a blank line after each HTML
# comment inside it, and passes every other line through.
# ==================================================================================================

def --wrapped main [...args: string] {
  ^cat
  | lines
  | reduce --fold {fence: null, out: []} {|line, state|
    let opening = ($line | parse --regex '^\s*(?<fence>`{3,}|~{3,})\s*(?<tag>\S*)')
    if $state.fence == null {
      let fence = if ($opening | is-empty) {
        null
      } else {
        {marker: $opening.0.fence, nested: ($opening.0.tag | str downcase | $in in [markdown md])}
      }
      {fence: $fence, out: ($state.out | append $line)}
    } else if ($line | str trim) == $state.fence.marker {
      {fence: null, out: ($state.out | append $line)}
    } else if $state.fence.nested and ($line | str starts-with "<!--") {
      {fence: $state.fence, out: ($state.out | append [$line ""])}
    } else {
      {fence: $state.fence, out: ($state.out | append $line)}
    }
  }
  | get out
  | each { $in + "\n" }
  | str join
  | print --no-newline $in
}
