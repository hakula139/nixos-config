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
# Cloudreve Backup (to Backblaze B2 via rclone)
# ==============================================================================

let
  cfg = config.hakula.services.cloudreve;
in
{
  config = lib.mkIf (cfg.enable && cfg.backup.enable) {
    assertions = [
      {
        assertion = cfg.backup.remotePath != null;
        message = "hakula.services.cloudreve.backup.remotePath must be set (e.g., 'b2:bucket-name/cloudreve').";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.cloudreve-rclone-config = {
      file = ../../../../secrets/shared/cloudreve-rclone-config.age;
      owner = serviceName;
      group = serviceName;
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Cloudreve backup service
    # --------------------------------------------------------------------------
    systemd.services.cloudreve-backup = {
      description = "Cloudreve backup to Backblaze B2";

      after = [
        "network-online.target"
        "cloudreve.service"
      ];
      wants = [ "network-online.target" ];

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
        pkgs.rclone
        config.services.postgresql.package
      ];

      script =
        let
          cloudreveStateDir = "/var/lib/${serviceName}";
          rcloneConfig = config.age.secrets.cloudreve-rclone-config.path;
        in
        ''
          set -euo pipefail

          timestamp=$(date +%Y%m%d-%H%M%S)
          backupDir="$STATE_DIRECTORY/$timestamp"

          install -d -m 0700 "$backupDir"

          echo "==> Dumping PostgreSQL database..."
          pg_dump -h /run/postgresql -U ${serviceName} -d ${dbName} >"$backupDir/cloudreve.sql"

          echo "==> Creating backend data archive..."
          tar -czf "$backupDir/backend_data.tgz" -C "${cloudreveStateDir}" data

          echo "==> Creating Redis data archive..."
          redis-cli -s ${lib.escapeShellArg redisSocket} --rdb "$backupDir/dump.rdb"
          tar -czf "$backupDir/redis_data.tgz" -C "$backupDir" dump.rdb

          echo "==> Uploading to Backblaze B2..."
          rclone copy \
            --config "${rcloneConfig}" \
            --transfers ${toString cfg.backup.transfers} \
            --progress \
            "$backupDir" \
            ${lib.escapeShellArg cfg.backup.remotePath}

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
