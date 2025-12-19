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
in
{
  config = lib.mkIf (cfg.enable && cfg.restore.enable) {
    # --------------------------------------------------------------------------
    # Cloudreve restore service
    # --------------------------------------------------------------------------
    systemd.services.cloudreve-restore = {
      description = "Cloudreve restore from backup";

      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      before = [
        "cloudreve.service"
      ]
      ++ lib.optionals (cfg.restore.redisDataTgz != null) [ redisUnit ];
      wantedBy = [
        "cloudreve.service"
      ]
      ++ lib.optionals (cfg.restore.redisDataTgz != null) [ redisUnit ];

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
      ];

      script = ''
        set -euo pipefail

        marker="$STATE_DIRECTORY/.restore-complete"
        if [ -f "$marker" ]; then
          exit 0
        fi

        install -d -m 0750 "$STATE_DIRECTORY/data"

        sqlFile=${if cfg.restore.sqlFile != null then lib.escapeShellArg cfg.restore.sqlFile else "''"}
        if [ -n "$sqlFile" ]; then
          if [ ! -f "$sqlFile" ]; then
            echo "cloudreve-restore: missing sql dump: $sqlFile" >&2
            exit 1
          fi

          echo "==> Restoring PostgreSQL database..."
          runuser -u postgres -- dropdb --if-exists -h /run/postgresql ${dbName}
          runuser -u postgres -- createdb -h /run/postgresql -O ${serviceName} ${dbName}
          runuser -u ${serviceName} -- psql -h /run/postgresql -U ${serviceName} -d ${dbName} -v ON_ERROR_STOP=1 <"$sqlFile"
        fi

        backendTgz=${
          if cfg.restore.backendDataTgz != null then lib.escapeShellArg cfg.restore.backendDataTgz else "''"
        }
        if [ -n "$backendTgz" ]; then
          if [ ! -f "$backendTgz" ]; then
            echo "cloudreve-restore: missing backend_data.tgz: $backendTgz" >&2
            exit 1
          fi

          echo "==> Restoring backend data..."
          tar -xzf "$backendTgz" -C "$STATE_DIRECTORY" --no-same-owner --no-same-permissions
          chown -R ${serviceName}:${serviceName} "$STATE_DIRECTORY"
        fi

        redisTgz=${
          if cfg.restore.redisDataTgz != null then lib.escapeShellArg cfg.restore.redisDataTgz else "''"
        }
        if [ -n "$redisTgz" ]; then
          if [ ! -f "$redisTgz" ]; then
            echo "cloudreve-restore: missing redis_data.tgz: $redisTgz" >&2
            exit 1
          fi

          echo "==> Restoring Redis data..."
          install -d -m 0750 -o ${redisUser} -g ${redisGroup} "${redisStateDir}"
          tar -xzf "$redisTgz" -C "${redisStateDir}" --no-same-owner --no-same-permissions
          chown -R ${redisUser}:${redisGroup} "${redisStateDir}"
          chmod 0600 "${redisStateDir}/dump.rdb" 2>/dev/null || true
        fi

        echo "==> Marking restore as complete..."
        touch "$marker"
        chown ${serviceName}:${serviceName} "$marker"

        echo "==> Restore complete: $timestamp"
      '';
    };
  };
}
