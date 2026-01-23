{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  isDesktop ? false,
  ...
}:

# ==============================================================================
# Shared Environment
# ==============================================================================

let
  tooling = import ../../lib/tooling.nix { inherit pkgs; };
  isLinux = pkgs.stdenv.isLinux;
  homeDir = config.home.homeDirectory;
  secretsDir = secrets.secretsPath homeDir;
in
{
  # ----------------------------------------------------------------------------
  # Services (shared)
  # ----------------------------------------------------------------------------
  services.ssh-agent.enable = lib.mkIf isLinux true;

  # ----------------------------------------------------------------------------
  # Files (shared)
  # ----------------------------------------------------------------------------
  home.file = {
    ".editorconfig".source = ../../.editorconfig;
    "ruff.toml".source = ../../ruff.toml;
  };

  # ----------------------------------------------------------------------------
  # Packages (shared)
  # ----------------------------------------------------------------------------
  home.packages =
    with pkgs;
    [
      # ------------------------------------------------------------------------
      # Everyday CLI
      # ------------------------------------------------------------------------
      bat
      btop
      eza
      fd
      fzf
      ripgrep
      zoxide

      # ------------------------------------------------------------------------
      # Archive & Compression
      # ------------------------------------------------------------------------
      unzip
      p7zip

      # ------------------------------------------------------------------------
      # Bash Development
      # ------------------------------------------------------------------------
      bash-language-server
      shellcheck
      shfmt

      # ------------------------------------------------------------------------
      # Python Development
      # ------------------------------------------------------------------------
      python3
      python3Packages.pip
      pipx
      poetry
      pyright
      ruff
      uv

      # ------------------------------------------------------------------------
      # Node.js Development
      # ------------------------------------------------------------------------
      fnm
      nodePackages.typescript
      nodePackages.typescript-language-server

      # ------------------------------------------------------------------------
      # Other Tools
      # ------------------------------------------------------------------------
      httpie
      jq
      yq
      fontconfig
      git-filter-repo
      hugo
      scc
    ]
    ++ tooling.nix
    ++ tooling.secrets
    # --------------------------------------------------------------------------
    # Desktop-only packages (heavy dev toolchains)
    # --------------------------------------------------------------------------
    ++ lib.optionals isDesktop (
      with pkgs;
      [
        # ----------------------------------------------------------------------
        # C/C++ Development
        # ----------------------------------------------------------------------
        llvmPackages.clang
        llvmPackages.clang-tools
        llvmPackages.lld
        llvmPackages.lldb
        cppcheck
        ccache
        cmake
        gnumake
        ninja
        pkg-config
        catch2
        doxygen

        # ----------------------------------------------------------------------
        # Go Development
        # ----------------------------------------------------------------------
        go
        gopls

        # ----------------------------------------------------------------------
        # Rust Development
        # ----------------------------------------------------------------------
        rustup

        # ----------------------------------------------------------------------
        # Containers & Kubernetes
        # ----------------------------------------------------------------------
        docker
        podman
        podman-compose
        kubectl
        kubernetes-helm
        k9s
        kubectx

        # ----------------------------------------------------------------------
        # Media
        # ----------------------------------------------------------------------
        ffmpeg
        imagemagick
      ]
    );

  # ----------------------------------------------------------------------------
  # Environment Variables
  # ----------------------------------------------------------------------------
  home.sessionVariables = {
    # Node.js
    PNPM_HOME = "${config.xdg.dataHome}/pnpm";
  }
  // lib.optionalAttrs isDesktop {
    # Go
    GOPATH = "$HOME/go";

    # Rust
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_UPDATE_ROOT = "https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup";
    RUSTUP_DIST_SERVER = "https://mirrors.tuna.tsinghua.edu.cn/rustup";
  };

  # ----------------------------------------------------------------------------
  # PATH additions
  # ----------------------------------------------------------------------------
  home.sessionPath = [
    "$HOME/.local/bin"
    "${config.xdg.dataHome}/pnpm"
  ]
  ++ lib.optionals isDesktop [
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
  ];

  # ----------------------------------------------------------------------------
  # Shell Configuration
  # ----------------------------------------------------------------------------
  programs.zsh.initContent = lib.mkAfter ''
    # --------------------------------------------------------------------------
    # fnm (Fast Node Manager) - replacement for nvm
    # Use `fnm use <version>` to switch Node.js versions.
    # --------------------------------------------------------------------------
    if command -v fnm &>/dev/null; then
      eval "$(fnm env --use-on-cd)"
    fi

    # --------------------------------------------------------------------------
    # Corepack - Enable pnpm with per-project version management
    # --------------------------------------------------------------------------
    if command -v corepack &>/dev/null; then
      corepack enable pnpm 2>/dev/null
    fi
  '';

  # ----------------------------------------------------------------------------
  # Secrets Configuration (agenix)
  # On NixOS: system-level agenix handles decryption, skip this config
  # On Darwin / standalone: home-manager agenix handles decryption
  # ----------------------------------------------------------------------------
  age.identityPaths = lib.mkIf (!isNixOS) [
    "${homeDir}/.ssh/id_ed25519"
  ];

  home.activation.ensureSecretsDir = lib.mkIf (!isNixOS) (
    lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      install -d -m 0700 "${secretsDir}"
    ''
  );
}
