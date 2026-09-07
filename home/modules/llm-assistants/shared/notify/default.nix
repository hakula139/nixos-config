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
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;

  # Tiny Windows toast notification CLI for WSL
  # https://github.com/shanselman/toasty
  toasty = pkgs.runCommand "toasty" { } ''
    install -D -m 0755 ${
      pkgs.fetchurl {
        url = "https://github.com/shanselman/toasty/releases/download/v0.7/toasty-x64.exe";
        hash = "sha256-7cslwnZOC/miKx4VHOQLq+OifGvjBcXpeEUq334RSw4=";
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
        "${toasty}/bin/toasty.exe" "$body" -t "$title" 2>/dev/null || true
      else
        ${pkgs.libnotify}/bin/notify-send "$title" "$body" 2>/dev/null || true
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
  mkProjectNotifyScript = "${projectNotifyPackage}/bin/project-notify";
in
{
  inherit notifyScript mkProjectNotifyScript;
}
