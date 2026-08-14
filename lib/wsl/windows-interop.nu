#!/usr/bin/env nu

# ==============================================================================
# Windows Interop Helpers (WSL only)
# ==============================================================================

# `--env` is required on both defs: a plain `def` discards the PATH mutation
# when it returns, so cmd.exe would stay unreachable.
def --env interop-init [] {
  let win_sys32 = "/mnt/c/Windows/System32"
  if ($win_sys32 | path exists) and ($win_sys32 not-in $env.PATH) {
    $env.PATH = ($env.PATH | append $win_sys32)
  }

  if (which cmd.exe | is-empty) {
    print -e "Error: cmd.exe not found. This script requires WSL."
    exit 1
  }
}

export def --env windows-env-path [name: string]: nothing -> string {
  interop-init

  # `cmd.exe` rejects a UNC cwd, which any WSL path is.
  let value = (
    try { cd "/mnt/c"; ^cmd.exe /C $"echo %($name)%" | str trim } catch { "" }
  )
  if ($value | is-empty) or ($value == $"%($name)%") {
    print -e $"Error: Failed to resolve %($name)%"
    exit 1
  }

  ^wslpath $value | str trim
}
