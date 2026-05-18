# ==============================================================================
# Tailscale (Mesh VPN)
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.services.tailscale;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale mesh VPN";

    userspaceNetworking = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use userspace networking instead of a kernel TUN device.
        Defined for option-level parity with the Darwin module; on Linux
        the kernel TUN driver is preferred and this flag is ignored.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Tailscale service
    # --------------------------------------------------------------------------
    services.tailscale.enable = true;
  };
}
