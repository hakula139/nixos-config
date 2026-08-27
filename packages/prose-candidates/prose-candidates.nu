#!/usr/bin/env nu

# ==============================================================================
# Prose Tic Candidates
# ==============================================================================

# A pattern has to be single-quoted, since `"..."` rejects `\w` as an
# unrecognized escape, and an apostrophe inside one has to be `\x27`.
const TICS = [
  [name fails-commit skip-han pattern];
  # The digit exclusions are what keep an arithmetic minus out.
  ["dash" false false '(?<![\x{4e00}-\x{9fff}—])—(?![\x{4e00}-\x{9fff}—])|(?<=\w)--(?=\w)|(?<=(?:[^\W\d]|[`)\]"\x27])\s)(?:--|[-–−])(?=\s(?:[^\W\d]|[`(\["\x27]))']
  # A same-line terminator still reports, left to the judge.
  ["semicolon" false false '(?<!&[a-z]{2,8})(?<=[\w)\]"\x27])\s*;(?=\s+\w)']
  ["antithesis" false false '\b\w+, not\b|\brather than\b|\binstead of\b|\bas opposed to\b']
  ["empty-summary" true false '\b(?:In summary|Overall|To recap|To sum up|All in all)\b']
  ["connector" false false '\b(?:however|therefore|moreover|furthermore|additionally)\b']
  ["intensifier" true false '\b(?:extremely|incredibly|absolutely|vastly|hugely|massively|utterly)\b']
  ["absolutist" true false '\b(?:bug-free|production-ready|fully verified|guaranteed|bulletproof|rock-solid|battle-tested)\b']
  # Chinese puts its sentence-final mark inside the closing quote, and the mark
  # is not Han, so no test on the adjacent character can separate the scripts.
  ["typographic" true true '…|[“”‘’]']
]

# The guide's own rule lists would otherwise report every word they enumerate.
const NAMED = '`[^`]*`|"[\w -]{1,20}"|\x27[\w -]{1,20}\x27'

def candidates [text: string]: nothing -> list<record> {
  mut fenced = false
  mut found = []
  for entry in ($text | lines | enumerate) {
    let raw = $entry.item
    if ($raw | str trim | str starts-with '```') {
      $fenced = (not $fenced)
      continue
    }
    if $fenced { continue }
    let line = ($raw | str replace --regex --all $NAMED ' ')
    let han = ($line =~ '\p{Han}')
    for tic in $TICS {
      if $han and $tic.skip-han { continue }
      # `parse` yields a row per match only when the pattern captures.
      let hits = ($line | parse --regex ('(?i)(?<m>' + $tic.pattern + ')'))
      for hit in $hits {
        $found = ($found | append {
          line: ($entry.index + 1)
          tic: $tic.name
          match: ($hit.m | str trim)
          context: ($raw | str trim | str substring --grapheme-clusters 0..<200)
        })
      }
    }
  }
  $found
}

def render [rows: list<record>, prefix: string]: nothing -> list<string> {
  $rows | each {|r| $"($prefix)L($r.line) ($r.tic): ($r.match)  |  ($r.context)" }
}

# One connector is fine, so the class is only worth reporting when it recurs.
def drop-lone-connector [found: list<record>]: nothing -> list<record> {
  if (($found | where tic == "connector" | length) < 2) {
    $found | where tic != "connector"
  } else {
    $found
  }
}

def main [...files: string] {
  if ($files | is-empty) {
    let rows = (drop-lone-connector (candidates (^cat)))
    render $rows "" | each {|line| print $line }
    return
  }

  let blocking = ($TICS | where fails-commit | get name)
  mut failed = false
  mut banned = false
  for file in $files {
    # `path type` reports a symlink as such, and `CLAUDE.md` is one.
    if ($file | path expand | path type) != "file" {
      print -e $"($file): not a readable file"
      $failed = true
      continue
    }
    # `candidates` rejects a byte stream, outside whatever `try` wraps the open.
    let text = (try { open --raw $file | into string } catch { null })
    if $text == null {
      print -e $"($file): not valid UTF-8"
      $failed = true
      continue
    }

    let rows = (drop-lone-connector (candidates $text))
    if ($rows | is-empty) { continue }
    render $rows $"($file):" | each {|line| print -e $line }
    if ($rows | any {|r| $r.tic in $blocking }) {
      $banned = true
    }
  }
  if $banned {
    print -e $"The style guide bans ($blocking | str join ', ') with no exemption."
  }
  if $failed or $banned {
    exit 1
  }
}
