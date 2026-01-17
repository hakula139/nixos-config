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
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # OpenSSH service
    # --------------------------------------------------------------------------
    services.openssh = {
      enable = true;
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
      '';
    };
  };
}
