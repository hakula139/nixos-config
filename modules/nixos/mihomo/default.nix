# ==================================================================================================
# Mihomo (Clash-Compatible Proxy Service)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  hostType,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.mihomo;

  systemctl = "${config.systemd.package}/bin/systemctl";

  packages = repoLib.mihomo.mkPackages {
    inherit
      pkgs
      cfg
      corpHosts
      hostType
      ;
    secretFile = config.age.secrets.mihomo-secret.path;
    subscriptionUrlFile = config.age.secrets.mihomo-subscription-url.path;
  };

  hardening = repoLib.systemd.hardening // {
    User = "mihomo";
    Group = "mihomo";
    UMask = "0077";
    StateDirectory = "mihomo";
    StateDirectoryMode = "0700";
    CapabilityBoundingSet = if cfg.tun.enable then [ "CAP_NET_ADMIN" ] else "";
    AmbientCapabilities = lib.optionals cfg.tun.enable [ "CAP_NET_ADMIN" ];
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
    ];
  };

  updateHardening = hardening // {
    CapabilityBoundingSet = "";
    AmbientCapabilities = [ ];
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.mihomo = repoLib.mihomo.mkOptions;

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    age.secrets.mihomo-secret = repoLib.secrets.mkSecret {
      name = "mihomo/secret";
      owner = "mihomo";
      group = "mihomo";
    };

    age.secrets.mihomo-subscription-url = repoLib.secrets.mkSecret {
      name = "mihomo/subscription-url";
      owner = "mihomo";
      group = "mihomo";
    };

    # ----------------------------------------------------------------------------------------------
    # User & Group
    # ----------------------------------------------------------------------------------------------
    users.groups.mihomo = { };

    users.users.mihomo = {
      isSystemUser = true;
      group = "mihomo";
    };

    # ----------------------------------------------------------------------------------------------
    # Systemd services
    # ----------------------------------------------------------------------------------------------
    systemd.services.mihomo = lib.mkMerge [
      repoLib.systemd.restartUnit

      {
        description = "Mihomo proxy service";
        wantedBy = [ "multi-user.target" ];

        serviceConfig = hardening // {
          Type = "simple";
          ExecStart = lib.concatStringsSep " " packages.startCommand;
          ExecStartPost = "${packages.checkPort} --pid $MAINPID";
          ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
        };
      }
    ];

    systemd.services.mihomo-update = {
      description = "Update the mihomo subscription config";

      serviceConfig = updateHardening // {
        Type = "oneshot";
        ExecStart = lib.getExe packages.update;
        ExecStartPost = "+${systemctl} try-reload-or-restart mihomo.service";
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Systemd timer
    # ----------------------------------------------------------------------------------------------
    systemd.timers.mihomo-update = {
      description = "Timer for mihomo subscription updates";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "*-*-* 04:00:00";
        Persistent = true;
      };
    };
  };
}
