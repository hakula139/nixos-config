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

  proseTools = lib.concatStringsSep "|" (
    [
      "AskUserQuestion"
      "Edit"
      "Write"
    ]
    ++ builtins.attrNames hookScripts.mcpProseFields
  );
in
{
  PreToolUse = [
    {
      matcher = proseTools;
      hooks = [
        {
          type = "command";
          command = "${hookScripts.prosePolish}";
          statusMessage = "Polishing prose";
        }
      ];
    }
  ];

  PostToolUse = [
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
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = "${hookScripts.autoFormat}";
        }
      ];
    }
  ];

  PermissionRequest = [
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
    {
      hooks = [
        {
          type = "prompt";
          prompt = hookScripts.completenessPrompt;
          statusMessage = "Checking completeness";
        }
      ];
    }
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
