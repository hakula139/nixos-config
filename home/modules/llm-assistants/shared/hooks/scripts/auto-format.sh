input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty')

collect_files() {
  case "$tool_name" in
    apply_patch)
      printf '%s' "$input" | jq -r '.tool_input.command // ""' | sed -n -E 's/^\*\*\* (Add|Update) File: //p'
      ;;
    *)
      printf '%s' "$input" | jq -r '.tool_input.file_path // empty'
      ;;
  esac
}

collect_files | sort -u | while IFS= read -r file_path; do
  [[ -z "$file_path" || ! -f "$file_path" ]] && continue

  case "$file_path" in
    *.sh)
      shfmt -w "$file_path" 2>/dev/null || true
      shellcheck "$file_path" 2>&1 | head -20 || true
      ;;
    *.nix)
      nix fmt "$file_path" 2>/dev/null || true
      ;;
    *.py)
      ruff format "$file_path" 2>/dev/null || true
      ruff check --fix "$file_path" 2>/dev/null || true
      ruff check "$file_path" 2>&1 | head -20 || true
      ;;
    *.rs)
      if command -v cargo &>/dev/null; then
        cargo fmt --all --quiet 2>/dev/null || true
        cargo clippy --all-targets --quiet -- -D warnings 2>&1 | head -20 || true
      fi
      ;;
    *.go)
      if command -v goimports &>/dev/null; then
        goimports -w "$file_path" 2>/dev/null || true
      elif command -v gofmt &>/dev/null; then
        gofmt -w "$file_path" 2>/dev/null || true
      fi
      ;;
    *.toml)
      if command -v taplo &>/dev/null; then
        taplo fmt "$file_path" 2>/dev/null || true
      fi
      ;;
    *.css | *.js)
      if command -v npx &>/dev/null; then
        npx --no prettier --write "$file_path" 2>/dev/null || true
      fi
      ;;
    *.md)
      if command -v npx &>/dev/null; then
        npx --no markdownlint-cli2 "$file_path" 2>&1 | head -20 || true
        npx --no cspell --no-progress "$file_path" 2>&1 | head -20 || true
      fi
      ;;
  esac
done
