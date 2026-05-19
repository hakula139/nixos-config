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
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;
  };
}
