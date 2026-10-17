# ==================================================================================================
# Activity History
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  hostName,
  hostType,
  repoLib,
  secretPath,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.hakula.activity-history;
  json = pkgs.formats.json { };

  homeDir = config.home.homeDirectory;
  isWork = hostType == "work";

  caldavSecret = secretPath "feishu/caldav";
  readCaldav = key: [
    (lib.getExe pkgs.nushell)
    "--no-config-file"
    "--commands"
    "open --raw ${caldavSecret} | from toml | get ${key}"
  ];

  configFile = json.generate "activity-history.json" {
    host = hostName;
    root = "${homeDir}/synced/activity-history/${hostName}";
    userConfig = "${config.xdg.configHome}/activity-history/config.toml";
    fallback = if isWork then "work" else "personal";
    rules = [
      {
        match = "**/nixos-config*";
        context = "personal";
      }
    ];
    ignore = [ ];
    sources = [
      "claude"
      "codex"
      "omp"
      "git"
    ]
    ++ (
      if isWork then
        [
          "gitlab"
          "calendar"
        ]
      else
        [ "github" ]
    );
    gitRoots =
      if isDarwin then
        [ "${homeDir}/GitHub" ]
      else
        [
          "${homeDir}/github"
          "${homeDir}/gitlab"
        ];
    claude = "${config.home.profileDirectory}/bin/claude";
    window = {
      start = "10hr";
      end = "20hr";
    };
    lunch = {
      start = "12hr";
      end = "13hr";
    };
  };

  activityHistory = repoLib.wrapPackage {
    inherit pkgs;
    pkg = pkgs.activity-history;
    wrapArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath (
        if isWork then
          [
            pkgs.glab
            config.programs.khal.package
            config.programs.vdirsyncer.package
          ]
        else
          [ config.programs.gh.package ]
      ))
    ];
    envVars.ACTIVITY_HISTORY_CONFIG = "${configFile}";
  };

  runArgs = [
    (lib.getExe activityHistory)
    "run"
  ];
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.activity-history = {
    enable = lib.mkEnableOption "daily activity history of agent sessions, commits, and meetings";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      hakula.activity-history.enable = lib.mkDefault config.hakula.syncthing.enable;
    }

    (lib.mkIf cfg.enable {
      # --------------------------------------------------------------------------------------------
      # Packages
      # --------------------------------------------------------------------------------------------
      home.packages = [ activityHistory ];

      # --------------------------------------------------------------------------------------------
      # Shell aliases
      # --------------------------------------------------------------------------------------------
      programs.zsh.shellAliases.ah = "activity-history";
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

    (lib.mkIf (cfg.enable && !isDarwin) {
      # --------------------------------------------------------------------------------------------
      # Systemd services (Linux)
      # --------------------------------------------------------------------------------------------
      systemd.user.services.activity-history = {
        Unit = {
          Description = "Record and summarize the day's activity history";
          After = [ "network-online.target" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = lib.escapeShellArgs runArgs;
        };
      };

      # --------------------------------------------------------------------------------------------
      # Systemd timer (Linux)
      # --------------------------------------------------------------------------------------------
      systemd.user.timers.activity-history = {
        Unit = {
          Description = "Timer for the daily activity history";
        };

        Timer = {
          OnCalendar = "*-*-* 20:30:00";
          Persistent = true;
        };

        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    })

    (lib.mkIf (cfg.enable && isDarwin) {
      # --------------------------------------------------------------------------------------------
      # Launchd agents (macOS)
      # --------------------------------------------------------------------------------------------
      launchd.agents.activity-history = {
        enable = true;
        config = {
          Label = "com.hakula.activity-history";
          ProgramArguments = runArgs;
          StartCalendarInterval = [
            {
              Hour = 20;
              Minute = 30;
            }
          ];
          StandardOutPath = "${homeDir}/Library/Logs/activity-history.log";
          StandardErrorPath = "${homeDir}/Library/Logs/activity-history.log";
        };
      };
    })
  ];
}
