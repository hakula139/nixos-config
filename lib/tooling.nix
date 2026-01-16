{ pkgs }:

# ==============================================================================
# Shared Tooling
# ==============================================================================

{
  # ----------------------------------------------------------------------------
  # Nix Development
  # ----------------------------------------------------------------------------
  nix = with pkgs; [
    unstable.cachix # Cachix client (binary cache)
    deadnix # Find unused Nix bindings / attributes
    nil # Nix language server (LSP)
    nix-tree # Explore dependency tree of Nix derivations
    nixfmt-rfc-style # Nix formatter (RFC style)
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
}
