{
  modulesPath,
  lib,
  ...
}:

# ==============================================================================
# DMIT Hardware Profile
# ==============================================================================
# This module contains shared boot loader, hardware, and disk configuration
# for all DMIT instances. Import this from your instance-specific host
# configuration.
# ==============================================================================

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../../modules/nixos
    ../disk-config.nix
  ];

  # ============================================================================
  # Boot Loader & Hardware
  # ============================================================================
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "/dev/vda" ];
    configurationLimit = lib.mkDefault 5;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 2048;
    }
  ];

  services.qemuGuest.enable = true;

  # ============================================================================
  # Networking
  # ============================================================================
  # DMIT assigns /32 IPv4 with an off-subnet gateway using proxy ARP.
  # dhcpcd misinterprets this as an ARP conflict, causing an infinite
  # lease-drop-reacquire loop. systemd-networkd handles this correctly.
  networking.useDHCP = false;

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "en*";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };
}
