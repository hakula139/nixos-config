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
    # Allow the primary user to manage `tailscale serve` (e.g. `t3 pair --tailscale`) without root.
    services.tailscale.extraSetFlags = [ "--operator=${config.hakula.user.name}" ];
  };
}
