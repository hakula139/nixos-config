{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Claude Code Hooks
# ==============================================================================

let
  notify = import ./notify.nix { inherit pkgs lib; };
in
{
  # ----------------------------------------------------------------------------
  # Post Tool Use - Formatting and validation
  # ----------------------------------------------------------------------------
  PostToolUse = [
    # Shell formatting and linting
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = ''
            for file in $CLAUDE_FILE_PATHS; do
              if [[ "$file" == *.sh ]]; then
                ${pkgs.shfmt}/bin/shfmt -w "$file" 2>/dev/null || true
                ${pkgs.shellcheck}/bin/shellcheck "$file" || true
              fi
            done
          '';
        }
      ];
    }
    # Nix formatting
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = ''
            for file in $CLAUDE_FILE_PATHS; do
              if [[ "$file" == *.nix ]]; then
                nix fmt "$file" 2>/dev/null || true
              fi
            done
          '';
        }
      ];
    }
  ];

  # ----------------------------------------------------------------------------
  # Notification - Permission requests and idle reminders
  # ----------------------------------------------------------------------------
  Notification = [
    {
      hooks = [
        {
          type = "command";
          command = ''
            input="$(cat)"
            project="$(basename "$PWD")"
            message="$(echo "$input" | ${pkgs.jq}/bin/jq -r '.message // "Notification"')"
            "${notify.notifyScript}" "Claude Code" "[$project] $message"
          '';
        }
      ];
    }
  ];

  # ----------------------------------------------------------------------------
  # Stop - Notifications when Claude needs input or completes
  # ----------------------------------------------------------------------------
  Stop = [
    {
      matcher = ".*";
      hooks = [
        {
          type = "command";
          command = ''
            reason="$CLAUDE_STOP_HOOK_REASON"
            project="$(basename "$PWD")"
            case "$reason" in
              user_input_needed)
                "${notify.notifyScript}" "Claude Code" "[$project] Waiting for input"
                ;;
              end_turn)
                "${notify.notifyScript}" "Claude Code" "[$project] Task completed"
                ;;
            esac
          '';
        }
      ];
    }
  ];
}
