# ==================================================================================================
# Activity History Sources
# ==================================================================================================

use common.nu *

export def collect-git [cfg: record, bounds: record]: nothing -> list {
  $cfg.gitRoots
  | where ($it | path exists)
  | each {|root| ls $root | where type == dir | get name }
  | flatten
  | where ($it | path join ".git" | path exists)
  | each {|repo|
    let email = (^git -C $repo config user.email | str trim)
    (
      ^git -C $repo log
        --exclude=refs/stash
        --all
        --no-merges
        $"--author=($email)"
        $"--since=(($bounds.start - 1day) | format date '%+')"
        "--format=%H%x09%aI%x09%s"
    )
    | lines
    | parse "{sha}\t{ts}\t{subject}"
    | where {|c| $c.ts | into datetime | within $bounds }
    | each {|c|
      {
        id: $"git:($c.sha)"
        host: $cfg.host
        source: git
        kind: commit
        ts: (utc-iso ($c.ts | into datetime))
        cwd: $repo
        title: $c.subject
        refs: [($c.sha | str substring 0..7)]
      }
    }
  }
  | flatten
}

export def collect-gitlab [cfg: record, bounds: record]: nothing -> list {
  # GitLab compares dates in UTC and excludes both endpoints.
  let after = (($bounds.start - 1day) | date to-timezone UTC | format date "%Y-%m-%d")
  let before = (($bounds.end + 1day) | date to-timezone UTC | format date "%Y-%m-%d")
  let events = (
    ^glab api $"events?after=($after)&before=($before)&per_page=100" --paginate --output ndjson
    | from json --objects
    | where {|e| to-local $e.created_at | within $bounds }
    | where action_name != "deleted"
  )
  let paths = (
    $events
    | get project_id
    | uniq
    | each {|id|
      {id: $id, path: (^glab api $"projects/($id)" | from json | get path_with_namespace)}
    }
  )
  $events
  | each {|e|
    let path = ($paths | where id == $e.project_id | get 0.path)
    let ref = match $e.target_type? {
      "MergeRequest" => $"($path)!($e.target_iid)"
      "Issue" => $"($path)#($e.target_iid)"
      _ => null
    }
    {
      id: $"gitlab:($e.id)"
      host: $cfg.host
      source: gitlab
      kind: $e.action_name
      ts: (utc-iso (to-local $e.created_at))
      project: ($path | path basename)
      key: $"gitlab:($path)"
      title: ($e.target_title? | default $e.push_data?.commit_title? | excerpt)
      text: ($e.note?.body? | excerpt)
      refs: ([$ref $e.push_data?.ref?] | compact)
    }
  }
}

export def collect-github [cfg: record, bounds: record]: nothing -> list {
  let login = (^gh api user --jq .login)
  ^gh api --paginate $"users/($login)/events?per_page=100" --jq ".[]"
  | from json --objects
  | where {|e| to-local $e.created_at | within $bounds }
  | where type not-in [CreateEvent DeleteEvent]
  | where {|e| $e.payload.action? not-in [labeled unlabeled assigned unassigned] }
  | each {|e|
    let number = ($e.payload.pull_request?.number? | default $e.payload.issue?.number?)
    {
      id: $"github:($e.id)"
      host: $cfg.host
      source: github
      kind: ([$e.type $e.payload.action?] | compact | str join ":")
      ts: (utc-iso (to-local $e.created_at))
      project: ($e.repo.name | path basename)
      key: $"github:($e.repo.name)"
      title: ($e.payload.issue?.title? | default $e.payload.comment?.body? | excerpt)
      refs: ([(if $number != null { $"($e.repo.name)#($number)" }) $e.payload.ref?] | compact)
    }
  }
}

export def sync-calendar []: nothing -> nothing {
  # A first discover asks whether to create the local calendar directory.
  "y" | ^vdirsyncer --verbosity ERROR discover | ignore
  ^vdirsyncer --verbosity ERROR sync
}

export def collect-calendar [cfg: record, date: string]: nothing -> list {
  ^khal list --once $date 1d --json uid --json title --json start --json end --json all-day
  | from json
  | where all-day == "False"
  | each {|m|
    let start = ($m.start | into datetime)
    {
      id: $"calendar:($m.uid):(utc-iso $start)"
      host: $cfg.host
      source: calendar
      kind: meeting
      ts: (utc-iso $start)
      end: (utc-iso ($m.end | into datetime))
      key: $"calendar:($m.title | str trim)"
      title: ($m.title | str trim)
    }
  }
}
