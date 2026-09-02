# ==============================================================================
# Codex Hooks
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  enableDevToolchains ? true,
  ...
}:

let
  sharedHooks = import ../shared/hooks {
    inherit
      pkgs
      lib
      repo
      enableDevToolchains
      ;
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
    autoFormat
  ];

  postEditMatcher = sharedHooks.mkMatcher toolClasses postEditHooks;

  postEditScript = pkgs.writeShellScript "codex-post-edit" ''
    input="$(cat)"
    ${lib.concatMapStringsSep "\n" (
      hook: ''printf '%s' "$input" | ${hook.command} || true''
    ) postEditHooks}
  '';

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

  PostToolUse = [
    {
      matcher = postEditMatcher;
      hooks = [
        {
          type = "command";
          command = "${postEditScript}";
          timeout = sharedHooks.timeouts.postEdit;
          statusMessage = "Processing edited files";
        }
      ];
    }
    (mkWorkmuxHook "working")
  ];

  SubagentStart = [ (mkWorkmuxHook "working") ];

  SubagentStop = [ (mkWorkmuxHook "done") ];

  Stop = [ (mkWorkmuxHook "done") ];
}
