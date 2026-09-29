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
    peertube = final.callPackage ../packages/peertube { };
    peertube-runner = final.callPackage ../packages/peertube/runner.nix { };
    thaw = final.callPackage ../packages/thaw { };
    wakatime-cli = final.callPackage ../packages/wakatime-cli { };
    zsh-hist = final.callPackage ../packages/zsh-hist { };
  })
]
