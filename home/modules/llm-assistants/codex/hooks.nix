# ==============================================================================
# Codex Hooks
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  devTools ? true,
  ...
}:

let
  hookScripts = import ../shared/hooks { inherit pkgs lib repo; };

  enforceMcpScript = hookScripts.mkEnforceMcpScript {
    name = "codex-enforce-mcp";
    hintMode = "system-message";
  };
  autoFormatScript = hookScripts.mkAutoFormatScript {
    name = "codex-auto-format";
    inherit devTools;
  };
  guardLocalFilesScript = hookScripts.mkGuardLocalFilesScript {
    name = "codex-guard-local-files";
  };
  proseGateScript = hookScripts.mkProseGateScript {
    name = "codex-prose-gate";
    promptFile = ../claude-code/hooks/prompts/prose-tics.md;
    inherit devTools;
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

  PreToolUse = [
    {
      matcher = "^Bash$";
      hooks = [
        {
          type = "command";
          command = "${enforceMcpScript}";
          timeout = 10;
          statusMessage = "Checking Bash command";
        }
      ];
    }
    # A matcher of only alphanumerics, `_`, and `|` is treated as an exact
    # match, so the anchors keep this a regex.
    {
      matcher = "^(Bash|Edit|Write|apply_patch)$";
      hooks = [
        {
          type = "command";
          command = "${guardLocalFilesScript}";
          timeout = 10;
          statusMessage = "Checking guarded paths";
        }
      ];
    }
  ];

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

  # No completeness gate here. Codex parses `prompt` and `agent` handler types
  # but executes only `command` ones, so Claude Code's Stop prompt gate would
  # install and silently never run. An equivalent needs a command hook that
  # invokes its own judge and emits {"decision":"block","reason":"..."}.
  Stop = [ (mkWorkmuxHook "done") ];
}
