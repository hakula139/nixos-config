{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Mihomo - Clash-compatible proxy service
# ==============================================================================

let
  cfg = config.hakula.mihomo;
  isDarwin = pkgs.stdenv.isDarwin;

  homeDir = config.home.homeDirectory;
  configDir = "${homeDir}/.config/mihomo";
  configFile = "${configDir}/config.yaml";
  subscriptionUrlFile = config.age.secrets.mihomo-subscription-url.path;
  secretFile = config.age.secrets.mihomo-secret.path;
  baseConfigTemplate = builtins.readFile ./config.yaml;

  updateScript =
    let
      runtimePath = lib.makeBinPath [
        pkgs.coreutils
        pkgs.curl
        pkgs.gnused
      ];
    in
    pkgs.writeShellScript "mihomo-update" ''
      set -euo pipefail
      export PATH="${runtimePath}"

      CONFIG_DIR="${configDir}"
      CONFIG_FILE="${configFile}"
      SUBSCRIPTION_URL="$(cat ${subscriptionUrlFile})"
      SECRET="$(cat ${secretFile})"
      BASE_CONFIG_TEMPLATE="${baseConfigTemplate}"

      mkdir -p "$CONFIG_DIR"

      echo "Fetching mihomo subscription from: $SUBSCRIPTION_URL"
      curl -fsSL "$SUBSCRIPTION_URL" -o "$CONFIG_FILE.tmp"

      if [ ! -s "$CONFIG_FILE.tmp" ]; then
        echo "Error: Downloaded config is empty"
        rm -f "$CONFIG_FILE.tmp"
        exit 1
      fi

      echo "Preparing base configuration with secrets"
      BASE_CONFIG=$(
        echo "$BASE_CONFIG_TEMPLATE" \
          | sed "s|__PORT__|${toString cfg.port}|g" \
          | sed "s|__CONTROLLER_PORT__|${toString cfg.controllerPort}|g" \
          | sed "s|__SECRET__|$SECRET|g"
      )

      echo "Merging base configuration with subscription"
      {
        echo "$BASE_CONFIG"
        echo
        cat "$CONFIG_FILE.tmp"
      } >"$CONFIG_FILE.merged"
      mv "$CONFIG_FILE.merged" "$CONFIG_FILE.tmp"

      if [ -f "$CONFIG_FILE" ]; then
        echo "Backing up existing config to $CONFIG_FILE.bak"
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
      fi

      mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
      echo "Successfully updated mihomo config"
    '';

  startScript = pkgs.writeShellScript "mihomo-start" ''
    set -euo pipefail

    echo "Updating config before start..."
    ${updateScript}

    echo "Starting mihomo..."
    exec ${pkgs.mihomo}/bin/mihomo -d ${configDir}
  '';
in
{
  # ----------------------------------------------------------------------------
  # Module Options
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

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets = lib.mkIf (!isNixOS) {
      mihomo-subscription-url = secrets.mkHomeSecret {
        name = "mihomo-subscription-url";
        inherit homeDir;
      };

      mihomo-secret = secrets.mkHomeSecret {
        name = "mihomo-secret";
        inherit homeDir;
      };
    };

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    home.packages = [ pkgs.mihomo ];

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
          Environment = [
            "HTTP_PROXY="
            "HTTPS_PROXY="
            "http_proxy="
            "https_proxy="
          ];
        };
      };

      mihomo = {
        Unit = {
          Description = "Mihomo proxy service";
          After = [
            "network-online.target"
            "mihomo-update.service"
          ];
          Wants = [
            "network-online.target"
            "mihomo-update.service"
          ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${pkgs.mihomo}/bin/mihomo -d ${configDir}";
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
          EnvironmentVariables = {
            HTTP_PROXY = "";
            HTTPS_PROXY = "";
            http_proxy = "";
            https_proxy = "";
          };
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
