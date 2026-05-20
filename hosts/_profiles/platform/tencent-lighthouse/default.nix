# ==============================================================================
# Tencent Lighthouse Hardware Profile
# ==============================================================================

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

  # ----------------------------------------------------------------------------
  # Boot Loader & Hardware
  # ----------------------------------------------------------------------------
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

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking.useDHCP = true;
}
