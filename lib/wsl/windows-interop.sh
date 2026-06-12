#!/usr/bin/env bash

windows_interop_init() {
  local win_sys32="/mnt/c/Windows/System32"
  if [[ -d "$win_sys32" && ":$PATH:" != *":$win_sys32:"* ]]; then
    export PATH="$PATH:$win_sys32"
  fi

  if ! command -v cmd.exe &>/dev/null; then
    echo "Error: cmd.exe not found. This script requires WSL." >&2
    exit 1
  fi
}

windows_env_path() {
  local name="${1:?environment variable name required}"
  local value

  windows_interop_init
  value="$(cmd.exe /C "echo %${name}%" 2>/dev/null | tr -d '\r\n')"
  if [[ -z "$value" || "$value" == "%${name}%" ]]; then
    echo "Error: Failed to resolve %${name}%" >&2
    exit 1
  fi

  wslpath "$value"
}
