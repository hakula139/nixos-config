{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# PostgreSQL (Database Server)
# ==============================================================================

let
  cfg = config.hakula.services.postgresql;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.postgresql = {
    enable = lib.mkEnableOption "PostgreSQL database server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_17;
      description = "PostgreSQL package / version to use for this host";
    };

    listenOnPodman = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow PostgreSQL connections from Podman containers via bridge network";
    };
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # PostgreSQL service
    # --------------------------------------------------------------------------
    services.postgresql = {
      enable = true;
      package = cfg.package;
      settings = {
        password_encryption = lib.mkDefault "scram-sha-256";
      }
      // lib.optionalAttrs cfg.listenOnPodman {
        listen_addresses = lib.mkForce "127.0.0.1,${config.hakula.podman.network.gateway}";
      };
    };
  };
}
