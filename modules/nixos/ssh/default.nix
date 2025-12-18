{ lib, config, ... }:

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
      default = [ 22 ];
    };
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # SSH
    # ----------------------------------------------------------------------------
    services.openssh = {
      enable = true;
      ports = cfg.ports;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
  };
}
