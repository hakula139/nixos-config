# ==================================================================================================
# Backup Service (Restic -> Backblaze B2)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  backblaze,
  repoLib,
  ...
}:

let
  esc = lib.escapeShellArg;

  cfg = config.hakula.services.backup;
  serviceName = "backup";

  baseStateDir = "/var/lib/backups";
  stateDirFor = name: "${baseStateDir}/${name}";

  resticServiceFor = name: "restic-backups-${name}";
  heartbeatServiceFor = result: name: "backup-heartbeat-${result}-${name}";
  restoreServiceFor = name: "backup-restore-${name}";

  targetModule = import ./target-module.nix { inherit lib; };
  enabledTargets = lib.filterAttrs (_: t: t.enable) cfg.targets;
  heartbeatTargets = lib.filterAttrs (_: t: t.heartbeatUrl != null) enabledTargets;
  restoreTargets = lib.filterAttrs (_: t: t.restoreSnapshot != null) enabledTargets;
  allExtraGroups = lib.unique (lib.flatten (lib.mapAttrsToList (_: t: t.extraGroups) enabledTargets));

  repositoryFor =
    name:
    "s3:https://${backblaze.s3Endpoint}/${cfg.b2Bucket}/${
      lib.concatStringsSep "/" (
        lib.filter (p: p != "") [
          cfg.backupPath
          name
        ]
      )
    }";

  # Above restic's 15-minute backend retry window, so only a stalled run hits it.
  resticTimeout = "1h";

  heartbeatCurlArgs = lib.escapeShellArgs (
    repoLib.curl.mkArgs {
      connectTimeout = 10;
      maxTime = 30;
    }
  );

  heartbeatServiceConfig = {
    Type = "oneshot";
    User = serviceName;
    Group = serviceName;
  };
in
{
  imports = [
    ./targets/cloudreve.nix
    ./targets/peertube.nix
    ./targets/umami.nix
  ];

  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.backup = {
    enable = lib.mkEnableOption "Restic backup service to Backblaze B2";

    b2Bucket = lib.mkOption {
      type = lib.types.str;
      example = "hakula-backup";
      description = "Backblaze B2 bucket name";
    };

    backupPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "cloudcone-sc2";
      description = "Base path within the B2 bucket (each target appends its name)";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 04:00:00";
      description = "Default schedule for backups";
    };

    retention = {
      daily = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "Default number of daily backups to keep";
      };

      weekly = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Default number of weekly backups to keep";
      };

      monthly = lib.mkOption {
        type = lib.types.int;
        default = 6;
        description = "Default number of monthly backups to keep";
      };
    };

    targets = lib.mkOption {
      type = lib.types.attrsOf targetModule;
      default = { };
      description = "Backup targets to configure";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.b2Bucket != "";
        message = "hakula.services.backup.b2Bucket must be set.";
      }
    ];

    # ----------------------------------------------------------------------------------------------
    # User & Group
    # ----------------------------------------------------------------------------------------------
    users.users.${serviceName} = {
      isSystemUser = true;
      group = serviceName;
      extraGroups = [ "systemd-journal" ] ++ allExtraGroups;
    };

    users.groups.${serviceName} = { };

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    age.secrets.backup-env = repoLib.secrets.mkSecret {
      name = "backup/env";
      owner = serviceName;
      group = serviceName;
    };

    age.secrets.backup-restic-password = repoLib.secrets.mkSecret {
      name = "backup/restic-password";
      owner = serviceName;
      group = serviceName;
    };

    # ----------------------------------------------------------------------------------------------
    # Filesystem layout (for each target)
    # ----------------------------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${baseStateDir} 0750 ${serviceName} ${serviceName} -"
    ]
    ++ lib.mapAttrsToList (
      name: _: "d ${stateDirFor name} 0700 ${serviceName} ${serviceName} -"
    ) enabledTargets;

    # ----------------------------------------------------------------------------------------------
    # Restic backups (for each target)
    # ----------------------------------------------------------------------------------------------
    services.restic.backups = lib.mapAttrs (
      name: targetCfg:
      let
        effectiveSchedule = if targetCfg.schedule != null then targetCfg.schedule else cfg.schedule;
        stateDir = stateDirFor name;
      in
      {
        initialize = true;
        repository = repositoryFor name;
        environmentFile = config.age.secrets.backup-env.path;
        passwordFile = config.age.secrets.backup-restic-password.path;

        paths = if targetCfg.paths != [ ] then targetCfg.paths else [ stateDir ];

        extraBackupArgs = [
          "--tag"
          name
        ]
        ++ targetCfg.extraBackupArgs;

        backupPrepareCommand =
          let
            runtimePath = lib.makeBinPath (
              [
                pkgs.coreutils
              ]
              ++ targetCfg.runtimeInputs
            );
          in
          lib.optionalString (targetCfg.prepareCommand != "") ''
            set -euo pipefail
            export PATH="${runtimePath}:$PATH"

            rm -rf ${stateDir}
            install -d -m 0700 -o ${serviceName} -g ${serviceName} ${stateDir}

            ${targetCfg.prepareCommand}

            chown -R ${serviceName}:${serviceName} ${stateDir}
          '';

        backupCleanupCommand = lib.optionalString (targetCfg.cleanupCommand != "") ''
          ${targetCfg.cleanupCommand}
        '';

        pruneOpts = [
          "--keep-daily"
          (toString cfg.retention.daily)
          "--keep-weekly"
          (toString cfg.retention.weekly)
          "--keep-monthly"
          (toString cfg.retention.monthly)
        ];

        timerConfig = {
          OnCalendar = effectiveSchedule;
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      }
    ) enabledTargets;

    # ----------------------------------------------------------------------------------------------
    # Systemd services (for each target)
    # ----------------------------------------------------------------------------------------------
    systemd.services = lib.mkMerge [
      # --------------------------------------------------------------------------------------------
      # Backup units
      # --------------------------------------------------------------------------------------------
      (lib.mapAttrs' (
        name: targetCfg:
        lib.nameValuePair (resticServiceFor name) {
          serviceConfig.TimeoutStartSec = resticTimeout;
          unitConfig = lib.optionalAttrs (targetCfg.heartbeatUrl != null) {
            OnSuccess = [ "${heartbeatServiceFor "succeeded" name}.service" ];
            OnFailure = [ "${heartbeatServiceFor "failed" name}.service" ];
          };
        }
      ) enabledTargets)

      # --------------------------------------------------------------------------------------------
      # Heartbeat services
      # --------------------------------------------------------------------------------------------
      (lib.mapAttrs' (
        name: targetCfg:
        lib.nameValuePair (heartbeatServiceFor "succeeded" name) (
          let
            inherit (targetCfg) heartbeatUrl;
          in
          {
            description = "Report backup success for ${name} to heartbeat URL";
            serviceConfig = heartbeatServiceConfig;

            path = [
              pkgs.curl
            ];

            script = ''
              curl \
                ${heartbeatCurlArgs} \
                --location \
                --request POST \
                ${esc heartbeatUrl} >/dev/null || true
            '';
          }
        )
      ) heartbeatTargets)

      (lib.mapAttrs' (
        name: targetCfg:
        lib.nameValuePair (heartbeatServiceFor "failed" name) (
          let
            inherit (targetCfg) heartbeatUrl;
          in
          {
            description = "Report backup failure for ${name} to heartbeat URL";
            serviceConfig = heartbeatServiceConfig;

            path = [
              pkgs.coreutils
              pkgs.curl
              pkgs.systemd
            ];

            script = ''
              # init.scope mirrors -u's PID 1 match
              match=(
                _SYSTEMD_INVOCATION_ID="$MONITOR_INVOCATION_ID"
                +
                INVOCATION_ID="$MONITOR_INVOCATION_ID"
                _SYSTEMD_CGROUP=/init.scope
              )

              output="$(
                journalctl "''${match[@]}" -n 100 --no-pager 2>&1 \
                  | head -c 20000
              )"
              printf '%s' "$output" \
                | curl \
                  ${heartbeatCurlArgs} \
                  --location \
                  --request POST \
                  --data-binary @- \
                  ${esc "${heartbeatUrl}/fail"} >/dev/null || true
            '';
          }
        )
      ) heartbeatTargets)

      # --------------------------------------------------------------------------------------------
      # Restore services
      # --------------------------------------------------------------------------------------------
      (lib.mapAttrs' (
        name: targetCfg:
        lib.nameValuePair (restoreServiceFor name) (
          let
            stateDir = stateDirFor name;
            restoreDir = "${stateDir}/restore";
          in
          {
            description = "Restore ${name} from Restic backup";

            after = [
              "network-online.target"
            ];
            wants = [
              "network-online.target"
            ];

            serviceConfig = {
              Type = "oneshot";
              UMask = "0077";
              EnvironmentFile = config.age.secrets.backup-env.path;
              TimeoutStartSec = resticTimeout;
            };

            path = [
              pkgs.coreutils
              pkgs.restic
              pkgs.util-linux
            ]
            ++ targetCfg.runtimeInputs;

            environment = {
              RESTIC_REPOSITORY = repositoryFor name;
              RESTIC_PASSWORD_FILE = config.age.secrets.backup-restic-password.path;
            };

            script = ''
              set -euo pipefail

              rm -rf ${restoreDir}
              install -d -m 0700 -o ${serviceName} -g ${serviceName} ${restoreDir}

              echo "==> Restoring snapshot ${targetCfg.restoreSnapshot} from Restic..."
              restic restore ${targetCfg.restoreSnapshot} \
                --target ${restoreDir} \
                --path ${stateDir}

              echo "==> Running restore command..."
              ${targetCfg.restoreCommand}

              echo "==> Restore complete for ${name}!"
            '';
          }
        )
      ) restoreTargets)
    ];
  };
}
