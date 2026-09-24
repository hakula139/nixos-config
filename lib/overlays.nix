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
    colmena = inputs.colmena.packages.${final.stdenv.hostPlatform.system}.colmena;
    system-manager = inputs.system-manager.packages.${final.stdenv.hostPlatform.system}.default;
    inherit (inputs.llm-agents.packages.${final.stdenv.hostPlatform.system})
      ccusage
      claude-agent-acp
      claude-code
      codex
      codex-acp
      oh-my-opencode
      omp
      opencode
      workmux
      ;

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

    wakatime-cli =
      (final.unstable.wakatime-cli.override { buildGoModule = final.unstable.buildGoLatestModule; })
      .overrideAttrs
        (old: {
          version = "2.26.6";
          src = old.src.override { hash = "sha256-H8ZfulbHUsq1s9bh+9iW7W/yp1DJsEOaoPe5uFQKKYc="; };
          vendorHash = "sha256-ZoQ7fTzig5mPNAqWZDb8eeVh0OoJm4U5yq3hRyqedLU=";
          patches = (old.patches or [ ]) ++ [
            ../packages/wakatime-cli/html-dependency-raw-text.patch
          ];
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
    acpx = final.callPackage ../packages/acpx { };
    browser-tools = final.callPackage ../packages/browser-tools { };
    cloudreve = final.callPackage ../packages/cloudreve { };
    mcp-server-filesystem = final.callPackage ../packages/mcp/mcp-server-filesystem { };
    mcp-server-git = final.callPackage ../packages/mcp/mcp-server-git { };
    mcp-server-github = final.callPackage ../packages/mcp/mcp-server-github { };
    mcp-server-gitlab = final.callPackage ../packages/mcp/mcp-server-gitlab { };
    nu-check = final.callPackage ../packages/nu-check { };
    peertube-runner = final.callPackage ../packages/peertube/runner.nix { };
    zsh-hist = final.callPackage ../packages/zsh-hist { };
  })
]
