# ==================================================================================================
# Feishu CalDAV Calendar Sync
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
  readCaldav = key: [
    (lib.getExe' pkgs.coreutils "cat")
    (secretPath "feishu/caldav/${key}")
  ];
in
lib.mkIf (config.hakula.llm-assistants.enable && hostType == "work" && isDesktop) {
  # ------------------------------------------------------------------------------------------------
  # Secrets
  # ------------------------------------------------------------------------------------------------
  hakula.secrets.required = {
    "feishu/caldav/password" = { };
    "feishu/caldav/url" = { };
    "feishu/caldav/username" = { };
  };

  # ------------------------------------------------------------------------------------------------
  # Calendar
  # ------------------------------------------------------------------------------------------------
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
}
