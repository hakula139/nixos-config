# ==================================================================================================
# Corp Mirror Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  ...
}:

let
  inherit (corpHosts) artifactoryUrl githubMirrorUrl harbor;

  cfg = config.hakula.corp-mirrors;

  ini = pkgs.formats.ini { listToValue = lib.concatStringsSep " "; };
  toml = pkgs.formats.toml { };

  # ------------------------------------------------------------------------------------------------
  # Go Development
  # ------------------------------------------------------------------------------------------------
  goProxy = "${artifactoryUrl}/api/go/mirrors-golang";

  # ------------------------------------------------------------------------------------------------
  # Node.js Development
  # ------------------------------------------------------------------------------------------------
  npmRegistry = "${artifactoryUrl}/api/npm/mirrors-npm";

  # ------------------------------------------------------------------------------------------------
  # Python Development
  # ------------------------------------------------------------------------------------------------
  pypiMirror = "${artifactoryUrl}/api/pypi/mirrors-pypi/simple";
  pypiExtraIndexes = [
    "${artifactoryUrl}/api/pypi/hpc-pypi/simple"
  ];

  # On hosts that reach pypi.org the mirror is explicit, so corp locks validate while pypi.org stays
  # the default, and first-match falls through to it when the HPC index cannot satisfy a package.
  uvConfig = {
    index = [
      (
        {
          name = "corp";
          url = pypiMirror;
        }
        // (if cfg.enable then { default = true; } else { explicit = true; })
      )
    ]
    ++ map (url: { inherit url; }) pypiExtraIndexes;
  }
  // lib.optionalAttrs (!cfg.enable) { index-strategy = "unsafe-first-match"; };

  # ------------------------------------------------------------------------------------------------
  # Containers
  # ------------------------------------------------------------------------------------------------
  ociMirrors = [
    "docker.io"
    "gcr.io"
    "ghcr.io"
    "mcr.microsoft.com"
    "nvcr.io"
    "quay.io"
    "registry.k8s.io"
  ];

  registries =
    map (registry: {
      prefix = registry;
      location = registry;
      mirror = [
        {
          prefix = registry;
          location = "${harbor}/${registry}";
        }
      ];
    }) ociMirrors
    ++ [
      {
        prefix = harbor;
        location = harbor;
      }
    ];
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.corp-mirrors = {
    enable = lib.mkEnableOption "every corp mirror, for a host without pypi.org access";

    uvIndexes = {
      enable = lib.mkEnableOption "only uv's corp indexes, for a host that reaches pypi.org";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.sessionVariables = {
        # ------------------------------------------------------------------------------------------
        # Go Development
        # ------------------------------------------------------------------------------------------
        GOPROXY = goProxy;

        # ------------------------------------------------------------------------------------------
        # Python Development
        # ------------------------------------------------------------------------------------------
        UV_PYTHON_INSTALL_MIRROR = "${githubMirrorUrl}/astral-sh/python-build-standalone/releases/download";

        # ------------------------------------------------------------------------------------------
        # Playwright
        # ------------------------------------------------------------------------------------------
        PLAYWRIGHT_DOWNLOAD_HOST = "${artifactoryUrl}/mirrors-generic-playwright";
      };

      home.file = {
        # ------------------------------------------------------------------------------------------
        # Go Development
        # ------------------------------------------------------------------------------------------
        ".config/go/env".text = ''
          GOPROXY=${goProxy}
        '';

        # ------------------------------------------------------------------------------------------
        # Node.js Development
        # ------------------------------------------------------------------------------------------
        ".npmrc".text = ''
          registry=${npmRegistry}
        '';

        # ------------------------------------------------------------------------------------------
        # Python Development
        # ------------------------------------------------------------------------------------------
        ".config/pip/pip.conf".source = ini.generate "pip.conf" {
          global = {
            index-url = pypiMirror;
            extra-index-url = pypiExtraIndexes;
          };
        };

        # ------------------------------------------------------------------------------------------
        # Containers
        # ------------------------------------------------------------------------------------------
        ".config/containers/registries.conf".source = toml.generate "registries.conf" {
          unqualified-search-registries = [ "docker.io" ];
          registry = registries;
        };
      };
    })

    (lib.mkIf (cfg.enable || cfg.uvIndexes.enable) {
      # --------------------------------------------------------------------------------------------
      # Python Development
      # --------------------------------------------------------------------------------------------
      home.file.".config/uv/uv.toml".source = toml.generate "uv.toml" uvConfig;
    })
  ];
}
