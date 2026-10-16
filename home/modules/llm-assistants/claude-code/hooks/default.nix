# ==================================================================================================
# Claude Code Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  mkHooks,
  modelAliases,
  notify,
}:

let
  sharedHooks = mkHooks {
    assistant = "claude-code";
    toolClasses = {
      askQuestion = [ "AskUserQuestion" ];
      fileWrite = [
        "Edit"
        "Write"
      ];
    };
  };

  projectNotify = "${notify.mkProjectNotifyScript} 'Claude Code'";

  autoDream = import ./auto-dream {
    inherit pkgs lib;
    inherit (sharedHooks) mkNuHook timeouts;
    model = modelAliases.standard;
  };

  installed = sharedHooks.install (
    with sharedHooks.hooks;
    [
      autoDream
      prosePolish
      autoFormat
      commentGate
      completeness
    ]
  );

  ownEvents = {
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
              session_id="$(printf '%s' "$input" | ${lib.getExe pkgs.jq} -r '.session_id // empty')"
              teammate_name="$(printf '%s' "$input" | ${lib.getExe pkgs.jq} -r '.teammate_name // empty')"
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
            type = "command";
            command = ''
              ${projectNotify} "Response complete"
            '';
          }
        ];
      }
    ];
  };
in
{
  events = lib.zipAttrsWith (_: lib.concatLists) [
    installed.events
    ownEvents
  ];

  inherit (installed) dataFiles;
}
