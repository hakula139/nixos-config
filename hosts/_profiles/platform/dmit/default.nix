# ==================================================================================================
# DMIT Hardware Profile
# ==================================================================================================

{
  modulesPath,
  lib,
  repo,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    repo.modules.nixos
    ../disk-config.nix
  ];

  # ------------------------------------------------------------------------------------------------
  # Boot Loader & Hardware
  # ------------------------------------------------------------------------------------------------
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "/dev/vda" ];
    configurationLimit = 5;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4096;
    }
  ];

  services.qemuGuest.enable = true;

  # ------------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------------
  # DMIT assigns /32 IPv4 with an off-subnet gateway using proxy ARP. dhcpcd misinterprets this as
  # an ARP conflict and loops on dropping and reacquiring the lease, which systemd-networkd avoids.
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
