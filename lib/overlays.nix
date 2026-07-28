# ==============================================================================
# Nixpkgs Overlays
# ==============================================================================

{
  inputs,
  nixpkgs-unstable,
}:

[
  inputs.rust-overlay.overlays.default
  (final: _: {
    # --------------------------------------------------------------------------
    # Nixpkgs channels
    # --------------------------------------------------------------------------
    unstable = import nixpkgs-unstable {
      localSystem = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };

    # --------------------------------------------------------------------------
    # Flake-input CLIs
    # --------------------------------------------------------------------------
    agenix = inputs.agenix.packages.${final.stdenv.hostPlatform.system}.default;

    system-manager = inputs.system-manager.packages.${final.stdenv.hostPlatform.system}.default;

    workmux = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.workmux;

    # --------------------------------------------------------------------------
    # Upstream overrides
    # --------------------------------------------------------------------------
    peertube = final.unstable.peertube.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../packages/peertube/cdn-redirect-runner.patch
        ../packages/peertube/hq-transcode.patch
        ../packages/peertube/runner-download-timeout.patch
      ];
      meta = old.meta // {
        platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
      };
    });

    # --------------------------------------------------------------------------
    # Toolchains
    # --------------------------------------------------------------------------
    rustToolchain = final.rust-bin.stable.latest.default.override {
      extensions = [
        "llvm-tools-preview"
        "rust-analyzer"
        "rust-src"
      ];
    };

    # --------------------------------------------------------------------------
    # Custom packages
    # --------------------------------------------------------------------------
    cloudreve = final.callPackage ../packages/cloudreve { };
    mcp-server-filesystem = final.callPackage ../packages/mcp/mcp-server-filesystem { };
    mcp-server-git = final.callPackage ../packages/mcp/mcp-server-git { };
    mcp-server-github = final.callPackage ../packages/mcp/mcp-server-github { };
    mcp-server-gitlab = final.callPackage ../packages/mcp/mcp-server-gitlab { };
    peertube-runner = final.callPackage ../packages/peertube/runner.nix { };
    zsh-hist = final.callPackage ../packages/zsh-hist { };
  })
]
