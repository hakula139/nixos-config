{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve (Self-hosted Cloud Storage)
# ==============================================================================

let
  cfg = config.hakula.services.cloudreve;
  restoreCfg = cfg.restore;

  serviceName = "cloudreve";
  dbName = serviceName;
  redisName = serviceName;
  redisServiceName = "redis-${redisName}";
  redisUnit = "${redisServiceName}.service";
  redisUser = config.services.redis.servers.${serviceName}.user;
  redisGroup = config.services.redis.servers.${serviceName}.group;
  redisStateDir = "/var/lib/${redisServiceName}";
  redisSocket = "/run/redis-${redisName}/redis.sock";

  configFile = pkgs.writeText "cloudreve-conf.ini" ''
    [System]
    Mode = master
    Listen = :${toString cfg.port}

    [Database]
    Type = postgres
    Host = /run/postgresql
    Port = 5432
    Name = ${dbName}
    User = ${serviceName}
    UnixSocket = true

    [Redis]
    Network = unix
    Server = ${redisSocket}
    DB = 0
  '';
in
{
  imports = [
    (import ./restore {
      inherit
        serviceName
        dbName
        redisServiceName
        redisUnit
        redisUser
        redisGroup
        redisStateDir
        ;
    })
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.cloudreve = {
    enable = lib.mkEnableOption "Cloudreve cloud storage service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5212;
      description = "Port for Cloudreve web interface";
    };

    restore = {
      enable = lib.mkEnableOption "Restore Cloudreve from a backup directory";

      sqlFile = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Absolute path to a cloudreve.sql (pg_dump) file";
      };

      backendDataTgz = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Absolute path to a backend_data.tgz file";
      };

      redisDataTgz = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Absolute path to a redis_data.tgz file";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.postgresql.enable;
        message = "Cloudreve requires PostgreSQL. Enable it via hakula.services.postgresql.enable = true.";
      }
    ];

    # --------------------------------------------------------------------------
    # Users & Groups
    # --------------------------------------------------------------------------
    users.users.${serviceName} = {
      isSystemUser = true;
      group = serviceName;
      extraGroups = [ redisGroup ];
    };
    users.groups.${serviceName} = { };

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
        local ${dbName} ${serviceName} peer
      '';
    };

    # --------------------------------------------------------------------------
    # Redis (local)
    # --------------------------------------------------------------------------
    services.redis.servers.${serviceName} = {
      enable = true;
      port = 0;
      unixSocket = redisSocket;
      unixSocketPerm = 660;
    };

    # --------------------------------------------------------------------------
    # Cloudreve systemd service
    # --------------------------------------------------------------------------
    systemd.services.cloudreve = {
      description = "Cloudreve file management and sharing system";
      documentation = [ "https://docs.cloudreve.org" ];

      after = [
        "network.target"
        "postgresql.service"
        redisUnit
      ]
      ++ lib.optionals restoreCfg.enable [
        "cloudreve-restore.service"
      ];
      requires = [
        "postgresql.service"
        redisUnit
      ]
      ++ lib.optionals restoreCfg.enable [
        "cloudreve-restore.service"
      ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        install -m 0755 ${lib.getExe pkgs.cloudreve} "$STATE_DIRECTORY/cloudreve"
        install -d -m 0750 "$STATE_DIRECTORY/data"
        if [ ! -f "$STATE_DIRECTORY/data/conf.ini" ]; then
          install -m 0600 ${configFile} "$STATE_DIRECTORY/data/conf.ini"
        fi
      '';

      serviceConfig = {
        Type = "simple";
        ExecStart = "%S/${serviceName}/cloudreve";
        Restart = "on-failure";
        RestartSec = "5s";
        User = serviceName;
        Group = serviceName;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        StateDirectory = serviceName;
        StateDirectoryMode = "0750";
        UMask = "0077";
        WorkingDirectory = "%S/${serviceName}";
        ReadWritePaths = [ "%S/${serviceName}" ];
      };
    };
  };
}
