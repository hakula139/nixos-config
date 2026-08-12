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
  hookScripts = import ../shared/hooks {
    inherit
      pkgs
      lib
      repo
      enableDevToolchains
      ;
    assistant = "codex";
  };

  postEditScript = pkgs.writeShellScript "codex-post-edit" ''
    input="$(cat)"
    printf '%s' "$input" | ${hookScripts.wakatime} || true
    printf '%s' "$input" | ${hookScripts.autoFormat} || true
    printf '%s' "$input" | ${hookScripts.proseGate} || true
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
      matcher = "Edit|Write|^apply_patch$";
      hooks = [
        {
          type = "command";
          command = "${postEditScript}";
          timeout = 120;
          statusMessage = "Processing edited files";
        }
      ];
    }
    (mkWorkmuxHook "working")
  ];

  SubagentStart = [ (mkWorkmuxHook "working") ];

  SubagentStop = [ (mkWorkmuxHook "done") ];

  Stop = [
    {
      hooks = [
        {
          type = "command";
          command = "${hookScripts.completenessGate}";
          timeout = hookScripts.completenessTimeout;
          statusMessage = "Checking completeness";
        }
      ];
    }
    (mkWorkmuxHook "done")
  ];
}
