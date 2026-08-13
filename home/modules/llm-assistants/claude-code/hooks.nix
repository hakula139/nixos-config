# ==============================================================================
# Claude Code Hooks
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  enableDevToolchains ? true,
  ...
}:

let
  notify = import ../shared/notify.nix { inherit pkgs lib; };
  hookScripts = import ../shared/hooks {
    inherit
      pkgs
      lib
      repo
      enableDevToolchains
      ;
    assistant = "claude-code";
  };
  projectNotify = "${notify.mkProjectNotifyScript} 'Claude Code'";

  proseGateMatcher = lib.concatStringsSep "|" [
    "Edit"
    "Write"
    "mcp__Atlassian__confluence_(create_page|update_page|add_comment|add_inline_comment|reply_to_comment)"
    "mcp__Git__git_commit"
    "mcp__(GitHub|GitLab)__(create|update|add)_"
    "mcp__.*_write"
  ];
in
{
  PostToolUse = [
    # WakaTime heartbeat for AI-generated file edits
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = "${hookScripts.wakatime}";
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
          command = "${hookScripts.autoFormat}";
        }
      ];
    }
    # Style gate - flag banned prose tics in edited files and MCP-published prose
    {
      matcher = proseGateMatcher;
      hooks = [
        {
          type = "command";
          command = "${hookScripts.proseGate}";
          timeout = hookScripts.timeouts.proseGate;
          statusMessage = "Checking prose style";
        }
      ];
    }
  ];

  PermissionRequest = [
    # Notify when Claude Code asks a question
    {
      matcher = "AskUserQuestion";
      hooks = [
        {
          type = "command";
          command = ''
            ${projectNotify} "Question asked"
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
            input="$(cat)"
            session_id="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.session_id // empty')"
            teammate_name="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.teammate_name // empty')"
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

  Stop = [
    # Completeness gate - block stopping while requested work is unfinished
    {
      hooks = [
        {
          type = "prompt";
          prompt = hookScripts.completenessPrompt;
          timeout = hookScripts.timeouts.judge;
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
