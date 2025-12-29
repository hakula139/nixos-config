{
  modulesPath,
  pkgs,
  lib,
  hostName,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/nixos
    ./disk-config.nix
  ];

  # ============================================================================
  # Boot Loader & Hardware
  # ============================================================================
  # CloudCone's VPS uses a legacy external bootloader.
  # We create a static grub.conf that points to our NixOS kernel.
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "/dev/vda" ];
    configurationLimit = 10;

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
      size = 2048;
    }
  ];

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    inherit hostName;
    enableIPv6 = false;
    useDHCP = false; # CloudCone requires static IP configuration

    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "74.48.189.161";
          prefixLength = 26;
        }
      ];
    };

    defaultGateway = "74.48.189.129";

    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.cachix.enable = true;
  hakula.services.netdata.enable = true;
  hakula.services.nginx.enable = true;
  hakula.services.openssh = {
    enable = true;
    ports = [ 35060 ];
  };
  hakula.services.xray = {
    enable = true;
    ws.enable = true;
  };
  services.qemuGuest.enable = true;

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
