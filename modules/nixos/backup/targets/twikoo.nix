{
  config,
  pkgs,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Twikoo Backup Target
# ==============================================================================

let
  backupServiceName = "backup";
  backupCfg = config.hakula.services.backup;
  backupTwikooCfg = config.hakula.services.backup.twikoo;

  stateDir = "/var/lib/backups/twikoo";
  exportCollections = [
    "comment"
    "counter"
    "config"
  ];
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.backup.twikoo = {
    enable = lib.mkEnableOption "Twikoo backup via API export";

    apiUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://twikoo-api.hakula.xyz";
      description = "Twikoo API endpoint URL";
    };

    schedule = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "*-*-* 04:00:00";
      description = "Override the default schedule for Twikoo backup";
    };
  };

  config = lib.mkIf (backupCfg.enable && backupTwikooCfg.enable) {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.twikoo-access-token = secrets.mkSecret {
      name = "twikoo-access-token";
      owner = backupServiceName;
      group = backupServiceName;
    };

    # --------------------------------------------------------------------------
    # Backup target configuration
    # --------------------------------------------------------------------------
    hakula.services.backup.targets.twikoo = {
      enable = true;

      schedule = backupTwikooCfg.schedule;

      paths = [ stateDir ];

      extraBackupArgs = [
        "--tag"
        "api-export"
      ];

      runtimeInputs = [
        pkgs.curl
      ];

      heartbeatUrl = lib.mkDefault "https://uptime.betterstack.com/api/v1/heartbeat/CrDMRbSCsaR1v45b71Ybr8yv";

      prepareCommand = ''
        TWIKOO_ACCESS_TOKEN=$(cat ${config.age.secrets.twikoo-access-token.path})

        apiUrl=${lib.escapeShellArg backupTwikooCfg.apiUrl}

        for collection in ${lib.concatStringsSep " " exportCollections}; do
          echo "==> Exporting $collection..."

          payload=$(printf '{
            "event": "COMMENT_EXPORT_FOR_ADMIN",
            "accessToken": "%s",
            "collection": "%s"
          }' "$TWIKOO_ACCESS_TOKEN" "$collection")

          curl -fsSL -X POST "$apiUrl" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            -o "${stateDir}/twikoo.$collection.json"
        done
      '';

      cleanupCommand = ''
        rm -rf ${stateDir}
      '';
    };
  };
}
