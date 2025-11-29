{ lib, ... }:

{
  imports = [
    ../../modules/common.nix
    ./disk-config.nix
  ];

  boot.loader.grub = {
    efiSupport = false;
    mirroredBoots = lib.mkForce [
      {
        devices = [ "/dev/vda" ];
        path = "/boot";
      }
    ];
  };

  networking = {
    hostName = "us";
    firewall.allowedTCPPorts = [ 35060 ];
  };

  system.stateVersion = "25.05";
}
