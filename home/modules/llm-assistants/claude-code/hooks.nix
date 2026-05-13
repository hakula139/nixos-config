# ==============================================================================
# Claude Code Hooks
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

let
  notify = import ../shared/notify.nix { inherit pkgs lib; };
  hookScripts = import ../shared/hooks { inherit pkgs lib; };
  projectNotify = "${notify.mkProjectNotifyScript} 'Claude Code'";
  autoFormatScript = hookScripts.mkAutoFormatScript { name = "claude-code-auto-format"; };
  enforceMcpScript = hookScripts.mkEnforceMcpScript {
    name = "claude-code-enforce-mcp";
    hintMode = "permission-allow";
  };
  wakatimeScript = hookScripts.mkWakatimeScript {
    name = "claude-code-wakatime-heartbeat";
    pluginName = "claude-code-hook/1.0";
  };
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
    # WakaTime heartbeat for AI-generated file edits
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = "${wakatimeScript}";
          async = true;
        }
      ];
    }
    # Auto-format and lint edited files
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = "${autoFormatScript}";
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
    # Quality gate - evaluate conversation completeness
    # Disabled: prompt-type Stop hooks have a known JSON validation bug.
    # https://github.com/anthropics/claude-code/issues/11947
    # {
    #   hooks = [
    #     {
    #       type = "prompt";
    #       prompt = ''
    #         Should the agent stop working? Evaluate whether all requested tasks are complete:
    #         1. All user-requested tasks are actually done (not left partially done).
    #         2. No WIP or unimplemented features are described as complete.
    #         3. If code was modified, related docs and tests are updated where applicable.
    #         4. No errors or failures remain unaddressed.
    #       '';
    #       model = "sonnet";
    #       timeout = 15;
    #     }
    #   ];
    # }

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
