{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# PeerTube Backup Target
# ==============================================================================

let
  backupCfg = config.hakula.services.backup;
  backupPeertubeCfg = config.hakula.services.backup.peertube;
  peertubeCfg = config.hakula.services.peertube;

  serviceName = "peertube";
  dataDir = "/var/lib/${serviceName}";

  dbName = serviceName;

  redisName = serviceName;
  redisServiceName = "redis-${redisName}";
  redisUser = config.services.redis.servers.${redisName}.user;
  redisGroup = config.services.redis.servers.${redisName}.group;
  redisSocket = "/run/${redisServiceName}/redis.sock";
  redisStateDir = "/var/lib/${redisServiceName}";

  stateDir = "/var/lib/backups/peertube";
  restoreDir = "${stateDir}/restore";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.backup.peertube = {
    enable = lib.mkEnableOption "PeerTube backup (PostgreSQL, Redis, local storage)";

    schedule = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "*-*-* 04:00:00";
      description = "Override the default schedule for PeerTube backup";
    };

    restoreSnapshot = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "latest";
      description = "Snapshot ID to restore from (e.g., 'latest', or a specific snapshot ID)";
    };
  };

  config = lib.mkIf (backupCfg.enable && backupPeertubeCfg.enable) {
    assertions = [
      {
        assertion = peertubeCfg.enable;
        message = "PeerTube backup requires PeerTube. Enable it via hakula.services.peertube.enable = true.";
      }
    ];

    # --------------------------------------------------------------------------
    # Backup target configuration
    # --------------------------------------------------------------------------
    hakula.services.backup.targets.peertube = {
      enable = true;

      inherit (backupPeertubeCfg) schedule;

      paths = [
        stateDir
        dataDir
      ];

      extraBackupArgs = [
        "--tag"
        "postgresql"
        "--tag"
        "redis"
        # Videos already on B2 object storage
        "--exclude"
        "${dataDir}/storage/original-video-files"
        "--exclude"
        "${dataDir}/storage/web-videos"
        "--exclude"
        "${dataDir}/storage/streaming-playlists"
        # Ephemeral / regenerable data
        "--exclude"
        "${dataDir}/storage/cache"
        "--exclude"
        "${dataDir}/storage/tmp"
        "--exclude"
        "${dataDir}/storage/tmp_persistent"
        "--exclude"
        "${dataDir}/storage/logs"
        "--exclude"
        "${dataDir}/storage/bin"
        "--exclude"
        "${dataDir}/storage/redundancy"
        "--exclude"
        "${dataDir}/www"
      ];

      extraGroups = [
        serviceName
        redisGroup
      ];

      runtimeInputs = [
        pkgs.gnutar
        pkgs.gzip
        pkgs.redis
        pkgs.util-linux
        config.services.postgresql.package
      ];

      heartbeatUrl = "https://uptime.betterstack.com/api/v1/heartbeat/26L1dR77wW57QC9T8VkoYS4t";

      prepareCommand = ''
        echo "==> Dumping PostgreSQL database..."
        runuser -u postgres -- pg_dump -d ${dbName} >"${stateDir}/peertube.sql"

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
        sqlFile="${restoreDir}${stateDir}/peertube.sql"
        redisTgz="${restoreDir}${stateDir}/redis_data.tgz"
        dataDir="${restoreDir}${dataDir}"

        if [ -f "$sqlFile" ]; then
          echo "==> Restoring PostgreSQL database..."
          runuser -u postgres -- dropdb --if-exists ${dbName}
          runuser -u postgres -- createdb -O ${serviceName} ${dbName}
          runuser -u postgres -- psql -d ${dbName} -v ON_ERROR_STOP=1 <"$sqlFile"
        else
          echo "peertube.sql not found in backup, skipping database restore"
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

        if [ -d "$dataDir" ]; then
          echo "==> Restoring PeerTube local data..."
          cp -a "$dataDir/." "${dataDir}/"
          chown -R ${serviceName}:${serviceName} "${dataDir}"
        else
          echo "PeerTube data directory not found in backup, skipping local data restore"
        fi
      '';

      inherit (backupPeertubeCfg) restoreSnapshot;
    };
  };
}
