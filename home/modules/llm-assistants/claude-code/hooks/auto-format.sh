#!/usr/bin/env bash

# ==============================================================================
# Auto-Format and Lint
# ==============================================================================
# PostToolUse hook that formats and lints files after Edit / Write operations.
# Reads tool_input.file_path from stdin JSON and dispatches based on file
# extension. Tools not in PATH are silently skipped.
#
# Formatters run first (silent, rewrite files), then linters (output for AI).
# Linter output is capped to avoid flooding the context window.
# ==============================================================================

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

case "$FILE_PATH" in
  *.sh)
    shfmt -w "$FILE_PATH" 2>/dev/null || true
    shellcheck "$FILE_PATH" 2>&1 | head -20 || true
    ;;
  *.nix)
    nix fmt "$FILE_PATH" 2>/dev/null || true
    ;;
  *.py)
    ruff format "$FILE_PATH" 2>/dev/null || true
    ruff check --fix "$FILE_PATH" 2>/dev/null || true
    ruff check "$FILE_PATH" 2>&1 | head -20 || true
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
    if command -v taplo &>/dev/null; then
      taplo fmt "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac
