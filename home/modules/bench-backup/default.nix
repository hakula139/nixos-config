# ==================================================================================================
# Private Bench Backup
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  secretPath,
  ...
}:

let
  cfg = config.hakula.bench-backup;
  stateDir = "${config.xdg.stateHome}/bench-backup";
  logDir = "${config.home.homeDirectory}/Library/Logs/bench-backup";

  restic = lib.findFirst (package: package.name == "restic-bench") null config.home.packages;

  worker = repoLib.mkNuCommand {
    inherit pkgs;
    name = "bench-backup-worker";
    script = ./backup.nu;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sqlite
    ];
    config = {
      inherit (cfg) dataDir;
      restic = lib.getExe restic;
    };
  };

  command = pkgs.writeShellApplication {
    name = "bench-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.flock
    ];
    text = ''
      umask 077
      install -dm0700 ${lib.escapeShellArg stateDir}
      exec flock -n ${lib.escapeShellArg "${stateDir}/run.lock"} ${lib.getExe worker} "$@"
    '';
  };

  agent = mode: schedule: {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe command)
        mode
      ];
      StartCalendarInterval = schedule;
      Umask = 63;
      StandardOutPath = "${logDir}/${mode}.log";
      StandardErrorPath = "${logDir}/${mode}.log";
    };
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.bench-backup = {
    enable = lib.mkEnableOption "encrypted hourly backups of private bench data on macOS";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/assistant-bench";
      description = "Private bench data directory";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "hakula.bench-backup requires macOS.";
      }
    ];

    hakula.secrets.required = {
      "bench-backup/env" = { };
      "bench-backup/password" = { };
      "bench-backup/repository" = { };
    };

    services.restic = {
      enable = true;
      backups.bench = {
        environmentFile = secretPath "bench-backup/env";
        passwordFile = secretPath "bench-backup/password";
        repositoryFile = secretPath "bench-backup/repository";
      };
    };

    home.packages = [ command ];

    launchd.agents = {
      bench-backup = agent "backup" { Minute = 0; };
      bench-backup-maintain = agent "maintain" {
        Weekday = 0;
        Hour = 4;
        Minute = 30;
      };
    };

    home.activation.benchBackupDirectories =
      lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ]
        ''
          run install -dm0700 ${
            lib.escapeShellArgs [
              stateDir
              logDir
            ]
          }
        '';
  };
}
