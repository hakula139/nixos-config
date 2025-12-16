{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Shared Environment
# ==============================================================================

let
  tooling = import ../../lib/tooling.nix { inherit pkgs; };
in
{
  home.packages =
    with pkgs;
    [
      # ------------------------------------------------------------------------
      # Build Tools
      # ------------------------------------------------------------------------
      cmake
      gnumake

      # ------------------------------------------------------------------------
      # LLVM / Clang Toolchain
      # ------------------------------------------------------------------------
      llvmPackages.clang
      llvmPackages.llvm
      llvmPackages.lld

      # ------------------------------------------------------------------------
      # Go
      # ------------------------------------------------------------------------
      go
      gopls # Go language server

      # ------------------------------------------------------------------------
      # Rust
      # ------------------------------------------------------------------------
      rustup # Rust toolchain manager

      # ------------------------------------------------------------------------
      # Node.js
      # ------------------------------------------------------------------------
      fnm # Fast Node Manager (replacement for nvm)

      # ------------------------------------------------------------------------
      # Python
      # ------------------------------------------------------------------------
      python3
      python3Packages.pip
      poetry # Modern dependency management
      ruff # Fast linter & formatter
      uv # Ultra-fast pip replacement

      # ------------------------------------------------------------------------
      # Java
      # ------------------------------------------------------------------------
      jdk21
      # jdk17
      # jdk11

      # ------------------------------------------------------------------------
      # Haskell
      # ------------------------------------------------------------------------
      ghc # Glasgow Haskell Compiler
      cabal-install # Haskell package manager
      stack # Haskell build tool

      # ------------------------------------------------------------------------
      # Containers & Kubernetes
      # ------------------------------------------------------------------------
      kubectl
      kubernetes-helm
      k9s # TUI for Kubernetes
      kubectx # Switch contexts / namespaces quickly

      # ------------------------------------------------------------------------
      # Other Tools
      # ------------------------------------------------------------------------
      jq # JSON processor
      yq # YAML processor
      httpie # Modern curl alternative
    ]
    ++ tooling.nix
    ++ tooling.secrets;

  # ============================================================================
  # Environment Variables (shared)
  # ============================================================================
  home.sessionVariables = {
    # Go
    GOPATH = "$HOME/go";

    # Rust
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_UPDATE_ROOT = "https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup";
    RUSTUP_DIST_SERVER = "https://mirrors.tuna.tsinghua.edu.cn/rustup";
  };

  # ============================================================================
  # PATH additions (shared)
  # ============================================================================
  home.sessionPath = [
    "$HOME/go/bin" # Go binaries
    "$HOME/.cargo/bin" # Rust binaries
    "$HOME/.local/bin" # Local binaries
    "$HOME/.local/share/corepack" # pnpm / yarn via corepack
  ];

  # ============================================================================
  # Shell Configuration for Dev Tools
  # ============================================================================
  programs.zsh.initContent = lib.mkAfter ''
    # --------------------------------------------------------------------------
    # fnm (Fast Node Manager) - replacement for nvm
    # --------------------------------------------------------------------------
    if command -v fnm &>/dev/null; then
      eval "$(fnm env --use-on-cd)"
    fi
  '';
}
