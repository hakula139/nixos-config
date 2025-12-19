{
  serviceName,
  dbName,
  redisServiceName,
  redisUnit,
  redisUser,
  redisGroup,
  redisStateDir,
}:
{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cloudreve Restore (from backup)
# ==============================================================================

let
  cfg = config.hakula.services.cloudreve;
  isRestoreEnabled = cfg.restore.fromPath != null;
  isRemote = cfg.restore.fromPath != null && lib.hasPrefix "b2:" cfg.restore.fromPath;
in
{
  config = lib.mkIf (cfg.enable && isRestoreEnabled) {
    assertions = [
      {
        assertion = cfg.restore.fromPath != "";
        message = "hakula.services.cloudreve.restore.fromPath must not be an empty string.";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.cloudreve-rclone-config = lib.mkIf isRemote {
      file = ../../../../secrets/shared/cloudreve-rclone-config.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Cloudreve restore service
    # --------------------------------------------------------------------------
    systemd.services.cloudreve-restore = {
      description = "Cloudreve restore from backup";

      after = [
        "postgresql.service"
      ]
      ++ lib.optionals isRemote [ "network-online.target" ];
      requires = [ "postgresql.service" ];
      wants = lib.optionals isRemote [ "network-online.target" ];
      before = [
        "cloudreve.service"
        redisUnit
      ];
      wantedBy = [
        "cloudreve.service"
        redisUnit
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = serviceName;
        StateDirectoryMode = "0750";
        UMask = "0077";
      };

      path = [
        pkgs.coreutils
        pkgs.gnutar
        pkgs.gzip
        pkgs.util-linux
        config.services.postgresql.package
      ]
      ++ lib.optionals isRemote [ pkgs.rclone ];

      script = ''
        set -euo pipefail

        marker="$STATE_DIRECTORY/.restore-complete"
        if [ -f "$marker" ]; then
          echo "Restore already completed, nothing to do"
          exit 0
        fi

        install -d -m 0750 "$STATE_DIRECTORY/data"

        fromPath=${lib.escapeShellArg cfg.restore.fromPath}

        ${lib.optionalString isRemote ''
          echo "==> Downloading snapshot from remote storage..."
          snapshotName=$(basename "$fromPath")
          restoreDir="$STATE_DIRECTORY/restore/$snapshotName"
          rm -rf "$restoreDir"
          install -d -m 0700 "$restoreDir"

          rclone copy \
            --config ${lib.escapeShellArg config.age.secrets.cloudreve-rclone-config.path} \
            --progress \
            "$fromPath" \
            "$restoreDir"
        ''}

        ${lib.optionalString (!isRemote) ''
          echo "==> Restoring from local snapshot..."
          restoreDir="$fromPath"
        ''}

        sqlFile="$restoreDir/cloudreve.sql"
        backendTgz="$restoreDir/backend_data.tgz"
        redisTgz="$restoreDir/redis_data.tgz"

        if [ -f "$sqlFile" ]; then
          echo "==> Restoring PostgreSQL database..."
          runuser -u postgres -- dropdb --if-exists -h /run/postgresql ${dbName}
          runuser -u postgres -- createdb -h /run/postgresql -O ${serviceName} ${dbName}
          runuser -u ${serviceName} -- psql -h /run/postgresql -U ${serviceName} -d ${dbName} -v ON_ERROR_STOP=1 <"$sqlFile"
        else
          echo "cloudreve.sql not found, skipping database restore"
        fi

        if [ -f "$backendTgz" ]; then
          echo "==> Restoring backend data..."
          tar -xzf "$backendTgz" -C "$STATE_DIRECTORY" --no-same-owner --no-same-permissions
          chown -R ${serviceName}:${serviceName} "$STATE_DIRECTORY"
        else
          echo "backend_data.tgz not found, skipping backend restore"
        fi

        if [ -f "$redisTgz" ]; then
          echo "==> Restoring Redis data..."
          install -d -m 0750 -o ${redisUser} -g ${redisGroup} "${redisStateDir}"
          tar -xzf "$redisTgz" -C "${redisStateDir}" --no-same-owner --no-same-permissions
          chown -R ${redisUser}:${redisGroup} "${redisStateDir}"
          chmod 0600 "${redisStateDir}/dump.rdb" 2>/dev/null || true
        else
          echo "redis_data.tgz not found, skipping Redis restore"
        fi

        echo "==> Marking restore as complete..."
        touch "$marker"
        chown ${serviceName}:${serviceName} "$marker"

        echo "==> Restore complete!"
      '';
    };
  };
}
