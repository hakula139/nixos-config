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
  sharedHooks = import ../shared/hooks {
    inherit
      pkgs
      lib
      repo
      enableDevToolchains
      ;
    assistant = "claude-code";
  };
  projectNotify = "${notify.mkProjectNotifyScript} 'Claude Code'";

  # ----------------------------------------------------------------------------
  # Shared hook vocabulary
  # ----------------------------------------------------------------------------
  toolClasses = {
    askQuestion = [ "AskUserQuestion" ];
    fileWrite = [
      "Edit"
      "Write"
    ];
  };

  enabledHooks = [
    "prosePolish"
    "wakatime"
    "autoFormat"
    "commentGate"
    "completeness"
  ];

  mkCommand =
    hook:
    if hook ? command then
      {
        type = "command";
        inherit (hook) command;
      }
    else
      {
        type = "prompt";
        inherit (hook) prompt;
      };

  mkEntry =
    hook:
    lib.optionalAttrs (hook ? tools) {
      matcher = lib.concatStringsSep "|" (
        lib.concatMap (tool: toolClasses.${tool} or [ tool ]) hook.tools
      );
    }
    // {
      hooks = [
        (
          mkCommand hook
          // lib.optionalAttrs (hook ? statusMessage) { inherit (hook) statusMessage; }
          // lib.optionalAttrs (hook ? async) { inherit (hook) async; }
        )
      ];
    };

  sharedEvents = lib.mapAttrs (_: names: map (name: mkEntry sharedHooks.hooks.${name}) names) (
    lib.groupBy (name: sharedHooks.hooks.${name}.event) enabledHooks
  );

  # ----------------------------------------------------------------------------
  # Claude Code only
  # ----------------------------------------------------------------------------
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
lib.zipAttrsWith (_: lib.concatLists) [
  sharedEvents
  ownEvents
]
