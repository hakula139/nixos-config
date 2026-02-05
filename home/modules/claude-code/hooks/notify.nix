{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Claude Code Notification Support
# ==============================================================================
# Cross-platform notification wrapper:
# - macOS: osascript
# - Linux: notify-send
# - WSL: toasty
# ==============================================================================

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # Tiny Windows toast notification CLI
  # https://github.com/shanselman/toasty
  toasty = pkgs.fetchurl {
    url = "https://github.com/shanselman/toasty/releases/download/v0.5/toasty-x64.exe";
    hash = "sha256-DTlIB4JCcjfGbDFsvN+T32KuvjC4yb/KHu0xZzzT1WQ=";
  };

  # Cross-platform notification script
  notifyScript = pkgs.writeShellScript "claude-notify" ''
    set -euo pipefail

    title="''${1:-Claude Code}"
    body="''${2:-}"

    ${lib.optionalString isLinux ''
      # Check if running in WSL
      if grep -qi microsoft /proc/version 2>/dev/null; then
        "${toasty}" "$body" -t "$title" --app claude 2>/dev/null || true
      else
        ${pkgs.libnotify}/bin/notify-send "$title" "$body"
      fi
    ''}
    ${lib.optionalString isDarwin ''
      osascript -e "display notification \"$body\" with title \"$title\""
    ''}
  '';
in
{
  inherit notifyScript;
}
