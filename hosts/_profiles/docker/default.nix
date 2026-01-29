{ config, lib, ... }:

let
  username = config.hakula.user.name;
in

# ==============================================================================
# Docker Container Profile
# ==============================================================================
# This module contains shared configuration for NixOS Docker images built with
# nixos-generators. Import this from your container-specific host configuration.
# ==============================================================================

{
  imports = [
    ../../../modules/nixos
  ];

  # ============================================================================
  # Container Configuration
  # ============================================================================
  boot.isContainer = true;

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    domain = null;
    firewall.enable = lib.mkDefault false;
  };

  # ============================================================================
  # User Overrides
  # ============================================================================
  users.users.${username}.linger = false;

  # ============================================================================
  # Directory Management
  # ============================================================================
  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root -"
  ];
}
