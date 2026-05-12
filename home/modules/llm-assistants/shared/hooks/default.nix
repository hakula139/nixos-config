# ==============================================================================
# Shared Hook Scripts
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

let
  mkEnvExports = lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}");

  mkHookScript =
    {
      name,
      script,
      env ? { },
    }:
    pkgs.writeShellScript name (
      lib.concatStringsSep "\n" (mkEnvExports env ++ [ (builtins.readFile script) ])
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
      env.HAKULA_HOOK_HINT_MODE = hintMode;
    };

  mkWakatimeScript =
    {
      name ? "wakatime-heartbeat",
      pluginName,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/wakatime.sh;
      env.HAKULA_WAKATIME_PLUGIN = pluginName;
    };
}
