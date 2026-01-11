{ pkgs, ... }:

# ==============================================================================
# Shared Configuration (cross-platform)
# ==============================================================================

let
  keys = import ../secrets/keys.nix;
  tooling = import ../lib/tooling.nix { inherit pkgs; };
in
{
  # ----------------------------------------------------------------------------
  # SSH public keys
  # ----------------------------------------------------------------------------
  sshKeys = keys.users;

  # ----------------------------------------------------------------------------
  # Base packages (system-wide)
  # ----------------------------------------------------------------------------
  basePackages = with pkgs; [
    curl
    wget
    git
    htop
    vim
  ];

  # ----------------------------------------------------------------------------
  # Font packages
  # ----------------------------------------------------------------------------
  fonts = with pkgs; [
    nerd-fonts.jetbrains-mono
    sarasa-gothic
    source-han-sans
    source-han-serif
  ];

  # ----------------------------------------------------------------------------
  # Cachix configuration
  # ----------------------------------------------------------------------------
  cachix =
    let
      cacheName = "hakula";
      publicKey = "hakula.cachix.org-1:7zwB3fhMfReHdOjh6DmnaLXgqbPDBcojvN9F+osZw0k=";
      cacheUrl = "https://${cacheName}.cachix.org";
    in
    {
      inherit cacheName publicKey;
      caches = {
        substituters = [ cacheUrl ];
        trusted-public-keys = [ publicKey ];
      };
    };

  # ----------------------------------------------------------------------------
  # Nix development tools
  # ----------------------------------------------------------------------------
  nixTooling = tooling.nix;

  # ----------------------------------------------------------------------------
  # Nix settings
  # ----------------------------------------------------------------------------
  nixSettings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    keep-outputs = false;
    keep-derivations = false;
    download-buffer-size = 1073741824; # 1 GB
  };
}
