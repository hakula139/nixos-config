# ==================================================================================================
# Activity History Context
# ==================================================================================================

# Worktrees report work on the repository that owns them.
def repo-dir [cwd: string]: nothing -> string {
  $cwd
  # A Claude Code worktree, `<repo>/.claude/worktrees/<name>`
  | str replace --regex '/\.claude/worktrees/[^/]+.*$' ''
  # A Workmux worktree, `<repo>__worktrees/<name>`
  | str replace --regex '__worktrees/.*$' ''
}

export def project-of [cfg: record, cwd: string]: nothing -> string {
  let dir = (repo-dir $cwd)
  let root = ($cfg.gitRoots | where {|r| $dir | str starts-with $"($r)/" } | get -o 0)
  if $root == null {
    return ($dir | path basename)
  }
  $dir | str substring (($root | str length) + 1).. | split row "/" | first
}

def home-relative []: string -> string {
  str replace --regex '^~(?=/|$)' $nu.home-dir
}

# A pattern also matches everything below the path it names.
def glob-match [pattern: string]: string -> bool {
  let subject = $in
  let regex = (
    $pattern
    # Regex metacharacters other than the glob wildcards `*` and `?`
    | str replace --all --regex '([.+()|^$\[\]{}\\])' '\$1'
    | str replace --all '**' "\u{1}"
    | str replace --all '*' '[^/]*'
    | str replace --all '?' '[^/]'
    | str replace --all "\u{1}" '.*'
  )
  $subject =~ ('^' + $regex + '(/.*)?$')
}

export def context-of [settings: record, key: string, weekend: bool]: nothing -> string {
  if $weekend {
    return "personal"
  }
  $settings.rules
  | where {|rule| $key | glob-match $rule.match }
  | get -o 0.context
  | default $settings.fallback
}

export def ignored [settings: record, key: string]: nothing -> bool {
  $settings.ignore | any {|pattern| $key | glob-match $pattern }
}

# Extend the Nix-provided defaults with the host's untracked config file.
export def settings [cfg: record]: nothing -> record {
  let local = if ($cfg.userConfig | path exists) { open $cfg.userConfig } else { {} }
  {
    fallback: ($local.fallback? | default $cfg.fallback)
    rules: (
      ($local.rules? | default []) ++ $cfg.rules | each {|r| $r | update match { home-relative } }
    )
    ignore: (($local.ignore? | default []) ++ $cfg.ignore | each { home-relative })
    projects: ($local.projects? | default {})
    examples: ($local.examples? | default [])
  }
}
