#!/usr/bin/env nu

# ==================================================================================================
# Prose Polish
# ==================================================================================================
# Rewrites prose through a gateway model and keeps only rewrites that pass the fidelity checks.
# ==================================================================================================

# A fence opens with any indentation, so one nested in a list item counts.
const OPENER = '^[ \t]*(?<d>`{3,}|~{3,})'
# Only whitespace may follow a closing delimiter, so an info string never closes a fence.
const CLOSER = '^[ \t]*(?<d>`{3,}|~{3,})[ \t]*\r?$'
# YAML or TOML front matter
const FRONT = '(?s)\A(?<m>(?:---|\+\+\+)\r?\n.*?\r?\n(?:---|\+\+\+)(?:\r?\n|\z))'

# Compared by count, so a passage keeps whatever it arrived with and only the rewriter is held to
# the ban. Chinese prose takes the fullwidth `；`.
const BANNED_MARKS = ['—' '--' '…' ';' '‘' '’' '“' '”']

# Ordered spans are compared in source order, since moving a heading or list item changes the
# document. The rest compare as a multiset, because merging or reordering two sentences that each
# carry a quotation must stay allowed while losing or editing one must not.
const CHECKS = [
  [kind ordered pattern];
  ["ATX heading" true '(?m)^(?<m>#{1,6} .*)$']
  ["setext heading" true '(?m)^(?<m>.+\n[=-]{2,}\s*)$']
  ["list marker" true '(?m)^(?<m>\s*(?:[-*+]|\d+\.) )']
  ["blockquote marker" true '(?m)^(?<m>[ \t]*>[> \t]*)']
  ["table row" true '(?m)^(?<m>\s*\|.*\|\s*)$']
  ["code span" false '(?<m>`[^`\n]+`)']
  ["link destination" false '\]\((?<m>[^)]+)\)']
  ["reference destination" false '(?m)^\s*\[(?!\^)[^]]+\]:\s*(?<m>\S+)']
  ["image marker" false '(?<m>!\[)']
  ["bracketed span" false '(?<m>\[\^[^\[\]\n]+\]|\[[^\[\]\n]+\](?!\(|\[[^\]\n]))']
  ["HTML tag" false '(?<m></?[A-Za-z][^>\n]*>)']
  ["HTML comment" false '(?s)(?<m><!--.*?-->)']
  ["URL" false '(?<m>https?://[^\s)>]+)']
  ["identifier" false '(?<m>(?<![A-Za-z0-9_])(?=[A-Za-z0-9_.:/+-]*[A-Za-z])(?=[A-Za-z0-9_.:/+-]*\d)[A-Za-z0-9_](?:[A-Za-z0-9_.:/+-]*[A-Za-z0-9_])?(?![A-Za-z0-9_]))']
  ["number" false '(?<m>[-+]?\d+(?:\.\d+)*(?:%|[A-Za-z]+)?)']
  ["quotation" false '(?<m>“[^”\n]*”|「[^」\n]*」|『[^』\n]*』|"[^"\n]*")']
]

# --------------------------------------------------------------------------------------------------
# Markdown pieces
# --------------------------------------------------------------------------------------------------

# The delimiter a line opens a fence with, or null when the line opens none.
def fence-delimiter [line: string]: nothing -> any {
  let parsed = ($line | parse --regex $OPENER)
  if ($parsed | is-empty) { null } else { $parsed | get 0.d }
}

# Whether a line closes the fence `delimiter` opened. CommonMark lets a closer use the same
# character and run at least as long.
def closes-fence [line: string, delimiter: string]: nothing -> bool {
  let parsed = ($line | parse --regex $CLOSER)
  if ($parsed | is-empty) {
    false
  } else {
    let found = ($parsed | get 0.d)
    let same = (($found | str substring 0..<1) == ($delimiter | str substring 0..<1))
    let longer = (($found | str length) >= ($delimiter | str length))
    $same and $longer
  }
}

# Blank-line-separated pieces, each carrying the separator that follows it, so rejoining every block
# and separator reproduces the document.
def pieces [text: string]: nothing -> list<record> {
  # Front matter goes in whole and never counts as prose, whatever blank lines it holds.
  let front = ($text | parse --regex $FRONT | get -o 0.m | default "")
  mut out = (
    if ($front | is-empty) { [] } else { [{block: $front, sep: "", prose: false}] }
  )

  mut delimiter = ""
  for piece in (
    ($text | str substring ($front | str length)..)
    | parse --regex '(?s)(?<block>.*?)(?<sep>\n\s*\n|\z)'
  ) {
    # A fence holding a blank line splits across pieces, and no piece of one is prose.
    mut fenced = ($delimiter | is-not-empty)
    for line in ($piece.block | lines) {
      if ($delimiter | is-empty) {
        let opened = (fence-delimiter $line)
        if $opened != null {
          $delimiter = $opened
          $fenced = true
        }
      } else if (closes-fence $line $delimiter) {
        $delimiter = ""
        $fenced = true
      }
    }
    $out = ($out | append ($piece | insert prose (not $fenced)))
  }
  $out
}

# `reframe` measures margins with `\s`, which matches an ideographic space, so a rewrite must lose
# the same set.
def trim-margins [text: string]: nothing -> string {
  $text | str replace --regex '(?s)\A\s+' "" | str replace --regex '(?s)\s+\z' ""
}

def reframe [before: string, after: string]: nothing -> string {
  let lead = ($before | parse --regex '(?s)\A(?<m>\s*)' | get 0.m)
  let trail = ($before | parse --regex '(?s)(?<m>\s*)\z' | get 0.m)
  $lead + (trim-margins $after) + $trail
}

# Line endings are formatting, so comparisons run on one form.
def unix [text: string]: nothing -> string {
  $text | str replace --all "\r\n" "\n"
}

# A rewrite takes back the line endings its own piece arrived with.
def match-endings [sample: string, text: string]: nothing -> string {
  if ($sample | str contains "\r\n") {
    (unix $text) | str replace --all "\n" "\r\n"
  } else {
    $text
  }
}

# The document with each accepted rewrite in its piece, leaving every other byte as it arrived.
def assemble [text: string, edits: list<record>]: nothing -> string {
  mut out = []
  for slot in ((pieces $text) | enumerate) {
    let row = ($edits | where {|edit| $edit.index == $slot.index } | get -o 0)
    let block = if $row == null {
      $slot.item.block
    } else {
      reframe $slot.item.block (match-endings $slot.item.block $row.after)
    }
    $out = ($out | append ($block + $slot.item.sep))
  }
  $out | str join ""
}

# --------------------------------------------------------------------------------------------------
# Targets
# --------------------------------------------------------------------------------------------------

# Whether the text holds at least one letter, which numbers and punctuation alone do not.
def has-letter [text: string]: nothing -> bool {
  ($text | parse --regex '\p{L}' | is-not-empty)
}

# Code shapes the rewriter cannot edit safely, so a piece holding one stays as it is.
def holds-code [text: string]: nothing -> bool {
  let indented = ($text | parse --regex '(?m)^(?<m>(?: {4,}| {0,3}\t)[ \t]*\S)' | is-not-empty)
  let ticked = ($text | str contains "``")
  let raw = ($text | parse --regex '(?i)(?<m><(?:pre|code|script|style)(?:\s|>))' | is-not-empty)
  $indented or $ticked or $raw
}

# A piece made only of headings or table rows can only be refused, so it never reaches the model.
def structural-only [text: string]: nothing -> bool {
  $text | lines | all {|line|
    let trimmed = ($line | str trim)
    $trimmed == "" or ($trimmed | parse --regex '^(?:#{1,6} .*|\|.*\|)$' | is-not-empty)
  }
}

# Whether the piece can reach the model, which needs prose outside fences and none of the material
# the checks cannot protect.
def polishable [piece: record]: nothing -> bool {
  let lettered = (has-letter $piece.block)
  let coded = (holds-code $piece.block)
  let structural = (structural-only $piece.block)
  $piece.prose and $lettered and (not $coded) and (not $structural)
}

# Pieces worth a rewrite, each with the index of the piece it came from.
def document-targets [text: string]: nothing -> list<record> {
  pieces $text
  | enumerate
  | where {|slot| polishable $slot.item }
  | each {|slot|
    let block = (trim-margins $slot.item.block)
    {index: $slot.index, before: (unix $block)}
  }
}

# --------------------------------------------------------------------------------------------------
# Fidelity checks
# --------------------------------------------------------------------------------------------------

# Each check row with its matches in `text` as `spans`.
def spans [text: string]: nothing -> list<record> {
  $CHECKS | each {|row|
    $row | insert spans ($text | parse --regex $row.pattern | get -o m | default [])
  }
}

# The spans in `before` left over after removing one occurrence per span in `after`.
def multiset-difference [before: list<string>, after: list<string>]: nothing -> list<string> {
  mut remaining = $before
  for span in $after {
    let index = ($remaining | enumerate | where item == $span | get -o 0.index)
    if $index != null {
      $remaining = ($remaining | reject $index)
    }
  }
  $remaining
}

# Spans render as JSON strings so edge whitespace, line breaks, and quotes in a span stay visible.
def span-diff [kind: string, before: list<string>, after: list<string>]: nothing -> string {
  let dropped = (multiset-difference $before $after)
  let added = (multiset-difference $after $before)
  let dropped_spans = ($dropped | each {|span| $span | to json } | str join ", ")
  let added_spans = ($added | each {|span| $span | to json } | str join ", ")
  if ($dropped | is-empty) {
    $"the rewrite added the ($kind) ($added_spans)"
  } else if ($added | is-empty) {
    $"the rewrite dropped the ($kind) ($dropped_spans)"
  } else {
    $"the rewrite dropped the ($kind) ($dropped_spans) and added ($added_spans)"
  }
}

def adds-mark [before: string, after: string]: nothing -> list<string> {
  $BANNED_MARKS | where {|mark|
    ($after | split row $mark | length) > ($before | split row $mark | length)
  }
}

def violations [before: string, after: string]: nothing -> list<string> {
  mut found = []
  for pair in ((spans $before) | zip (spans $after)) {
    let previous = $pair.0
    let current = $pair.1
    if ($previous.spans | sort) != ($current.spans | sort) {
      $found = ($found | append (span-diff $current.kind $previous.spans $current.spans))
    } else if $current.ordered and $previous.spans != $current.spans {
      $found = ($found | append $"the rewrite reordered the ($current.kind)s")
    }
  }
  # A rewrite may merge lines, since rejoining clipped sentences is the point, but gaining one means
  # a paragraph was cut into pieces.
  let before_lines = ($before | lines | length)
  let after_lines = ($after | lines | length)
  if $after_lines > $before_lines {
    $found = (
      $found
      | append $"the rewrite holds ($after_lines) lines where the input holds ($before_lines), so a paragraph was split"
    )
  }
  let added = (adds-mark $before $after)
  if ($added | is-not-empty) {
    let banned = ($added | each {|mark| $mark | to json } | str join ", ")
    $found = ($found | append $"the rewrite added the banned mark ($banned)")
  }
  $found
}

def grade [target: record, raw: string]: nothing -> record {
  let after = (reframe $target.before $raw)
  $target | merge {after: $after, problem: (violations $target.before $after | str join "; ")}
}

# --------------------------------------------------------------------------------------------------
# Rewriting
# --------------------------------------------------------------------------------------------------

def call-model [
  passages: list<record>
  notes: list<string>
  config: record
]: nothing -> list<string> {
  let request = {
    model: $config.model
    maxTokens: 16384
    json: true
    system: $config.phrasing
    user: (
      [
        ($config.prompt | str trim)
        "The input is a JSON object. Return only the same object shape and numeric IDs, replacing each text value with its rewrite."
        ...$notes
        ({passages: $passages} | to json --raw)
      ]
      | str join "\n\n"
    )
  }

  let caller = $config.modelCall
  let run = ($request | to json | ^$caller | complete)
  if $run.exit_code != 0 {
    print --stderr --no-newline $run.stderr
    return []
  }

  let parsed = (try { $run.stdout | from json } catch { null })
  if (not ($parsed | describe | str starts-with "record")) {
    return []
  }
  # An id mismatch also catches a short, long, or id-less reply, and a rewrite landing in another
  # passage's slot would corrupt both.
  let rewritten = ($parsed | get -o passages | default [])
  # `get -o` errors when an item is not a record.
  let ids = (try { $rewritten | get -o id } catch { null })
  if $ids != ($passages | get id) {
    return []
  }
  let out = ($rewritten | get -o text)
  if ($out | any {|text| ($text | describe) != "string" or ($text | is-empty) }) {
    []
  } else {
    $out
  }
}

# The rewriter cannot see why a passage was refused, so return the refused attempt with the reason.
def repair [pending: list<record>, config: record]: nothing -> list<string> {
  let passages = (
    $pending
    | each {|row|
      {
        id: $row.index
        text: $row.item.before
        rejected: $row.item.after
        problem: $row.item.problem
      }
    }
  )

  call-model $passages [($config.repairPrompt | str trim)] $config
}

# Each target graded with its final rewrite in `after` and any remaining fault in `problem`, or
# null when the opening model call fails.
def rewrite [found: list<record>, config: record]: nothing -> any {
  let passages = ($found | enumerate | each {|slot| {id: $slot.index, text: $slot.item.before} })
  let opening = (call-model $passages [] $config)
  if ($opening | is-empty) {
    return null
  }

  mut graded = ($found | zip $opening | each {|pair| grade $pair.0 $pair.1 })

  for _ in 0..<$config.maxRepairs {
    let pending = ($graded | enumerate | where item.problem != "")
    if ($pending | is-empty) {
      break
    }
    let retried = (repair $pending $config)
    if ($retried | is-empty) {
      break
    }
    for pair in ($pending | zip $retried) {
      $graded = ($graded | update $pair.0.index (grade $pair.0.item $pair.1))
    }
  }
  $graded
}

# A row condition reads a bare word as a string, so a column-to-column test needs a closure.
def accepted [graded: list<record>]: nothing -> list<record> {
  $graded | where {|row| $row.problem == "" and $row.after != $row.before }
}

# --------------------------------------------------------------------------------------------------
# Command
# --------------------------------------------------------------------------------------------------

def report [message: string] {
  print --stderr $"prose-polish: ($message)"
}

def fail [reason: string] {
  report $reason
  exit 1
}

def gateway-model [config: record, key: any]: nothing -> string {
  if $key == null {
    return $config.model
  }
  let model = ($config.models | get -o $key)
  if $model == null {
    fail $"unknown model ($key). The catalog lists ($config.models | columns | str join ', ')."
  }
  $model
}

# Rewrite the prose of a Markdown document, in place when given a path and through stdout otherwise.
#
# Fenced code, front matter, pieces that hold indented code, double-backtick spans, or raw code
# elements, and pieces that are only headings or table rows or hold no letters stay as they are.
# Rewrites that fail the fidelity checks keep the original text, and each one is reported on stderr,
# while skipped pieces produce no report. Exits 1 when the model key is unknown, the model call
# fails, or the input cannot be read, including a missing path or bytes that are not UTF-8.
def main [
  config_file: string # Supplied by the wrapper
  path?: path # Document to rewrite in place, read from stdin when omitted
  --model (-m): string # Model catalog key, such as gemini-3.8-flash, in place of the default
] {
  let config = (open $config_file)
  let config = ($config | update model (gateway-model $config $model))

  let raw = (
    if $path == null { ^cat | into binary } else { open --raw $path | into binary }
  )

  let bom = ($raw | bytes starts-with 0x[ef bb bf])
  let body = ($raw | bytes at (if $bom { 3 } else { 0 })..)
  let text = ($body | decode utf-8)
  # `decode utf-8` replaces invalid bytes and honors a UTF-16 BOM, so only a strict round trip
  # establishes that the input is UTF-8.
  if ($text | encode utf-8) != $body {
    fail "the input is not UTF-8 text"
  }

  let found = (document-targets $text)
  let graded = if ($found | is-empty) { [] } else { rewrite $found $config }
  if $graded == null {
    fail "the model call failed"
  }
  for row in ($graded | where problem != "") {
    report $"kept this passage because its rewrite failed a check: ($row.problem)"
    print --stderr $row.before
  }

  let result = (assemble $text (accepted $graded))
  let out = (if $bom { "\u{feff}" + $result } else { $result })
  if $path == null {
    print --no-newline $out
  } else if $result != $text {
    $out | encode utf-8 | save --force --raw $path
  }
}
