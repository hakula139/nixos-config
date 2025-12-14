{ pkgs, ... }:

# ============================================================================
# Shared Configuration
# ============================================================================

let
  keys = import ../secrets/keys.nix;

  cachixCacheName = "hakula";
  cachixPublicKey = "hakula.cachix.org-1:7zwB3fhMfReHdOjh6DmnaLXgqbPDBcojvN9F+osZw0k=";
  caches = import ./nix/caches.nix { inherit cachixCacheName cachixPublicKey; };
in
{
  # SSH public keys
  sshKeys = keys.users;

  # Base packages available on all systems
  basePackages = with pkgs; [
    curl
    git
    htop
    vim
  ];

  # Font packages (Nerd Fonts for terminal icons)
  fonts = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # Nix development tools
  nixTooling = with pkgs; [
    cachix
    nil
    nix-tree
    nixfmt-rfc-style
    nom
    nvd
  ];

  # Nix settings
  nixSettings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    keep-outputs = true;
    keep-derivations = true;
    download-buffer-size = 536870912;
    inherit (caches) substituters trusted-public-keys;
  };
}
