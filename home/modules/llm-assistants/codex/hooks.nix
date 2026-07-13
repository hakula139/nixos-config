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
  notify = import ../shared/notify.nix { inherit pkgs lib; };
  hookScripts = import ../shared/hooks { inherit pkgs lib repo; };
  projectNotify = "${notify.mkProjectNotifyScript} 'Codex'";

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

  PermissionRequest = [
    {
      hooks = [
        {
          type = "command";
          command = ''
            tool_name="$(${pkgs.jq}/bin/jq -r '.tool_name // empty')"
            case "$tool_name" in
              mcp__*)
                mcp_name="''${tool_name#mcp__}"
                mcp_name="''${mcp_name%%__*}"
                ${projectNotify} "$mcp_name permission requested" >/dev/null 2>&1
                ;;
              *)
                ${projectNotify} "$tool_name permission requested" >/dev/null 2>&1
                ;;
            esac
          '';
          timeout = 10;
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
            ${projectNotify} "Response complete" >/dev/null 2>&1
          '';
          timeout = 10;
        }
      ];
    }
  ];
}
