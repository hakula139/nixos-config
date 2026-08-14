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
  # Only the dev shell consumes this. Every real host gets nushell from
  # `programs.nushell`, which also writes the config files its LSP needs.
  shell = with pkgs; [
    nushell
  ];
}
