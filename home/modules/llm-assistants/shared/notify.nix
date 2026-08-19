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

  # Project-scoped notification: projectNotify <title> <message>
  # Prepends "[project-name]" to the message body, with the thread id when the
  # caller supplies a payload carrying one.
  mkProjectNotifyScript = pkgs.writeShellScript "project-notify" ''
    set -euo pipefail

    title="''${1:-Notification}"
    message="''${2:-}"
    payload="''${3:-}"
    project="$(basename "$PWD")"
    session_tag=""

    if [[ -n "$payload" ]] && printf '%s' "$payload" | ${pkgs.jq}/bin/jq -e . >/dev/null 2>&1; then
      thread_id="$(printf '%s' "$payload" | ${pkgs.jq}/bin/jq -r '."thread-id" // empty')"
      payload_cwd="$(printf '%s' "$payload" | ${pkgs.jq}/bin/jq -r '.cwd // empty')"
      if [[ -n "$payload_cwd" ]]; then
        project="$(basename "$payload_cwd")"
      fi
      if [[ -n "$thread_id" ]]; then
        session_tag=" ''${thread_id:0:8}"
      fi
    fi

    "${notifyScript}" "$title" "[$project$session_tag] $message"
  '';
in
{
  inherit notifyScript mkProjectNotifyScript;
}
