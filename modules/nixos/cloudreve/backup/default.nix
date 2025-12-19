{
  serviceName,
  dbName,
  redisServiceName,
  redisSocket,
  redisStateDir,
}:
{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve Backup
# ==============================================================================

let
  cfg = config.hakula.services.cloudreve;
  isRemote = cfg.backup.toPath != null && lib.hasPrefix "b2:" cfg.backup.toPath;
in
{
  config = lib.mkIf (cfg.enable && cfg.backup.enable) {
    assertions = [
      {
        assertion = cfg.backup.toPath != null && cfg.backup.toPath != "";
        message = "hakula.services.cloudreve.backup.toPath must be set and not an empty string.";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.cloudreve-rclone-config = lib.mkIf isRemote {
      file = ../../../../secrets/shared/cloudreve-rclone-config.age;
      owner = serviceName;
      group = serviceName;
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Cloudreve backup service
    # --------------------------------------------------------------------------
    systemd.services.cloudreve-backup = {
      description = "Cloudreve backup";

      after = [
        "cloudreve.service"
      ]
      ++ lib.optionals isRemote [ "network-online.target" ];
      wants = lib.optionals isRemote [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = serviceName;
        Group = serviceName;
        StateDirectory = "${serviceName}-backup";
        StateDirectoryMode = "0700";
        UMask = "0077";
        PrivateTmp = true;
      };

      path = [
        pkgs.coreutils
        pkgs.gnutar
        pkgs.gzip
        pkgs.redis
        config.services.postgresql.package
      ]
      ++ lib.optionals isRemote [ pkgs.rclone ];

      script = ''
        set -euo pipefail

        cloudreveStateDir="/var/lib/${serviceName}";

        timestamp=$(date +%Y%m%d-%H%M%S)
        backupDir="$STATE_DIRECTORY/$timestamp"
        toPath="${lib.escapeShellArg cfg.backup.toPath}/$timestamp"

        install -d -m 0700 "$backupDir"

        echo "==> Dumping PostgreSQL database..."
        pg_dump -h /run/postgresql -U ${serviceName} -d ${dbName} >"$backupDir/cloudreve.sql"

        echo "==> Creating backend data archive..."
        tar -czf "$backupDir/backend_data.tgz" -C "$cloudreveStateDir" data

        echo "==> Creating Redis data archive..."
        redis-cli -s ${lib.escapeShellArg redisSocket} --rdb "$backupDir/dump.rdb"
        tar -czf "$backupDir/redis_data.tgz" -C "$backupDir" dump.rdb

        ${lib.optionalString isRemote ''
          echo "==> Uploading snapshot to remote storage..."
          rclone copy \
            --config ${lib.escapeShellArg config.age.secrets.cloudreve-rclone-config.path} \
            --progress \
            "$backupDir" \
            "$toPath"
        ''}

        ${lib.optionalString (!isRemote) ''
          echo "==> Copying snapshot to local destination..."
          install -d -m 0700 "$toPath"
          cp -a "$backupDir/." "$toPath/"
        ''}

        echo "==> Backup complete: $timestamp"
      '';
    };

    # --------------------------------------------------------------------------
    # Systemd timer
    # --------------------------------------------------------------------------
    systemd.timers.cloudreve-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "cloudreve-backup.service";
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };
  };
}
