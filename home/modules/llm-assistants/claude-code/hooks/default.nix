# ==============================================================================
# Claude Code Hooks
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  ...
}:

let
  notify = import ../../shared/notify.nix { inherit pkgs lib; };
  hookScripts = import ../../shared/hooks { inherit pkgs lib repo; };
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
  proseGateScript = hookScripts.mkProseGateScript {
    name = "claude-code-prose-gate";
    promptFile = ./prompts/prose-tics.md;
  };

  completenessPrompt = builtins.readFile ./prompts/completeness.md;
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
    # Style gate - flag banned prose tics in edited files and MCP-published prose
    {
      matcher = "Edit|Write|mcp__(GitLab|GitHub)__(create|update|add)_|mcp__.*_write";
      hooks = [
        {
          type = "command";
          command = "${proseGateScript}";
          timeout = 30;
          statusMessage = "Checking prose style";
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
    # Completeness gate - block stopping while requested work is unfinished
    {
      hooks = [
        {
          type = "prompt";
          prompt = completenessPrompt;
          timeout = 30;
          statusMessage = "Checking completeness";
        }
      ];
    }
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
