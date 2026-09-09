# ==============================================================================
# Codex Hooks
# ==============================================================================

{
  pkgs,
  lib,
  mkHooks,
  gateway ? { },
  ...
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
    wakatime
    (
      autoFormat
      // {
        timeout = sharedHooks.timeouts.postEdit;
        statusMessage = "Formatting edited files";
        command = toString (
          pkgs.writeShellScript "codex-format-feedback" ''
            set -euo pipefail
            ${autoFormat.command} | ${pkgs.jq}/bin/jq -Rs '
              select(length > 0)
              | {hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: .}}
            '
          ''
        );
      }
    )
    commentGate
  ];

  mkEntry = hook: {
    matcher = sharedHooks.mkMatcher toolClasses [ hook ];
    hooks = [
      (
        {
          type = "command";
          inherit (hook) command;
        }
        // lib.optionalAttrs (hook ? timeout) { inherit (hook) timeout; }
        // lib.optionalAttrs (hook ? statusMessage) { inherit (hook) statusMessage; }
      )
    ];
  };

  mkWorkmuxHook = status: {
    hooks = [
      {
        type = "command";
        command = "${pkgs.workmux}/bin/workmux set-window-status ${status}";
      }
    ];
  };
in
{
  UserPromptSubmit = [ (mkWorkmuxHook "working") ];

  PostToolUse = map mkEntry postEditHooks ++ [
    (mkWorkmuxHook "working")
  ];

  SubagentStart = [ (mkWorkmuxHook "working") ];

  SubagentStop = [ (mkWorkmuxHook "done") ];

  Stop = [
    (mkEntry sharedHooks.hooks.completeness)
    (mkWorkmuxHook "done")
  ];
}
