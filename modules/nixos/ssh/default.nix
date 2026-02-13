{
  config,
  lib,
  ...
}:

# ==============================================================================
# OpenSSH (Remote Access)
# ==============================================================================

let
  cfg = config.hakula.services.openssh;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.openssh = {
    enable = lib.mkEnableOption "OpenSSH server";
    ports = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 35060 ];
      description = "Ports to listen on for SSH connections";
    };
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # OpenSSH service
    # ----------------------------------------------------------------------------
    services.openssh = {
      enable = true;
      inherit (cfg) ports;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
  };
}
