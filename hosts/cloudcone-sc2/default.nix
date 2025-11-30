{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/common.nix
    ./disk-config.nix
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
    configurationLimit = 10;
    extraInstallCommands = ''
      ln -sfn /nix/var/nix/profiles/system/kernel /boot/vmlinuz
      ln -sfn /nix/var/nix/profiles/system/initrd /boot/initrd

      cat <<EOF >/boot/grub/grub.conf
      default=0
      timeout=1
      title NixOS
          root (hd0,0)
          kernel /boot/vmlinuz init=/nix/var/nix/profiles/system/init root=/dev/vda1 ro
          initrd /boot/initrd
      EOF
    '';
  };

  networking = {
    hostName = "cloudcone-sc2";
    useDHCP = false;

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

  system.stateVersion = "25.05";
}
