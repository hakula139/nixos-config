# ==================================================================================================
# aria2 (Download Utility with RPC)
# ==================================================================================================

{
  config,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.aria2;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.aria2 = {
    enable = lib.mkEnableOption "aria2 download utility with RPC server";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    sops.secrets.aria2-rpc-secret = repoLib.secrets.mkSecret {
      name = "aria2/rpc-secret-cloudreve";
      owner = "aria2";
      group = "aria2";
      restartUnits = [ "aria2.service" ];
    };

    # ----------------------------------------------------------------------------------------------
    # aria2 service
    # ----------------------------------------------------------------------------------------------
    systemd.services.aria2 = repoLib.systemd.restartUnit;

    services.aria2 = {
      enable = true;
      rpcSecretFile = config.sops.secrets.aria2-rpc-secret.path;
      serviceUMask = "0002";
      settings = lib.mapAttrs (_: lib.mkDefault) (
        repoLib.aria2.downloadSettings // repoLib.aria2.rpcSettings
      );
    };
  };
}
