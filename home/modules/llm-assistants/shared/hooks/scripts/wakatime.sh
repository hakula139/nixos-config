set -euo pipefail

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty')
plugin_name="${HAKULA_WAKATIME_PLUGIN:-llm-assistant-hook/1.0}"

wakatime_cli="$HOME/.wakatime/wakatime-cli-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
[[ -x "$wakatime_cli" ]] || exit 0

project_folder=$(printf '%s' "$input" | jq -r '.cwd // empty')

emit_changed_files() {
  case "$tool_name" in
    apply_patch)
      printf '%s' "$input" | jq -r '.tool_input.command // ""' | awk '
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
      file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
      line_changes=$(
        printf '%s' "$input" | jq '
          ((.tool_input.new_string // "") | split("\n") | length)
          - ((.tool_input.old_string // "") | split("\n") | length)
        '
      )
      [[ -n "$file_path" ]] && printf '%s\t%s\n' "$file_path" "$line_changes"
      ;;
    Write)
      file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
      line_changes=$(printf '%s' "$input" | jq '(.tool_input.content // "") | split("\n") | length')
      [[ -n "$file_path" ]] && printf '%s\t%s\n' "$file_path" "$line_changes"
      ;;
    *)
      file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
      [[ -n "$file_path" ]] && printf '%s\t0\n' "$file_path"
      ;;
  esac
}

emit_changed_files | while IFS=$'\t' read -r file_path line_changes; do
  [[ -z "$file_path" || ! -e "$file_path" ]] && continue

  args=(
    --entity "$file_path"
    --entity-type file
    --write
    --category "ai coding"
    --plugin "$plugin_name"
    --ai-line-changes "$line_changes"
  )
  [[ -n "$project_folder" ]] && args+=(--project-folder "$project_folder")

  "$wakatime_cli" "${args[@]}" >/dev/null 2>&1 || true
done
