# ==============================================================================
# Shared Hook Scripts
# ==============================================================================

{
  pkgs,
  ...
}:

let
  mkHookScript =
    {
      name,
      script,
      substitutions ? { },
    }:
    pkgs.writeShellScript name (
      builtins.replaceStrings (builtins.attrNames substitutions) (builtins.attrValues substitutions) (
        builtins.readFile script
      )
    );
in
{
  mkAutoFormatScript =
    {
      name ? "auto-format",
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/auto-format.sh;
    };

  mkEnforceMcpScript =
    {
      name ? "enforce-mcp",
      hintMode,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/enforce-mcp.sh;
      substitutions."@hintMode@" = hintMode;
    };

  mkWakatimeScript =
    {
      name ? "wakatime-heartbeat",
      pluginName,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/wakatime.sh;
      substitutions."@pluginName@" = pluginName;
    };
}
