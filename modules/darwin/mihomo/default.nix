# ==================================================================================================
# Mihomo (Clash-Compatible Proxy Daemon)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  corpHosts,
  hostType,
  ...
}:

let
  cfg = config.hakula.services.mihomo;

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

  label = config.launchd.daemons.mihomo.serviceConfig.Label;
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
    # Directory management
    # ----------------------------------------------------------------------------------------------
    system.activationScripts.preActivation.text = lib.mkAfter ''
      install -dm0755 /var/lib
      install -dm0700 ${lib.escapeShellArg repoLib.mihomo.stateDir}
    '';

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    age.secrets.mihomo-secret = repoLib.secrets.mkSecret {
      name = "mihomo/secret";
      group = "wheel";
    };

    age.secrets.mihomo-subscription-url = repoLib.secrets.mkSecret {
      name = "mihomo/subscription-url";
      group = "wheel";
    };

    # ----------------------------------------------------------------------------------------------
    # Networking
    # ----------------------------------------------------------------------------------------------
    networking.dns = lib.mkIf cfg.tun.enable [
      "223.5.5.5"
      "119.29.29.29"
    ];

    system.activationScripts.networking.text = lib.mkAfter (
      lib.optionalString (config.networking.knownNetworkServices != [ ]) ''
        networkservices=$(networksetup -listallnetworkservices)
        ${lib.concatMapStringsSep "\n" (
          service:
          let
            serviceArg = lib.escapeShellArg service;
            proxyArgs = lib.escapeShellArgs [
              service
              "127.0.0.1"
              (toString repoLib.mihomo.mixedPort)
            ];
          in
          ''
            case "$networkservices" in
              *${serviceArg}*)
                networksetup -setwebproxy ${proxyArgs}
                networksetup -setwebproxystate ${serviceArg} on
                networksetup -setsecurewebproxy ${proxyArgs}
                networksetup -setsecurewebproxystate ${serviceArg} on
                networksetup -setsocksfirewallproxy ${proxyArgs}
                networksetup -setsocksfirewallproxystate ${serviceArg} on
                networksetup -setautoproxystate ${serviceArg} off
                ;;
            esac
          ''
        ) config.networking.knownNetworkServices}
      ''
    );

    # ----------------------------------------------------------------------------------------------
    # Launchd daemons
    # ----------------------------------------------------------------------------------------------
    launchd.daemons.mihomo = {
      command = lib.escapeShellArgs packages.startCommand;

      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        Umask = 63;
        StandardOutPath = "/var/log/mihomo.log";
        StandardErrorPath = "/var/log/mihomo.log";
      };
    };

    launchd.daemons.mihomo-update = {
      script = "${lib.getExe packages.update} && /bin/launchctl kill SIGHUP system/${label}";

      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 4;
            Minute = 0;
          }
        ];

        Umask = 63;
        StandardOutPath = "/var/log/mihomo-update.log";
        StandardErrorPath = "/var/log/mihomo-update.log";
      };
    };
  };
}
