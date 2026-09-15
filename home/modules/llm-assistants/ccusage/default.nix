# ==============================================================================
# ccusage Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.hakula.ccusage;

  json = pkgs.formats.json { };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.ccusage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install ccusage and configure its usage stores";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    home.packages = [ pkgs.ccusage ];

    # --------------------------------------------------------------------------
    # Configuration files
    # --------------------------------------------------------------------------
    # ccusage discovers configuration for all agents in the Claude directory.
    xdg.configFile."claude/ccusage.json".source = json.generate "ccusage.json" {
      pi.stores = [
        {
          name = "omp";
          path = "${config.home.homeDirectory}/.omp/agent/sessions";
        }
      ];
    };
  };
}
