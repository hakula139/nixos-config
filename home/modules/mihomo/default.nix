# ==================================================================================================
# Mihomo - Clash-compatible proxy service
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  repoLib,
  hostType,
  secretPath,
  ...
}:

let
  cfg = config.hakula.mihomo;
  isWork = hostType == "work";

  inherit (pkgs) mihomo;
  inherit (pkgs.stdenv) isDarwin;

  esc = lib.escapeShellArg;

  # ------------------------------------------------------------------------------------------------
  # Paths
  # ------------------------------------------------------------------------------------------------
  homeDir = config.home.homeDirectory;
  configDir = "${homeDir}/.config/mihomo";

  secretFile = secretPath "mihomo/secret";
  subscriptionUrlFile = secretPath "mihomo/subscription-url";

  # ------------------------------------------------------------------------------------------------
  # Base config
  # ------------------------------------------------------------------------------------------------
  baseConfig = {
    # ----------------------------------------------------------------------------------------------
    # Proxy Ports
    # ----------------------------------------------------------------------------------------------
    mixed-port = cfg.port;

    # ----------------------------------------------------------------------------------------------
    # Allow LAN
    # ----------------------------------------------------------------------------------------------
    allow-lan = true;
    bind-address = "*";

    # ----------------------------------------------------------------------------------------------
    # External Control
    # ----------------------------------------------------------------------------------------------
    external-controller = "0.0.0.0:${toString cfg.controllerPort}";

    # ----------------------------------------------------------------------------------------------
    # General
    # ----------------------------------------------------------------------------------------------
    mode = "rule";
    log-level = "info";
    ipv6 = true;
    unified-delay = true;
    tcp-concurrent = true;

    # ----------------------------------------------------------------------------------------------
    # Auto Update GEO
    # ----------------------------------------------------------------------------------------------
    geo-auto-update = true;
    geo-update-interval = 24;

    # ----------------------------------------------------------------------------------------------
    # Cache
    # ----------------------------------------------------------------------------------------------
    profile.store-selected = true;

    # ----------------------------------------------------------------------------------------------
    # DNS
    # ----------------------------------------------------------------------------------------------
    dns = {
      # --------------------------------------------------------------------------------------------
      # Basics
      # --------------------------------------------------------------------------------------------
      enable = true;
      prefer-h3 = true;
      ipv6 = true;
      use-system-hosts = true;

      # --------------------------------------------------------------------------------------------
      # Fake IP
      # --------------------------------------------------------------------------------------------
      enhanced-mode = "fake-ip";
      fake-ip-range = "198.18.0.1/16";
      fake-ip-filter = [
        "*.lan"
        "*.local"
      ];
      fake-ip-filter-mode = "blacklist";

      # --------------------------------------------------------------------------------------------
      # Upstreams
      # --------------------------------------------------------------------------------------------
      default-nameserver = [
        "223.5.5.5"
        "8.8.8.8"
      ];
      nameserver = [
        "https://doh.pub/dns-query"
        "https://dns.alidns.com/dns-query"
      ];
      fallback = [
        "https://dns.google/dns-query"
        "https://cloudflare-dns.com/dns-query"
      ];
      fallback-filter = {
        geoip = true;
        geoip-code = "CN";
        ipcidr = [
          "240.0.0.0/4"
        ];
      };
    }
    // lib.optionalAttrs isWork {
      nameserver-policy."+.${corpHosts.domain}" = "system";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Update command
  # ------------------------------------------------------------------------------------------------
  updatePackage = repoLib.mkNuCommand {
    inherit pkgs;
    name = "mihomo-update";
    script = ./mihomo-update.nu;
    runtimeInputs = [ pkgs.curl ];

    config = {
      inherit
        baseConfig
        configDir
        secretFile
        subscriptionUrlFile
        ;
      inherit (repoLib.proxy) proxyVars;

      curlArgs = [
        "-fsSL"

        "--connect-timeout"
        "10"

        "--max-time"
        "60"
      ];

      ruleProviders = lib.optionalAttrs isWork {
        Intranet = {
          type = "inline";
          behavior = "classical";
          payload = [
            "DOMAIN-SUFFIX,${corpHosts.domain}"
            "IP-CIDR,10.0.0.0/8,no-resolve"
          ];
        };
      };

      prependRules = lib.optionals isWork [
        "RULE-SET,Intranet,DIRECT"
      ];
    };
  };

  updateScript = lib.getExe updatePackage;

  # ------------------------------------------------------------------------------------------------
  # Service scripts
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

  portCheckPackage = repoLib.mkNuCommand {
    inherit pkgs;
    name = "mihomo-check-port";
    script = ./check-port.nu;
    runtimeInputs = [ pkgs.iproute2 ];
    flags.port = toString cfg.port;
  };

  portCheckScript = lib.getExe portCheckPackage;
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
    home.packages = [
      mihomo
    ];

    # ----------------------------------------------------------------------------------------------
    # Systemd services (Linux)
    # ----------------------------------------------------------------------------------------------
    systemd.user.services = lib.mkIf (!isDarwin) {
      mihomo-update = {
        Unit = {
          Description = "Update mihomo subscription config";
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${updateScript}";
          ExecStartPost = "${config.systemd.user.systemctlPath} --user try-reload-or-restart mihomo.service";
          RemainAfterExit = false;
        };
      };

      mihomo = {
        Unit = repoLib.systemd.restartLimit // {
          Description = "Mihomo proxy service";
        };

        Service = repoLib.systemd.restart // {
          Type = "simple";
          ExecStart = "${startScript}";
          ExecStartPost = "${portCheckScript} --pid $MAINPID";
          ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
        };

        Install = {
          WantedBy = [
            "default.target"
          ];
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
          WantedBy = [
            "timers.target"
          ];
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
      run install -dm0700 ${esc configDir}
    '';
  };
}
