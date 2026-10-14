#!/usr/bin/env nu

# ==================================================================================================
# Auto-Dream
# ==================================================================================================
# Claude Code's native auto-dream needs a server-side flag that disabling nonessential traffic never
# fetches. This hook applies the same gates and asks the session to dream in a background agent.
# ==================================================================================================

const MIN_AGE = 24hr
const MIN_SESSIONS = 5
# A nudge the session ignored, or a dream it abandoned, comes back after this long.
const RETRY_AFTER = 1hr

const PROJECTS_DIR = $nu.home-dir | path join ".claude" "projects"
const NUDGE_DIR = $nu.cache-dir | path join "claude-code" "auto-dream"

# Claude Code's project directory name for a path
def project-slug [path: string]: nothing -> string {
  $path | str replace --all --regex '[^a-zA-Z0-9]' '-'
}

# All worktrees of a repository share the main worktree's memory store.
def main-worktree [git: string, cwd: string]: nothing -> string {
  let result = (^$git -C $cwd worktree list --porcelain | complete)
  if $result.exit_code != 0 {
    return ""
  }

  $result.stdout | lines | parse "worktree {path}" | get -o 0.path | default ""
}

def modified [path: string]: nothing -> datetime {
  if ($path | path exists) { ls $path | get 0.modified } else { 0 | into datetime }
}

def memories [store: string]: nothing -> list<string> {
  if not ($store | path exists) {
    return []
  }

  ls $store
  | where type == file and ($it.name | str ends-with ".md")
  | get name
  | where ($it | path basename) != "MEMORY.md"
}

# Worktree and subdirectory sessions keep transcripts in directories whose names extend the slug.
def sessions-since [slug: string, since: datetime, current: string]: nothing -> int {
  ls $PROJECTS_DIR
  | where type == dir and ($it.name | path basename | str starts-with $slug)
  | each {|dir| ls $dir.name }
  | flatten
  | where type == file and ($it.name | str ends-with ".jsonl") and $it.modified > $since
  | where ($it.name | path parse | get stem) != $current
  | length
}

def nudge [config: record, input: record]: nothing -> any {
  let main = (main-worktree $config.git $input.cwd)
  if ($main | is-empty) {
    return null
  }

  let slug = (project-slug $main)
  let store = ($PROJECTS_DIR | path join $slug "memory")
  if (memories $store | is-empty) {
    return null
  }

  let since = (modified ($store | path join ".consolidate-lock"))
  let marker = ($NUDGE_DIR | path join $slug)
  if (date now) - $since < $MIN_AGE or (date now) - (modified $marker) < $RETRY_AFTER {
    return null
  }

  let sessions = (sessions-since $slug $since $input.session_id)
  if $sessions < $MIN_SESSIONS {
    return null
  }

  mkdir $NUDGE_DIR
  touch $marker
  let last = if $since == (0 | into datetime) { "none recorded" } else { $since | format date "%Y-%m-%d" }
  let context = (
    $config.prompt
    | str replace --all '@model@' $config.model
    | str replace --all '@sessions@' ($sessions | into string)
    | str replace --all '@since@' $last
    | str replace --all '@store@' $store
  )

  # SessionStart feeds `additionalContext` to the model, while `systemMessage` reaches only the user.
  {
    systemMessage: $"Memory consolidation is due after ($sessions) sessions, so Claude will dream in a background agent."
    hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}
  }
  | to json --raw
}

def main [config_file: string] {
  let out = (try { nudge (open $config_file) (^cat | from json) } catch { null })
  if $out != null {
    print $out
  }
}
