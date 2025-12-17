{ lib, config, ... }:

# ==============================================================================
# OpenSSH (Remote Access)
# ==============================================================================

let
  cfg = config.services.sshServer;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.services.sshServer = {
    enable = lib.mkEnableOption "OpenSSH server";
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # SSH
    # ----------------------------------------------------------------------------
    services.openssh = {
      enable = true;
      ports = [ 35060 ];
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
  };
}
