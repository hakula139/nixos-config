# ==================================================================================================
# Activity Report
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  hostType,
  isDesktop,
  secretPath,
  ...
}:

let
  cfg = config.hakula.activity-report;

  isWork = hostType == "work";

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
    enable = lib.mkEnableOption "activity-report and its skill";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      programs.activity-report = {
        enable = true;
        package = pkgs.activity-report;
        skillDirectories = [ ];

        settings = {
          # Workmux worker sessions count as unattended since prompts come from the launching agent.
          excluded_dirs = [ "/[^/]+__worktrees/workmux-" ];

          assistants = {
            claude = config.lib.llmAssistants.claudeConfigDir;
            codex = config.lib.llmAssistants.codexConfigDir;
            omp = config.lib.llmAssistants.ompConfigDir;
          };

          labels = {
            default = [ hostType ];
            projects.nixos-config = lib.mkDefault [ "personal" ];
          };
        };
      };
    })

    (lib.mkIf (cfg.enable && isWork && isDesktop) {
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
