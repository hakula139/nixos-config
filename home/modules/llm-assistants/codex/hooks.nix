# ==================================================================================================
# Codex Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  mkHooks,
  gateway ? { },
}:

let
  sharedHooks = mkHooks {
    inherit gateway;
    assistant = "codex";
  };

  toolClasses = {
    fileWrite = [
      "Edit"
      "Write"
      "^apply_patch$"
    ];
  };

  postEditHooks = with sharedHooks.hooks; [
    (
      autoFormat
      // {
        timeout = sharedHooks.timeouts.postEdit;
        statusMessage = "Formatting edited files";
      }
    )
    commentGate
  ];

  mkEntry = hook: {
    matcher = sharedHooks.mkMatcher toolClasses [ hook ];
    hooks = [
      (
        {
          inherit (hook) type command;
        }
        // lib.optionalAttrs (hook ? timeout) { inherit (hook) timeout; }
        // lib.optionalAttrs (hook ? statusMessage) { inherit (hook) statusMessage; }
      )
    ];
  };

  workmuxHooks =
    (lib.importJSON "${pkgs.workmux.src}/resources/codex/hooks/workmux-status.json").hooks;
in
lib.zipAttrsWith (_: lib.concatLists) [
  { PostToolUse = map mkEntry postEditHooks; }
  workmuxHooks
]
