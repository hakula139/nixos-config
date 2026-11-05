# ==================================================================================================
# Claude Code Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  mkHooks,
  enableCorpGateway,
  modelAliases,
  notify,
}:

let
  sharedHooks = mkHooks {
    inherit enableCorpGateway;
    assistant = "claude-code";
    toolClasses = {
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
    model = modelAliases.flagship;
  };

  teammateIdle = import ./teammate-idle { inherit pkgs lib; };

  installed = sharedHooks.install (
    with sharedHooks.hooks;
    [
      autoDream
      autoFormat
      commentGate
      completeness
      teammateIdle
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
