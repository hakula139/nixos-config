# ==============================================================================
# Claude Code MCP Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  enabledServers,
  ...
}:

let
  json = pkgs.formats.json { };

  mcpOptions = import ../shared/mcp/options.nix { inherit lib; };
  mcp = import ../shared/mcp {
    inherit
      config
      pkgs
      lib
      secrets
      isNixOS
      ;
  };

  serversConfig = builtins.listToAttrs (
    map (s: {
      name = mcpOptions.serverDisplayNames.${s};
      value = mcp.servers.${s};
    }) enabledServers
  );

  configFile = json.generate "claude-code-mcp-config.json" {
    mcpServers = serversConfig;
  };

  # home-manager's programs.claude-code.mcpServers injects --mcp-config via
  # --append-flags, but Commander.js's variadic option parsing greedily
  # consumes subcommand names (setup-token, auth, etc.) as config file paths.
  # Handle --mcp-config here and skip injection for subcommands.
  configGuard = pkgs.writeShellScript "claude-mcp-config-guard" ''
    for __cc_arg in "$@"; do
      case "$__cc_arg" in
        agents|auth|doctor|install|mcp|plugin|plugins|setup-token|update|upgrade)
          return 0
          ;;
        --)
          break
          ;;
      esac
    done
    set -- --mcp-config ${configFile} "$@"
  '';
in
{
  inherit (mcp) secrets;
  inherit configGuard;
}
