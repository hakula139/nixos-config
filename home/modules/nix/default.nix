# ==============================================================================
# Nix Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  caches,
  isNixOS ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isLinux;
  cfg = config.hakula.nix;

  nixConf = ''
    experimental-features = nix-command flakes
    extra-substituters = ${lib.concatStringsSep " " caches.substituters}
    extra-trusted-public-keys = ${lib.concatStringsSep " " caches.trusted-public-keys}
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.nix.configPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Absolute path to the local nixos-config checkout";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      xdg.configFile."nix/nix.conf" = lib.mkIf (isLinux && !isNixOS) {
        text = nixConf;
      };
    }

    (lib.mkIf (cfg.configPath != null) {
      home.sessionVariables.NIXOS_CONFIG_DIR = cfg.configPath;
      xdg.configFile."nixos-config/repository".text = cfg.configPath + "\n";
    })
  ];
}
