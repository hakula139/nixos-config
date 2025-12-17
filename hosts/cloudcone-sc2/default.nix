{ modulesPath, pkgs, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/nixos
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
    device = "/dev/vda";

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

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    hostName = "cloudcone-sc2";
    useDHCP = false; # CloudCone requires static IP configuration

    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = "74.48.108.20";
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = "2607:f130:0:10d::7f";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:10d::80";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:10d::81";
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = "74.48.108.1";
    defaultGateway6 = "2607:f130:0:10d::1";

    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };

  # ============================================================================
  # Services
  # ============================================================================
  services.cachixSecret.enable = true;
  services.clashGenerator.enable = true;
  services.cloudconeAgent.enable = true;
  services.netdataMonitoring.enable = true;
  services.nginxProxy.enable = true;
  services.qemuGuest.enable = true;
  services.sshServer.enable = true;
  services.xrayServer.enable = true;

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.05";
}
