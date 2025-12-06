{ pkgs }:

# ============================================================================
# Shared Configuration
# ============================================================================

{
  # SSH public keys
  sshKeys = {
    hakula = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqd9HS6uF0h0mXMbIwCv9yrkvvdl3o1wUgQWVkjKuiJ";
  };

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
