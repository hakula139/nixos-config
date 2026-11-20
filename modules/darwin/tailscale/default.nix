# ==================================================================================================
# Tailscale (Mesh VPN)
# ==================================================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.services.tailscale;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    launchd.daemons.tailscaled.command = lib.mkForce (
      lib.getExe' config.services.tailscale.package "tailscaled" + " --tun=userspace-networking"
    );
  };
}
