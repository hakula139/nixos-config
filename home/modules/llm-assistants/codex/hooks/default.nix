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

  compactContext = import ./compact-context {
    inherit (sharedHooks) mkNuHook timeouts;
  };

  toolClasses = {
    fileWrite = [
      "Edit"
      "Write"
      "^apply_patch$"
    ];
  };

  enabledHooks = with sharedHooks.hooks; [
    compactContext
    autoFormat
    commentGate
  ];

  mkEntry = hook: {
    matcher = hook.matcher or (sharedHooks.mkMatcher toolClasses [ hook ]);
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

  installed = sharedHooks.install enabledHooks;
  enabledEvents = lib.mapAttrs (_: map mkEntry) (lib.groupBy (hook: hook.event) installed.hooks);

  workmuxHooks =
    (lib.importJSON "${pkgs.workmux.src}/resources/codex/hooks/workmux-status.json").hooks;
in
{
  events = lib.zipAttrsWith (_: lib.concatLists) [
    enabledEvents
    workmuxHooks
  ];

  inherit (installed) dataFiles;
}
