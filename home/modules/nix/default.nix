# ==================================================================================================
# Nix Configuration
# ==================================================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.nix;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.nix.configPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Absolute path to the local nixos-config checkout";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf (cfg.configPath != null) {
    xdg.configFile."nixos-config/repository".text = cfg.configPath + "\n";
  };
}
