# ==================================================================================================
# Activity Report
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  hostType,
  secretPath,
  isDesktop ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.hakula.llm-assistants.activity-report;
  json = pkgs.formats.json { };

  homeDir = config.home.homeDirectory;
  isWork = hostType == "work";

  digestConfig = json.generate "activity-digest.json" {
    context = hostType;
    gitRoots =
      if isDarwin then
        [ "${homeDir}/GitHub" ]
      else
        [
          "${homeDir}/github"
          "${homeDir}/gitlab"
        ];
  };

  digest = pkgs.writers.writeNuBin "activity-digest" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.git ])

      "--add-flag"
      "${digestConfig}"
    ];
  } (builtins.readFile ./activity-digest.nu);

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
  options.hakula.llm-assistants.activity-report.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.hakula.llm-assistants.enable && isDesktop;
    description = "Whether to install the activity-report skill and the digest it reads";
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
