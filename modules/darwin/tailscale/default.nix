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
        Avoids routing table conflicts with other TUN-based tools
        (e.g., Clash Verge).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Tailscale service
    # --------------------------------------------------------------------------
    services.tailscale.enable = true;

    launchd.daemons.tailscaled.command = lib.mkIf cfg.userspaceNetworking (
      lib.mkForce (
        lib.getExe' config.services.tailscale.package "tailscaled" + " --tun=userspace-networking"
      )
    );
  };
}
