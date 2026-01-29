{ lib, ... }:

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
  users.users.hakula = {
    createHome = false;
    linger = false;
  };
}
