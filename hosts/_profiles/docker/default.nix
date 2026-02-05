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
# Shared configuration for NixOS Docker images. The docker-image.nix module
# from nixpkgs is imported in flake.nix's mkDocker builder.
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
    domain = lib.mkForce null;
    firewall.enable = lib.mkForce false;
  };

  # ============================================================================
  # User Overrides
  # ============================================================================
  users.users.${username}.linger = lib.mkForce false;

  # ============================================================================
  # Directory Management
  # ============================================================================
  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root -"
  ];
}
