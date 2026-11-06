#!/usr/bin/env nu

# ==================================================================================================
# Forge CLI Stub
# ==================================================================================================
# Stands in for `glab mr list` and `gh pr list`, listing the `STUB_REQUESTS` from the branch that
# `--source-branch` or `--head` names, or failing with `STUB_FORGE_ERROR`. Each call appends its
# arguments to `STUB_LOG` as one JSON line.
# ==================================================================================================

def --wrapped main [...args: string] {
  {args: $args}
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  if ($env.STUB_FORGE_ERROR? | is-not-empty) {
    print -e $env.STUB_FORGE_ERROR
    exit 1
  }

  let flag = ($args | enumerate | where item in ["--source-branch" "--head"] | first)
  let branch = ($args | get ($flag.index + 1))
  (
    $env.STUB_REQUESTS
    | from json
    | where {|request| ($request.source_branch? | default $request.headRefName?) == $branch }
    | to json --raw
    | print
  )
}
