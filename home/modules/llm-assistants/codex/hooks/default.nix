# ==================================================================================================
# Codex Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  mkHooks,
  enableCorpGateway,
}:

let
  sharedHooks = mkHooks {
    inherit enableCorpGateway;
    assistant = "codex";
    toolClasses = {
      fileWrite = [
        "Edit"
        "Write"
        "^apply_patch$"
      ];
    };
  };

  compactContext = import ./compact-context {
    inherit (sharedHooks) mkNuHook timeouts;
  };

  installed = sharedHooks.install (
    with sharedHooks.hooks;
    [
      compactContext
      autoFormat
      commentGate
    ]
  );

  workmuxHooks =
    (lib.importJSON "${pkgs.workmux.src}/resources/codex/hooks/workmux-status.json").hooks;
in
{
  events = lib.zipAttrsWith (_: lib.concatLists) [
    installed.events
    workmuxHooks
  ];

  inherit (installed) dataFiles;
}
