# ==============================================================================
# Corp Mirror Configuration
# ==============================================================================

{
  config,
  lib,
  corpHosts,
  hostType,
  ...
}:

let
  inherit (corpHosts) artifactoryUrl githubMirrorUrl harbor;

  cfg = config.hakula.corp-mirrors;

  pypiMirror = "${artifactoryUrl}/api/pypi/mirrors-pypi/simple";
  pypiExtraIndexes = [
    "${artifactoryUrl}/api/pypi/hpc-pypi/simple"
  ];

  npmRegistry = "${artifactoryUrl}/api/npm/mirrors-npm";

  goProxy = "${artifactoryUrl}/api/go/mirrors-golang";
  cargoMirror = "sparse+${artifactoryUrl}/api/cargo/mirrors-cargo-crates/index/";

  ociMirrors = [
    "docker.io"
    "gcr.io"
    "ghcr.io"
    "mcr.microsoft.com"
    "nvcr.io"
    "quay.io"
    "registry.k8s.io"
  ];

  mkRegistry = registry: ''
    [[registry]]
    prefix = "${registry}"
    location = "${registry}"

    [[registry.mirror]]
    prefix = "${registry}"
    location = "${harbor}/${registry}"
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.corp-mirrors = {
    enable = lib.mkEnableOption "corp network mirror configuration";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      hakula.corp-mirrors.enable = lib.mkDefault (hostType == "work");
    }

    (lib.mkIf cfg.enable {
      home.sessionVariables = {
        # ----------------------------------------------------------------------
        # Python Development
        # ----------------------------------------------------------------------
        UV_PYTHON_INSTALL_MIRROR = "${githubMirrorUrl}/astral-sh/python-build-standalone/releases/download";

        # ----------------------------------------------------------------------
        # Node.js Development
        # ----------------------------------------------------------------------
        FNM_NODE_DIST_MIRROR = "${artifactoryUrl}/mirrors-generic-nodejs-dist";

        # ----------------------------------------------------------------------
        # Playwright
        # ----------------------------------------------------------------------
        PLAYWRIGHT_DOWNLOAD_HOST = "${artifactoryUrl}/mirrors-generic-playwright";

        # ----------------------------------------------------------------------
        # Go Development
        # ----------------------------------------------------------------------
        GOPROXY = goProxy;

        # ----------------------------------------------------------------------
        # Rust Development
        # ----------------------------------------------------------------------
        RUSTUP_DIST_SERVER = "${artifactoryUrl}/mirrors-rust-lang-static/dist";
        RUSTUP_UPDATE_ROOT = "${artifactoryUrl}/mirrors-rust-lang-static/rustup";
      };

      home.file = {
        # ----------------------------------------------------------------------
        # Python Development
        # ----------------------------------------------------------------------
        ".config/pip/pip.conf".text = ''
          [global]
          index-url = ${pypiMirror}
          extra-index-url =
          ${lib.concatMapStringsSep "\n" (url: "    ${url}") pypiExtraIndexes}
        '';

        ".config/uv/uv.toml".text = ''
          [[index]]
          url = "${pypiMirror}"
          default = true

          ${lib.concatMapStringsSep "\n" (url: ''
            [[index]]
            url = "${url}"
          '') pypiExtraIndexes}
        '';

        # ----------------------------------------------------------------------
        # Node.js Development
        # ----------------------------------------------------------------------
        ".npmrc".text = ''
          registry=${npmRegistry}
        '';

        # ----------------------------------------------------------------------
        # Go Development
        # ----------------------------------------------------------------------
        ".config/go/env".text = ''
          GOPROXY=${goProxy}
        '';

        # ----------------------------------------------------------------------
        # Rust Development
        # ----------------------------------------------------------------------
        ".cargo/config.toml".text = ''
          [registry]
          default = "artifactory"

          [registries.artifactory]
          index = "${cargoMirror}"

          [source.artifactory-remote]
          registry = "${cargoMirror}"

          [source.crates-io]
          replace-with = "artifactory-remote"
        '';

        # ----------------------------------------------------------------------
        # Containers
        # ----------------------------------------------------------------------
        ".config/containers/registries.conf".text = ''
          unqualified-search-registries = ['docker.io']

          ${lib.concatMapStringsSep "\n\n" mkRegistry ociMirrors}
          [[registry]]
          prefix = "${harbor}"
          location = "${harbor}"
        '';
      };
    })
  ];
}
