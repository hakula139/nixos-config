# ==================================================================================================
# Umami (Analytics)
# ==================================================================================================

{
  config,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.umami;
  serviceName = "umami";
  dbName = serviceName;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.umami = {
    enable = lib.mkEnableOption "Umami analytics";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for Umami web interface";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/umami-software/umami:3.5.0";
      description = "Docker image for Umami";
    };

    clientIPHeader = lib.mkOption {
      type = lib.types.str;
      default = "x-forwarded-for";
      description = "HTTP header to check for the client's IP address";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.postgresql.enable;
        message = "Umami requires PostgreSQL. Enable it via hakula.services.postgresql.enable = true.";
      }
    ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    sops.secrets.umami-db-password = repoLib.secrets.mkSecret {
      name = "umami/db-password";
      owner = "postgres";
      group = "postgres";
      restartUnits = [ "postgresql-setup.service" ];
    };

    sops.secrets.umami-app-secret = repoLib.secrets.mkSecret {
      name = "umami/app-secret";
      owner = "root";
    };

    sops.templates."umami.env" = {
      restartUnits = [ "podman-${serviceName}.service" ];
      content = ''
        DATABASE_URL=postgresql://${serviceName}:${config.sops.placeholder.umami-db-password}@10.88.0.1:5432/${dbName}
        APP_SECRET=${config.sops.placeholder.umami-app-secret}
      '';
    };

    # ----------------------------------------------------------------------------------------------
    # PostgreSQL
    # ----------------------------------------------------------------------------------------------
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
        host ${dbName} ${serviceName} ${config.hakula.podman.network.subnet} scram-sha-256
      '';
    };

    systemd.services.postgresql-setup = {
      postStart = lib.mkAfter ''
        set -euo pipefail
        db_password=$(< ${config.sops.secrets.umami-db-password.path})

        psql \
          -v ON_ERROR_STOP=1 \
          -c "ALTER ROLE ${serviceName} WITH PASSWORD '$db_password';"
      '';
    };

    # ----------------------------------------------------------------------------------------------
    # Container (podman)
    # ----------------------------------------------------------------------------------------------
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers.${serviceName} = {
      inherit (cfg) image;

      ports = [
        "127.0.0.1:${toString cfg.port}:3000"
      ];

      environment = {
        CLIENT_IP_HEADER = cfg.clientIPHeader;
      };

      environmentFiles = [
        config.sops.templates."umami.env".path
      ];
    };

    # ----------------------------------------------------------------------------------------------
    # Systemd service
    # ----------------------------------------------------------------------------------------------
    systemd.services."podman-${serviceName}" = lib.mkMerge [
      repoLib.systemd.restartUnit

      {
        after = [
          "postgresql.service"
        ]
        ++ lib.optionals (config.hakula.services.backup.umami.restoreSnapshot or null != null) [
          "backup-restore-umami.service"
        ];

        requires = [
          "postgresql.service"
        ]
        ++ lib.optionals (config.hakula.services.backup.umami.restoreSnapshot or null != null) [
          "backup-restore-umami.service"
        ];
      }
    ];
  };
}
