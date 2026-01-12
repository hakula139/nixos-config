{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Claude Code Configuration
# ==============================================================================

let
  cfg = config.hakula.claudeCode;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.claudeCode = {
    enable = lib.mkEnableOption "Claude Code configuration";
  };

  config = lib.mkIf cfg.enable (
    let
      secretsDir = "${config.home.homeDirectory}/.secrets";
      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          isNixOS
          secretsDir
          ;
      };
    in
    lib.mkMerge [
      mcp.secrets
      {
        # ------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------
        home.packages = [
          pkgs.unstable.claude-code
        ];

        # ------------------------------------------------------------------------
        # User configuration files
        # ------------------------------------------------------------------------
        home.file = {
          ".claude.json".source = mcp.mcpJson;
        };
      }
    ]
  );
}
