# ==============================================================================
# Mihomo - Clash-compatible proxy service
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.hakula.mihomo;

  homeDir = config.home.homeDirectory;
  configDir = "${homeDir}/.config/mihomo";
  configFile = "${configDir}/config.yaml";

  secretPath = config.hakula.secrets.path;
  secretFile = secretPath "mihomo/secret";
  subscriptionUrlFile = secretPath "mihomo/subscription-url";

  baseConfig =
    builtins.replaceStrings
      [ "__PORT__" "__CONTROLLER_PORT__" ]
      [ (toString cfg.port) (toString cfg.controllerPort) ]
      (builtins.readFile ./config.yaml);

  updateScript =
    let
      runtimePath = lib.makeBinPath [
        pkgs.coreutils
        pkgs.curl
        pkgs.gawk
        pkgs.yq-go
      ];
    in
    pkgs.writeShellScript "mihomo-update" ''
      set -euo pipefail
      export PATH="${runtimePath}"

      CONFIG_DIR="${configDir}"
      CONFIG_FILE="${configFile}"
      SUBSCRIPTION_URL="$(cat ${subscriptionUrlFile})"
      export MIHOMO_SECRET="$(cat ${secretFile})"
      BASE_CONFIG_TEMPLATE=${lib.escapeShellArg baseConfig}

      mkdir -p "$CONFIG_DIR"

      echo "Fetching mihomo subscription from: $SUBSCRIPTION_URL"
      curl -fsSL "$SUBSCRIPTION_URL" -o "$CONFIG_FILE.tmp"

      if [ ! -s "$CONFIG_FILE.tmp" ]; then
        echo "Error: Downloaded config is empty"
        rm -f "$CONFIG_FILE.tmp"
        exit 1
      fi

      # Substitute the secret literally to avoid sed metachar corruption
      # when the secret contains `|`, `&`, or `\`. Awk reads MIHOMO_SECRET
      # from the environment and does not reinterpret it.
      echo "Preparing base configuration with secrets"
      BASE_CONFIG=$(
        printf '%s' "$BASE_CONFIG_TEMPLATE" \
          | awk '{
              s = ENVIRON["MIHOMO_SECRET"]
              while ((i = index($0, "__SECRET__")) > 0) {
                $0 = substr($0, 1, i - 1) s substr($0, i + length("__SECRET__"))
              }
              print
            }'
      )

      echo "Merging base configuration with subscription"
      {
        echo "$BASE_CONFIG"
        echo
        cat "$CONFIG_FILE.tmp"
      } >"$CONFIG_FILE.merged"
      mv "$CONFIG_FILE.merged" "$CONFIG_FILE.tmp"

      echo "Validating merged config"
      if ! yq -e '.' "$CONFIG_FILE.tmp" >/dev/null 2>&1; then
        echo "Error: merged config is not valid YAML; keeping previous config" >&2
        rm -f "$CONFIG_FILE.tmp"
        exit 1
      fi

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
    hakula.secrets.required = {
      "mihomo/secret" = { };
      "mihomo/subscription-url" = { };
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
