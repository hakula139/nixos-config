{
  config,
  pkgs,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Backup Service (Restic -> Backblaze B2)
# ==============================================================================

let
  cfg = config.hakula.services.backup;
  serviceName = "backup";
  resticServiceFor = name: "restic-backups-${name}";
  resticUnitFor = name: "${resticServiceFor name}.service";
  baseStateDir = "/var/lib/backups";
  stateDirFor = name: "${baseStateDir}/${name}";

  targetModule = import ./target-module.nix { inherit lib; };
  enabledTargets = lib.filterAttrs (_: t: t.enable) cfg.targets;
  heartbeatTargets = lib.filterAttrs (_: t: t.heartbeatUrl != null) enabledTargets;
  restoreTargets = lib.filterAttrs (_: t: t.restoreSnapshot != null) enabledTargets;
  allExtraGroups = lib.unique (lib.flatten (lib.mapAttrsToList (_: t: t.extraGroups) enabledTargets));

  mkRepository =
    path: name:
    "b2:${cfg.b2Bucket}:${
      lib.concatStringsSep "/" (
        lib.filter (p: p != "") [
          path
          name
        ]
      )
    }";

  repositoryFor = mkRepository cfg.backupPath;
in
{
  imports = [
    ./targets/cloudreve.nix
    ./targets/twikoo.nix
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
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
      description = "Base path within the B2 bucket (each target appends its name).";
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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.b2Bucket != "";
        message = "hakula.services.backup.b2Bucket must be set.";
      }
    ];

    # --------------------------------------------------------------------------
    # User & Group
    # --------------------------------------------------------------------------
    users.users.${serviceName} = {
      isSystemUser = true;
      group = serviceName;
      extraGroups = allExtraGroups;
    };
    users.groups.${serviceName} = { };

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.backup-env = secrets.mkSecret {
      name = "backup-env";
      owner = serviceName;
      group = serviceName;
    };

    age.secrets.backup-restic-password = secrets.mkSecret {
      name = "backup-restic-password";
      owner = serviceName;
      group = serviceName;
    };

    # --------------------------------------------------------------------------
    # Restic backups (for each target)
    # --------------------------------------------------------------------------
    services.restic.backups = lib.mapAttrs (
      name: targetCfg:
      let
        effectiveSchedule = if targetCfg.schedule != null then targetCfg.schedule else cfg.schedule;
        stateDir = stateDirFor name;
      in
      {
        initialize = true;
        user = serviceName;
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

    # --------------------------------------------------------------------------
    # Filesystem layout (for each target)
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${baseStateDir} 0750 ${serviceName} ${serviceName} -"
    ]
    ++ lib.mapAttrsToList (
      name: _: "d ${stateDirFor name} 0700 ${serviceName} ${serviceName} -"
    ) enabledTargets;

    # --------------------------------------------------------------------------
    # Systemd services (for each target)
    # --------------------------------------------------------------------------
    systemd.services = lib.mkMerge [
      # ------------------------------------------------------------------------
      # Restore services
      # ------------------------------------------------------------------------
      (lib.mapAttrs' (
        name: targetCfg:
        lib.nameValuePair "backup-restore-${name}" (
          let
            stateDir = stateDirFor name;
            restoreDir = "${stateDir}/restore";
            repository = repositoryFor name;
            runtimePath = lib.makeBinPath (
              [
                pkgs.coreutils
                pkgs.restic
                pkgs.util-linux
              ]
              ++ targetCfg.runtimeInputs
            );
          in
          {
            description = "Restore ${name} from Restic backup";

            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              Type = "oneshot";
              UMask = "0077";
              EnvironmentFile = config.age.secrets.backup-env.path;
            };

            path = [
              pkgs.coreutils
              pkgs.restic
              pkgs.util-linux
            ]
            ++ targetCfg.runtimeInputs;

            environment = {
              RESTIC_REPOSITORY = repository;
              RESTIC_PASSWORD_FILE = config.age.secrets.backup-restic-password.path;
            };

            script = ''
              set -euo pipefail
              export PATH="${runtimePath}:$PATH"

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

      # ------------------------------------------------------------------------
      # Heartbeat services
      # ------------------------------------------------------------------------
      (lib.mapAttrs' (
        name: targetCfg:
        lib.nameValuePair "backup-heartbeat-succeeded-${name}" (
          let
            heartbeatUrl = targetCfg.heartbeatUrl;
          in
          {
            description = "Report backup success for ${name} to heartbeat URL";
            serviceConfig = {
              Type = "oneshot";
              User = serviceName;
              Group = serviceName;
            };
            path = [
              pkgs.curl
            ];
            script = ''
              curl -fsSL -X POST ${lib.escapeShellArg heartbeatUrl} >/dev/null || true
            '';
          }
        )
      ) heartbeatTargets)

      (lib.mapAttrs' (
        name: targetCfg:
        lib.nameValuePair "backup-heartbeat-failed-${name}" (
          let
            heartbeatUrl = targetCfg.heartbeatUrl;
            resticUnit = resticUnitFor name;
          in
          {
            description = "Report backup failure for ${name} to heartbeat URL";
            serviceConfig = {
              Type = "oneshot";
              User = serviceName;
              Group = serviceName;
            };
            path = [
              pkgs.coreutils
              pkgs.curl
              pkgs.systemd
            ];
            script = ''
              code="''${EXIT_STATUS:-fail}"
              url="${lib.escapeShellArg heartbeatUrl}/$code"
              output="$(
                journalctl -u ${lib.escapeShellArg resticUnit} -n 100 --no-pager 2>&1 \
                  | head -c 20000
              )"
              curl -fsSL -X POST -d "$output" "$url" >/dev/null || true
            '';
          }
        )
      ) heartbeatTargets)

      # ------------------------------------------------------------------------
      # Unit dependencies for heartbeat services
      # ------------------------------------------------------------------------
      (lib.mapAttrs' (
        name: _:
        lib.nameValuePair (resticServiceFor name) {
          unitConfig = {
            OnSuccess = [ "backup-heartbeat-succeeded-${name}.service" ];
            OnFailure = [ "backup-heartbeat-failed-${name}.service" ];
          };
        }
      ) heartbeatTargets)
    ];
  };
}
