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

  Notification = [
    # Permission prompt - notify when Claude Code needs approval
    {
      matcher = "permission_prompt";
      hooks = [
        {
          type = "command";
          command = ''
            project="$(basename "$PWD")"
            "${notify.notifyScript}" "Claude Code" "[$project] Permission requested"
          '';
        }
      ];
    }
  ];

  Stop = [
    # Response complete - notify when Claude Code finishes responding
    {
      hooks = [
        {
          type = "command";
          command = ''
            project="$(basename "$PWD")"
            "${notify.notifyScript}" "Claude Code" "[$project] Response complete"
          '';
        }
      ];
    }
  ];
}
