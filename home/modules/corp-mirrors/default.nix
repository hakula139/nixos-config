# ==============================================================================
# Corp Mirror Configuration
# ==============================================================================

{
  config,
  lib,
  corpDomain,
  hostType,
  ...
}:

let
  cfg = config.hakula.corp-mirrors;

  artifactory = "https://artifactory.${corpDomain}/artifactory";
  githubMirror = "https://github-mirror.${corpDomain}";
  harbor = "harbor.${corpDomain}";

  pypiMirror = "${artifactory}/api/pypi/mirrors-pypi/simple";
  pypiExtraIndexes = [
    "${artifactory}/api/pypi/hpc-pypi/simple"
  ];

  npmMirror = "${artifactory}/api/npm/npm/";
  npmRegistry = "https://registry.npmjs.org/";
  goProxy = "${artifactory}/api/go/mirrors-golang";
  cargoMirror = "sparse+${artifactory}/api/cargo/mirrors-cargo-crates/index/";

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
        UV_PYTHON_INSTALL_MIRROR = "${githubMirror}/astral-sh/python-build-standalone/releases/download";

        # ----------------------------------------------------------------------
        # Node.js Development
        # ----------------------------------------------------------------------
        FNM_NODE_DIST_MIRROR = "${artifactory}/mirrors-generic-nodejs-dist";

        # ----------------------------------------------------------------------
        # Playwright
        # ----------------------------------------------------------------------
        PLAYWRIGHT_DOWNLOAD_HOST = "${artifactory}/mirrors-generic-playwright";

        # ----------------------------------------------------------------------
        # Go Development
        # ----------------------------------------------------------------------
        GOPROXY = goProxy;

        # ----------------------------------------------------------------------
        # Rust Development
        # ----------------------------------------------------------------------
        RUSTUP_DIST_SERVER = "${artifactory}/mirrors-rust-lang-static/dist";
        RUSTUP_UPDATE_ROOT = "${artifactory}/mirrors-rust-lang-static/rustup";
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
        # Resolve @pnpm from npmjs. pnpm 11 rejects the mirror's rewritten
        # tarball host when self-installing a pinned packageManager.
        ".npmrc".text = lib.mkForce ''
          manage-package-manager-versions=true
          registry=${npmMirror}
          @pnpm:registry=${npmRegistry}
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
