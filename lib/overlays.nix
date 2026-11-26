# ==================================================================================================
# Nixpkgs Overlays
# ==================================================================================================

{
  inputs,
  repoLib,
}:

[
  inputs.rust-overlay.overlays.default
  inputs.flake-catalog.overlays.default

  (final: prev: {
    # ----------------------------------------------------------------------------------------------
    # Nixpkgs channels
    # ----------------------------------------------------------------------------------------------
    unstable = import inputs.nixpkgs-unstable {
      localSystem = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };

    # ----------------------------------------------------------------------------------------------
    # Flake-input CLIs
    # ----------------------------------------------------------------------------------------------
    colmena = inputs.colmena.packages.${final.stdenv.hostPlatform.system}.colmena;
    system-manager = inputs.system-manager.packages.${final.stdenv.hostPlatform.system}.default;
    inherit (inputs.devkit.lib.mkLib final) nu-check nu-test;
    inherit (inputs.llm-agents.packages.${final.stdenv.hostPlatform.system})
      ccusage
      claude-agent-acp
      claude-code
      codex
      codex-acp
      omp
      workmux
      ;

    # ----------------------------------------------------------------------------------------------
    # Toolchains
    # ----------------------------------------------------------------------------------------------
    rustToolchain = final.rust-bin.stable.latest.default.override {
      extensions = [
        "llvm-tools-preview"
        "rust-analyzer"
        "rust-src"
      ];
    };

    # ----------------------------------------------------------------------------------------------
    # Custom packages
    # ----------------------------------------------------------------------------------------------
    acpx = final.callPackage ../packages/acpx { };
    browser-tools = final.callPackage ../packages/browser-tools { };
    cloudreve = final.callPackage ../packages/cloudreve { };
    direnv = prev.direnv.override { bash = final.unstable.bash; };
    file-formatter = final.callPackage ../packages/file-formatter { inherit repoLib; };
    mcp-server-github = final.callPackage ../packages/mcp/mcp-server-github { };
    mcp-server-gitlab = final.callPackage ../packages/mcp/mcp-server-gitlab { };
    nushell = final.callPackage ../packages/nushell { };
    peertube = final.callPackage ../packages/peertube { };
    peertube-runner = final.callPackage ../packages/peertube/runner.nix { };
    thaw = final.callPackage ../packages/thaw { };
    zsh-hist = final.callPackage ../packages/zsh-hist { };
  })
]
