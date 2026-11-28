# ==================================================================================================
# Nixpkgs Overlays
# ==================================================================================================

{
  inputs,
}:

[
  inputs.rust-overlay.overlays.default
  inputs.agents-nix.overlays.default
  inputs.flake-catalog.overlays.default

  (final: _prev: {
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
    nushell = inputs.nixpkgs-master.legacyPackages.${final.stdenv.hostPlatform.system}.nushell;
    system-manager = inputs.system-manager.packages.${final.stdenv.hostPlatform.system}.default;
    inherit (inputs.devkit.lib.mkLib final) nu-check nu-test;

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
    cloudreve = final.callPackage ../packages/cloudreve { };
    direnv = final.unstable.direnv;
    peertube = final.callPackage ../packages/peertube { };
    peertube-runner = final.callPackage ../packages/peertube/runner.nix { };
    thaw = final.callPackage ../packages/thaw { };
    zsh-hist = final.callPackage ../packages/zsh-hist { };
  })
]
