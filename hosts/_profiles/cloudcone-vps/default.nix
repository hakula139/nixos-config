{
  modulesPath,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# CloudCone VPS Hardware Profile
# ==============================================================================
# This module contains shared boot loader, hardware, and disk configuration
# for all CloudCone VPS instances. Import this from your instance-specific
# host configuration.
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
  # CloudCone's VPS uses a legacy external bootloader.
  # We create a static grub.conf that points to our NixOS kernel.
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "/dev/vda" ];
    configurationLimit = lib.mkDefault 5;

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
          root (hd0,1)
          kernel /boot/vmlinuz init=/nix/var/nix/profiles/system/init root=/dev/vda2 ro
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

  # ============================================================================
  # Networking
  # ============================================================================
  networking.useDHCP = false;
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
    "2001:4860:4860::8888"
    "2606:4700:4700::1111"
  ];

  # Disable IPv6 privacy extensions (RFC 4941) to prevent the kernel from
  # generating temporary addresses that would be preferred as the source
  # address for outbound connections. CloudCone VPS only routes traffic from
  # statically assigned IPv6 addresses.
  networking.tempAddresses = "disabled";

  # Disable SLAAC and Router Advertisements on eth0.
  # CloudCone assigns static IPv6 addresses, but the kernel creates additional
  # SLAAC / autoconf addresses via router advertisements and uses them as the
  # default source for outbound traffic. The provider only routes the static
  # addresses, breaking IPv6 connectivity.
  boot.kernel.sysctl = {
    "net.ipv6.conf.eth0.autoconf" = 0;
    "net.ipv6.conf.eth0.accept_ra" = 0;
  };
}
