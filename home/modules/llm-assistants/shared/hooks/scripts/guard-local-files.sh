#!/usr/bin/env bash

# ==============================================================================
# Guard Local-Only Files (PreToolUse)
# ==============================================================================
# Denies edits and commits that would publish a value meant to stay in the
# working tree. `data/corp-domain.nix` holds a placeholder in git and the real
# corp domain locally, so an edit committing the real value leaks it and a
# revert to the placeholder destroys local state.
# ==============================================================================

# `-e` is omitted: the checks below intentionally fall through to `exit 0`.
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

readonly GUARDED_RE='data/corp-domain\.nix'

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

case "$TOOL_NAME" in
  Edit | Write | NotebookEdit)
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
    [[ "$FILE_PATH" =~ $GUARDED_RE ]] \
      && deny "data/corp-domain.nix carries the real corp domain in the working tree and a placeholder in git. Leave it untouched."
    ;;
  apply_patch)
    printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' \
      | sed -n -E 's/^\*\*\* (Add|Update|Delete) File: //p' \
      | grep -qE "$GUARDED_RE" \
      && deny "data/corp-domain.nix carries the real corp domain in the working tree and a placeholder in git. Leave it untouched."
    ;;
  Bash)
    COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
    # `git add` and `git commit <path>` stage it; checkout and restore would
    # overwrite the local value with the committed placeholder.
    [[ "$COMMAND" =~ $GUARDED_RE ]] \
      && [[ "$COMMAND" =~ git[[:space:]]+(add|commit|checkout|restore|stash) ]] \
      && deny "That would stage or overwrite data/corp-domain.nix, which holds the real corp domain locally and a placeholder in git."
    ;;
  mcp__Git__git_add)
    printf '%s' "$INPUT" | jq -r '.tool_input.files[]? // empty' \
      | grep -qE "$GUARDED_RE" \
      && deny "data/corp-domain.nix must not be staged: it holds the real corp domain locally and a placeholder in git."
    ;;
esac

exit 0
