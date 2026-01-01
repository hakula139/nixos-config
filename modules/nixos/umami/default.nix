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
      group = "postgres"; # umami-db-init needs to read this file
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
    # Systemd services
    # --------------------------------------------------------------------------
    systemd.services.umami-db-init = {
      description = "Initialize Umami PostgreSQL password";

      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      before = [ "podman-${serviceName}.service" ];
      requiredBy = [ "podman-${serviceName}.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        Group = "postgres";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
      };

      restartTriggers = [ config.age.secrets.umami-env.file ];

      path = [
        config.services.postgresql.package
      ];

      script = ''
        set -euo pipefail
        source ${config.age.secrets.umami-env.path}
        psql -c "ALTER USER ${serviceName} WITH PASSWORD '$DB_PASSWORD';"
      '';
    };

    systemd.services."podman-${serviceName}" = {
      after = [
        "postgresql.service"
        "umami-db-init.service"
      ];
      requires = [
        "postgresql.service"
        "umami-db-init.service"
      ];
    };
  };
}
