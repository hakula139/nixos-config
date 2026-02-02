{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Umami Backup Target
# ==============================================================================

let
  backupCfg = config.hakula.services.backup;
  backupUmamiCfg = config.hakula.services.backup.umami;
  umamiCfg = config.hakula.services.umami;

  serviceName = "umami";
  dbName = serviceName;

  stateDir = "/var/lib/backups/umami";
  restoreDir = "${stateDir}/restore";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.backup.umami = {
    enable = lib.mkEnableOption "Umami backup (PostgreSQL)";

    schedule = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "*-*-* 04:00:00";
      description = "Override the default schedule for Umami backup";
    };

    restoreSnapshot = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "latest";
      description = "Snapshot ID to restore from (e.g., 'latest', or a specific snapshot ID)";
    };
  };

  config = lib.mkIf (backupCfg.enable && backupUmamiCfg.enable) {
    assertions = [
      {
        assertion = umamiCfg.enable;
        message = "Umami backup requires Umami. Enable it via hakula.services.umami.enable = true.";
      }
    ];

    # --------------------------------------------------------------------------
    # Backup target configuration
    # --------------------------------------------------------------------------
    hakula.services.backup.targets.umami = {
      enable = true;

      schedule = backupUmamiCfg.schedule;

      paths = [ stateDir ];

      extraBackupArgs = [
        "--tag"
        "postgresql"
      ];

      runtimeInputs = [
        pkgs.util-linux
        config.services.postgresql.package
      ];

      heartbeatUrl = lib.mkDefault "https://uptime.betterstack.com/api/v1/heartbeat/CVksqJgmWW1KDKiiUEaSyHWw";

      prepareCommand = ''
        echo "==> Dumping PostgreSQL database..."
        runuser -u postgres -- pg_dump -d ${dbName} >"${stateDir}/umami.sql"

        echo "==> Backup preparation complete"
      '';

      cleanupCommand = ''
        rm -rf ${stateDir}
      '';

      restoreCommand = ''
        sqlFile="${restoreDir}${stateDir}/umami.sql"

        if [ -f "$sqlFile" ]; then
          echo "==> Restoring PostgreSQL database..."
          runuser -u postgres -- dropdb --if-exists ${dbName}
          runuser -u postgres -- createdb -O ${serviceName} ${dbName}
          runuser -u postgres -- psql -d ${dbName} -v ON_ERROR_STOP=1 <"$sqlFile"
        else
          echo "umami.sql not found in backup, skipping database restore"
        fi
      '';

      restoreSnapshot = backupUmamiCfg.restoreSnapshot;
    };
  };
}
