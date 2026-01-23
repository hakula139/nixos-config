{
  config,
  lib,
  ...
}:

# ==============================================================================
# Docker Hub (Global Registry Auth)
# ==============================================================================

let
  cfg = config.hakula.dockerHub;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.dockerHub = {
    registry = lib.mkOption {
      type = lib.types.str;
      default = "docker.io";
      description = "Docker Hub registry";
    };

    username = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = "Docker Hub username used to authenticate image pulls";
    };

    tokenAgeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the Docker Hub access token file";
    };

    ociLogin = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Computed login attrset for virtualisation.oci-containers.containers.<name>.login";
    };
  };

  config = lib.mkMerge [
    {
      hakula.dockerHub.ociLogin = lib.optionalAttrs (cfg.username != null && cfg.tokenAgeFile != null) {
        registry = cfg.registry;
        username = cfg.username;
        passwordFile = config.age.secrets.dockerhub-token.path;
      };
    }

    (lib.mkIf (cfg.username != null && cfg.tokenAgeFile != null) {
      # ------------------------------------------------------------------------
      # User & Group
      # ------------------------------------------------------------------------
      users.groups.dockerhub = { };

      # ------------------------------------------------------------------------
      # Secrets
      # ------------------------------------------------------------------------
      age.secrets.dockerhub-token = {
        file = cfg.tokenAgeFile;
        owner = "root";
        group = "dockerhub";
        mode = "0440";
      };
    })
  ];
}
