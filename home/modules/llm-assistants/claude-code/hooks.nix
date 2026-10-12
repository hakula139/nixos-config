# ==================================================================================================
# Claude Code Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  mkHooks,
  notify,
}:

let
  sharedHooks = mkHooks {
    assistant = "claude-code";
  };

  projectNotify = "${notify.mkProjectNotifyScript} 'Claude Code'";

  toolClasses = {
    askQuestion = [ "AskUserQuestion" ];
    fileWrite = [
      "Edit"
      "Write"
    ];
  };

  enabledHooks = with sharedHooks.hooks; [
    prosePolish
    autoFormat
    commentGate
    completeness
  ];

  mkHandler =
    hook:
    if hook.type == "command" then
      {
        inherit (hook) type command;
      }
    else
      {
        inherit (hook) type prompt;
      };

  mkEntry =
    hook:
    lib.optionalAttrs (hook ? tools) {
      matcher = sharedHooks.mkMatcher toolClasses [ hook ];
    }
    // {
      hooks = [
        (
          mkHandler hook
          // lib.optionalAttrs (hook ? timeout) { inherit (hook) timeout; }
          // lib.optionalAttrs (hook ? statusMessage) { inherit (hook) statusMessage; }
          // lib.optionalAttrs (hook ? async) { inherit (hook) async; }
        )
      ];
    };

  installed = sharedHooks.install enabledHooks;
  sharedEvents = lib.mapAttrs (_: map mkEntry) (lib.groupBy (hook: hook.event) installed.hooks);

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
    sharedEvents
    ownEvents
  ];

  inherit (installed) dataFiles;
}
