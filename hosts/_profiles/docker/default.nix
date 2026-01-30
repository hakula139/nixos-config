{
  config,
  lib,
  ...
}:

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

  # Agenix needs an identity path for secret decryption. Containers don't run
  # openssh, so the host key must be bind-mounted at runtime.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

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
