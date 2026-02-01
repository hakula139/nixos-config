{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve Backup Target
# ==============================================================================

let
  backupCfg = config.hakula.services.backup;
  backupCloudreveCfg = config.hakula.services.backup.cloudreve;
  cloudreveCfg = config.hakula.services.cloudreve;

  serviceName = "cloudreve";
  dbName = serviceName;
  redisName = serviceName;
  redisServiceName = "redis-${redisName}";
  redisUser = config.services.redis.servers.${serviceName}.user;
  redisGroup = config.services.redis.servers.${serviceName}.group;
  redisSocket = "/run/${redisServiceName}/redis.sock";
  redisStateDir = "/var/lib/${redisServiceName}";

  stateDir = "/var/lib/backups/cloudreve";
  restoreDir = "${stateDir}/restore";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.backup.cloudreve = {
    enable = lib.mkEnableOption "Cloudreve backup (PostgreSQL, Redis)";

    schedule = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "*-*-* 04:00:00";
      description = "Override the default schedule for Cloudreve backup";
    };

    restoreSnapshot = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "latest";
      description = "Snapshot ID to restore from (e.g., 'latest', or a specific snapshot ID)";
    };
  };

  config = lib.mkIf (backupCfg.enable && backupCloudreveCfg.enable) {
    assertions = [
      {
        assertion = cloudreveCfg.enable;
        message = "Cloudreve backup requires Cloudreve. Enable it via hakula.services.cloudreve.enable = true.";
      }
    ];

    # --------------------------------------------------------------------------
    # PostgreSQL access
    # --------------------------------------------------------------------------
    services.postgresql = {
      ensureUsers = [
        {
          name = "backup";
        }
      ];
      authentication = lib.mkAfter ''
        local ${dbName} backup peer
      '';
    };

    # --------------------------------------------------------------------------
    # Backup target configuration
    # --------------------------------------------------------------------------
    hakula.services.backup.targets.cloudreve = {
      enable = true;

      schedule = backupCloudreveCfg.schedule;

      paths = [ stateDir ];

      extraBackupArgs = [
        "--tag"
        "postgresql"
        "--tag"
        "redis"
      ];

      extraGroups = [
        redisGroup
      ];

      runtimeInputs = [
        pkgs.gnutar
        pkgs.gzip
        pkgs.redis
        config.services.postgresql.package
      ];

      heartbeatUrl = lib.mkDefault "https://uptime.betterstack.com/api/v1/heartbeat/aEq66Y6nTJfjh4DVkDvQMjUj";

      prepareCommand = ''
        echo "==> Dumping PostgreSQL database..."
        pg_dump -h /run/postgresql -U backup -d ${dbName} >"${stateDir}/cloudreve.sql"

        echo "==> Creating Redis data archive..."
        redis-cli -s ${lib.escapeShellArg redisSocket} --rdb "${stateDir}/dump.rdb"
        tar -czf "${stateDir}/redis_data.tgz" -C "${stateDir}" dump.rdb
        rm -f "${stateDir}/dump.rdb"

        echo "==> Backup preparation complete"
      '';

      cleanupCommand = ''
        rm -rf ${stateDir}
      '';

      restoreCommand = ''
        sqlFile="${restoreDir}${stateDir}/cloudreve.sql"
        redisTgz="${restoreDir}${stateDir}/redis_data.tgz"

        if [ -f "$sqlFile" ]; then
          echo "==> Restoring PostgreSQL database..."
          runuser -u postgres -- dropdb --if-exists -h /run/postgresql ${dbName}
          runuser -u postgres -- createdb -h /run/postgresql -O ${serviceName} ${dbName}
          runuser -u postgres -- psql -h /run/postgresql -d ${dbName} -v ON_ERROR_STOP=1 <"$sqlFile"
        else
          echo "cloudreve.sql not found in backup, skipping database restore"
        fi

        if [ -f "$redisTgz" ]; then
          echo "==> Restoring Redis data..."
          mkdir -p "${redisStateDir}"
          tar -xzf "$redisTgz" -C "${redisStateDir}" --no-same-owner
          chown -R ${redisUser}:${redisGroup} "${redisStateDir}"
          chmod 0600 "${redisStateDir}/dump.rdb" 2>/dev/null || true
        else
          echo "redis_data.tgz not found in backup, skipping Redis restore"
        fi
      '';

      restoreSnapshot = backupCloudreveCfg.restoreSnapshot;
    };
  };
}
