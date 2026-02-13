{
  config,
  lib,
  secrets,
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

    ociLogin = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Computed login attrset for virtualisation.oci-containers.containers.<name>.login";
    };
  };

  config = lib.mkMerge [
    {
      hakula.dockerHub.ociLogin = lib.optionalAttrs (cfg.username != null) {
        inherit (cfg) registry username;
        passwordFile = config.age.secrets.dockerhub-token.path;
      };
    }

    (lib.mkIf (cfg.username != null) {
      # ------------------------------------------------------------------------
      # User & Group
      # ------------------------------------------------------------------------
      users.groups.dockerhub = { };

      # ------------------------------------------------------------------------
      # Secrets
      # ------------------------------------------------------------------------
      age.secrets.dockerhub-token = secrets.mkSecret {
        name = "dockerhub-token";
        owner = "root";
        group = "dockerhub";
        mode = "0440";
      };
    })
  ];
}
