{ pkgs }:

# ============================================================================
# Shared Configuration
# ============================================================================

let
  keys = import ../secrets/keys.nix;
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
    nil
    nixfmt-rfc-style
  ];

  # Nix settings
  nixSettings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    keep-outputs = true;
    keep-derivations = true;
  };
}
