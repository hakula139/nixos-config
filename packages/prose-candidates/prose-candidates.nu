#!/usr/bin/env nu

# ==============================================================================
# Prose Tic Candidates
# ==============================================================================
# Enumerates the literal surface forms of the banned tics, so the judge rules on
# candidates rather than having to spot them, which it demonstrably failed at.
# ==============================================================================

# A pattern has to be single-quoted, since `"..."` rejects `\w` as an
# unrecognized escape, and an apostrophe inside one has to be `\x27`.
#
# `block` marks the tics the guide bans with no exemption, the only ones a commit
# can be failed on. The rest turn on a judgement no regex can make.
const TICS = [
  [name block pattern];
  # Excludes a dash doing its own job: a compound, a numeric range, a `--flag`,
  # a list bullet, an arrow.
  ["dash" false '(?<![\x{4e00}-\x{9fff}—])—(?![\x{4e00}-\x{9fff}—])|(?<=\w)--(?=\w)|(?<=[\w`)\]"\x27]\s)(?:--|[-–−])(?=\s[\w`(\["\x27])']
  # Excludes statement terminators, which would report every line of Nix or Python.
  ["semicolon" false '(?<=[\w"\x27])\s*;(?=\s+\w)']
  ["antithesis" false '\b\w+, not\b|\brather than\b|\binstead of\b|\bas opposed to\b']
  ["empty-summary" true '\b(?:In summary|Overall|To recap|To sum up|All in all)\b']
  ["connector" false '\b(?:however|therefore|moreover|furthermore|additionally)\b']
  ["intensifier" true '\b(?:extremely|incredibly|absolutely|vastly|hugely|massively|utterly)\b']
  ["absolutist" true '\b(?:bug-free|production-ready|fully verified|guaranteed|bulletproof|rock-solid|battle-tested)\b']
  # `……` and `“”` are correct Chinese punctuation, so these count only outside Han text.
  ["typographic" true '(?<![\x{4e00}-\x{9fff}…])(?:…|[“”‘’])(?![\x{4e00}-\x{9fff}…])']
]

# A backticked or briefly quoted span names a term instead of using it, so a rule
# list enumerating banned words would otherwise report every one of them.
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
    for tic in $TICS {
      # `parse` yields a row per match only when the pattern captures.
      let hits = ($line | parse --regex ('(?i)(?<m>' + $tic.pattern + ')'))
      for hit in $hits {
        $found = ($found | append {
          line: ($entry.index + 1)
          tic: $tic.name
          match: ($hit.m | str trim)
          context: ($raw | str trim | str substring 0..<120)
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

# Stdin reports and always succeeds, for the advisory hook. File arguments make it
# a commit gate that fails once a file carries a tic the guide bans outright.
def main [...files: string] {
  if ($files | is-empty) {
    let rows = (drop-lone-connector (candidates (^cat)))
    if ($rows | is-empty) {
      print "none"
      return
    }
    render $rows "" | each {|line| print $line }
    return
  }

  mut blocked = false
  for file in $files {
    let text = (try { open --raw $file } catch { "" })
    let rows = (drop-lone-connector (candidates $text))
    if ($rows | is-empty) { continue }
    render $rows $"($file):" | each {|line| print $line }
    if (($rows | where tic in ($TICS | where block | get name) | length) > 0) {
      $blocked = true
    }
  }
  if $blocked {
    error make --unspanned {
      msg: "prose tics the style guide bans outright; see the lines above"
    }
  }
}
