#!/usr/bin/env bash

# ==============================================================================
# Auto-Format and Lint (PostToolUse)
# ==============================================================================
# PostToolUse hook that formats and lints files after edit operations.
# Reads edited file paths from stdin JSON and dispatches based on file extension.
# Claude Code sends Edit / Write payloads with tool_input.file_path; Codex sends
# apply_patch payloads with file paths embedded in tool_input.command.
#
# Formatters run first (silent, rewrite files), then linters (output for AI).
# Linter output is capped to avoid flooding the context window. Rust and Go
# toolchains stay PATH-probed, since pinning them would add GiBs to every host.
# ==============================================================================

# `-e` is omitted: every tool invocation intentionally tolerates failure.
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

have() {
  [[ -n "$1" && -x "$1" ]]
}

collect_files() {
  case "$TOOL_NAME" in
    apply_patch)
      printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' | sed -n -E 's/^\*\*\* (Add|Update) File: //p'
      ;;
    *)
      printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty'
      ;;
  esac
}

collect_files | sort -u | while IFS= read -r FILE_PATH; do
  [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && continue

  case "$FILE_PATH" in
    *.sh)
      "@shfmt@" -w "$FILE_PATH" 2>/dev/null || true
      "@shellcheck@" "$FILE_PATH" 2>&1 | head -20 || true
      ;;
    *.nix)
      "@nixfmt@" "$FILE_PATH" 2>/dev/null || true
      ;;
    *.py)
      have "@ruff@" || continue
      "@ruff@" format "$FILE_PATH" 2>/dev/null || true
      "@ruff@" check --fix "$FILE_PATH" 2>/dev/null || true
      "@ruff@" check "$FILE_PATH" 2>&1 | head -20 || true
      ;;
    *.rs)
      if command -v cargo &>/dev/null; then
        cargo fmt --all --quiet 2>/dev/null || true
        cargo clippy --all-targets --quiet -- -D warnings 2>&1 | head -20 || true
      fi
      ;;
    *.go)
      if command -v goimports &>/dev/null; then
        goimports -w "$FILE_PATH" 2>/dev/null || true
      elif command -v gofmt &>/dev/null; then
        gofmt -w "$FILE_PATH" 2>/dev/null || true
      fi
      ;;
    *.toml)
      have "@taplo@" || continue
      "@taplo@" fmt "$FILE_PATH" 2>/dev/null || true
      ;;
    *.css | *.js)
      have "@prettier@" || continue
      "@prettier@" --write "$FILE_PATH" 2>/dev/null || true
      ;;
    *.md)
      have "@dprint@" || continue
      TMP=$(mktemp)
      if "@dprint@" fmt --config "@dprintConfig@" --stdin md <"$FILE_PATH" >"$TMP" 2>/dev/null && [[ -s "$TMP" ]]; then
        mv "$TMP" "$FILE_PATH"
      else
        rm -f "$TMP"
      fi
      "@markdownlint@" --fix "$FILE_PATH" 2>/dev/null || true
      "@markdownlint@" "$FILE_PATH" 2>&1 | head -20 || true
      "@cspell@" --no-progress "$FILE_PATH" 2>&1 | head -20 || true
      ;;
  esac
done
