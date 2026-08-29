# ==============================================================================
# Mihomo - Clash-compatible proxy service
# ==============================================================================

{
  config,
  pkgs,
  lib,
  proxyLib,
  secretPath,
  ...
}:

let
  inherit (pkgs) mihomo;
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.hakula.mihomo;

  homeDir = config.home.homeDirectory;
  configDir = "${homeDir}/.config/mihomo";

  secretFile = secretPath "mihomo/secret";
  subscriptionUrlFile = secretPath "mihomo/subscription-url";

  baseConfigFile = pkgs.writeText "mihomo-base.yaml" (
    builtins.replaceStrings
      [ "__PORT__" "__CONTROLLER_PORT__" ]
      [ (toString cfg.port) (toString cfg.controllerPort) ]
      (builtins.readFile ./config.yaml)
  );

  updateConfig = pkgs.writeText "mihomo-update.json" (
    builtins.toJSON {
      inherit
        baseConfigFile
        configDir
        secretFile
        subscriptionUrlFile
        ;
      inherit (proxyLib) proxyVars;
    }
  );
  updatePackage = pkgs.writers.writeNuBin "mihomo-update" {
    makeWrapperArgs = [
      "--add-flag"
      "${updateConfig}"
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.curl ])
    ];
  } (builtins.readFile ./mihomo-update.nu);
  updateScript = "${updatePackage}/bin/mihomo-update";

  startScript = pkgs.writeShellScript "mihomo-start" ''
    set -euo pipefail

    echo "Updating config before start..."
    ${updateScript}

    echo "Starting mihomo..."
    exec ${mihomo}/bin/mihomo -d ${configDir}
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.mihomo = {
    enable = lib.mkEnableOption "Mihomo proxy service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7890;
      description = "Mixed port for HTTP / SOCKS proxy";
    };

    controllerPort = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "External controller API port";
    };

    updateInterval = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Systemd calendar interval for subscription updates";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    hakula.secrets.required = {
      "mihomo/secret" = { };
      "mihomo/subscription-url" = { };
    };

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    home.packages = [ mihomo ];

    # --------------------------------------------------------------------------
    # Systemd services (Linux)
    # --------------------------------------------------------------------------
    systemd.user.services = lib.mkIf (!isDarwin) {
      mihomo-update = {
        Unit = {
          Description = "Update mihomo subscription config";
          After = [ "network-online.target" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${updateScript}";
          RemainAfterExit = false;
        };
      };

      mihomo = {
        Unit = {
          Description = "Mihomo proxy service";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${startScript}";
          Restart = "on-failure";
          RestartSec = "5s";
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };

    # --------------------------------------------------------------------------
    # Systemd timer (Linux)
    # --------------------------------------------------------------------------
    systemd.user.timers = lib.mkIf (!isDarwin) {
      mihomo-update = {
        Unit = {
          Description = "Timer for mihomo subscription updates";
        };

        Timer = {
          OnCalendar = cfg.updateInterval;
          Persistent = true;
          Unit = "mihomo-update.service";
        };

        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    };

    # --------------------------------------------------------------------------
    # Launchd agents (macOS)
    # --------------------------------------------------------------------------
    launchd.agents = lib.mkIf isDarwin {
      mihomo-update = {
        enable = true;
        config = {
          Label = "one.metacubex.mihomo-update";
          ProgramArguments = [ "${updateScript}" ];
          StartCalendarInterval = [
            {
              Hour = 4;
              Minute = 0;
            }
          ];
          StandardOutPath = "${homeDir}/Library/Logs/mihomo-update.log";
          StandardErrorPath = "${homeDir}/Library/Logs/mihomo-update.log";
        };
      };

      mihomo = {
        enable = true;
        config = {
          Label = "one.metacubex.mihomo";
          ProgramArguments = [ "${startScript}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${homeDir}/Library/Logs/mihomo.log";
          StandardErrorPath = "${homeDir}/Library/Logs/mihomo.log";
        };
      };
    };

    # --------------------------------------------------------------------------
    # Directory management
    # --------------------------------------------------------------------------
    home.activation.mihomoSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      install -d -m 0700 "${configDir}"
    '';
  };
}
