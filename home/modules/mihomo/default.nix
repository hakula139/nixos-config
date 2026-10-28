# ==================================================================================================
# Mihomo - Clash-compatible proxy service
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
  inherit (pkgs) mihomo;
  inherit (pkgs.stdenv) isDarwin;

  esc = lib.escapeShellArg;

  cfg = config.hakula.mihomo;
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Paths
  # ------------------------------------------------------------------------------------------------
  homeDir = config.home.homeDirectory;
  configDir = "${homeDir}/.config/mihomo";

  secretFile = secretPath "mihomo/secret";
  subscriptionUrlFile = secretPath "mihomo/subscription-url";

  # ------------------------------------------------------------------------------------------------
  # Config update
  # ------------------------------------------------------------------------------------------------
  baseConfigFile = pkgs.writeText "mihomo-base.yaml" (
    builtins.replaceStrings
      [ "__PORT__" "__CONTROLLER_PORT__" ]
      [ (toString cfg.port) (toString cfg.controllerPort) ]
      (builtins.readFile ./config.yaml)
  );

  updateConfig = json.generate "mihomo-update.json" {
    inherit
      baseConfigFile
      configDir
      secretFile
      subscriptionUrlFile
      ;
    inherit (repoLib.proxy) proxyVars;

    curlArgs = repoLib.curl.mkArgs {
      connectTimeout = 10;
      maxTime = 60;
    };
  };

  updatePackage = pkgs.writers.writeNuBin "mihomo-update" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.curl ])

      "--add-flag"
      "${updateConfig}"
    ];
  } (builtins.readFile ./mihomo-update.nu);

  updateScript = lib.getExe updatePackage;

  # ------------------------------------------------------------------------------------------------
  # Service
  # ------------------------------------------------------------------------------------------------
  mihomoLabel = "one.metacubex.mihomo";

  updateReloadScript = pkgs.writeShellScript "mihomo-update-reload" ''
    set -euo pipefail

    ${updateScript}

    /bin/launchctl kill SIGHUP "gui/$(id -u)/${mihomoLabel}"
  '';

  startScript = pkgs.writeShellScript "mihomo-start" ''
    set -euo pipefail

    # Ignored until mihomo's signal.Notify takes over. An early SIGHUP kills the wrapper or mihomo.
    trap "" HUP

    echo "Updating config before start..."
    if ! ${updateScript}; then
      if [[ -f ${esc configDir}/config.yaml ]]; then
        echo >&2 "Warning: subscription update failed, starting mihomo from the previous config"
      else
        echo >&2 "Error: subscription update failed and no config exists in" ${esc configDir}
        exit 1
      fi
    fi

    echo "Starting mihomo..."
    exec ${lib.getExe mihomo} -d ${esc configDir}
  '';
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
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

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = {
      "mihomo/secret" = { };
      "mihomo/subscription-url" = { };
    };

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    home.packages = [ mihomo ];

    # ----------------------------------------------------------------------------------------------
    # Systemd services (Linux)
    # ----------------------------------------------------------------------------------------------
    systemd.user.services = lib.mkIf (!isDarwin) {
      mihomo-update = {
        Unit = {
          Description = "Update mihomo subscription config";
          After = [ "network-online.target" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${updateScript}";
          ExecStartPost = "${config.systemd.user.systemctlPath} --user try-reload-or-restart mihomo.service";
          RemainAfterExit = false;
        };
      };

      mihomo = {
        Unit = {
          Description = "Mihomo proxy service";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = repoLib.systemd.restart // {
          Type = "simple";
          ExecStart = "${startScript}";
          ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Systemd timer (Linux)
    # ----------------------------------------------------------------------------------------------
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

    # ----------------------------------------------------------------------------------------------
    # Launchd agents (macOS)
    # ----------------------------------------------------------------------------------------------
    launchd.agents = lib.mkIf isDarwin {
      mihomo-update = {
        enable = true;

        config = {
          Label = "one.metacubex.mihomo-update";
          ProgramArguments = [ "${updateReloadScript}" ];
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
          Label = mihomoLabel;
          ProgramArguments = [ "${startScript}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${homeDir}/Library/Logs/mihomo.log";
          StandardErrorPath = "${homeDir}/Library/Logs/mihomo.log";
        };
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Directory management
    # ----------------------------------------------------------------------------------------------
    home.activation.mihomoSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run install -d -m 0700 ${esc configDir}
    '';
  };
}
