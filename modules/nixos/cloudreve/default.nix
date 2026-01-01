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

  serviceName = "cloudreve";
  dbName = serviceName;
  redisName = serviceName;
  redisServiceName = "redis-${redisName}";
  redisUnit = "${redisServiceName}.service";
  redisGroup = config.services.redis.servers.${serviceName}.group;
  redisSocket = "/run/${redisServiceName}/redis.sock";

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
    ./umami
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

    aria2 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable aria2 for remote download support";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.postgresql.enable;
        message = "Cloudreve requires PostgreSQL. Enable it via hakula.services.postgresql.enable = true.";
      }
      {
        assertion = !cfg.aria2.enable || config.hakula.services.aria2.enable;
        message = "Cloudreve aria2 integration requires aria2. Enable it via hakula.services.aria2.enable = true.";
      }
    ];

    # --------------------------------------------------------------------------
    # Users & Groups
    # --------------------------------------------------------------------------
    users.users.${serviceName} = {
      isSystemUser = true;
      group = serviceName;
      extraGroups = [
        redisGroup
      ]
      ++ lib.optionals cfg.aria2.enable [ "aria2" ];
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
      ++ lib.optionals cfg.aria2.enable [
        "aria2.service"
      ]
      ++ lib.optionals (config.hakula.services.backup.cloudreve.restoreSnapshot or null != null) [
        "backup-restore-cloudreve.service"
      ];

      requires = [
        "postgresql.service"
        redisUnit
      ]
      ++ lib.optionals (config.hakula.services.backup.cloudreve.restoreSnapshot or null != null) [
        "backup-restore-cloudreve.service"
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
        ExecStart = "%S/%N/cloudreve";
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
        UMask = "0077";
        StateDirectory = "%N";
        StateDirectoryMode = "0750";
        WorkingDirectory = "%S/%N";
        ReadWritePaths = [
          "%S/%N"
        ]
        ++ lib.optionals cfg.aria2.enable [ config.services.aria2.settings.dir ];
      };
    };
  };
}
