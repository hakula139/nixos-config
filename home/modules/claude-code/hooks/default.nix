{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Claude Code Hooks
# ==============================================================================

let
  notify = import ../../notify { inherit pkgs lib; };
  projectNotify = "${notify.mkProjectNotifyScript} 'Claude Code'";
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

  PermissionRequest = [
    # Notify when Claude Code needs user attention (permission or question)
    {
      hooks = [
        {
          type = "command";
          command = ''
            tool_name="$(${pkgs.jq}/bin/jq -r '.tool_name // empty')"
            case "$tool_name" in
              AskUserQuestion)
                ${projectNotify} "Question asked"
                ;;
              mcp__*)
                # Extract MCP server name
                mcp_name="''${tool_name#mcp__}"
                mcp_name="''${mcp_name%%__*}"
                ${projectNotify} "$mcp_name permission requested"
                ;;
              *)
                ${projectNotify} "$tool_name permission requested"
                ;;
            esac
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
            ${projectNotify} "Response complete"
          '';
        }
      ];
    }
  ];
}
