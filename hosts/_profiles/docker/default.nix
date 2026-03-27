# ==============================================================================
# Docker Container Profile
# ==============================================================================
# Shared configuration for NixOS Docker images built with
# dockerTools.buildLayeredImage. The mkDocker builder in flake.nix handles
# the image creation with multi-layer caching.
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  username = config.hakula.user.name;
in

{
  imports = [
    ../../../modules/nixos
  ];

  # ----------------------------------------------------------------------------
  # Container Configuration
  # ----------------------------------------------------------------------------
  boot.isContainer = true;

  # Agenix needs an identity path for secret decryption. Containers don't run
  # openssh, so we use a dedicated key stored in the persistent Docker volume.
  age.identityPaths = [ "/root/.config/agenix/identity" ];

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    domain = lib.mkForce null;
    firewall.enable = lib.mkForce false;
  };

  # ----------------------------------------------------------------------------
  # User Overrides
  # ----------------------------------------------------------------------------
  users.users.${username}.linger = lib.mkForce false;

  # ----------------------------------------------------------------------------
  # Directory Management
  # ----------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root -"
  ];
}
