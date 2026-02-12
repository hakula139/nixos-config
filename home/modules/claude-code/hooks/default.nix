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
  enforceMcpScript = pkgs.writeShellScript "enforce-mcp" (builtins.readFile ./enforce-mcp.sh);
in
{
  PreToolUse = [
    # Enforce MCP tool usage over Bash equivalents
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          command = "${enforceMcpScript}";
        }
      ];
    }
  ];

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

  # Nudge teammates once to check for remaining work before going idle
  TeammateIdle = [
    {
      hooks = [
        {
          type = "command";
          command = ''
            session_id="$(${pkgs.jq}/bin/jq -r '.session_id // empty')"
            teammate_name="$(${pkgs.jq}/bin/jq -r '.teammate_name // empty')"
            nudge_flag="/tmp/claude-team-nudged-''${session_id:-unknown}"
            if [ ! -f "$nudge_flag" ]; then
              touch "$nudge_flag"
              printf "Teammate %s: before going idle, check TaskList for unclaimed tasks and send any unsent findings via SendMessage." "$teammate_name" >&2
              exit 2
            fi
          '';
        }
      ];
    }
  ];

  # Notify when a teammate marks a task as completed
  TaskCompleted = [
    {
      hooks = [
        {
          type = "command";
          command = ''
            task_subject="$(${pkgs.jq}/bin/jq -r '.task_subject // empty')"
            ${projectNotify} "Task completed: $task_subject"
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
