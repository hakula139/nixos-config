{
  config,
  lib,
  ...
}:

# ==============================================================================
# Umami (Analytics)
# ==============================================================================

let
  cfg = config.hakula.services.umami;

  serviceName = "umami";
  dbName = serviceName;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.umami = {
    enable = lib.mkEnableOption "Umami analytics";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for Umami web interface";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/umami-software/umami:postgresql-latest";
      description = "Docker image for Umami";
    };

    clientIPHeader = lib.mkOption {
      type = lib.types.str;
      default = "x-forwarded-for";
      description = "HTTP header to check for the client's IP address";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.postgresql.enable;
        message = "Umami requires PostgreSQL. Enable it via hakula.services.postgresql.enable = true.";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.umami-env = {
      file = ../../../secrets/shared/umami-env.age;
      owner = "root";
      group = "postgres"; # postgresql postStart needs to read this file
      mode = "0440";
    };

    # --------------------------------------------------------------------------
    # PostgreSQL (local)
    # --------------------------------------------------------------------------
    services.postgresql = {
      ensureDatabases = [ dbName ];
      ensureUsers = [
        {
          name = serviceName;
          ensureDBOwnership = true;
        }
      ];
      authentication = lib.mkAfter ''
        host ${dbName} ${serviceName} 127.0.0.1/32 scram-sha-256
      '';
    };

    systemd.services.postgresql = {
      postStart = lib.mkAfter ''
        set -euo pipefail
        source ${config.age.secrets.umami-env.path}

        ${config.services.postgresql.package}/bin/psql \
          -p ${toString config.services.postgresql.settings.port} \
          -v ON_ERROR_STOP=1 \
          -c "ALTER ROLE ${serviceName} WITH PASSWORD '$DB_PASSWORD';"
      '';
    };

    # --------------------------------------------------------------------------
    # Container (podman)
    # --------------------------------------------------------------------------
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers.${serviceName} = {
      image = cfg.image;
      login = config.hakula.dockerHub.ociLogin;

      ports = [
        "127.0.0.1:${toString cfg.port}:3000"
      ];

      environment = {
        CLIENT_IP_HEADER = cfg.clientIPHeader;
      };

      environmentFiles = [
        config.age.secrets.umami-env.path
      ];
    };

    # --------------------------------------------------------------------------
    # Systemd service
    # --------------------------------------------------------------------------
    systemd.services."podman-${serviceName}" = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
    };
  };
}
