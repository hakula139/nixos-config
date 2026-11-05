# ==================================================================================================
# Claude Code Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  shared,
  enableCorpGateway,
}:

let
  sharedHooks = shared.mkHooks {
    inherit enableCorpGateway;
    assistant = "claude-code";
    toolClasses = {
      fileWrite = [
        "Edit"
        "Write"
      ];
    };
  };

  projectNotify = "${shared.notify.mkProjectNotifyScript} 'Claude Code'";

  autoDream = import ./auto-dream {
    inherit pkgs lib sharedHooks;
    model = shared.profileDefinitions.modelAliases.claude.flagship;
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
