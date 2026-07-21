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

gone_count=0
removed_count=0
skipped_count=0
verification_worktree=""

cleanup_verification_worktree() {
  [[ -n "$verification_worktree" ]] || return 0

  git worktree remove "$verification_worktree" >/dev/null 2>&1 || true
  rmdir "$verification_worktree" 2>/dev/null || true
  verification_worktree=""
}

trap cleanup_verification_worktree EXIT

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

  if ! git merge-base --is-ancestor "refs/heads/${branch}" "$base_ref"; then
    printf 'SKIP %s: branch is not merged into %s\n' "$branch" "$base_ref"
    ((skipped_count += 1))
    continue
  fi

  if ! $apply; then
    if [[ -n "$branch_worktree" ]]; then
      printf 'PLAN %s: remove worktree %s and delete branch (merged into %s)\n' \
        "$branch" "$branch_worktree" "$base_ref"
    else
      printf 'PLAN %s: delete branch (merged into %s)\n' "$branch" "$base_ref"
    fi
    continue
  fi

  deletion_root="$repo_root"
  if ! git merge-base --is-ancestor "refs/heads/${branch}" HEAD; then
    verification_worktree="$(mktemp -d "${TMPDIR:-/tmp}/clean-gone.XXXXXX")"
    if ! git worktree add --quiet --detach "$verification_worktree" "$base_ref"; then
      cleanup_verification_worktree
      printf 'SKIP %s: failed to prepare deletion check against %s\n' "$branch" "$base_ref" >&2
      ((skipped_count += 1))
      continue
    fi
    deletion_root="$verification_worktree"
  fi

  if [[ -n "$branch_worktree" ]]; then
    if ! git worktree remove "$branch_worktree"; then
      cleanup_verification_worktree
      printf 'SKIP %s: failed to remove worktree %s\n' "$branch" "$branch_worktree" >&2
      ((skipped_count += 1))
      continue
    fi
  fi

  if git -C "$deletion_root" branch -d -- "$branch"; then
    ((removed_count += 1))
  else
    printf 'SKIP %s: Git refused to delete the branch\n' "$branch" >&2
    ((skipped_count += 1))
  fi

  cleanup_verification_worktree
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
