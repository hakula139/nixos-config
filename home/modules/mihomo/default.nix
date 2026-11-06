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
  systemctl = config.systemd.user.systemctlPath;

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
    script = ./update.nu;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];

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

  startPackage = repoLib.mkNuCommand {
    inherit pkgs;
    name = "mihomo-start";
    script = ./start.nu;
    runtimeInputs = [
      mihomo
      updatePackage
    ];
    flags.config-dir = configDir;
  };

  # Go keeps an inherited SIG_IGN for SIGHUP until signal.Notify, so an early reload cannot kill the
  # start script or mihomo before mihomo handles it.
  startCommand = [
    (lib.getExe' pkgs.coreutils "env")
    "--ignore-signal=HUP"
    (lib.getExe startPackage)
  ];

  updateReloadPackage = repoLib.mkNuCommand {
    inherit pkgs;
    name = "mihomo-update-reload";
    script = ./update-reload.nu;
    runtimeInputs = [ updatePackage ];
    flags.label = mihomoLabel;
  };

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
          ExecStart = updateScript;
          ExecStartPost = "${systemctl} --user try-reload-or-restart mihomo.service";
          RemainAfterExit = false;
        };
      };

      mihomo = {
        Unit = repoLib.systemd.restartLimit // {
          Description = "Mihomo proxy service";
        };

        Service = repoLib.systemd.restart // {
          Type = "simple";
          ExecStart = lib.concatStringsSep " " startCommand;
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
          ProgramArguments = [ (lib.getExe updateReloadPackage) ];
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
          ProgramArguments = startCommand;
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
