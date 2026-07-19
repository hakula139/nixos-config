# ==============================================================================
# Codex Hooks
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  ...
}:

let
  hookScripts = import ../shared/hooks { inherit pkgs lib repo; };

  enforceMcpScript = hookScripts.mkEnforceMcpScript {
    name = "codex-enforce-mcp";
    hintMode = "system-message";
  };
  autoFormatScript = hookScripts.mkAutoFormatScript { name = "codex-auto-format"; };
  wakatimeScript = hookScripts.mkWakatimeScript {
    name = "codex-wakatime-heartbeat";
    pluginName = "codex-hook/1.0";
  };
  postEditScript = pkgs.writeShellScript "codex-post-edit" ''
    input="$(cat)"
    printf '%s' "$input" | ${wakatimeScript} || true
    printf '%s' "$input" | ${autoFormatScript} || true
  '';
in
{
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
  ];
}
