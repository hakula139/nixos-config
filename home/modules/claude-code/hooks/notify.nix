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

  # Tiny Windows toast notification CLI for WSL
  # https://github.com/shanselman/toasty
  toasty = pkgs.runCommand "toasty" { } ''
    install -D -m 0755 ${
      pkgs.fetchurl {
        url = "https://github.com/shanselman/toasty/releases/download/v0.5/toasty-x64.exe";
        hash = "sha256-DTlIB4JCcjfGbDFss9+T8rYqvjC4yb/KHu0xZz3NFWQ=";
      }
    } $out/bin/toasty.exe
  '';

  # Cross-platform notification script
  notifyScript = pkgs.writeShellScript "claude-notify" ''
    set -euo pipefail

    title="''${1:-Claude Code}"
    body="''${2:-}"

    ${lib.optionalString isLinux ''
      # Check if running in WSL
      if grep -qi microsoft /proc/version 2>/dev/null; then
        "${toasty}/bin/toasty.exe" "$body" -t "$title" --app claude 2>/dev/null || true
      else
        ${pkgs.libnotify}/bin/notify-send "$title" "$body"
      fi
    ''}
    ${lib.optionalString isDarwin ''
      osascript -e "display notification \"$body\" with title \"$title\" sound name \"Glass\""
    ''}
  '';
in
{
  inherit notifyScript;
}
