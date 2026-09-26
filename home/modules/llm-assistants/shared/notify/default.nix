# ==============================================================================
# Cross-Platform Notification Support
# ==============================================================================
# - macOS: osascript
# - Linux: notify-send
# - WSL: toasty
# ==============================================================================

{
  pkgs,
  lib,
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;

  # Tiny Windows toast notification CLI for WSL
  # https://github.com/shanselman/toasty
  toasty = pkgs.runCommand "toasty" { } ''
    install -D -m 0755 ${
      pkgs.fetchurl {
        url = "https://github.com/shanselman/toasty/releases/download/v0.8.1/toasty-x64.exe";
        hash = "sha256-HGx6JBXNkqEUjPngj9LoX6SOq1dSzj1+D9wfjqH6LaI=";
      }
    } $out/bin/toasty.exe
  '';

  # Cross-platform notification script: notify <title> [body]
  notifyScript = pkgs.writeShellScript "notify" ''
    set -euo pipefail

    title="''${1:-Notification}"
    body="''${2:-}"

    ${lib.optionalString isLinux ''
      # Check if running in WSL
      if grep -qi microsoft /proc/version 2>/dev/null; then
        "${lib.getExe' toasty "toasty.exe"}" "$body" -t "$title" 2>/dev/null || true
      else
        ${lib.getExe pkgs.libnotify} "$title" "$body" 2>/dev/null || true
      fi
    ''}
    ${lib.optionalString isDarwin ''
      osascript -e "display notification \"$body\" with title \"$title\" sound name \"Glass\""
    ''}
  '';

  projectNotifyPackage = pkgs.writers.writeNuBin "project-notify" {
    makeWrapperArgs = [
      "--add-flag"
      "${notifyScript}"
    ];
  } (builtins.readFile ./project-notify.nu);
  mkProjectNotifyScript = lib.getExe projectNotifyPackage;
in
{
  inherit notifyScript mkProjectNotifyScript;
}
