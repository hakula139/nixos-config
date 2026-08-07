# ==============================================================================
# Shared Environment
# ==============================================================================

{
  config,
  pkgs,
  lib,
  repo,
  toolingFor,
  enableDevToolchains ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isLinux;
  tooling = toolingFor pkgs;
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
    ".duckdbrc".text = ''
      .autopilot on
    '';
    ".editorconfig".source = lib.path.append repo.root ".editorconfig";
    ".prettierrc.json".source = lib.path.append repo.root ".prettierrc.json";
    "ruff.toml".source = lib.path.append repo.root "ruff.toml";
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
      # System Utilities
      # ------------------------------------------------------------------------
      file
      pv
      rsync
      socat

      # ------------------------------------------------------------------------
      # Archive & Compression
      # ------------------------------------------------------------------------
      unzip
      p7zip

      # ------------------------------------------------------------------------
      # Data & Document Tools
      # ------------------------------------------------------------------------
      jq
      yq-go

      # ------------------------------------------------------------------------
      # Project Tools
      # ------------------------------------------------------------------------
      fontconfig
      git-cliff
      git-filter-repo
      scc
    ]
    ++ tooling.nix
    ++ tooling.secrets
    # --------------------------------------------------------------------------
    # Dev Toolchains
    # --------------------------------------------------------------------------
    ++ lib.optionals enableDevToolchains (
      with pkgs;
      [
        # ----------------------------------------------------------------------
        # Bash Development
        # ----------------------------------------------------------------------
        bash-language-server
        shellcheck
        shfmt

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
        # Node.js Development
        # ----------------------------------------------------------------------
        nodejs_24
        pnpm
        bun
        typescript
        typescript-language-server
        unstable.prettier

        # ----------------------------------------------------------------------
        # Python Development
        # ----------------------------------------------------------------------
        python3
        python3Packages.pip
        poetry
        pyright
        ruff
        uv

        # ----------------------------------------------------------------------
        # Rust Development
        # ----------------------------------------------------------------------
        rustToolchain
        cargo-llvm-cov

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
        # Data & Document Tools
        # ----------------------------------------------------------------------
        cspell
        dprint
        duckdb
        markdownlint-cli2
        poppler-utils
        taplo

        # ----------------------------------------------------------------------
        # Media
        # ----------------------------------------------------------------------
        ffmpeg
        imagemagick
        gallery-dl
        yt-dlp

        # ----------------------------------------------------------------------
        # Network Tools
        # ----------------------------------------------------------------------
        httpie
        mitmproxy

        # ----------------------------------------------------------------------
        # Project Tools
        # ----------------------------------------------------------------------
        unstable.hugo
        unstable.wakatime-cli
      ]
    );

  # ----------------------------------------------------------------------------
  # Environment Variables
  # ----------------------------------------------------------------------------
  home.sessionVariables = {
    # Node.js
    PNPM_HOME = "${config.xdg.dataHome}/pnpm";
  }
  // lib.optionalAttrs enableDevToolchains {
    # Go
    GOPATH = "$HOME/go";

    # Rust (CARGO_HOME for user-installed binaries and registry cache)
    CARGO_HOME = "$HOME/.cargo";
  };

  # ----------------------------------------------------------------------------
  # PATH additions
  # ----------------------------------------------------------------------------
  home.sessionPath = [
    "$HOME/.local/bin"
    "${config.xdg.dataHome}/pnpm/bin"
  ]
  ++ lib.optionals enableDevToolchains [
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
  ];
}
