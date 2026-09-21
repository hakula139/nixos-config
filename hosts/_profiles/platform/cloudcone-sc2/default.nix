# ==============================================================================
# CloudCone SC2 Hardware Profile
# ==============================================================================

{
  modulesPath,
  pkgs,
  lib,
  repo,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    repo.modules.nixos
    ./disk-config.nix
  ];

  # ----------------------------------------------------------------------------
  # Boot Loader & Hardware
  # ----------------------------------------------------------------------------
  # CloudCone's VPS uses a legacy external bootloader that expects a standard
  # MBR partition table and a legacy grub.conf.
  # We shim this by creating a static grub.conf that points to our NixOS kernel.
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "/dev/vda" ];
    configurationLimit = 5;

    extraInstallCommands = ''
      # Create symlinks to the current kernel / initrd in /boot.
      # This allows the static grub.conf to always find the latest build.
      ${lib.getExe' pkgs.coreutils "ln"} -sfn /nix/var/nix/profiles/system/kernel /boot/vmlinuz
      ${lib.getExe' pkgs.coreutils "ln"} -sfn /nix/var/nix/profiles/system/initrd /boot/initrd

      # Create a static legacy grub.conf for CloudCone's external bootloader.
      ${lib.getExe' pkgs.coreutils "cat"} <<EOF >/boot/grub/grub.conf
      default=0
      timeout=1
      title NixOS
          root (hd0,0)
          kernel /boot/vmlinuz init=/nix/var/nix/profiles/system/init root=/dev/vda1 ro
          initrd /boot/initrd
      EOF
    '';
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
  networking.useDHCP = false;
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
    "2001:4860:4860::8888"
    "2606:4700:4700::1111"
  ];
}
