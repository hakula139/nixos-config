# ==================================================================================================
# PostgreSQL (Database Server)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.postgresql;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.postgresql = {
    enable = lib.mkEnableOption "PostgreSQL database server";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # PostgreSQL service
    # ----------------------------------------------------------------------------------------------
    systemd.services.postgresql = repoLib.systemd.restartUnit;

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_17;

      # Bind to all interfaces, since PostgreSQL silently skips the podman bridge address
      # (10.88.0.1) when the bridge does not exist yet at startup. The firewall (podman0 only) and
      # pg_hba.conf restrict access.
      enableTCPIP = true;

      settings = {
        password_encryption = "scram-sha-256";
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Firewall
    # ----------------------------------------------------------------------------------------------
    # Allow podman containers to reach PostgreSQL via the podman bridge.
    networking.firewall.interfaces.${config.hakula.podman.network.interface}.allowedTCPPorts = [
      config.services.postgresql.settings.port
    ];
  };
}
