#!/usr/bin/env bash
set -euo pipefail

apply=false
base_override=""

usage() {
  cat <<'EOF'
Usage: clean-gone.sh [--apply] [--base <ref>]

Safely remove local branches whose configured upstreams are gone.
The default mode is a dry run. Pass --apply to perform the reported removals.
EOF
}

while (($# > 0)); do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    --base)
      if (($# < 2)); then
        printf 'error: --base requires a Git ref\n' >&2
        exit 2
      fi
      base_override="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: run this script inside a Git worktree\n' >&2
  exit 2
}

if [[ -n "$base_override" ]] && ! git rev-parse --verify --quiet "${base_override}^{commit}" >/dev/null; then
  printf 'error: base ref does not resolve to a commit: %s\n' "$base_override" >&2
  exit 2
fi

declare -A worktrees=()
worktree_path=""
while IFS= read -r -d '' field; do
  case "$field" in
    "worktree "*)
      worktree_path="${field#worktree }"
      ;;
    "branch refs/heads/"*)
      branch="${field#branch refs/heads/}"
      worktrees["$branch"]="$worktree_path"
      ;;
  esac
done < <(git worktree list --porcelain -z)

resolve_base() {
  local remote="$1"
  local candidate

  if [[ -n "$base_override" ]]; then
    printf '%s\n' "$base_override"
    return
  fi

  candidate="$(git symbolic-ref --quiet --short "refs/remotes/${remote}/HEAD" 2>/dev/null || true)"
  if [[ -n "$candidate" ]] && git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
    printf '%s\n' "$candidate"
    return
  fi

  for candidate in "${remote}/main" "${remote}/master"; do
    if git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

branch_is_integrated() {
  local branch="$1"
  local base_ref="$2"
  local -a changed_paths=()
  local branch_ref="refs/heads/${branch}"
  local candidate
  local cherry_output
  local merge_base
  local path
  local paths_file

  if git merge-base --is-ancestor "$branch_ref" "$base_ref"; then
    return
  fi

  cherry_output="$(git cherry "$base_ref" "$branch_ref")" || return 1
  if [[ -n "$cherry_output" ]] && ! grep -q '^+' <<<"$cherry_output"; then
    return
  fi

  merge_base="$(git merge-base "$base_ref" "$branch_ref")" || return 1
  paths_file="$(mktemp)" || return 1
  if ! git diff --name-only --no-renames -z "$merge_base" "$branch_ref" >"$paths_file"; then
    rm -f -- "$paths_file"
    return 1
  fi

  while IFS= read -r -d '' path; do
    changed_paths+=(":(literal)$path")
  done <"$paths_file"
  rm -f -- "$paths_file"

  if ((${#changed_paths[@]} == 0)); then
    return
  fi

  while IFS= read -r candidate; do
    if git diff --quiet "$branch_ref" "$candidate" -- "${changed_paths[@]}"; then
      return
    fi
  done < <(git rev-list --first-parent "$base_ref" "^${merge_base}")

  return 1
}

gone_count=0
removed_count=0
skipped_count=0

while IFS=$'\t' read -r branch tracking remote; do
  [[ "$tracking" == *gone* ]] || continue
  ((gone_count += 1))

  branch_worktree="${worktrees[$branch]:-}"
  if [[ "$branch_worktree" == "$repo_root" ]]; then
    printf 'SKIP %s: branch is active in the current worktree\n' "$branch"
    ((skipped_count += 1))
    continue
  fi

  if [[ -n "$branch_worktree" ]] && [[ -n "$(git -C "$branch_worktree" status --porcelain)" ]]; then
    printf 'SKIP %s: worktree has uncommitted or untracked changes: %s\n' "$branch" "$branch_worktree"
    ((skipped_count += 1))
    continue
  fi

  if [[ -z "$remote" || "$remote" == "." ]]; then
    printf 'SKIP %s: cannot determine a remote default branch\n' "$branch"
    ((skipped_count += 1))
    continue
  fi

  if ! base_ref="$(resolve_base "$remote")"; then
    printf 'SKIP %s: remote default branch is unavailable for %s\n' "$branch" "$remote"
    ((skipped_count += 1))
    continue
  fi

  if ! branch_is_integrated "$branch" "$base_ref"; then
    printf 'SKIP %s: branch is not integrated into %s\n' "$branch" "$base_ref"
    ((skipped_count += 1))
    continue
  fi

  if ! $apply; then
    if [[ -n "$branch_worktree" ]]; then
      printf 'PLAN %s: remove worktree %s and delete branch (integrated into %s)\n' \
        "$branch" "$branch_worktree" "$base_ref"
    else
      printf 'PLAN %s: delete branch (integrated into %s)\n' "$branch" "$base_ref"
    fi
    continue
  fi

  if [[ -n "$branch_worktree" ]]; then
    if ! git worktree remove "$branch_worktree"; then
      printf 'SKIP %s: failed to remove worktree %s\n' "$branch" "$branch_worktree" >&2
      ((skipped_count += 1))
      continue
    fi
  fi

  # -d cannot recognize squash merges; integration was verified above.
  if git branch -D -- "$branch"; then
    ((removed_count += 1))
  else
    printf 'SKIP %s: Git refused to delete the branch\n' "$branch" >&2
    ((skipped_count += 1))
  fi

done < <(
  git for-each-ref \
    --format='%(refname:short)%09%(upstream:track)%09%(upstream:remotename)' \
    refs/heads/
)

if ((gone_count == 0)); then
  printf 'No local branches have a gone upstream.\n'
  exit 0
fi

if ! $apply; then
  printf 'Dry run only. Re-run with --apply after reviewing the plan.\n'
  exit 0
fi

git worktree prune
printf 'Removed %d branch(es); skipped %d branch(es).\n' "$removed_count" "$skipped_count"

if ((skipped_count > 0)); then
  exit 1
fi
