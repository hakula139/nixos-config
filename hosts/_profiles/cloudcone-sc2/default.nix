{
  modulesPath,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# CloudCone SC2 Hardware Profile
# ==============================================================================
# This module contains shared boot loader, hardware, and disk configuration
# for all CloudCone SC2 instances. Import this from your instance-specific
# host configuration.
# ==============================================================================

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../../modules/nixos
    ./disk-config.nix
  ];

  # ============================================================================
  # Boot Loader & Hardware
  # ============================================================================
  # CloudCone's VPS uses a legacy external bootloader that expects a standard
  # MBR partition table and a legacy grub.conf.
  # We shim this by creating a static grub.conf that points to our NixOS kernel.
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "/dev/vda" ];
    configurationLimit = 20;

    extraInstallCommands = ''
      # Create symlinks to the current kernel / initrd in /boot.
      # This allows the static grub.conf to always find the latest build.
      ${pkgs.coreutils}/bin/ln -sfn /nix/var/nix/profiles/system/kernel /boot/vmlinuz
      ${pkgs.coreutils}/bin/ln -sfn /nix/var/nix/profiles/system/initrd /boot/initrd

      # Create a static legacy grub.conf for CloudCone's external bootloader.
      ${pkgs.coreutils}/bin/cat <<EOF >/boot/grub/grub.conf
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
      size = 2048;
    }
  ];

  services.qemuGuest.enable = true;
}
