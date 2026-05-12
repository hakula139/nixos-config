#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# WakaTime Heartbeat for AI-Generated Code (PostToolUse)
# ==============================================================================
# PostToolUse hook that sends a file-level WakaTime heartbeat with
# --ai-line-changes for each edit tool invocation.
#
# Claude Code sends Edit / Write payloads with direct file and content fields.
# Codex sends apply_patch payloads, so patch text is parsed to recover changed
# files and approximate net line changes.
#
# This replaces app-level heartbeats, which lack language detection (reported
# as "Other") and rarely include AI line attribution.
# ==============================================================================

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
readonly PLUGIN_NAME="@pluginName@"

# Resolve platform-specific wakatime-cli binary.
WAKATIME_CLI="$HOME/.wakatime/wakatime-cli-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
[[ -x "$WAKATIME_CLI" ]] || exit 0

PROJECT_FOLDER=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')

emit_changed_files() {
  local file_path line_changes

  case "$TOOL_NAME" in
    apply_patch)
      printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' | awk '
        /^\*\*\* (Add|Update) File: / {
          file = substr($0, index($0, ": ") + 2)
          files[file] = 1
          next
        }
        /^\*\*\* Delete File: / {
          file = ""
          next
        }
        file != "" && /^\+/ && $0 !~ /^\+\+\+/ {
          changes[file]++
          next
        }
        file != "" && /^-/ && $0 !~ /^---/ {
          changes[file]--
          next
        }
        END {
          for (file in files) {
            print file "\t" changes[file] + 0
          }
        }
      '
      ;;
    Edit)
      file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
      line_changes=$(
        printf '%s' "$INPUT" | jq '
          ((.tool_input.new_string // "") | split("\n") | length)
          - ((.tool_input.old_string // "") | split("\n") | length)
        '
      )
      [[ -n "$file_path" ]] && printf '%s\t%s\n' "$file_path" "$line_changes"
      ;;
    Write)
      file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
      line_changes=$(printf '%s' "$INPUT" | jq '(.tool_input.content // "") | split("\n") | length')
      [[ -n "$file_path" ]] && printf '%s\t%s\n' "$file_path" "$line_changes"
      ;;
    *)
      file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
      [[ -n "$file_path" ]] && printf '%s\t0\n' "$file_path"
      ;;
  esac
}

emit_changed_files | while IFS=$'\t' read -r FILE_PATH LINE_CHANGES; do
  [[ -z "$FILE_PATH" || ! -e "$FILE_PATH" ]] && continue

  ARGS=(
    --entity "$FILE_PATH"
    --entity-type file
    --write
    --category "ai coding"
    --plugin "$PLUGIN_NAME"
    --ai-line-changes "$LINE_CHANGES"
  )
  [[ -n "$PROJECT_FOLDER" ]] && ARGS+=(--project-folder "$PROJECT_FOLDER")

  "$WAKATIME_CLI" "${ARGS[@]}" >/dev/null 2>&1 || true
done
