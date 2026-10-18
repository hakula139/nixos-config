# ==================================================================================================
# Activity Report
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  hostType,
  secretPath,
  ...
}:

let
  cfg = config.hakula.activity-report;

  homeDir = config.home.homeDirectory;
  isWork = hostType == "work";

  # ------------------------------------------------------------------------------------------------
  # Digest
  # ------------------------------------------------------------------------------------------------
  json = pkgs.formats.json { };

  digestConfig = json.generate "activity-digest.json" {
    context = hostType;
    inherit (cfg)
      excludedDirs
      worktreePatterns
      personalProjects
      readingMinutes
      maxMinutes
      agentMaxMinutes
      ;
    assistantDirs = {
      claude = "${homeDir}/.claude";
      codex =
        if config.home.preferXdgDirectories then "${config.xdg.configHome}/codex" else "${homeDir}/.codex";
      omp = "${homeDir}/.omp/agent";
    };
  };

  digest = pkgs.writers.writeNuBin "activity-digest" {
    makeWrapperArgs = [
      "--add-flag"
      "${digestConfig}"
    ];
  } (builtins.readFile ./activity-digest.nu);

  # ------------------------------------------------------------------------------------------------
  # Calendar
  # ------------------------------------------------------------------------------------------------
  caldavSecret = secretPath "feishu/caldav";
  readCaldav = key: [
    (lib.getExe pkgs.nushell)
    "--no-config-file"
    "--commands"
    "open --raw ${caldavSecret} | from toml | get ${key}"
  ];
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.activity-report = {
    enable = lib.mkEnableOption "activity-report skill and its digest command";

    excludedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # Workmux workers take their prompts from the agent that launched them.
      default = [ "__worktrees/" ];
      description = "Regexes matching session directories excluded from human hours and excerpts";
    };

    worktreePatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/\\.claude/worktrees/[^/]+.*$"
        "__worktrees/[^/]+.*$"
      ];
      description = "Regexes stripped from a session's working directory to recover its repository";
    };

    personalProjects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixos-config" ];
      description = "Projects reported as personal on every host, regardless of the host's context";
    };

    readingMinutes = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 10;
      description = "Minutes a prompt earns after its agent turn ends, for reading the reply";
    };

    maxMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Most minutes a single prompt can earn";
    };

    agentMaxMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = "Most agent minutes a single turn can earn";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [ digest ];
    })

    (lib.mkIf (cfg.enable && isWork) {
      # --------------------------------------------------------------------------------------------
      # Secrets
      # --------------------------------------------------------------------------------------------
      hakula.secrets.required."feishu/caldav" = { };

      # --------------------------------------------------------------------------------------------
      # Calendar
      # --------------------------------------------------------------------------------------------
      accounts.calendar = {
        basePath = "${config.xdg.dataHome}/calendars";
        accounts.feishu = {
          remote = {
            type = "caldav";
            passwordCommand = readCaldav "password";
          };
          local = {
            type = "filesystem";
            fileExt = ".ics";
          };
          vdirsyncer = {
            enable = true;
            urlCommand = readCaldav "url";
            userNameCommand = readCaldav "username";
            conflictResolution = "remote wins";
            timeRange = {
              start = "datetime.now() - timedelta(days=14)";
              end = "datetime.now() + timedelta(days=1)";
            };
          };
          khal = {
            enable = true;
            readOnly = true;
          };
        };
      };

      programs.vdirsyncer.enable = true;
      programs.khal = {
        enable = true;
        locale = {
          dateformat = "%Y-%m-%d";
          datetimeformat = "%Y-%m-%dT%H:%M:%S%z";
          longdateformat = "%Y-%m-%d";
          longdatetimeformat = "%Y-%m-%dT%H:%M:%S%z";
          timeformat = "%H:%M";
        };
      };
    })
  ];
}
