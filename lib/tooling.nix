# ==============================================================================
# Shared Tooling
# ==============================================================================

{ pkgs }:

{
  # ----------------------------------------------------------------------------
  # Nix Development
  # ----------------------------------------------------------------------------
  nix = with pkgs; [
    cachix # Cachix client (binary cache)
    colmena # Multi-host NixOS deployment tool
    deadnix # Find unused Nix bindings / attributes
    nh # Nix CLI wrapper with nom / nvd integration
    nixd # Nix language server (LSP)
    nix-tree # Explore dependency tree of Nix derivations
    nixfmt # Nix formatter
    nom # nix-output-monitor (pretty build output)
    nvd # Nix / NixOS diff tool (generations / closures)
    statix # Nix linter
  ];

  # ----------------------------------------------------------------------------
  # Secrets Management
  # ----------------------------------------------------------------------------
  secrets = with pkgs; [
    age # File encryption tool used by agenix
    agenix # Manage age-encrypted secrets (*.age)
  ];

  # ----------------------------------------------------------------------------
  # Shell Scripting
  # ----------------------------------------------------------------------------
  shell = with pkgs; [
    nushell # Structured-data shell; scripting language for this repo
  ];
}
