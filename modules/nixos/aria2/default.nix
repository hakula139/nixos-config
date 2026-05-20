# ==============================================================================
# aria2 (Download Utility with RPC)
# ==============================================================================

{
  config,
  lib,
  secrets,
  ...
}:

let
  cfg = config.hakula.services.aria2;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.aria2 = {
    enable = lib.mkEnableOption "aria2 download utility with RPC server";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.aria2-rpc-secret = secrets.mkSecret {
      name = "cloudreve/aria2-rpc-secret";
      owner = "aria2";
      group = "aria2";
    };

    # --------------------------------------------------------------------------
    # aria2 service
    # --------------------------------------------------------------------------
    services.aria2 = {
      enable = true;
      rpcSecretFile = config.age.secrets.aria2-rpc-secret.path;
      serviceUMask = "0002";
    };
  };
}
