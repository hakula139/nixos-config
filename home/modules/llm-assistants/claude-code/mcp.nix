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

  # home-manager's programs.claude-code.mcpServers injection trips
  # Commander.js's variadic parsing, which eats subcommand names as
  # config paths. Inject --mcp-config here, skipping for subcommands.
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
