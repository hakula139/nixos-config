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
  hookScripts = import ../shared/hooks { inherit pkgs lib repo; };

  autoFormatScript = hookScripts.mkAutoFormatScript {
    name = "codex-auto-format";
    inherit enableDevToolchains;
  };
  completenessGateScript = hookScripts.mkCompletenessGateScript {
    name = "codex-completeness-gate";
    promptFile = ../shared/hooks/prompts/completeness.md;
  };
  proseGateScript = hookScripts.mkProseGateScript {
    name = "codex-prose-gate";
    promptFile = ../shared/hooks/prompts/prose-tics.md;
    inherit enableDevToolchains;
  };
  wakatimeScript = hookScripts.mkWakatimeScript {
    name = "codex-wakatime-heartbeat";
    pluginName = "codex-hook/1.0";
  };
  postEditScript = pkgs.writeShellScript "codex-post-edit" ''
    input="$(cat)"
    printf '%s' "$input" | ${wakatimeScript} || true
    printf '%s' "$input" | ${autoFormatScript} || true
    printf '%s' "$input" | ${proseGateScript} || true
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
          command = "${completenessGateScript}";
          timeout = 40;
          statusMessage = "Checking completeness";
        }
      ];
    }
    (mkWorkmuxHook "done")
  ];
}
